# Vetro Architecture & Technical Design

Vetro is a next-generation static analysis engine, architectural audit suite, and runtime primitive library for modern Dart and Flutter applications.

---

## 1. Monorepo & Dart Workspace Structure

Vetro is organized as a unified Dart 3 workspace separating developer tooling from runtime code:

```text
Vetro/
├── bin/
│   └── vetro.dart                  # CLI entry point (`vetro audit`, `vetro make`)
├── lib/
│   ├── analyzers/                  # Language-specific AST adapters
│   │   ├── dart/                   # Dart / Flutter analyzer using package:analyzer
│   │   ├── python/                 # Python AST analyzer
│   │   └── typescript/             # TypeScript AST analyzer
│   ├── cli/                        # Git diff parser & CLI utilities
│   ├── core/                       # Agnostic mathematical & graph algorithms
│   │   ├── metrics/                # Shannon entropy, clustering coefficient, cohesion
│   │   ├── models/                 # Finding, Config, AnalysisContext, AST nodes
│   │   ├── report/                 # Terminal, JSON, Markdown, and Prompt reporters
│   │   └── rules/                  # Agnostic architectural rules
│   └── vetro.dart                  # Main CLI library barrel
├── packages/
│   └── vetro_core/                 # Runtime primitives package (zero-codegen, pure Dart 3)
│       ├── lib/
│       │   ├── src/
│       │   │   ├── failure/        # Failure & StandardFailure hierarchy
│       │   │   └── result/         # Result<T, E>, Success, FailureResult
│       │   └── vetro_core.dart     # Public runtime barrel export
│       └── test/                   # Runtime test suite
├── docs/                           # Architecture, benchmarks, and validation reports
└── test/                           # CLI and static analysis test suites (131+ tests)
```

---

## 2. Core Separation of Concerns

### Tooling vs. Runtime
- **`vetro` (CLI & Analyzer Engine)**:
  - Runs during development and CI/CD pipelines.
  - Audits codebases for architectural degradation, boundary violations, low entropy, and cognitive complexity.
  - Generates actionable prompt remedies for human developers and autonomous AI agents.
- **`packages/vetro_core` (Runtime Primitives)**:
  - Imported directly by application code (`pubspec.yaml` dependency).
  - 100% pure Dart 3 (`sdk: ^3.11.0` / 3.12+).
  - Zero external dependencies and zero code generation (`build_runner`).
  - Provides deterministic, type-safe return types (`Result<T, E>`) to replace exception-based control flow.

---

## 3. The Two Extraction Engines: File Visitor & Topological Graph

The static analysis pipeline in Vetro is powered by two complementary extraction engines:

```text
Source Files (.dart, .py, .ts)
         │
         ├──▶ [1. RecursiveAstVisitor (File-Level)] ────▶ Campbell Cognitive Complexity
         │                                          ────▶ Shannon Identifier Entropy
         │                                          ────▶ Local AST Directives & Tokens
         │
         └──▶ [2. Topological Graph (Global-Level)] ────▶ Clean Architecture Boundary Checks
                                                    ────▶ Eigenvector & PageRank Centrality
                                                    ────▶ Local Clustering Coefficient (Ci)
```

### 1. `RecursiveAstVisitor` (File-Level AST Traversal)
The compiler transforms source code into an Abstract Syntax Tree (AST). Vetro employs the `RecursiveAstVisitor` pattern (from `package:analyzer`) to traverse nodes deterministically without code execution:
- **Campbell Cognitive Complexity**: Visits functions and methods to count control flow branchings (`if`, `else if`, `switch`, loops, ternary operators), accumulating nesting penalties to measure true human comprehension effort.
- **Shannon Identifier Entropy ($H(X)$)**: Tokenizes variable and method identifiers to measure lexical diversity, surfacing repetitive naming anti-patterns common in uncurated AI-generated code.
- **Import Extraction**: Inspects all `ImportDirective` declarations to build the local dependency manifest for each file.

### 2. Topological Dependency Graph (Global-Level Architecture)
Vetro aggregates individual file dependencies into a global directed mathematical network $G = (V, E)$, where vertices $V$ represent modules/classes and directed edges $E$ represent imports and call relationships:
- **Clean Architecture Boundary Invariants**: If a directed edge flows outward from `domain/` toward `presentation/` or `data/`, a boundary violation is raised immediately at compile time.
- **Eigenvector & PageRank Centrality**: Identifies architectural bottleneck nodes that concentrate disproportionate dependency traffic, exposing "God Objects" frequently produced by unconstrained AI code generation.
- **Local Clustering Coefficient ($C_i$)**: Evaluates whether modules intended to be decoupled are forming tightly-coupled "big balls of mud".

### Fault Isolation via `Result<T, E>`
Auditing arbitrary, in-development repositories is inherently unpredictable: codebases often contain syntax errors, corrupted tokens, missing file paths, or circular import loops. 

If the AST Visitor or graph constructor relied on legacy exception throwing (`throw Exception`), the entire analysis of a large repository would abort on the first malformed file. By designing the extraction pipeline around `Result<T, AnalysisFailure>`, every file extraction returns either `Success(FileMetrics)` or `FailureResult(AnalysisFailure)`. Corrupted files are cleanly isolated into structured diagnostic reports while the global analysis continues evaluating the rest of the project uninterrupted.

