import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:vetro/core/metrics/similarity.dart';

/// Recursively extracts structural tokens from an AST node,
/// normalizing all user-defined identifiers to `_id_`.
List<String> tokenizeAst(AstNode node) {
  final visitor = TokenExtractorVisitor();
  node.accept(visitor);
  return visitor.tokens;
}

/// Computes the structural similarity between two AST subtrees.
double astStructuralSimilarity(AstNode nodeA, AstNode nodeB) {
  final tokensA = tokenizeAst(nodeA);
  final tokensB = tokenizeAst(nodeB);
  return lcsSimilarity(tokensA, tokensB);
}

/// Extracts raw token lexemes from an AST node's token stream,
/// filtering out common punctuation and operators to prevent them from
/// inflating similarity scores as "stop words".
List<String> tokenizeRaw(AstNode node) {
  final tokens = <String>[];
  var token = node.beginToken;
  
  if (token == token.next) {
    if (!isStopWord(token.lexeme)) {
      tokens.add(token.lexeme);
    }
    return tokens;
  }

  while (token != node.endToken) {
    if (!isStopWord(token.lexeme)) {
      tokens.add(token.lexeme);
    }
    final next = token.next;
    if (next == null || next == token) break;
    token = next;
  }
  if (!isStopWord(node.endToken.lexeme)) {
    tokens.add(node.endToken.lexeme);
  }
  return tokens;
}

/// Checks if a lexeme is a common punctuation or operator "stop word".
bool isStopWord(String lexeme) {
  const stopWords = {
    '(', ')', '{', '}', '[', ']', ';', ',', '.', ':', '?', '=',
    '+', '-', '*', '/', '%', '==', '!=', '>', '<', '>=', '<=',
    '&&', '||', '!', '??', '?.', '=>', '+=', '-=', '*=', '/=',
  };
  return stopWords.contains(lexeme);
}

/// Computes the structural similarity between two AST subtrees using cosine similarity.
double astCosineSimilarity(AstNode nodeA, AstNode nodeB) {
  final tokensA = tokenizeRaw(nodeA);
  final tokensB = tokenizeRaw(nodeB);
  return cosineSimilarity(tokensA, tokensB);
}

/// Computes a deterministic structural hash for a given AST [node].
String computeAstHash(AstNode node) {
  final tokens = tokenizeAst(node);
  return fnv1a32(tokens);
}

/// A recursive AST visitor that extracts structural tokens.
final class TokenExtractorVisitor extends RecursiveAstVisitor<void> {
  final List<String> tokens = [];

  @override
  void visitFunctionDeclaration(FunctionDeclaration node) {
    tokens.add('FunctionDeclaration');
    super.visitFunctionDeclaration(node);
  }

  @override
  void visitMethodDeclaration(MethodDeclaration node) {
    tokens.add('MethodDeclaration');
    super.visitMethodDeclaration(node);
  }

  @override
  void visitClassDeclaration(ClassDeclaration node) {
    tokens.add('ClassDeclaration');
    super.visitClassDeclaration(node);
  }

  @override
  void visitConstructorDeclaration(ConstructorDeclaration node) {
    tokens.add('ConstructorDeclaration');
    super.visitConstructorDeclaration(node);
  }

  @override
  void visitFieldDeclaration(FieldDeclaration node) {
    tokens.add('FieldDeclaration');
    super.visitFieldDeclaration(node);
  }

  @override
  void visitVariableDeclaration(VariableDeclaration node) {
    tokens.add('VariableDeclaration');
    super.visitVariableDeclaration(node);
  }

  @override
  void visitFormalParameterList(FormalParameterList node) {
    tokens.add('FormalParameterList:${node.parameters.length}');
    super.visitFormalParameterList(node);
  }

  @override
  void visitFunctionExpression(FunctionExpression node) {
    tokens.add('FunctionExpression');
    super.visitFunctionExpression(node);
  }

  @override
  void visitMethodInvocation(MethodInvocation node) {
    tokens.add('MethodInvocation');
    super.visitMethodInvocation(node);
  }

  @override
  void visitBinaryExpression(BinaryExpression node) {
    tokens.add('BinaryExpression:${node.operator.lexeme}');
    super.visitBinaryExpression(node);
  }

  @override
  void visitPrefixExpression(PrefixExpression node) {
    tokens.add('PrefixExpression:${node.operator.lexeme}');
    super.visitPrefixExpression(node);
  }

  @override
  void visitPostfixExpression(PostfixExpression node) {
    tokens.add('PostfixExpression:${node.operator.lexeme}');
    super.visitPostfixExpression(node);
  }

  @override
  void visitConditionalExpression(ConditionalExpression node) {
    tokens.add('ConditionalExpression');
    super.visitConditionalExpression(node);
  }

  @override
  void visitAssignmentExpression(AssignmentExpression node) {
    tokens.add('AssignmentExpression:${node.operator.lexeme}');
    super.visitAssignmentExpression(node);
  }

  @override
  void visitIndexExpression(IndexExpression node) {
    tokens.add('IndexExpression');
    super.visitIndexExpression(node);
  }

  @override
  void visitPropertyAccess(PropertyAccess node) {
    tokens.add('PropertyAccess');
    super.visitPropertyAccess(node);
  }

