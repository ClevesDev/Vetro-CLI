import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';

/// Computes cyclomatic complexity for a given AST [node].
int cyclomaticComplexity(AstNode node) {
  final visitor = ComplexityVisitor();
  node.accept(visitor);
  return 1 + visitor.decisionPoints;
}

/// Visitor that counts decision points in the AST.
final class ComplexityVisitor extends RecursiveAstVisitor<void> {
  int decisionPoints = 0;

  @override
  void visitIfStatement(IfStatement node) {
    decisionPoints++;
    super.visitIfStatement(node);
  }

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

  @override
  void visitSwitchCase(SwitchCase node) {
    decisionPoints++;
    super.visitSwitchCase(node);
  }

  @override
  void visitSwitchPatternCase(SwitchPatternCase node) {
    decisionPoints++;
    super.visitSwitchPatternCase(node);
  }

  @override
  void visitSwitchExpressionCase(SwitchExpressionCase node) {
    decisionPoints++;
    super.visitSwitchExpressionCase(node);
  }

  @override
  void visitCatchClause(CatchClause node) {
    decisionPoints++;
    super.visitCatchClause(node);
  }

  @override
  void visitConditionalExpression(ConditionalExpression node) {
    decisionPoints++;
    super.visitConditionalExpression(node);
  }

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
int cognitiveComplexity(AstNode node) {
  final visitor = CognitiveComplexityVisitor();
  node.accept(visitor);
  return visitor.complexity;
}

/// Visitor that computes Campbell's cognitive complexity.
final class CognitiveComplexityVisitor extends RecursiveAstVisitor<void> {
  int complexity = 0;
  int _nestingLevel = 0;

  void _withNesting(void Function() f) {
    _nestingLevel++;
    f();
    _nestingLevel--;
  }

  bool _isElseIf(IfStatement node) {
    final parent = node.parent;
    if (parent is IfStatement) {
      return parent.elseStatement == node;
    }
    return false;
  }

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
