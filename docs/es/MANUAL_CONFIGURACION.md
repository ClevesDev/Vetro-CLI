# Vetro-CLI: Manual Integral de Configuración y Uso

> **El Linter Arquitectónico y Firewall de Deuda Técnica para Dart, Flutter y Proyectos Políglotas.**

---

## 1. Visión General y Propósito

**Vetro-CLI** es un analizador estático de arquitectura y cortafuegos de deuda técnica. A diferencia de compiladores tradicionales o linters de sintaxis (como `dart analyze` o ESLint) que solo evalúan sintaxis léxica y tipos, Vetro inspecciona:
* **Flujo de Control Profundo en el AST:** Controladores de memoria sin liberar, fugas de lógica asíncrona dentro de métodos `build()` de UI y fronteras de excepción sin tipar.
* **Teoría de Redes y Grafos:** Dependencias circulares, puentes caóticos de modularidad, centralidad de autovectores (*eigenvector centrality*) y coeficientes de agrupamiento local en el grafo de dependencias.
* **Teoría de la Información y Complejidad:** Esfuerzo de Halstead, complejidad cognitiva, bifurcaciones ciclomáticas y entropía de Shannon.
* **Duplicación de Código:** Clones semánticos y mutaciones estructurales por copy-paste (`copy_mutate`).

### El AI Debt Score (0 - 100)
Vetro calcula una métrica compuesta de **Salud Arquitectónica**:
* **85 - 100 (Óptimo):** Arquitectura modular, cero fugas de memoria, separación estricta de capas. Código listo para producción.
* **70 - 84 (Estable):** Proyecto saludable con deuda técnica menor y controlada.
* **50 - 69 (En Riesgo):** Alta complejidad ciclomática o duplicación oculta; requiere refactorización planificada.
* **< 50 (Crítico):** Riesgo arquitectónico severo, dependencias circulares o violaciones del ciclo de vida de memoria.

---

## 2. Uso de la Interfaz de Línea de Comandos (CLI)

### Comandos de Análisis
```bash
# Analizar el directorio actual
vetro .

# Analizar un proyecto en una ruta específica
vetro /ruta/al/proyecto

# Exportar el reporte en formatos JSON, Markdown o Prompt de IA
vetro . --format json --output reporte.json
vetro . --format markdown --output reporte.md
vetro . --format prompt --export-remedies

# Ejecutar como Quality Gate en CI/CD (falla si existe algún hallazgo con severidad 'error')
vetro . --fail-on-severity error
```

### Comandos Especializados
```bash
# Inicializar un archivo de configuración base vetro.yaml
vetro init
vetro init --force

# Analizar únicamente archivos modificados en Git (diferenciales staged y de working tree)
vetro diff
vetro diff --format markdown

# Andamiar un módulo o feature bajo Arquitectura Limpia
vetro make feature autenticacion --state riverpod
```

### Tabla de Opciones y Parámetros
| Parámetro / Flag | Descripción | Valor por Defecto |
| :--- | :--- | :--- |
| `-f, --format` | Formato del reporte: `terminal`, `json`, `markdown`, `prompt` | `terminal` |
| `-o, --output` | Ruta de archivo donde se escribirá el reporte generado | `stdout` |
| `--fail-on-severity` | Termina con código `1` si hay hallazgos con severidad: `error`, `warning`, `info`, `none` | `none` |
| `-e, --exclude` | Patrones glob adicionales para excluir del análisis | `[]` |
| `--color / --no-color` | Activa o desactiva colores ANSI en la terminal | `true` |
| `-v, --verbose` | Muestra registros detallados de ejecución y depuración del AST | `false` |
| `-l, --language` | Fuerza un analizador de lenguaje específico: `dart`, `typescript`, `python`, `auto` | `auto` |
| `--export-remedies` | Exporta prompts automáticos de remediación con IA a `.vetro/remedies.md` | `false` |
| `-m, --max-remedies` | Cantidad máxima de prompts de remediación a exportar (o `"all"`) | `50` |

