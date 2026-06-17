import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/token.dart';
import 'package:vetro/core/metrics/halstead.dart';

/// Computes Halstead software metrics for a given AST [node].
HalsteadStats halsteadMetrics(AstNode node) {
  final operators = <String>[];
  final operands = <String>[];
  var totalOperators = 0;
  var totalOperands = 0;

  var token = node.beginToken;
  final endToken = node.endToken;

  void processToken(Token tok) {
    final lexeme = tok.lexeme;
    if (lexeme.isEmpty) return;

    if (tok.type.isKeyword || tok.isOperator || isPunctuationOperator(tok.type)) {
      operators.add(lexeme);
      totalOperators++;
    } else if (tok.type == TokenType.IDENTIFIER || isLiteralToken(tok.type)) {
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

  return halsteadFromClassifiedTokens(
    operators: operators,
    operands: operands,
    totalOperators: totalOperators,
    totalOperands: totalOperands,
  );
}

bool isPunctuationOperator(TokenType type) {
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

bool isLiteralToken(TokenType type) {
  return type == TokenType.STRING ||
      type == TokenType.INT ||
      type == TokenType.DOUBLE ||
      type == TokenType.HEXADECIMAL ||
      type.lexeme == 'true' ||
      type.lexeme == 'false' ||
      type.lexeme == 'null';
}
