# Vetro-CLI: Comprehensive Configuration & Usage Manual

> **The Architectural Linter & AI Technical Debt Firewall for Dart, Flutter & Cross-Language Codebases.**

---

## 1. Executive Overview

**Vetro-CLI** is a static architectural analyzer and technical debt firewall. Unlike standard compilers or syntax linters (e.g., `dart analyze`, ESLint) that only check lexical syntax and type signatures, Vetro evaluates:
* **Deep AST Control Flow:** Unreleased memory controllers, asynchronous handlers leaking inside UI build methods, and unhandled exception boundaries.
* **Network & Graph Theory:** Cyclic dependencies, modularity bridges, eigenvector centrality, and local clustering coefficients across your dependency graph.
* **Information Theory & Complexity:** Halstead effort, cognitive complexity, cyclomatic branching, and Shannon entropy.
* **Code Duplication:** Semantic and structural clones (`copy_mutate`).

### The AI Debt Score (0 - 100)
Vetro computes an aggregate **AI Technical Debt Score**:
* **85 - 100 (Optimal):** Production-ready, modular architecture, zero memory leaks, clean layer boundaries.
* **70 - 84 (Stable):** Healthy codebase with manageable maintenance debt.
* **50 - 69 (At Risk):** High cyclomatic complexity or hidden duplication; refactoring required.
* **< 50 (Critical):** High architectural risk, circular dependencies, or memory lifecycle violations.

---

## 2. Command-Line Interface (CLI) Usage

### Running Analysis
```bash
# Analyze current directory
vetro .

# Analyze specific project directory
vetro /path/to/project

# Format report as JSON, Markdown, or AI Remediation Prompt
vetro . --format json --output report.json
vetro . --format markdown --output report.md
vetro . --format prompt --export-remedies

# Enforce Quality Gate in CI/CD (fail if any 'error' severity finding exists)
vetro . --fail-on-severity error
```

### Specialized Commands
```bash
# Initialize a starter vetro.yaml configuration file
vetro init
vetro init --force

# Analyze only files modified in Git (Staged & Working Tree diffs)
vetro diff
vetro diff --format markdown

# Scaffold a clean-architecture feature module
vetro make feature authentication --state riverpod
```

### CLI Options Reference
| Flag / Option | Description | Defaults |
| :--- | :--- | :--- |
| `-f, --format` | Output format: `terminal`, `json`, `markdown`, `prompt` | `terminal` |
| `-o, --output` | Target file path to write the generated report | `stdout` |
| `--fail-on-severity` | Exit with code `1` if findings match severity: `error`, `warning`, `info`, `none` | `none` |
| `-e, --exclude` | Extra glob patterns to exclude from analysis | `[]` |
| `--color / --no-color` | Enable or disable ANSI colors in terminal output | `true` |
| `-v, --verbose` | Enable verbose execution and AST debugging output | `false` |
| `-l, --language` | Target language analyzer: `dart`, `typescript`, `python`, `auto` | `auto` |
| `--export-remedies` | Export automated AI remediation prompts to `.vetro/remedies.md` | `false` |
| `-m, --max-remedies` | Maximum number of remediation prompts to export (or `"all"`) | `50` |

### Exit Codes
* **`0`**: Analysis completed successfully without violating `--fail-on-severity`.
* **`1`**: Findings matched or exceeded `--fail-on-severity` (Quality Gate failed).
* **`2`**: System error (invalid flags, missing target directory, invalid `vetro.yaml`).

---

## 3. Configuration Reference (`vetro.yaml`)

Vetro automatically discovers `vetro.yaml` in your project root.

