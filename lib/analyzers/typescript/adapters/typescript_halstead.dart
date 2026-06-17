import 'package:vetro/core/metrics/halstead.dart';

/// Computes Halstead stats from raw tokens of a TypeScript function.
HalsteadStats computeTsHalstead(List<String> tokens) {
  final operators = <String>[];
  final operands = <String>[];
  var totalOperators = 0;
  var totalOperands = 0;

  const tsKeywords = {
    'break', 'case', 'catch', 'class', 'const', 'continue', 'debugger',
    'default', 'delete', 'do', 'else', 'export', 'extends',
    'finally', 'for', 'function', 'if', 'import', 'in', 'instanceof',
    'new', 'return', 'super', 'switch', 'this', 'throw',
    'try', 'typeof', 'var', 'void', 'while', 'with', 'yield', 'let',
    'package', 'private', 'protected', 'public', 'static', 'any', 'boolean',
    'constructor', 'declare', 'get', 'module', 'require', 'number',
    'readonly', 'set', 'string', 'symbol', 'type', 'from', 'of', 'as',
    'keyof', 'is', 'async', 'await'
  };

  const tsOperators = {
    '+', '-', '*', '/', '%', '++', '--', '=', '+=', '-=', '*=', '/=', '%=',
    '==', '===', '!=', '!==', '<', '<=', '>', '>=', '&&', '||', '!', '&',
    '|', '^', '~', '<<', '>>', '>>>', '?', ':', '??', '?.', '=>',
    '(', ')', '{', '}', '[', ']', ',', ';', '.'
  };

  for (final token in tokens) {
    if (token.isEmpty) continue;

    if (tsKeywords.contains(token) || tsOperators.contains(token)) {
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
