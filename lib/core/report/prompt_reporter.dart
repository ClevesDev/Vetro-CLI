import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:vetro/core/models/finding.dart';
import 'package:vetro/core/report/reporter.dart';

/// Reporter that formats findings as copy-pasteable remediation prompts for LLMs
/// structured in three deterministic phases: Isolated Context, Negative Constraints,
/// and Solution Contract (vetro_core), ordered topologically by architectural impact.
final class PromptReporter extends Reporter {
  const PromptReporter();

  @override
  String format(ProjectReport report) {
    final buffer = StringBuffer();
    final projectName = extractProjectName(report.projectPath);

    buffer.writeln('# 🤖 Vetro AI Remedy Prompts — $projectName');
    buffer.writeln('Generado el: ${report.analyzedAt.toIso8601String()}');
    buffer.writeln();
    buffer.writeln(
      'Utiliza los siguientes prompts para alimentar a tu asistente de IA (Claude, ChatGPT, Copilot) y automatizar la refactorización.',
    );
    buffer.writeln();

    final allFindings = report.allFindings;
    if (allFindings.isEmpty) {
      buffer.writeln(
        '✨ **No se encontraron hallazgos de deuda. ¡El código está impecable!**',
      );
      return buffer.toString();
    }

    // Topological sorting of findings by architectural impact
    final sortedFindings = List<Finding>.from(allFindings)
      ..sort((a, b) {
        final orderA = _ruleTopologicalOrder(a.ruleId);
        final orderB = _ruleTopologicalOrder(b.ruleId);
        if (orderA != orderB) return orderA.compareTo(orderB);

        // Severity tie-breaker: error > warning > info
        final sevCompare = b.severity.index.compareTo(a.severity.index);
        if (sevCompare != 0) return sevCompare;

        // File path tie-breaker
        final pathCompare = a.filePath.compareTo(b.filePath);
        if (pathCompare != 0) return pathCompare;

        // Line tie-breaker
        return a.line.compareTo(b.line);
      });

    var index = 1;
    for (final finding in sortedFindings) {
      final filePath = finding.filePath;
      final relPath = p.relative(filePath, from: report.projectPath);
      final priority = _ruleTopologicalOrder(finding.ruleId);
      final category = _topologicalCategoryName(priority);

      buffer.writeln('---');
      buffer.writeln();
      buffer.writeln('## 📌 Remedio #$index: ${finding.ruleName}');
      buffer.writeln();
      buffer.writeln('**Prioridad Topológica:** Nivel $priority — $category');
      buffer.writeln('**Ubicación:** `$relPath:${finding.line}`');
      buffer.writeln('**Severidad:** `${finding.severity.name.toUpperCase()}`');
      buffer.writeln('**Mensaje:** ${finding.message}');
      buffer.writeln();

      // Phase 1: Isolated Code Context
      final enclosingDecl = finding.evidence['enclosing_declaration'];
      final snippet = _getCodeSnippet(filePath, finding.line);

      if (enclosingDecl != null && enclosingDecl.isNotEmpty) {
        final ext = p.extension(filePath).replaceAll('.', '');
        final name = finding.evidence['enclosing_name'] ?? 'función';
        buffer.writeln('### Código de Contexto:');
        buffer.writeln('```$ext');
        buffer.writeln('// Ámbito completo: $name en $relPath:${finding.line}');
        buffer.writeln(enclosingDecl);
        buffer.writeln('```');
        buffer.writeln();
      } else if (snippet.isNotEmpty) {
        final ext = p.extension(filePath).replaceAll('.', '');
        buffer.writeln('### Código de Contexto:');
        buffer.writeln('```$ext');
        buffer.write(snippet);
        buffer.writeln('```');
        buffer.writeln();
      }

      // Include metric evidence details
      final nonContextEvidence = Map<String, String>.from(finding.evidence)
        ..remove('enclosing_declaration')
        ..remove('enclosing_name')
        ..remove('clause');

      if (nonContextEvidence.isNotEmpty) {
        buffer.writeln('### Evidencia Métrica:');
        for (final ev in nonContextEvidence.entries) {
          buffer.writeln('- **${ev.key}**: `${ev.value}`');
        }
        buffer.writeln();
      }

      // Instructions for LLMs (Deterministic 3-phase template)
      buffer.writeln(
        '### 📋 Prompt / Instrucciones de Refactorización para la IA:',
      );
      buffer.writeln('```text');
      buffer.write(buildPromptForFinding(finding, report.projectPath));
      buffer.writeln();
      buffer.writeln('```');
      buffer.writeln();

      index++;
    }

    return buffer.toString();
  }

