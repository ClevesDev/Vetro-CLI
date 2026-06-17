import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:vetro/core/models/finding.dart';
import 'package:vetro/core/report/reporter.dart';

/// Reporter that formats findings as copy-pasteable remediation prompts for LLMs.
final class PromptReporter extends Reporter {
  const PromptReporter();

  @override
  String format(ProjectReport report) {
    final buffer = StringBuffer();
    final projectName = extractProjectName(report.projectPath);

    buffer.writeln('# 🤖 Vetro AI Remedy Prompts — $projectName');
    buffer.writeln('Generado el: ${report.analyzedAt.toIso8601String()}');
    buffer.writeln();
    buffer.writeln('Utiliza los siguientes prompts para alimentar a tu asistente de IA (Claude, ChatGPT, Copilot) y automatizar la refactorización.');
    buffer.writeln();

    final allFindings = report.allFindings;
    if (allFindings.isEmpty) {
      buffer.writeln('✨ **No se encontraron hallazgos de deuda. ¡El código está impecable!**');
      return buffer.toString();
    }

    // Group findings by file
    final byFile = <String, List<Finding>>{};
    for (final finding in allFindings) {
      byFile.putIfAbsent(finding.filePath, () => []).add(finding);
    }

    var index = 1;
    for (final entry in byFile.entries) {
      final filePath = entry.key;
      final findings = entry.value;
      final relPath = p.relative(filePath, from: report.projectPath);

      for (final finding in findings) {
        buffer.writeln('---');
        buffer.writeln();
        buffer.writeln('## 📌 Remedio #$index: ${finding.ruleName}');
        buffer.writeln();
        buffer.writeln('**Ubicación:** `${relPath}:${finding.line}`');
        buffer.writeln('**Severidad:** `${finding.severity.name.toUpperCase()}`');
        buffer.writeln('**Mensaje:** ${finding.message}');
        buffer.writeln();

        // Include code snippet if available
        final snippet = _getCodeSnippet(filePath, finding.line);
        if (snippet.isNotEmpty) {
          final ext = p.extension(filePath).replaceAll('.', '');
          buffer.writeln('### Código de Contexto:');
          buffer.writeln('```$ext');
          buffer.write(snippet);
          buffer.writeln('```');
          buffer.writeln();
        }

        // Include mathematical evidence details
        if (finding.evidence.isNotEmpty) {
          buffer.writeln('### Evidencia Métrica:');
          for (final ev in finding.evidence.entries) {
            buffer.writeln('- **${ev.key}**: `${ev.value}`');
          }
          buffer.writeln();
        }

        // Instructions for the LLM
        buffer.writeln('### 📋 Prompt / Instrucciones de Refactorización para la IA:');
        buffer.writeln('```text');
        buffer.writeln('Actúa como un ingeniero de software experto en refactorización de código limpio.');
        buffer.writeln('Refactoriza el fragmento de código arriba provisto para resolver el problema de deuda de IA detectado.');
        buffer.writeln();
        buffer.writeln('Problema: ${finding.ruleName}');
        buffer.writeln('Detalle: ${finding.message}');
        buffer.writeln();
        buffer.writeln('Directrices de Refactorización:');
        buffer.write(_getRemedyInstructions(finding.ruleId));
        buffer.writeln();
        buffer.writeln('Reglas estrictas de entrega:');
        buffer.writeln('1. Devuelve únicamente el fragmento de código refactorizado y limpio.');
        buffer.writeln('2. Mantén intactos los contratos de tipos de firma y el comportamiento funcional externo.');
        buffer.writeln('3. Reduce la complejidad y mejora la mantenibilidad de forma demostrable.');
        buffer.writeln('```');
        buffer.writeln();

        index++;
      }
    }

    return buffer.toString();
  }

  String _getCodeSnippet(String filePath, int line) {
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

  String _getRemedyInstructions(String ruleId) {
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

      _ =>
        '- Inspecciona el código afectado y simplifica su diseño.\n'
        '- Asegúrate de seguir principios de código limpio (Clean Code), SOLID, y de única responsabilidad.'
    };
  }
}