### Complete YAML Schema
```yaml
vetro:
  # 1. Target files to include in analysis
  include:
    - 'lib/*.dart'
    - 'lib/**/*.dart'

  # 2. Global file exclusions (generated code, tests, build artifacts)
  exclude:
    - '**/*.g.dart'
    - '**/*.drift.dart'
    - '**/*.freezed.dart'
    - '**/*.mocks.dart'
    - 'test/**'

  # 3. Output configuration
  format: terminal       # terminal | json | markdown | prompt
  color: true
  verbose: false
  auto_exclude_generated: true

  # 4. Granular Rule Configurations
  rules:
    <rule_id>:
      enabled: true | false               # Toggle rule on/off
      severity: error | warning | info    # Override severity level
      exclude:                            # Granular path exclusions for this specific rule
        - 'lib/features/legacy/**'
      thresholds:                         # Custom mathematical thresholds
        <metric_name>: <numeric_value>
      options:                            # Rule-specific options
        <option_name>: <value>
```

### Production Example (`vetro.yaml`)
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
    # Strict Memory & Architecture Protections
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

    # Calibrated Thresholds
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

    # Rule-specific Exclusions
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

## 4. Comprehensive Rule Catalog

### Category A: Memory & Lifecycle Rules

#### 1. `unreleased_controllers`
* **Default Severity:** `error`
* **What it checks:** Detects stateful controllers (`TextEditingController`, `AnimationController`, `ScrollController`, `TabController`, `PageController`) instantiated in a `State` class that are not explicitly disposed in `dispose()`.
* **Exemptions:** Controllers injected via constructor from a parent widget, or disposed inside collection loops (`for (final c in list) c.dispose();`).
* **Why it matters:** In Flutter Desktop and Mobile, unreleased controllers cause severe memory leaks, dangling window listeners, and CPU spikes.
* **Bad Practice ❌:**
  ```dart
  class _MyWidgetState extends State<MyWidget> {
    final _controller = TextEditingController();
    // Missing dispose()!
  }
  ```