  /// Builds a self-contained, deterministic 3-phase prompt for an LLM to resolve [finding].
  static String buildPromptForFinding(Finding finding, String projectPath) {
    final relPath = p.relative(finding.filePath, from: projectPath);
    final enclosingDecl = finding.evidence['enclosing_declaration'];
    final buffer = StringBuffer();

    buffer.writeln(
      'Actúa como un ingeniero de software experto en refactorización de código limpio.',
    );
    buffer.writeln(
      'Refactoriza el fragmento de código provisto para resolver el problema de deuda detectado por Vetro:',
    );
    buffer.writeln();
    buffer.writeln('Problema: ${finding.ruleName} (${finding.ruleId})');
    buffer.writeln('Detalle: ${finding.message}');
    buffer.writeln('Ubicación: $relPath:${finding.line}');
    buffer.writeln();

    buffer.writeln('[1. CONTEXTO AISLADO]');
    buffer.writeln('Archivo: $relPath');
    buffer.writeln('Línea de inicio: ${finding.line}');
    if (enclosingDecl != null && enclosingDecl.isNotEmpty) {
      final name = finding.evidence['enclosing_name'] ?? 'método';
      buffer.writeln('Ámbito contenedor ($name):');
      buffer.writeln(enclosingDecl);
    } else if (finding.evidence.containsKey('clause')) {
      buffer.writeln('Fragmento afectado:');
      buffer.writeln(finding.evidence['clause']);
    }
    buffer.writeln();

    buffer.writeln('[2. RESTRICCIONES NEGATIVAS (PROHIBICIONES ESTRICTAS)]');
    buffer.writeln(_getNegativeConstraints(finding.ruleId));
    buffer.writeln();

    buffer.writeln('[3. CONTRATO DE SOLUCIÓN (vetro_core)]');
    buffer.writeln(_getSolutionContract(finding.ruleId));
    buffer.writeln();

    buffer.writeln('Directrices de Refactorización:');
    buffer.write(_getRemedyInstructions(finding.ruleId));
    buffer.writeln();
    buffer.writeln();

    buffer.writeln('Reglas estrictas de entrega:');
    buffer.writeln(
      '1. Devuelve únicamente el fragmento de código refactorizado y limpio.',
    );
    buffer.writeln(
      '2. Mantén intactos los contratos de tipos de firma y el comportamiento funcional externo.',
    );
    buffer.writeln(
      '3. Reduce la complejidad y mejora la mantenibilidad de forma demostrable.',
    );
    buffer.writeln(
      '4. Sin explicaciones conversacionales, comentarios superfluos ni saludos.',
    );

    return buffer.toString().trim();
  }

  static int _ruleTopologicalOrder(String ruleId) {
    return switch (ruleId) {
      'boundary_violation' || 'circular_dependency' => 1,
      'unchecked_boundary' => 2,
      'empty_catch' => 3,
      'cognitive_complexity' ||
      'cyclomatic_complexity' ||
      'halstead_complexity' => 4,
      'semantic_duplication' || 'copy_mutate' => 5,
      'low_cohesion' || 'tight_coupling' || 'low_entropy' => 6,
      _ => 7,
    };
  }

  static String _topologicalCategoryName(int priority) {
    return switch (priority) {
      1 => 'Arquitectura de Capas e Interfaces',
      2 => 'Flujo de Datos y Mapeo en Fronteras',
      3 => 'Gestión Resiliente de Errores e Infraestructura',
      4 => 'Complejidad Cognitiva y Flujo de Control',
      5 => 'Duplicación y Redundancia Semántica',
      6 => 'Cohesión y Acoplamiento Modular',
      _ => 'Calidad de Código y Mantenibilidad',
    };
  }