### Códigos de Salida (Exit Codes)
* **`0`**: Análisis exitoso sin violaciones que superen el umbral de `--fail-on-severity`.
* **`1`**: Se detectaron hallazgos que igualan o superan `--fail-on-severity` (Quality Gate roto).
* **`2`**: Error de sistema (flags inválidos, directorio inexistente o error de sintaxis en `vetro.yaml`).

---

## 3. Especificación del Archivo de Configuración (`vetro.yaml`)

Vetro descubre automáticamente el archivo `vetro.yaml` ubicado en la raíz del proyecto analizado.

### Esquema Completo del YAML
```yaml
vetro:
  # 1. Archivos a incluir en el escaneo
  include:
    - 'lib/*.dart'
    - 'lib/**/*.dart'

  # 2. Exclusiones globales (código generado, pruebas, artefactos de build)
  exclude:
    - '**/*.g.dart'
    - '**/*.drift.dart'
    - '**/*.freezed.dart'
    - '**/*.mocks.dart'
    - 'test/**'

  # 3. Configuración general de salida
  format: terminal       # terminal | json | markdown | prompt
  color: true
  verbose: false
  auto_exclude_generated: true

  # 4. Configuración granular por regla
  rules:
    <rule_id>:
      enabled: true | false               # Activa o desactiva la regla
      severity: error | warning | info    # Modifica el nivel de severidad
      exclude:                            # Exclusiones de ruta específicas para esta regla
        - 'lib/features/legado/**'
      thresholds:                         # Umbrales matemáticos personalizados
        <nombre_metrica>: <valor_numerico>
      options:                            # Opciones específicas de la regla
        <nombre_opcion>: <valor>
```

### Ejemplo de Configuración para Producción (`vetro.yaml`)
```yaml
vetro:
  include:
    - 'lib/*.dart'
    - 'lib/**/*.dart'
  exclude:
    - '**/*.g.dart'
    - '**/*.drift.dart'
    - '**/*.freezed.dart'
    - '**/*.mocks.dart'

  rules:
    # Protección Estricta de Memoria y Arquitectura
    unreleased_controllers:
      enabled: true
      severity: error

    business_logic_in_ui:
      enabled: true
      severity: error

    boundary_violation:
      enabled: true
      severity: error
      options:
        layers: ['domain', 'application', 'infrastructure', 'presentation']

    circular_dependency:
      enabled: true
      severity: warning

    unchecked_boundary:
      enabled: true
      severity: warning

    # Calibración de Umbrales
    cyclomatic_complexity:
      enabled: true
      severity: warning
      thresholds:
        max_complexity: 15.0

    cognitive_complexity:
      enabled: true
      severity: warning
      thresholds:
        max_cognitive_complexity: 15.0

    setState_in_complex_builds:
      enabled: true
      severity: warning
      thresholds:
        max_build_complexity: 12.0

    # Exclusiones Granulares por Módulo
    hardcoded_ui_tokens:
      enabled: true
      severity: info
      exclude:
        - 'lib/features/carnetizacion/**'
        - 'lib/features/caja/services/pdf/**'

    copy_mutate:
      enabled: true
      severity: warning
      thresholds:
        similarity: 0.75

    orphaned_abstraction:
      enabled: false

    intent_gap:
      enabled: false
```

---

## 4. Catálogo Completo de las 24 Reglas

### Categoría A: Gestión de Memoria y Ciclo de Vida

#### 1. `unreleased_controllers`
* **Severidad por Defecto:** `error`
* **¿Qué detecta?** Controladores con estado (`TextEditingController`, `AnimationController`, `ScrollController`, `TabController`, etc.) instanciados localmente en una clase `State` que no son liberados explícitamente en el método `dispose()`.
* **Exenciones:** Controladores inyectados vía constructor desde widgets padre o controladores liberados mediante bucles de colección (`for (final c in lista) c.dispose();`).
* **¿Por qué es peligroso?** Provoca fugas de memoria severas en aplicaciones de escritorio y móviles, retención indebida de ventanas y sobrecarga de CPU.
* **Ejemplo Incorrecto ❌:**
  ```dart
  class _MiWidgetState extends State<MiWidget> {
    final _controller = TextEditingController();
    // ¡Falta el método dispose() con _controller.dispose()!
  }
  ```
