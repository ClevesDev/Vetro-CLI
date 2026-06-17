import 'dart:math' as math;

/// Computes the ratio of intent comments to total comments in the source string.
double commentIntentRatio(String source) {
  final lines = source.split('\n');
  var commentCount = 0;
  var intentCount = 0;
  final intentKeywords = const {
    'why', 'because', 'reason', 'purpose', 'intent',
    'rationale', 'note', 'important', 'hack', 'workaround', 'todo'
  };

  for (final line in lines) {
    final trimmed = line.trim();
    if (trimmed.startsWith('//') || trimmed.startsWith('///')) {
      commentCount++;
      final lower = trimmed.toLowerCase();
      for (final kw in intentKeywords) {
        if (lower.contains(kw)) {
          intentCount++;
          break;
        }
      }
    }
  }

  if (commentCount == 0) return 0.0;
  return intentCount / commentCount;
}

/// Computes the Shannon entropy of a map of counts.
double shannonEntropyFromCounts(Map<String, int> counts) {
  var total = 0;
  for (final count in counts.values) {
    total += count;
  }

  if (total == 0) return 0.0;

  var entropy = 0.0;
  for (final count in counts.values) {
    final p = count / total;
    entropy -= p * (math.log(p) / math.log(2));
  }

  return entropy;
}

/// Computes the Shannon entropy of a sequence of items.
double shannonEntropyFromSequence(List<String> items) {
  final counts = <String, int>{};
  for (final item in items) {
    counts[item] = (counts[item] ?? 0) + 1;
  }
  return shannonEntropyFromCounts(counts);
}
