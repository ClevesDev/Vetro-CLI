import 'dart:math' as math;
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/token.dart';

/// Aggregated Halstead complexity statistics for an AST node.
final class HalsteadStats {
  const HalsteadStats({
    required this.distinctOperators,
    required this.distinctOperands,
    required this.totalOperators,
    required this.totalOperands,
  });

  final int distinctOperators;
  final int distinctOperands;
  final int totalOperators;
  final int totalOperands;

  int get vocabulary => distinctOperators + distinctOperands;
  int get length => totalOperators + totalOperands;

  double get volume {
    final n = vocabulary;
    if (n == 0) return 0.0;
    return length * (math.log(n) / math.log(2));
  }

  double get difficulty {
    if (distinctOperands == 0) return 0.0;
    return (distinctOperators / 2) * (totalOperands / distinctOperands);
  }

  double get effort => difficulty * volume;
}

/// Computes Halstead software metrics for a given AST [node].
///
/// Note: The purpose of this function is to compute Halstead software metrics
/// by scanning the raw token stream of an AST node and classifying them.
HalsteadStats halsteadMetrics(AstNode node) {
  final operators = <String>{};
  final operands = <String>{};
  var totalOperators = 0;
  var totalOperands = 0;

  var token = node.beginToken;
  final endToken = node.endToken;

  void processToken(Token tok) {
    final lexeme = tok.lexeme;
    if (lexeme.isEmpty) return;

    if (tok.type.isKeyword || tok.isOperator || _isPunctuationOperator(tok.type)) {
      operators.add(lexeme);
      totalOperators++;
    } else if (tok.type == TokenType.IDENTIFIER || _isLiteralToken(tok.type)) {
      operands.add(lexeme);
      totalOperands++;
    }
  }

  while (token != endToken) {
    processToken(token);
    final next = token.next;
    if (next == null || next == token) break;
    token = next;
  }
  processToken(endToken);

  return HalsteadStats(
    distinctOperators: operators.length,
    distinctOperands: operands.length,
    totalOperators: totalOperators,
    totalOperands: totalOperands,
  );
}

bool _isPunctuationOperator(TokenType type) {
  return type == TokenType.OPEN_PAREN ||
      type == TokenType.CLOSE_PAREN ||
      type == TokenType.OPEN_CURLY_BRACKET ||
      type == TokenType.CLOSE_CURLY_BRACKET ||
      type == TokenType.OPEN_SQUARE_BRACKET ||
      type == TokenType.CLOSE_SQUARE_BRACKET ||
      type == TokenType.SEMICOLON ||
      type == TokenType.COMMA ||
      type == TokenType.PERIOD ||
      type == TokenType.COLON ||
      type == TokenType.QUESTION;
}

bool _isLiteralToken(TokenType type) {
  return type == TokenType.STRING ||
      type == TokenType.INT ||
      type == TokenType.DOUBLE ||
      type == TokenType.HEXADECIMAL ||
      type.lexeme == 'true' ||
      type.lexeme == 'false' ||
      type.lexeme == 'null';
}
