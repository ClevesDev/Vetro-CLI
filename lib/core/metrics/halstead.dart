import 'dart:math' as math;

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

/// Computes Halstead stats from pre-classified lists of operators and operands.
HalsteadStats halsteadFromClassifiedTokens({
  required Iterable<String> operators,
  required Iterable<String> operands,
  required int totalOperators,
  required int totalOperands,
}) {
  return HalsteadStats(
    distinctOperators: operators.toSet().length,
    distinctOperands: operands.toSet().length,
    totalOperators: totalOperators,
    totalOperands: totalOperands,
  );
}