* **Good Practice ✅:**
  ```dart
  class _MyWidgetState extends State<MyWidget> {
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

### Category B: Clean Presentation & UI Performance

#### 2. `business_logic_in_ui`
* **Default Severity:** `error`
* **What it checks:** Forbids instantiating domain services, executing complex mathematical algorithms, or defining inline asynchronous handlers inside widget `build()` methods.
* **Why it matters:** Flutter rebuilds widgets at 60Hz or 120Hz. Executing business logic in `build()` causes frame drops, multiple redundant network/database calls, and memory churn.

#### 3. `setState_in_complex_builds`
* **Default Severity:** `warning` | **Threshold:** `max_build_complexity: 12.0`
* **What it checks:** Flags widgets calling `setState()` whose `build()` method has high cyclomatic complexity (> 12 branches).
* **Remedy:** Decompose the monolithic view into smaller, isolated `StatelessWidget` or `ConsumerWidget` components in a `widgets/` subfolder.

#### 4. `hardcoded_ui_tokens`
* **Default Severity:** `warning` (or `info`)
* **What it checks:** Flags raw inline `Color(0xFF...)` and `TextStyle(...)` instantiations inside UI trees.
* **Remedy:** Reference design tokens from `Theme.of(context)` or centralized design token classes (`AppColors`, `AppTextStyles`).

#### 5. `missing_const_constructors`
* **Default Severity:** `warning`
* **What it checks:** Identifies non-constant widget instantiations that can be safely marked `const`.
* **Smart Filter:** Vetro excludes string interpolations, GoogleFonts calls, and mutable method calls.

#### 6. `misplaced_layout_constraints`
* **Default Severity:** `error`
* **What it checks:** Detects unbounded viewport configurations (e.g., `ListView` inside an unconstrained `Column` without `Expanded` or `shrinkWrap: true`).

---

### Category C: Architectural Cleanliness & Boundaries

#### 7. `boundary_violation`
* **Default Severity:** `error`
* **What it checks:** Enforces Clean Architecture dependency rules across layers: `domain` ➔ `application` ➔ `infrastructure` ➔ `presentation`. Domain must NEVER import infrastructure or presentation.

#### 8. `circular_dependency`
* **Default Severity:** `warning`
* **What it checks:** Detects circular import cycles (`A -> B -> A` or `A -> B -> C -> A`) using Tarjan's strongly connected components algorithm.
* **Why it matters:** Circular dependencies degrade incremental build times, break tree shaking, and create tight architectural coupling.

#### 9. `unchecked_boundary`
* **Default Severity:** `warning`
* **What it checks:** Catch blocks in controllers or presentation layers that swallow or expose raw system exceptions (`SocketException`, `SqliteException`) instead of mapping them via domain `Failure` or `AppErrorMapper`.

#### 10. `empty_catch`
* **Default Severity:** `warning`
* **What it checks:** Flags empty catch blocks (`catch (e) {}`) that silently swallow critical errors.

---

### Category D: Algorithmic & Cognitive Complexity

#### 11. `cyclomatic_complexity`
* **Default Severity:** `warning` | **Threshold:** `max_complexity: 15.0`
* **What it checks:** Measures the number of linearly independent paths through a method.
* **Remedy:** Replace nested `if-else` cascades with Dart 3 pattern matching, switch expressions, or guard clauses.

#### 12. `cognitive_complexity`
* **Default Severity:** `warning` | **Threshold:** `max_cognitive_complexity: 15.0`
* **What it checks:** Measures how difficult code is for a human or AI to understand, penalizing nested control structures heavily.

#### 13. `halstead_complexity`
* **Default Severity:** `warning` | **Threshold:** `max_effort: 50000.0`
* **What it checks:** Evaluates algorithmic effort and vocabulary volume based on operator and operand densities.

#### 14. `low_entropy`
* **Default Severity:** `warning` | **Thresholds:** `min_entropy: 1.8`, `min_nodes: 30.0`
* **What it checks:** Shannon information entropy. Flags bloated, repetitive boilerplate blocks that lack semantic variety.

---

### Category E: Code Duplication & Clones

#### 15. `copy_mutate`
* **Default Severity:** `warning` | **Thresholds:** `similarity: 0.70`, `max_diff_ratio: 0.15`
* **What it checks:** Flags functions or classes copied with minimal variable renaming or slight modifications.
* **Remedy:** Extract common functionality into a reusable generic base class or extension method.

#### 16. `semantic_duplication`
* **Default Severity:** `warning` | **Threshold:** `similarity: 0.80`
* **What it checks:** Detects methods that share identical AST subtree structures despite distinct variable identifiers.

---

### Category F: Network & Graph Theory Metrics

#### 17. `local_clustering_coefficient`
* **Default Severity:** `warning` | **Thresholds:** `min_clustering: 0.15`, `min_connections: 4.0`
* **What it checks:** Identifies chaotic dependency hubs that connect disparate modules without cohesion.

#### 18. `tight_coupling`
* **Default Severity:** `warning` | **Threshold:** `max_coupling: 0.25`
* **What it checks:** Flags modules that have an excessive ratio of outgoing dependencies (`fan_out`) relative to their responsibility.

#### 19. `eigenvector_centrality`
* **Default Severity:** `warning` | **Threshold:** `max_centrality: 0.40`
* **What it checks:** Flags "God objects" or critical single points of failure in your dependency graph.

#### 20. `low_cohesion`
* **Default Severity:** `warning` | **Thresholds:** `min_cohesion: 0.15`, `min_methods: 3.0`
* **What it checks:** Lack of Cohesion in Methods (LCOM). Classes whose methods share few or zero instance fields. Drift `Table` classes are automatically excluded.

---

### Category G: Documentation & Testing

#### 21. `intent_gap`
* **Default Severity:** `info` | **Threshold:** `min_complexity: 5.0`
* **What it checks:** Complex methods (cyclomatic complexity ≥ 5) lacking docstrings (`///`) explaining their rationale.

#### 22. `orphaned_abstraction`
* **Default Severity:** `info`
* **What it checks:** Abstract classes with zero implementations in the workspace.