* **Ejemplo Correcto ✅:**
  ```dart
  class _MiWidgetState extends State<MiWidget> {
    late final TextEditingController _controller;
    @override
    void initState() {
      super.initState();
      _controller = TextEditingController();
    }
    @override
    void dispose() {
      _controller.dispose();
      super.dispose();
    }
  }
  ```

---

### Categoría B: Presentación Limpia y Rendimiento de UI

#### 2. `business_logic_in_ui`
* **Severidad por Defecto:** `error`
* **¿Qué detecta?** Prohíbe instanciar servicios de dominio, ejecutar algoritmos matemáticos complejos o declarar closures asíncronos directamente dentro del método `build()` de un widget.
* **¿Por qué es peligroso?** Flutter reconstruye los widgets a 60Hz o 120Hz. Ejecutar lógica en `build()` congela la pantalla, dispara llamadas duplicadas a la base de datos y satura el Garbage Collector.

#### 3. `setState_in_complex_builds`
* **Severidad por Defecto:** `warning` | **Umbral:** `max_build_complexity: 12.0`
* **¿Qué detecta?** Alerta widgets que invocan `setState()` cuyo método `build()` posee una complejidad ciclomática superior a 12 bifurcaciones.
* **Solución:** Descomponer el árbol en sub-widgets especializados (`StatelessWidget` o `ConsumerWidget`) en subdirectorios `widgets/`.

#### 4. `hardcoded_ui_tokens`
* **Severidad por Defecto:** `warning` (o `info`)
* **¿Qué detecta?** Valores crudos de `Color(0xFF...)` y estilos de texto `TextStyle(...)` declarados inline dentro del árbol visual.
* **Solución:** Consumir tokens centralizados desde el tema de la aplicación (`Theme.of(context)`) o clases de diseño (`AppColors`, `AppTextStyles`).

#### 5. `missing_const_constructors`
* **Severidad por Defecto:** `warning`
* **¿Qué detecta?** Instanciaciones de widgets invariantes que pueden y deben ser declaradas con la palabra clave `const`.
* **Filtro Inteligente:** Vetro ignora interpolaciones de texto dinámicas, fuentes tipográficas dinámicas y métodos encadenados como `.copyWith()`.

#### 6. `misplaced_layout_constraints`
* **Severidad por Defecto:** `error`
* **¿Qué detecta?** Viewports con altura o anchura infinita descontrolada (por ejemplo, un `ListView` dentro de un `Column` sin `Expanded` ni `shrinkWrap: true`).

---

### Categoría C: Arquitectura Limpia y Fronteras de Dominio

#### 7. `boundary_violation`
* **Severidad por Defecto:** `error`
* **¿Qué detecta?** Infracciones del flujo unidireccional de capas en Arquitectura Limpia: `domain` ➔ `application` ➔ `infrastructure` ➔ `presentation`. La capa de dominio jamás debe importar infraestructura ni presentación.

#### 8. `circular_dependency`
* **Severidad por Defecto:** `warning`
* **¿Qué detecta?** Ciclos de importación directa o transitiva (`A -> B -> A` o `A -> B -> C -> A`) evaluados con el algoritmo de componentes fuertemente conexas de Tarjan.
* **¿Por qué es peligroso?** Los ciclos impiden la compilación modular, bloquean el tree-shaking del compilador y generan acoplamientos invisibles.

#### 9. `unchecked_boundary`
* **Severidad por Defecto:** `warning`
* **¿Qué detecta?** Bloques `catch` en controladores o providers que capturan excepciones del sistema (`SocketException`, `SqliteException`) y las asignan al estado sin convertirlas a tipos de dominio (`Failure` o `AppError`).

#### 10. `empty_catch`
* **Severidad por Defecto:** `warning`
* **¿Qué detecta?** Bloques `catch` vacíos que silencian excepciones críticas sin registrar logs ni emitir alertas.

---

### Categoría D: Complejidad Algorítmica y Cognitiva

#### 11. `cyclomatic_complexity`
* **Severidad por Defecto:** `warning` | **Umbral:** `max_complexity: 15.0`
* **¿Qué detecta?** Mide la cantidad de caminos de ejecución linealmente independientes dentro de una función.
* **Solución:** Reemplazar cascadas anidadas de `if-else` por switch expressions de Dart 3, pattern matching y cláusulas de guarda.

