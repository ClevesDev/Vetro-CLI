# AGENTS.md — Vetro: Guía de Navegación para Agentes IA

> **Versión**: 0.1.0 | **Última actualización**: 2026-06-15
> Este archivo es el punto de entrada universal para cualquier agente IA que trabaje con este codebase.

---

## 🔬 ¿Qué es Vetro?

**Vetro** (del italiano *vetro* = vidrio) es un analizador estático de código que detecta **deuda técnica inducida por IA**. A diferencia de linters tradicionales (que verifican estilo y errores), Vetro detecta **patrones degenerativos** específicos del código generado por LLMs/agentes IA.

### Principio Fundacional

> **La IA opina. La matemática demuestra.**

Vetro NO usa IA para analizar código. Usa **matemática determinística** sobre árboles sintácticos abstractos (AST):
- Isomorfismo de grafos para duplicación semántica
- Entropía de Shannon para detectar código relleno
- Complejidad ciclomática para sobre-anidamiento
- Similitud coseno de tokens para copy-paste mutado
- Análisis de grafos de dependencia para acoplamiento oculto

Cada hallazgo es **reproducible, medible y demostrable**. No hay opiniones.

### Stack Técnico

| Capa | Tecnología |
|------|-----------|
| Lenguaje | Dart 3.11+ |
| AST Engine | `package:analyzer` (Dart SDK) |
| CLI | `package:args` + `package:cli_util` |
| Output | Terminal (ANSI), JSON, Markdown |
| Tests | `package:test` con fixtures de código bueno/malo |
| Distribución | `dart compile exe` → binario nativo |
| CI/CD | GitHub Actions (futuro) |

### Lenguajes Soportados (Roadmap)

| Fase | Lenguaje | AST Engine |
|------|----------|-----------|
| **MVP** | Dart | `package:analyzer` nativo |
| **v0.2** | TypeScript | `typescript` compiler API |
| **v0.3** | Python | `ast` stdlib |

---

## 📂 Arquitectura del Proyecto

```text
vetro/
├── bin/
│   └── vetro.dart                    # CLI entry point
│
├── lib/
│   ├── vetro.dart                    # Barrel export
│   │
│   ├── core/                         # 🧮 Motor matemático (language-agnostic)
│   │   ├── models/                   # Finding, Severity, FileReport, ProjectReport
│   │   ├── metrics/                  # Funciones puras de cálculo
│   │   │   ├── similarity.dart       # Similitud coseno, distancia AST
│   │   │   ├── complexity.dart       # Complejidad ciclomática
│   │   │   ├── entropy.dart          # Entropía de Shannon
│   │   │   └── dependency_graph.dart # Análisis de grafos de dependencia
│   │   ├── rules/                    # Interfaz base Rule + registro
│   │   │   ├── rule.dart             # abstract class Rule
│   │   │   └── rule_registry.dart    # Registro centralizado de reglas
│   │   └── report/                   # Generación de reportes
│   │       ├── reporter.dart         # abstract class Reporter
│   │       ├── terminal_reporter.dart
│   │       ├── json_reporter.dart
│   │       └── markdown_reporter.dart
│   │
│   ├── analyzers/                    # 🔍 Implementaciones por lenguaje
│   │   └── dart/                     # Analizador Dart
│   │       ├── dart_analyzer.dart    # Orquestador: parsea archivos → aplica reglas
│   │       ├── ast_utils.dart        # Helpers para navegación de AST Dart
│   │       └── rules/               # Reglas específicas para Dart
│   │           ├── semantic_duplication_rule.dart
│   │           ├── orphaned_abstraction_rule.dart
│   │           ├── copy_mutate_rule.dart
│   │           ├── intent_gap_rule.dart
│   │           ├── cyclomatic_complexity_rule.dart
│   │           └── fragile_test_rule.dart
│   │
│   └── cli/                          # 🖥️ Interfaz de línea de comandos
│       ├── cli_runner.dart           # Parseo de argumentos + orquestación
│       ├── commands/                 # Subcomandos
│       │   ├── analyze_command.dart  # vetro analyze ./lib
│       │   ├── report_command.dart   # vetro report --format json
│       │   └── init_command.dart     # vetro init (genera vetro.yaml)
│       └── ansi.dart                 # Colores y formato terminal
│
├── test/
│   ├── core/                         # Tests del motor matemático
│   │   ├── metrics/                  # Tests de funciones de cálculo
│   │   └── rules/                    # Tests de la interfaz de reglas
│   ├── analyzers/dart/               # Tests del analizador Dart
│   │   └── rules/                    # Tests de cada regla con fixtures
│   ├── cli/                          # Tests del CLI
│   └── fixtures/                     # 🧪 Código de prueba
│       ├── good/                     # Código limpio (no debe disparar reglas)
│       └── bad/                      # Código con AI debt (debe disparar reglas)
│
├── vetro.yaml                        # Configuración del proyecto (dog-fooding)
├── pubspec.yaml                      # Dependencias Dart
├── analysis_options.yaml             # Lint rules para Vetro mismo
├── AGENTS.md                         # Este archivo
├── README.md                         # Documentación pública
├── LICENSE                           # MIT
└── CHANGELOG.md                      # Historial de cambios
```