  static String _getNegativeConstraints(String ruleId) {
    return switch (ruleId) {
      'empty_catch' =>
        '- NO dejes el bloque catch vacío ni tragues silenciosamente el error.\n'
            '- NO captures Exception ni dynamic sin registrar log, relanzar o mapear.\n'
            '- NO envuelvas el cuerpo en otro bloque try/catch anidado innecesario.\n'
            '- NO agregues dependencias externas no declaradas (como fpdart o dartz).',

      'unchecked_boundary' =>
        '- NO captures excepciones crudas (Exception, Error, SocketException) en la capa de presentación.\n'
            '- NO expongas e.toString(), detalles de infraestructura o stack traces al estado de UI.\n'
            '- NO realices mapeos manuales inline dentro de controladores de vista.',

      'boundary_violation' =>
        '- NO importes dependencias de infraestructura ni presentación dentro del dominio.\n'
            '- NO violes el flujo unidireccional de dependencias de Clean Architecture.',

      'cognitive_complexity' || 'cyclomatic_complexity' =>
        '- NO agregues flags booleanos de control adicionales ni aumentes el anidamiento.\n'
            '- NO utilices múltiples niveles de if/else anidados ni bucles complejos dentro del mismo método.',

      _ =>
        '- NO introduzcas dependencias circulares ni rompas contratos de tipos existentes.\n'
            '- NO añadas código muerto, comentarios innecesarios ni dependencias externas sin justificación.',
    };
  }

  static String _getSolutionContract(String ruleId) {
    return switch (ruleId) {
      'empty_catch' =>
        '- Si la operación es falible en infraestructura/datos, refactoriza para devolver Result<T, FeatureFailure>.\n'
            '- Utiliza Result.guard() o Result.guardAsync() de package:vetro_core/vetro_core.dart.\n'
            '- Si la excepción es irrecuperable o de sistema, regístrala con el logger estructurado o propágala con rethrow;.',

      'unchecked_boundary' =>
        '- Asegura que el servicio o repositorio retorne Result<T, DomainFailure>.\n'
            '- Consume el resultado usando pattern matching con .when() o .fold().\n'
            '- Utiliza CompositeErrorMapper o una subclase de BaseFeatureErrorMapper<F> para traducir fallos a un UserMessage sanitizado.',

      'boundary_violation' =>
        '- Invierte la dependencia declarando una interfaz abstracta en el dominio e implementándola en la infraestructura.',

      'cognitive_complexity' || 'cyclomatic_complexity' =>
        '- Utiliza cláusulas de guardia (guard clauses) y retornos tempranos (early returns).\n'
            '- Emplea switch expressions y pattern matching de Dart 3 en lugar de if-else extensos.\n'
            '- Extrae bloques anidados a métodos auxiliares puros con nombres semánticos.',

      _ =>
        '- Sigue los principios SOLID y la arquitectura en capas.\n'
            '- Mantén alta cohesión y bajo acoplamiento entre módulos.',
    };
  }

  static String _getCodeSnippet(String filePath, int line) {
    try {
      final file = File(filePath);
      if (!file.existsSync()) return '';
      final lines = file.readAsLinesSync();
      if (lines.isEmpty) return '';

      // Normalize to 1-indexed range
      final start = (line - 5).clamp(1, lines.length);
      final end = (line + 5).clamp(1, lines.length);

      final snippet = StringBuffer();
      for (var i = start; i <= end; i++) {
        final prefix = (i == line) ? '👉 ' : '   ';
        snippet.writeln('$prefix$i: ${lines[i - 1]}');
      }
      return snippet.toString();
    } catch (_) {
      return '';
    }
  }

