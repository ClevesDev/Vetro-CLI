/// Cyclomatic complexity metric for Dart AST nodes.
///
/// Cyclomatic complexity (CC) measures the number of linearly independent
/// paths through a function's control flow graph.
///
/// **Formula**: CC = 1 + Σ(decision points)
///
/// Decision points counted:
/// - `if` statements
/// - `for` statements (including for-in via ForEachParts)
/// - `while` statements
/// - `do-while` statements
/// - `switch` cases (non-default `SwitchCase` and `SwitchPatternCase`)
/// - `switch` expression cases (`SwitchExpressionCase`)
/// - `catch` clauses
/// - Conditional expressions (`? :`)
/// - Logical operators (`&&`, `||`)
/// - Null-coalescing operator (`??`)
///
/// Reference: McCabe, T.J. (1976) "A Complexity Measure",
/// IEEE Transactions on Software Engineering, SE-2(4), pp. 308–320.
library;

import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';

/// Computes cyclomatic complexity for a given AST [node].
///
/// Returns an integer ≥ 1. A straight-line function with no branches
/// has CC = 1. Each decision point adds exactly 1.
///
/// Typical thresholds:
/// - 1–10: simple, low risk
/// - 11–20: moderate complexity
/// - 21–50: high complexity, consider refactoring
/// - 50+: untestable, must refactor
///
/// This is a pure function — deterministic, no side effects.
int cyclomaticComplexity(AstNode node) {
  final visitor = _ComplexityVisitor();
  node.accept(visitor);
  return 1 + visitor.decisionPoints;
}

/// Visitor that counts decision points in the AST.
///
/// Each visit method corresponds to one type of branching construct.
/// The visitor is recursive, so nested branches are counted correctly.
final class _ComplexityVisitor extends RecursiveAstVisitor<void> {
  /// Running count of decision points found.
  int decisionPoints = 0;

  // ── Control flow statements ────────────────────────────────────────

  @override
  void visitIfStatement(IfStatement node) {
    decisionPoints++;
    super.visitIfStatement(node);
  }

  /// Counts `for` and `for-in` loops.
  ///
  /// Both `for (var i = 0; ...)` and `for (final x in list)` produce
  /// a [ForStatement] node — the loop parts differ, but the decision
  /// point is the same: enter the loop body or skip it.
  @override
  void visitForStatement(ForStatement node) {
    decisionPoints++;
    super.visitForStatement(node);
  }

  @override
  void visitWhileStatement(WhileStatement node) {
    decisionPoints++;
    super.visitWhileStatement(node);
  }

  @override
  void visitDoStatement(DoStatement node) {
    decisionPoints++;
    super.visitDoStatement(node);
  }

  /// Counts non-default switch cases (traditional switch).
  ///
  /// Default cases are not counted because they don't add an
  /// independent path — they're the "else" of the switch.
  @override
  void visitSwitchCase(SwitchCase node) {
    decisionPoints++;
    super.visitSwitchCase(node);
  }

  /// Counts pattern-based switch cases (Dart 3+ switch statements).
  @override
  void visitSwitchPatternCase(SwitchPatternCase node) {
    decisionPoints++;
    super.visitSwitchPatternCase(node);
  }

  /// Counts switch expression cases (Dart 3+ `switch` expressions).
  @override
  void visitSwitchExpressionCase(SwitchExpressionCase node) {
    decisionPoints++;
    super.visitSwitchExpressionCase(node);
  }

  // ── Exception handling ─────────────────────────────────────────────

  @override
  void visitCatchClause(CatchClause node) {
    decisionPoints++;
    super.visitCatchClause(node);
  }

  // ── Expressions with branching semantics ───────────────────────────

  /// Counts the ternary conditional operator `? :`.
  @override
  void visitConditionalExpression(ConditionalExpression node) {
    decisionPoints++;
    super.visitConditionalExpression(node);
  }

  /// Counts logical operators `&&`, `||`, and null-coalescing `??`.
  ///
  /// Each of these introduces a short-circuit branch:
  /// - `&&`: if left is false, right is not evaluated
  /// - `||`: if left is true, right is not evaluated
  /// - `??`: if left is non-null, right is not evaluated
  ///
  /// Other binary operators (arithmetic, comparison, bitwise) do not
  /// introduce branching and are not counted.
  @override
  void visitBinaryExpression(BinaryExpression node) {
    final op = node.operator.lexeme;
    if (op == '&&' || op == '||' || op == '??') {
      decisionPoints++;
    }
    super.visitBinaryExpression(node);
  }
}

/// Computes Campbell's cognitive complexity for a given AST [node].
///
/// Cognitive complexity measures how difficult a function is to understand
/// for a human reader, penalizing nested control structures recursively.
int cognitiveComplexity(AstNode node) {
  final visitor = _CognitiveComplexityVisitor();
  node.accept(visitor);
  return visitor.complexity;
}

/// Visitor that computes Campbell's cognitive complexity.
final class _CognitiveComplexityVisitor extends RecursiveAstVisitor<void> {
  int complexity = 0;
  int _nestingLevel = 0;

  // ── Helper to execute block at a higher nesting level ────────────────
  void _withNesting(void Function() f) {
    _nestingLevel++;
    f();
    _nestingLevel--;
  }

  // ── Helper to check if this is an "else if" ────────────────────────
  bool _isElseIf(IfStatement node) {
    final parent = node.parent;
    if (parent is IfStatement) {
      return parent.elseStatement == node;
    }
    return false;
  }

  // ── Control flow statements ────────────────────────────────────────

  @override
  void visitIfStatement(IfStatement node) {
    if (_isElseIf(node)) {
      complexity += 1;
    } else {
      complexity += 1 + _nestingLevel;
    }

    _withNesting(() {
      node.thenStatement.accept(this);
      node.elseStatement?.accept(this);
    });
  }

  @override
  void visitForStatement(ForStatement node) {
    complexity += 1 + _nestingLevel;
    _withNesting(() {
      super.visitForStatement(node);
    });
  }

  @override
  void visitWhileStatement(WhileStatement node) {
    complexity += 1 + _nestingLevel;
    _withNesting(() {
      super.visitWhileStatement(node);
    });
  }

  @override
  void visitDoStatement(DoStatement node) {
    complexity += 1 + _nestingLevel;
    _withNesting(() {
      super.visitDoStatement(node);
    });
  }

  @override
  void visitSwitchStatement(SwitchStatement node) {
    complexity += 1;
    _withNesting(() {
      super.visitSwitchStatement(node);
    });
  }

  @override
  void visitCatchClause(CatchClause node) {
    complexity += 1 + _nestingLevel;
    _withNesting(() {
      super.visitCatchClause(node);
    });
  }

  // ── Expressions ────────────────────────────────────────────────────

  @override
  void visitConditionalExpression(ConditionalExpression node) {
    complexity += 1 + _nestingLevel;
    _withNesting(() {
      super.visitConditionalExpression(node);
    });
  }

  @override
  void visitBinaryExpression(BinaryExpression node) {
    final op = node.operator.lexeme;
    if (op == '&&' || op == '||' || op == '??') {
      final parent = node.parent;
      var isSequence = false;
      if (parent is BinaryExpression) {
        if (parent.operator.lexeme == op) {
          isSequence = true;
        }
      }
      if (!isSequence) {
        complexity += 1;
      }
    }
    super.visitBinaryExpression(node);
  }
}