  @override
  void visitInstanceCreationExpression(InstanceCreationExpression node) {
    tokens.add('InstanceCreationExpression');
    super.visitInstanceCreationExpression(node);
  }

  @override
  void visitThrowExpression(ThrowExpression node) {
    tokens.add('ThrowExpression');
    super.visitThrowExpression(node);
  }

  @override
  void visitAwaitExpression(AwaitExpression node) {
    tokens.add('AwaitExpression');
    super.visitAwaitExpression(node);
  }

  @override
  void visitAsExpression(AsExpression node) {
    tokens.add('AsExpression');
    super.visitAsExpression(node);
  }

  @override
  void visitIsExpression(IsExpression node) {
    tokens.add('IsExpression');
    super.visitIsExpression(node);
  }

  @override
  void visitCascadeExpression(CascadeExpression node) {
    tokens.add('CascadeExpression');
    super.visitCascadeExpression(node);
  }

  @override
  void visitSpreadElement(SpreadElement node) {
    tokens.add('SpreadElement');
    super.visitSpreadElement(node);
  }

  @override
  void visitIfStatement(IfStatement node) {
    tokens.add('IfStatement');
    super.visitIfStatement(node);
  }

  @override
  void visitForStatement(ForStatement node) {
    tokens.add('ForStatement');
    super.visitForStatement(node);
  }

  @override
  void visitWhileStatement(WhileStatement node) {
    tokens.add('WhileStatement');
    super.visitWhileStatement(node);
  }

  @override
  void visitDoStatement(DoStatement node) {
    tokens.add('DoStatement');
    super.visitDoStatement(node);
  }

  @override
  void visitSwitchStatement(SwitchStatement node) {
    tokens.add('SwitchStatement');
    super.visitSwitchStatement(node);
  }

  @override
  void visitSwitchExpression(SwitchExpression node) {
    tokens.add('SwitchExpression');
    super.visitSwitchExpression(node);
  }

  @override
  void visitReturnStatement(ReturnStatement node) {
    tokens.add('ReturnStatement');
    super.visitReturnStatement(node);
  }

  @override
  void visitYieldStatement(YieldStatement node) {
    tokens.add('YieldStatement');
    super.visitYieldStatement(node);
  }

  @override
  void visitAssertStatement(AssertStatement node) {
    tokens.add('AssertStatement');
    super.visitAssertStatement(node);
  }

  @override
  void visitTryStatement(TryStatement node) {
    tokens.add('TryStatement');
    super.visitTryStatement(node);
  }

  @override
  void visitCatchClause(CatchClause node) {
    tokens.add('CatchClause');
    super.visitCatchClause(node);
  }

  @override
  void visitBlockFunctionBody(BlockFunctionBody node) {
    tokens.add('BlockFunctionBody');
    super.visitBlockFunctionBody(node);
  }

  @override
  void visitExpressionFunctionBody(ExpressionFunctionBody node) {
    tokens.add('ExpressionFunctionBody');
    super.visitExpressionFunctionBody(node);
  }

  @override
  void visitIntegerLiteral(IntegerLiteral node) {
    tokens.add('IntegerLiteral');
  }

  @override
  void visitDoubleLiteral(DoubleLiteral node) {
    tokens.add('DoubleLiteral');
  }

  @override
  void visitBooleanLiteral(BooleanLiteral node) {
    tokens.add('BooleanLiteral');
  }

  @override
  void visitSimpleStringLiteral(SimpleStringLiteral node) {
    tokens.add('StringLiteral');
  }

  @override
  void visitStringInterpolation(StringInterpolation node) {
    tokens.add('StringInterpolation');
    super.visitStringInterpolation(node);
  }

  @override
  void visitNullLiteral(NullLiteral node) {
    tokens.add('NullLiteral');
  }

  @override
  void visitListLiteral(ListLiteral node) {
    tokens.add('ListLiteral');
    super.visitListLiteral(node);
  }

  @override
  void visitSetOrMapLiteral(SetOrMapLiteral node) {
    tokens.add('SetOrMapLiteral');
    super.visitSetOrMapLiteral(node);
  }

  @override
  void visitRecordLiteral(RecordLiteral node) {
    tokens.add('RecordLiteral');
    super.visitRecordLiteral(node);
  }

  @override
  void visitNamedType(NamedType node) {
    tokens.add('Type:${node.name2.lexeme}');
    super.visitNamedType(node);
  }

  @override
  void visitSwitchPatternCase(SwitchPatternCase node) {
    tokens.add('SwitchPatternCase');
    super.visitSwitchPatternCase(node);
  }

  @override
  void visitGuardedPattern(GuardedPattern node) {
    tokens.add('GuardedPattern');
    super.visitGuardedPattern(node);
  }

  @override
  void visitPatternVariableDeclaration(PatternVariableDeclaration node) {
    tokens.add('PatternVariableDeclaration');
    super.visitPatternVariableDeclaration(node);
  }

  @override
  void visitNullAssertPattern(NullAssertPattern node) {
    tokens.add('NullAssertPattern');
    super.visitNullAssertPattern(node);
  }

  @override
  void visitNullCheckPattern(NullCheckPattern node) {
    tokens.add('NullCheckPattern');
    super.visitNullCheckPattern(node);
  }
}
