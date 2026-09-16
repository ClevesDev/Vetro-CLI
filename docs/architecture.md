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

## 3. Mathematical & Algorithmic Foundation

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

## 6. Architectural Invariants

1. **Zero-Leakage Policy**: Vetro is a universal developer tool. No domain-specific business logic, client identifiers, or private filesystem paths may ever be committed to this repository.
2. **Deterministic Analysis**: All rules must produce identical results across operating systems, path separators, and execution environments.
3. **Dogfooding Standard**: Every new rule and metric added to Vetro is immediately run against the Vetro codebase itself to maintain zero technical debt.