#### 12. `cognitive_complexity`
* **Severidad por Defecto:** `warning` | **Umbral:** `max_cognitive_complexity: 15.0`
* **¿Qué detecta?** Evalúa la dificultad mental para comprender un flujo de código, penalizando fuertemente estructuras de control anidadas.

#### 13. `halstead_complexity`
* **Severidad por Defecto:** `warning` | **Umbral:** `max_effort: 50000.0`
* **¿Qué detecta?** Mide el volumen y esfuerzo algorítmico en función de la cantidad de operadores y operandos únicos y totales.

#### 14. `low_entropy`
* **Severidad por Defecto:** `warning` | **Umbrales:** `min_entropy: 1.8`, `min_nodes: 30.0`
* **¿Qué detecta?** Entropía de la información de Shannon. Señala bloques extensos y monótonos de boilerplate que carecen de densidad semántica.

---

### Categoría E: Duplicación y Clones de Código

#### 15. `copy_mutate`
* **Severidad por Defecto:** `warning` | **Umbrales:** `similarity: 0.70`, `max_diff_ratio: 0.15`
* **¿Qué detecta?** Métodos o clases que fueron copiados y pegados con ligeras modificaciones en nombres de variables o sentencias menores.
* **Solución:** Extraer la lógica común a una clase base genérica (`BaseTableSyncDelegate`) o funciones de utilidad.

#### 16. `semantic_duplication`
* **Severidad por Defecto:** `warning` | **Umbral:** `similarity: 0.80`
* **¿Qué detecta?** Funciones que comparten estructuras AST prácticamente idénticas, aunque utilicen identificadores completamente diferentes.

---

### Categoría F: Métricas de Grafos y Teoría de Redes

#### 17. `local_clustering_coefficient`
* **Severidad por Defecto:** `warning` | **Umbrales:** `min_clustering: 0.15`, `min_connections: 4.0`
* **¿Qué detecta?** Módulos que actúan como "puentes caóticos" acoplando paquetes dispersos sin pertenecer de forma natural a ninguno.

#### 18. `tight_coupling`
* **Severidad por Defecto:** `warning` | **Umbral:** `max_coupling: 0.25`
* **¿Qué detecta?** Clases con un ratio excesivo de dependencias salientes (`fan_out`) en relación a su tamaño y responsabilidad.

#### 19. `eigenvector_centrality`
* **Severidad por Defecto:** `warning` | **Umbral:** `max_centrality: 0.40`
* **¿Qué detecta?** "God Objects" o puntos únicos de fallo que concentran demasiada influencia estructural en el grafo de software.

#### 20. `low_cohesion`
* **Severidad por Defecto:** `warning` | **Umbrales:** `min_cohesion: 0.15`, `min_methods: 3.0`
* **¿Qué detecta?** Falta de Cohesión en Métodos (LCOM). Clases cuyos métodos no comparten variables de instancia. Las tablas de Drift SQLite quedan automáticamente excluidas.

---

### Categoría G: Documentación y Calidad

#### 21. `intent_gap`
* **Severidad por Defecto:** `info` | **Umbral:** `min_complexity: 5.0`
* **¿Qué detecta?** Funciones con complejidad ciclomática ≥ 5 que carecen de comentarios o docstrings `///` formales que expliquen la intención de negocio.

#### 22. `orphaned_abstraction`
* **Severidad por Defecto:** `info`
* **¿Qué detecta?** Clases abstractas sin ninguna implementación concreta detectada en el workspace.

#### 23. `fragile_test`
* **Severidad por Defecto:** `info` | **Umbral:** `max_mocks: 3.0`
* **¿Qué detecta?** Pruebas que dependen de más de 3 objetos simulados (mocks), señalando fragilidad ante cambios internos.

#### 24. `performance_media_query`
* **Severidad por Defecto:** `warning`
* **¿Qué detecta?** Llamadas genéricas a `MediaQuery.of(context)` en lugar de selectores específicos como `MediaQuery.sizeOf(context)`.

---

