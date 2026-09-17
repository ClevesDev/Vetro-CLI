# AI Technical Debt & Metric Calibration in Vetro

As generative AI code generation accelerates, modern software projects face novel failure modes: repetitive identifier patterns, unhandled boundary exceptions, subtle boundary violations, and bloated, low-entropy implementations.

This document outlines how Vetro's metric engine addresses key technical challenges when detecting AI-generated technical debt.

---

## 1. AST Directives vs. Symbol Resolution

### The Challenge
A naive AST parser only inspects syntax trees without resolving symbols, potentially missing relationships introduced via abstract interfaces, dependency injection containers (e.g. `Riverpod`, `GetIt`), or dynamic module loading.

### Vetro's Design Approach
1. **Architectural Boundary Invariants (Compile-Time Flow)**:
   In Clean Architecture, layer independence is governed by file-level compilation dependencies. If a file in `domain/` contains `import 'package:.../presentation/...'`, the dependency rule is fundamentally violated regardless of runtime dependency injection. Vetro analyzes import graphs directly to prevent layer leakage.
2. **Official Compiler Integration (`package:analyzer`)**:
   For Dart and Flutter, Vetro uses the official compiler parser from the Dart SDK rather than regular expressions or lightweight parsers. This enables full integration with Dart's `AnalysisContextCollection` when type-resolved symbol tables are required for advanced inter-procedural queries.

---

## 2. Entropy Calibration & Boilerplate Filtering

### The Challenge
Declarative UI frameworks like Flutter, SwiftUI, and modern web frameworks rely heavily on idiomatic boilerplate (e.g., `build(BuildContext context)`, `Key? key`, `EdgeInsets.all`, `@override`). Calculating Shannon Entropy indiscriminately over all syntax tokens would falsely categorize legitimate declarative UI as "low-entropy repetitive AI code".

### Vetro's Design Approach
1. **Framework-Aware Lexical Token Filtering**:
   Vetro filters reserved language keywords, standard framework identifiers, and metadata annotations (`@override`, `@riverpod`, `BuildContext`, `Widget`).
2. **Multi-Factor Rule Conjunction**:
   Low token entropy alone does not trigger a warning. Vetro correlates entropy with **Intent Gap** (absence of explanatory docstrings/comments) and **Cognitive Complexity**.
   - *Declarative Widget*: Low entropy + Cognitive Complexity 1 $\to$ **Ignored** (Clean code).
   - *AI Hallucination Pattern*: Low entropy + High Cognitive Complexity + Nested Loops with generic names (`data1`, `temp`, `item`, `res`) $\to$ **Flagged with high confidence**.

---

## 3. Multi-Dimensional Metric Decomposition (AI Debt Score)

### The Challenge
Aggregating continuous graph metrics (such as the Local Clustering Coefficient $C_i \in [0, 1]$ or normalized centrality) with discrete unbounded metrics (such as Campbell Cognitive Complexity $\in [0, \infty)$) into a single scalar score creates an uncalibrated "black box" metric susceptible to skew and false positives.

### Vetro's Design Approach
Rather than producing an opaque single score, Vetro evaluates code across three orthogonal, mathematically grounded vectors:

| Dimension | Measured Characteristic | Mathematical Primitive |
|---|---|---|
| **Graph Topology** | Coupling, modularity, circularities | Local Clustering Coefficient ($C_i$), Eigenvector Centrality |
| **Cognitive Friction** | Control flow nestings and mental load | Campbell Cognitive Complexity, Cyclomatic Complexity |
| **Information Density** | Vocabulary richness, repetition | Shannon Entropy ($H(X)$), Halstead Volume ($V$) |

Each finding is classified deterministically (`critical`, `warning`, `info`) and accompanied by a **Prompt Remedy** containing explicit instructions that human engineers or autonomous AI agents can use to execute surgical refactoring.
