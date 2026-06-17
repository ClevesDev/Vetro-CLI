/// Pure functions for structural code similarity analysis.
///
/// The core idea: two code fragments are "structurally similar" if they
/// perform the same operations in the same order, regardless of naming.
/// We achieve this by:
/// 1. Extracting structural tokens from each AST subtree (normalizing
///    all identifiers to `_id_` so naming differences vanish).
/// 2. Building term-frequency vectors from the token lists.
/// 3. Computing cosine similarity between the vectors.
///
/// Mathematical basis — cosine similarity:
///   cos(θ) = (A · B) / (‖A‖ × ‖B‖)
///   where A and B are term-frequency vectors over the shared vocabulary.
///   Result ∈ [0.0, 1.0]: 0 = completely different, 1 = identical structure.
library;

import 'dart:math' as math;

import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';

/// Computes the cosine similarity between two token sequences.
///
/// Given two lists of tokens (strings), this function:
/// 1. Builds a term-frequency map for each list.
/// 2. Constructs vectors over the union of all terms.
/// 3. Computes: cos(θ) = Σ(a_i × b_i) / (√Σ(a_i²) × √Σ(b_i²))
///
/// Returns 0.0 if either list is empty (no meaningful comparison).
/// Returns a value in [0.0, 1.0].
double cosineSimilarity(List<String> tokensA, List<String> tokensB) {
  // We check for empty inputs first because cosine similarity is undefined 
  // (division by zero) when one of the vectors has zero magnitude.
  if (tokensA.isEmpty || tokensB.isEmpty) return 0.0;

  final freqA = _termFrequency(tokensA);
  final freqB = _termFrequency(tokensB);

  // Build the union of all terms as the vector space.
  final allTerms = <String>{...freqA.keys, ...freqB.keys};

  var dotProduct = 0.0;
  var magnitudeA = 0.0;
  var magnitudeB = 0.0;

  for (final term in allTerms) {
    final a = (freqA[term] ?? 0).toDouble();
    final b = (freqB[term] ?? 0).toDouble();
    dotProduct += a * b;
    magnitudeA += a * a;
    magnitudeB += b * b;
  }

  final denominator = math.sqrt(magnitudeA) * math.sqrt(magnitudeB);
  if (denominator == 0.0) return 0.0;

  return (dotProduct / denominator).clamp(0.0, 1.0);
}

/// Recursively extracts structural tokens from an AST node,
/// normalizing all user-defined identifiers to `_id_`.
///
/// The token list captures the *shape* of the code:
/// - Node types (e.g., `IfStatement`, `MethodInvocation`)
/// - Operators and keywords (structural meaning)
/// - Literal types (but not literal values)
/// - All identifiers replaced with `_id_` to ignore naming
///
/// Two functions that do the same thing with different variable names
/// will produce identical token lists.
List<String> tokenizeAst(AstNode node) {
  final visitor = _TokenExtractorVisitor();
  node.accept(visitor);
  return visitor.tokens;
}

/// Computes the structural similarity between two AST subtrees.
///
/// This is the high-level API: tokenize both nodes with identifier
/// normalization, then compute the LCS-based similarity coefficient.
///
/// Returns a value in [0.0, 1.0]:
/// - 1.0 = identical structure (ignoring names)
/// - 0.0 = completely different structure
double astStructuralSimilarity(AstNode nodeA, AstNode nodeB) {
  final tokensA = tokenizeAst(nodeA);
  final tokensB = tokenizeAst(nodeB);
  return lcsSimilarity(tokensA, tokensB);
}

/// Extracts raw token lexemes from an AST node's token stream,
/// filtering out common punctuation and operators to prevent them from
/// inflating similarity scores as "stop words".
List<String> tokenizeRaw(AstNode node) {
  // We filter out common stop words because they represent boilerplate punctuation
  // and operators that occur in almost every function, inflating similarity scores.
  final tokens = <String>[];
  var token = node.beginToken;
  
  // Guard against unbound or single token cases.
  if (token == token.next) {
    if (!_isStopWord(token.lexeme)) {
      tokens.add(token.lexeme);
    }
    return tokens;
  }

  while (token != node.endToken) {
    if (!_isStopWord(token.lexeme)) {
      tokens.add(token.lexeme);
    }
    final next = token.next;
    if (next == null || next == token) break;
    token = next;
  }
  if (!_isStopWord(node.endToken.lexeme)) {
    tokens.add(node.endToken.lexeme);
  }
  return tokens;
}

/// Checks if a lexeme is a common punctuation or operator "stop word".
bool _isStopWord(String lexeme) {
  const stopWords = {
    '(', ')', '{', '}', '[', ']', ';', ',', '.', ':', '?', '=',
    '+', '-', '*', '/', '%', '==', '!=', '>', '<', '>=', '<=',
    '&&', '||', '!', '??', '?.', '=>', '+=', '-=', '*=', '/=',
  };
  return stopWords.contains(lexeme);
}

