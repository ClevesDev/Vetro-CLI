/// Pure functions for structural code similarity analysis.
///
/// Mathematical basis — cosine similarity:
///   cos(θ) = (A · B) / (‖A‖ × ‖B‖)
///   where A and B are term-frequency vectors over the shared vocabulary.
///   Result ∈ [0.0, 1.0]: 0 = completely different, 1 = identical structure.
library;

import 'dart:math' as math;

/// Computes the cosine similarity between two token sequences.
double cosineSimilarity(List<String> tokensA, List<String> tokensB) {
  if (tokensA.isEmpty || tokensB.isEmpty) return 0.0;

  final freqA = _termFrequency(tokensA);
  final freqB = _termFrequency(tokensB);

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

/// Computes a deterministic structural hash for a list of tokens.
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
double lcsSimilarity(List<String> a, List<String> b) {
  if (a.isEmpty || b.isEmpty) return 0.0;
  final lcs = lcsLength(a, b);
  return (2.0 * lcs) / (a.length + b.length);
}

/// Builds a term → count map from a list of tokens.
Map<String, int> _termFrequency(List<String> tokens) {
  final freq = <String, int>{};
  for (final token in tokens) {
    freq[token] = (freq[token] ?? 0) + 1;
  }
  return freq;
}