  static String _getRemedyInstructions(String ruleId) {
    return switch (ruleId) {
      'cognitive_complexity' =>
        '- Reduce el anidamiento de control. Utiliza guardias y retornos tempranos (early returns).\n'
            '- Simplifica y divide las condiciones complejas en booleanos descriptivos.\n'
            '- Si hay bucles profundamente anidados, extrae el cuerpo del bucle a una función pura independiente.',

      'cyclomatic_complexity' =>
        '- Reduce la cantidad de bifurcaciones de código.\n'
            '- Reemplaza estructuras complejas de if-else con lookups de diccionarios/mapas, expresiones de switch o despacho polimórfico si es adecuado.\n'
            '- Divide el método en métodos más pequeños y cohesionados.',

      'semantic_duplication' || 'copy_mutate' =>
        '- Esta lógica está duplicada en otra parte del codebase.\n'
            '- Extrae la estructura lógica común a una única función utilitaria o método helper parametrizado.\n'
            '- Reemplaza ambos bloques con llamadas a la nueva función compartida para eliminar la redundancia.',

      'low_entropy' =>
        '- Simplifica el código repetitivo o redundante (típico boilerplate generado por IA).\n'
            '- Usa abstracciones de mayor nivel, bucles declarativos, o mapeos en lugar de repetir bloques secuenciales similares.\n'
            '- Mejora la variedad semántica y expresividad de los nombres de variables.',

      'intent_gap' =>
        '- El código es complejo pero carece de documentación que explique las decisiones de diseño.\n'
            '- Añade un comentario de docstring descriptivo que responda a: ¿por qué se tomó esta decisión de diseño en lugar de una alternativa más simple?\n'
            '- Documenta cualquier suposición implícita o restricción matemática.',

      'halstead_complexity' =>
        '- El método tiene un volumen sintáctico y esfuerzo de diseño excesivo.\n'
            '- Divide esta función monolítica en sub-funciones separadas y de única responsabilidad.\n'
            '- Minimiza el número de variables locales activas simultáneamente en el mismo ámbito.',

      'low_cohesion' =>
        '- Los métodos de esta clase operan sobre variables y campos disjuntos, violando el Principio de Responsabilidad Única.\n'
            '- Considera dividir la clase en dos o más clases más pequeñas y especializadas.\n'
            '- Mueve los métodos no relacionados a las clases a las que realmente pertenecen.',

      'tight_coupling' =>
        '- Este archivo está demasiado acoplado a muchas dependencias.\n'
            '- Utiliza abstracciones (interfaces o clases abstractas) para desacoplar implementaciones concretas.\n'
            '- Aplica inyección de dependencias para desacoplar el flujo de control.',

      'circular_dependency' =>
        '- Existe una dependencia circular de importaciones.\n'
            '- Extrae los elementos comunes en ciclo a un nuevo archivo de hoja (leaf file) que no tenga dependencias hacia arriba.\n'
            '- O bien, consolida las partes interdependientes en un único módulo cohesivo.',

      'boundary_violation' =>
        '- Violación de capas en Arquitectura Limpia.\n'
            '- Invierte la dependencia declarando una interfaz en la capa interna y haciendo que la externa la implemente (Dependency Inversion).\n'
            '- Mueve las importaciones prohibidas de capas externas hacia las capas apropiadas.',

      'local_clustering_coefficient' =>
        '- Este archivo actúa como un puente caótico de dependencias.\n'
            '- Refactoriza la red de importaciones para agrupar módulos dependientes en submódulos más cohesivos.',

      'eigenvector_centrality' =>
        '- Este archivo es un embotellamiento central. Cualquier cambio aquí puede romper gran parte del sistema.\n'
            '- Simplifica su interfaz pública y modulariza sus componentes internos para reducir la carga de importaciones directas.',

      'fragile_test' =>
        '- El test está acoplado a detalles de implementación o tiene demasiados mocks.\n'
            '- Prueba el comportamiento observable de la interfaz pública (caja negra) en lugar de verificar interacciones internas de métodos privados.\n'
            '- Reduce el número de mocks e intenta usar stubs o datos reales en el test.',

      'empty_catch' =>
        '- Nunca tragues excepciones en silencio sin registrar log, re-lanzar o mapear.\n'
            '- Si la operación puede fallar previsiblemente, refactorízala para devolver Result<T, Failure>.\n'
            '- Si el fallo es irrecuperable, registra el error con un logger estructurado o propágalo usando rethrow;\n'
            '- Si es una operación de limpieza donde el fallo es intencional, añade un comentario de intención que justifique la decisión.',

      'unchecked_boundary' =>
        '- Las capas de presentación y controladores no deben capturar ni exponer excepciones crudas (Exception/Error).\n'
            '- Refactoriza la llamada subyacente para retornar un Result<T, FeatureFailure> desde la capa de dominio o infraestructura.\n'
            '- Utiliza FeatureErrorMapper o CompositeErrorMapper para traducir el fallo a un UserMessage sanitizado antes de reflejarlo en la UI.\n'
            '- Evita inyectar stack traces o detalles internos de infraestructura directamente en el estado de la vista.',

      _ =>
        '- Inspecciona el código afectado y simplifica su diseño.\n'
            '- Asegúrate de seguir principios de código limpio (Clean Code), SOLID, y de única responsabilidad.',
    };
  }
}