## 5. Directivas de Supresión en Línea (Escape Hatches)

Cuando existe una justificación técnica o de negocio documentada, los desarrolladores y agentes de IA pueden suprimir alertas mediante comentarios inline.

### Supresión de Línea Individual
Ubicar la directiva inmediatamente antes de la línea o al final de la misma:
```dart
// vetro:ignore: hardcoded_ui_tokens
final colorEspecial = Color(0xFF123456);

final paddingFijo = EdgeInsets.all(13.5); // vetro:ignore: hardcoded_ui_tokens
```

### Supresión de Múltiples Reglas
```dart
// vetro:ignore: cyclomatic_complexity, cognitive_complexity
void algoritmoMatematicoLegado() { ... }
```

### Supresión Global en una Línea
```dart
// vetro:ignore: all
void callbackInteroperabilidadC() { ... }
```

### Supresión a Nivel de Archivo Completo
Colocar en las primeras líneas del archivo:
```dart
// vetro:ignore_file: copy_mutate
// vetro:ignore_file: hardcoded_ui_tokens
import 'package:flutter/material.dart';
...
```

> [!CAUTION]
> **Regla Estricta para Asistentes de IA:** Queda PROHIBIDO utilizar `// vetro:ignore` para silenciar hallazgos con severidad `error` (`unreleased_controllers`, `business_logic_in_ui`). En estos casos, la refactorización es obligatoria.

---

## 6. Integración en Pipelines de CI/CD

### Ejemplo de Workflow en GitHub Actions (`.github/workflows/vetro.yml`)
```yaml
name: Control de Calidad Arquitectónica Vetro

on:
  push:
    branches: [main, develop]
  pull_request:
    branches: [main, develop]

jobs:
  vetro-audit:
    name: Auditoría de Deuda Técnica
    runs-on: ubuntu-latest
    steps:
      - name: Descargar Código
        uses: actions/checkout@v4

      - name: Configurar SDK Flutter / Dart
        uses: subosito/flutter-action@v2
        with:
          channel: 'stable'

      - name: Instalar Vetro-CLI
        run: dart pub global activate vetro

      - name: Ejecutar Quality Gate
        run: vetro . --fail-on-severity error --format markdown --output vetro_report.md

      - name: Publicar Reporte de Auditoría
        if: always()
        uses: actions/upload-artifact@v4
        with:
          name: reporte-auditoria-vetro
          path: vetro_report.md
```

---

## 7. Contrato de Cumplimiento para Agentes de IA (Para AGENTS.md / .cursorrules)

Copia y pega este bloque en el archivo de directivas de tu asistente de IA (`AGENTS.md`, `.cursorrules`, `.windsurfrules`):

```markdown
<!-- CONTRATO DE ARQUITECTURA VETRO PARA AGENTES DE IA -->
## Estándares de Arquitectura Vetro-CLI para Asistentes de IA

1. POLÍTICA DE CERO ERRORES:
   - Cualquier código generado o editado DEBE pasar `vetro . --fail-on-severity error` con 0 hallazgos.
   - Todo cambio que introduzca `unreleased_controllers`, `business_logic_in_ui` o `boundary_violation` será rechazado de inmediato.

2. CICLO DE VIDA DE CONTROLADORES:
   - Todo controlador con estado (TextEditingController, AnimationController, ScrollController) instanciado localmente en un State DEBE tener su respectiva llamada `.dispose()` explícita en `dispose()`.

3. CAPA DE PRESENTACIÓN PURA:
   - Jamás instanciar servicios de dominio, repositorios o formateadores dentro del método `build()` de un widget.
   - Extraer closures asíncronos fuera de los árboles de widgets hacia métodos de clase o proveedores de Riverpod.

4. DEPENDENCIAS ACÍCLICAS:
   - Queda prohibido introducir dependencias circulares (`circular_dependency`). Los modelos de dominio base jamás deben importar extensiones o mappers de features hijas.

5. POLÍTICA DE ESCAPE HATCHES:
   - Los agentes de IA NO deben insertar directivas `// vetro:ignore` sin la autorización explícita del usuario y un comentario técnico que justifique la imposibilidad de refactorizar.
```