---

## 4. Mathematical & Algorithmic Foundation

Vetro replaces subjective linting heuristics with proven mathematical and graph-theoretical metrics:

### A. Graph Theory & Dependency Analysis
- **Eigenvector Centrality**: Quantifies the influence of a module within the dependency graph. Modules with high centrality represent core architectural nodes that require high test coverage and stability.
- **Local Clustering Coefficient ($C_i$)**:
  $$\( C_i = \frac{2 e_i}{k_i(k_i - 1)} \)$$
  Measures the degree to which a module's neighbors form a complete subgraph (clique). High clustering indicates tight, modular cohesion, while low clustering reveals brittle coupling.
- **Clean Architecture Boundary Invariants**:
  Inspects import directives across architectural layers (`presentation` $\to$ `domain` $\leftarrow$ `data`). Outward dependency violations (e.g. `domain` importing `presentation` or `data`) are flagged deterministically.

### B. Information Theory & Semantic Analysis
- **Shannon Entropy of Identifiers ($H(X)$)**:
  $$\( H(X) = -\sum_{i=1}^n P(x_i) \log_2 P(x_i) \)$$
  Quantifies the lexical diversity and informational density of code tokens. Calibrated specifically for declarative frameworks (filtering boilerplate like `build(BuildContext context)` and `@override`) to pinpoint repetitive, hallucinatory AI code patterns.
- **Campbell Cognitive Complexity**:
  Measures the mental effort required to understand control flow, penalizing nested branches and unidiomatic jumps over flat sequential logic.
- **Halstead Software Science**:
  Computes program length, vocabulary, volume, and effort from distinct operators and operands.

---

## 4. Multi-Language Extensibility

While Dart and Flutter represent Vetro's flagship target, the core metrics engine (`lib/core/`) operates on a unified AST node abstraction:

| Language | AST Adapter | Parser Dependency |
|---|---|---|
| **Dart** | `DartAdapter` | `package:analyzer` (Official Dart SDK compiler front-end) |
| **Python** | `PythonAdapter` | AST node representation for Python 3 syntax |
| **TypeScript** | `TypeScriptAdapter` | AST node representation for ECMAScript/TS modules |

---

## 5. Modular Error Presentation Architecture

In conventional Flutter applications, error mapping tends to degenerate into a monolithic 1000-line switch statement, violating the Single Responsibility and Open/Closed Principles:

```text
❌ Monolithic Anti-Pattern:
Presentation Layer ───> MonolithicErrorMapper (1000+ lines, imports all feature models)
```

Vetro's `CompositeErrorMapper` implements the **Supervisor / Delegation Pattern**:
1. **Feature Isolation**: Each feature package or folder owns a dedicated `FeatureErrorMapper` (or `BaseFeatureErrorMapper<F>`) that only knows its local domain failures.
2. **Dynamic Delegation**: The `CompositeErrorMapper` queries registered mappers in priority order. When an error occurs, only the owning feature mapper translates it.
3. **Safe Fallbacks**: If no feature mapper matches or if an unexpected runtime exception escapes, a baseline `StandardErrorMapper` and fallback handler ensure the user never sees raw crash stack traces.

```text
✅ Vetro Supervisor Architecture:
Presentation Layer ───> CompositeErrorMapper
                              ├──> AuthErrorMapper (Feature)
                              ├──> CheckoutErrorMapper (Feature)
                              └──> StandardErrorMapper (Baseline Fallback)
```

---

## 6. AST Error Handling & Debt Detection Rules

To prevent error swallowing and boundary leaks, Vetro's AST Visitor enforces two core rules:

### `empty_catch` (`EmptyCatchRule`)
- **Target Node**: `CatchClause`
- **Detection**: Flags empty catch blocks (`catch (e) {}`, `catch (_) {}`) or catch bodies that do not contain logging, a `rethrow`, a `throw`, or a delegating error mapper call.
- **Goal**: Ensures zero silent exception swallowing across all layers.

### `unchecked_boundary` (`UncheckedBoundaryRule`)
- **Target Node**: Presentation classes (`*Controller`, `*Notifier`, `*ViewModel`, `*Bloc`, `*Cubit`, or code inside `presentation/`).
- **Detection**: Flags methods capturing generic `Exception`, `Error`, or untyped `catch (e)` without mapping them to a domain `Failure` or calling an error mapper (`CompositeErrorMapper` / `FeatureErrorMapper`).
- **Goal**: Guarantees raw infrastructure crashes are never exposed unformatted to presentation state or the UI.

---

## 7. Architectural Invariants

1. **Zero-Leakage Policy**: Vetro is a universal developer tool. No domain-specific business logic, client identifiers, or private filesystem paths may ever be committed to this repository.
2. **Deterministic Analysis**: All rules must produce identical results across operating systems, path separators, and execution environments.
3. **Dogfooding Standard**: Every new rule and metric added to Vetro is immediately run against the Vetro codebase itself to maintain zero technical debt.