/// Computes the structural similarity between two AST subtrees using cosine similarity.
///
/// This is the high-level API: tokenize both nodes using raw tokens (which
/// preserves identifier names and literal values), then compute the cosine similarity.
/// We do this because cosine similarity over raw tokens is less sensitive to exact
/// operations ordering, making it ideal for detecting copy-paste-modify patterns (Copy-Mutate).
///
/// Returns a value in [0.0, 1.0].
double astCosineSimilarity(AstNode nodeA, AstNode nodeB) {
  final tokensA = tokenizeRaw(nodeA);
  final tokensB = tokenizeRaw(nodeB);
  return cosineSimilarity(tokensA, tokensB);
}

/// Computes a deterministic structural hash for a given AST [node].
///
/// Normalizes the AST structure (ignoring variable names) and hashes the
/// resulting token list. If two nodes have identical structural token lists,
/// their hashes will be identical.
String computeAstHash(AstNode node) {
  final tokens = tokenizeAst(node);
  return fnv1a32(tokens);
}

String fnv1a32(List<String> tokens) {
  var hash = 2166136261;
  const prime = 16777619;
  const mask = 0xFFFFFFFF;

  for (final token in tokens) {
    for (var i = 0; i < token.length; i++) {
      hash ^= token.codeUnitAt(i);
      hash = (hash * prime) & mask;
    }
    hash ^= 0;
    hash = (hash * prime) & mask;
  }
  return hash.toRadixString(16).padLeft(8, '0');
}


/// Computes the Longest Common Subsequence (LCS) length between two token lists.
int lcsLength(List<String> a, List<String> b) {
  final n = a.length;
  final m = b.length;
  // We immediately return 0 because a sequence of length 0 can never 
  // share a common subsequence with any other sequence.
  if (n == 0 || m == 0) return 0;

  final dp = List.generate(n + 1, (_) => List.filled(m + 1, 0));

  for (var i = 1; i <= n; i++) {
    for (var j = 1; j <= m; j++) {
      if (a[i - 1] == b[j - 1]) {
        dp[i][j] = dp[i - 1][j - 1] + 1;
      } else {
        dp[i][j] = math.max(dp[i - 1][j], dp[i][j - 1]);
      }
    }
  }

  return dp[n][m];
}

/// Computes the LCS-based structural similarity coefficient.
///
/// **Formula**: similarity = 2 × LCS(a, b) / (|a| + |b|)
///
/// Returns a value in [0.0, 1.0].
double lcsSimilarity(List<String> a, List<String> b) {
  if (a.isEmpty || b.isEmpty) return 0.0;
  final lcs = lcsLength(a, b);
  return (2.0 * lcs) / (a.length + b.length);
}

/// Builds a term → count map from a list of tokens.
///
/// This is the bag-of-words model: each unique token is a dimension,
/// and its count is the coordinate value.
Map<String, int> _termFrequency(List<String> tokens) {
  final freq = <String, int>{};
  for (final token in tokens) {
    freq[token] = (freq[token] ?? 0) + 1;
  }
  return freq;
}

/// A recursive AST visitor that extracts structural tokens.
///
/// Every visited node contributes one or more tokens that encode
/// the *structure* of the code. Operators are preserved as they carry
/// semantic meaning (e.g., `+` vs `*`). Literal types are preserved
/// but values are discarded.
final class _TokenExtractorVisitor extends RecursiveAstVisitor<void> {
  /// The accumulated structural tokens in pre-order traversal.
  final List<String> tokens = [];

  // ── Declarations ───────────────────────────────────────────────────

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
    // Encode the arity — number of parameters is structural.
    tokens.add('FormalParameterList:${node.parameters.length}');
    super.visitFormalParameterList(node);
  }

  // ── Expressions ────────────────────────────────────────────────────

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
    // Preserve the operator — it's semantically meaningful.
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

  // ── Statements ─────────────────────────────────────────────────────

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

  // ── Function bodies ────────────────────────────────────────────────

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

  // ── Literals (type preserved, value discarded) ─────────────────────

  @override
  void visitIntegerLiteral(IntegerLiteral node) {
    tokens.add('IntegerLiteral');
    // Leaf node — no super call needed.
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

  // ── Collections ────────────────────────────────────────────────────

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

  // ── Types ──────────────────────────────────────────────────────────

  @override
  void visitNamedType(NamedType node) {
    // Type names are structural — preserve them.
    tokens.add('Type:${node.name2.lexeme}');
    super.visitNamedType(node);
  }

  // ── Patterns (Dart 3+) ─────────────────────────────────────────────

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