---

## 🔗 Patrón de Dependencias

```text
┌──────────────────────────────────────────────────────┐
│                    core/                              │
│  (models, metrics, rules, report)                    │
│  100% puro — sin dependencia de analyzer ni de Dart  │
│  Funciones puras. Sin side-effects. Testeable al 100%│
└────────────────────┬─────────────────────────────────┘
                     │
        ┌────────────┼────────────┐
        ▼            │            ▼
┌──────────────┐     │    ┌──────────────┐
│ analyzers/   │     │    │ cli/         │
│   dart/      │     │    │  commands/   │
│   (futuro:   │     │    │  ansi/       │
│    ts/, py/) │     │    └──────────────┘
└──────────────┘     │
                     │
                     ▼
              ┌─────────────┐
              │ bin/vetro.dart│
              │ (entry point)│
              └─────────────┘
```

> **Regla de oro**: `core/` NUNCA importa de `analyzers/` ni de `cli/`. Los analyzers importan de `core/`. El CLI importa de ambos. Las dependencias fluyen en UNA dirección.

---

## 🧮 Las 6 Reglas del MVP

### Regla 1: Duplicación Semántica (`semantic_duplication`)
- **Matemática**: Distancia de edición sobre AST normalizados (nombres removidos)
- **Detecta**: Funciones que hacen lo mismo con nombres/variables diferentes
- **Umbral**: Similitud AST ≥ 80%
- **Origen IA**: Los LLMs generan la misma solución con variaciones cosméticas entre sesiones

### Regla 2: Abstracciones Huérfanas (`orphaned_abstraction`)
- **Matemática**: Grafo de herencia/implementación — nodos con grado de entrada = 1
- **Detecta**: Interfaces/clases abstractas con una sola implementación
- **Umbral**: 0 (cualquier abstracción sin justificación es sospechosa)
- **Origen IA**: Los LLMs añaden abstracciones "por si acaso" sin beneficio real

### Regla 3: Copy-Mutate (`copy_mutate`)
- **Matemática**: Similitud coseno de vectores de tokens entre bloques de código
- **Detecta**: Bloques de código casi idénticos con mutaciones menores
- **Umbral**: Similitud ≥ 70% con diff ≤ 15% de líneas
- **Origen IA**: El LLM copia un patrón y lo modifica ligeramente en vez de extraer

### Regla 4: Vacío de Intención (`intent_gap`)
- **Matemática**: Ratio de entropía informacional comentarios:código
- **Detecta**: Archivos/funciones complejas sin documentación de *por qué*
- **Umbral**: Complejidad ≥ 5 AND ratio de comentarios de intención = 0
- **Origen IA**: Los LLMs generan código funcional pero sin explicar las decisiones

### Regla 5: Complejidad Ciclomática (`cyclomatic_complexity`)
- **Matemática**: Contar nodos de decisión en el grafo de control de flujo: E - N + 2P
- **Detecta**: Funciones con demasiadas ramas/caminos
- **Umbral**: CC ≥ 15 (configurable)
- **Origen IA**: Los LLMs anidan condiciones en vez de usar early returns o polimorfismo

### Regla 6: Tests Frágiles (`fragile_test`)
- **Matemática**: Ratio de acoplamientos a implementación vs. acoplamientos a comportamiento
- **Detecta**: Tests que prueban *cómo* funciona el código, no *qué* hace
- **Umbral**: > 3 mocks por test OR verificación de llamadas internas
- **Origen IA**: Los LLMs generan tests que replican la implementación como espejo

---

## ⚡ Flujos Críticos

### 1. Analizar un proyecto
```
CLI parse args
  → Resolver archivos .dart en la ruta
  → Para cada archivo:
      → Parsear a AST con package:analyzer
      → Aplicar cada Rule registrada
      → Recolectar Findings con severidad + ubicación
  → Agregar Findings en ProjectReport
  → Formatear con Reporter seleccionado
  → Imprimir resultado + exit code
```

### 2. Definir una regla nueva
```
1. Crear clase que extiende Rule en analyzers/dart/rules/
2. Implementar:
   - id: String único (snake_case)
   - name: String legible
   - description: String con explicación
   - severity: Severity (info/warning/error)
   - analyze(CompilationUnit): List<Finding>
3. Registrar en RuleRegistry
4. Crear fixtures en test/fixtures/good/ y test/fixtures/bad/
5. Escribir tests que validen positivos y negativos
```

---

## 🧪 Testing

```bash
dart test                           # Suite completa
dart test test/core/                # Motor matemático
dart test test/analyzers/dart/      # Reglas Dart
dart test test/cli/                 # CLI
```

