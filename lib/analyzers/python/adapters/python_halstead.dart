import 'package:vetro/core/metrics/halstead.dart';

/// Computes Halstead stats from raw tokens of a Python function.
HalsteadStats computePyHalstead(List<String> tokens) {
  final operators = <String>[];
  final operands = <String>[];
  var totalOperators = 0;
  var totalOperands = 0;

  const pyKeywords = {
    'as', 'assert', 'async', 'await',
    'break', 'class', 'continue', 'def', 'del', 'elif', 'else', 'except',
    'finally', 'for', 'from', 'global', 'if', 'import', 'nonlocal', 'pass',
    'raise', 'return', 'try', 'while', 'with', 'yield'
  };

  const pyOperators = {
    '+', '-', '*', '/', '%', '**', '//', '=', '+=', '-=', '*=', '/=', '%=',
    '//=', '==', '!=', '<', '<=', '>', '>=', 'is', 'in', 'and', 'or', 'not',
    '&', '|', '^', '~', '<<', '>>', '&=', '|=', '^=', '<<=', '>>=',
    '(', ')', '[', ']', '{', '}', ',', ':', '.', ';', '@', '->'
  };

  for (final token in tokens) {
    if (token.isEmpty) continue;

    if (pyKeywords.contains(token) || pyOperators.contains(token)) {
      operators.add(token);
      totalOperators++;
    } else {
      operands.add(token);
      totalOperands++;
    }
  }

  return halsteadFromClassifiedTokens(
    operators: operators,
    operands: operands,
    totalOperators: totalOperators,
    totalOperands: totalOperands,
  );
}