#### 23. `fragile_test`
* **Default Severity:** `info` | **Threshold:** `max_mocks: 3.0`
* **What it checks:** Tests relying on excessive mocks (> 3), signaling test brittleness.

#### 24. `performance_media_query`
* **Default Severity:** `warning`
* **What it checks:** Calling `MediaQuery.of(context)` directly instead of targeted selectors like `MediaQuery.sizeOf(context)`.

---

## 5. Inline & File-Level Suppression Directives

When a genuine architectural exception is required, developers and AI agents can suppress specific warnings using inline directives.

### Single-Line Suppression
Place directive immediately above the affected line or at the end of the line:
```dart
// vetro:ignore: hardcoded_ui_tokens
final customColor = Color(0xFF123456);

final fixedPadding = EdgeInsets.all(13.5); // vetro:ignore: hardcoded_ui_tokens
```

### Multi-Rule Suppression
```dart
// vetro:ignore: cyclomatic_complexity, cognitive_complexity
void complexLegacyAlgorithm() { ... }
```

### Global Line Suppression
```dart
// vetro:ignore: all
void generatedInteropCallback() { ... }
```

### Whole-File Suppression
Place at the top of the file:
```dart
// vetro:ignore_file: copy_mutate
// vetro:ignore_file: hardcoded_ui_tokens
import 'package:flutter/material.dart';
...
```

> [!CAUTION]
> **Directive for AI Agents:** NEVER use `// vetro:ignore` to bypass `error` severity findings (`unreleased_controllers`, `business_logic_in_ui`). Refactoring is strictly required.

---

## 6. CI/CD Pipeline Integration

### GitHub Actions Workflow Example (`.github/workflows/vetro.yml`)
```yaml
name: Vetro Architectural Quality Gate

on:
  push:
    branches: [main, develop]
  pull_request:
    branches: [main, develop]

jobs:
  vetro-audit:
    name: Architectural & Debt Audit
    runs-on: ubuntu-latest
    steps:
      - name: Checkout Code
        uses: actions/checkout@v4

      - name: Setup Dart / Flutter SDK
        uses: subosito/flutter-action@v2
        with:
          channel: 'stable'

      - name: Install Vetro-CLI
        run: dart pub global activate vetro

      - name: Run Vetro Quality Gate
        run: vetro . --fail-on-severity error --format markdown --output vetro_report.md

      - name: Upload Audit Artifact
        if: always()
        uses: actions/upload-artifact@v4
        with:
          name: vetro-audit-report
          path: vetro_report.md
```

---

## 7. AI-Agent Compliance Contract (For System Prompts & AGENTS.md)

Add this block directly into your project's `AGENTS.md`, `.cursorrules`, or `.windsurfrules`:

```markdown
<!-- VETRO COMPLIANCE CONTRACT FOR AI AGENTS -->
## Vetro-CLI Architectural Standards for AI Coding Assistants

1. ZERO ERROR POLICY:
   - Any code created or modified MUST pass `vetro . --fail-on-severity error` with 0 findings.
   - Code that triggers `unreleased_controllers`, `business_logic_in_ui`, or `boundary_violation` will be rejected immediately.

2. CONTROLLER LIFECYCLE:
   - Every stateful controller (TextEditingController, AnimationController, ScrollController) instantiated in a State class MUST have an explicit `.dispose()` call inside `dispose()`.

3. CLEAN PRESENTATION LAYER:
   - Never instantiate domain services, repositories, or formatters inside widget `build()` methods.
   - Never define async lambda closures directly inside UI element callbacks; extract them into component methods or Riverpod providers.

4. ACYCLIC DEPENDENCIES:
   - Never introduce circular imports (`circular_dependency`). Domain root models must remain pure and never import feature-specific extensions or mappers.

5. ESCAPE HATCH DISCIPLINE:
   - AI assistants MUST NOT insert `// vetro:ignore` directives without explicit developer confirmation and a technical justification comment explaining why refactoring is impossible.
```