### Convención de fixtures
```text
test/fixtures/bad/semantic_duplication/
  ├── two_similar_functions.dart     # Debe disparar la regla
  └── three_variants.dart            # Debe disparar la regla

test/fixtures/good/semantic_duplication/
  ├── distinct_functions.dart        # NO debe disparar
  └── intentional_overloads.dart     # NO debe disparar
```

Cada regla DEBE tener al menos 3 fixtures buenos y 3 malos.

---

## ⚙️ Configuración (vetro.yaml)

```yaml
# vetro.yaml
vetro:
  version: 1

  # Archivos a analizar
  include:
    - lib/**/*.dart

  # Archivos a excluir
  exclude:
    - "**/*.g.dart"           # Generados por build_runner
    - "**/*.freezed.dart"     # Generados por freezed
    - "**/*.mocks.dart"       # Mocks generados

  # Configuración de reglas
  rules:
    semantic_duplication:
      enabled: true
      threshold: 0.80          # Similitud AST mínima para reportar
      severity: warning

    orphaned_abstraction:
      enabled: true
      severity: info

    copy_mutate:
      enabled: true
      threshold: 0.70          # Similitud coseno mínima
      max_diff_ratio: 0.15     # Máximo % de líneas diferentes
      severity: warning

    intent_gap:
      enabled: true
      min_complexity: 5        # Solo reportar si CC >= este valor
      severity: info

    cyclomatic_complexity:
      enabled: true
      threshold: 15
      severity: warning

    fragile_test:
      enabled: true
      max_mocks: 3
      severity: info

  # Formato de salida
  output:
    format: terminal           # terminal | json | markdown
    color: true
    verbose: false
```

---

## 📖 Contratos Clave

| Contrato | Archivo | Propósito |
|----------|---------|-----------|
| `Rule` | `core/rules/rule.dart` | Interfaz base: toda regla implementa `analyze()` → `List<Finding>` |
| `Finding` | `core/models/finding.dart` | Un hallazgo: archivo, línea, regla, severidad, mensaje, evidencia |
| `Reporter` | `core/report/reporter.dart` | Interfaz de formateo: recibe `ProjectReport` → `String` |
| `Analyzer` | `analyzers/dart/dart_analyzer.dart` | Orquestador por lenguaje: resuelve archivos, parsea, aplica reglas |
| `Metrics` | `core/metrics/*.dart` | Funciones PURAS de cálculo. Sin side-effects. Sin estado. |

---

## ⚠️ Convenciones Importantes

1. **Funciones puras**: Todo en `core/metrics/` DEBE ser una función pura. Sin IO, sin estado, sin side-effects.
2. **Determinismo**: Dado el mismo input, SIEMPRE el mismo output. Sin aleatoriedad. Sin timestamps.
3. **Sin IA**: Vetro NO usa LLMs, embeddings, ni modelos de ML. Solo matemática.
4. **Fixtures obligatorios**: Toda regla tiene tests con fixtures positivos Y negativos.
5. **Dog-fooding**: Vetro se analiza a sí mismo. Si detecta deuda en su propio código, se arregla.
6. **Severity semántica**: `error` = el código está objetivamente mal. `warning` = probablemente mal. `info` = merece revisión humana.
7. **Zero dependencies externas**: Solo `package:analyzer`, `package:args`, `package:path`, `package:yaml`. Nada más.
8. **Exit codes**: `0` = limpio. `1` = warnings. `2` = errors. Estándar UNIX.

---

## 🎯 Dogfooding: Vetro ↔ Proyecto_XXX_D

Proyecto_XXX_D (`/home/dimas/development/Proyecto_XXX_D`) es el primer proyecto real contra el que Vetro se prueba. Ambos proyectos coexisten pero son independientes:

```text
/home/dimas/development/
├── Proyecto_XXX_D/     # ERP (Flutter + Drift) — cliente #1 de Vetro
└── Vetro/              # Analizador estático — analiza a Proyecto_XXX_D (y a sí mismo)
```

---

## 📊 Métricas del Reporte

```
📊 Vetro Report — proyecto_ejemplo
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

  Archivos analizados:    127
  Líneas de código:     8,432
  Tiempo de análisis:   1.2s

  🧟 Semantic Duplicates:    14  ██████░░░░  warning
  🏚️ Orphaned Abstractions:   7  ███░░░░░░░  info
  🫥 Intent Gaps:             23  ██████████  info
  🔄 Copy-Mutate Patterns:    9  ████░░░░░░  warning
  🌀 High Complexity:         4  ██░░░░░░░░  warning
  ⚠️ Fragile Tests:            5  ██░░░░░░░░  info

  AI Debt Score: 62/100 (needs attention)

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

El **AI Debt Score** es un número compuesto:
- `100` = código impecable
- `0` = deuda crítica
- Fórmula: ponderación por severidad × frecuencia × impacto en mantenibilidad
