import 'dart:math' as math;

/// Computes the average pairwise cosine similarity between multiple identifier vocabularies.
double averagePairwiseVocabularySimilarity(List<Set<String>> vocabularies) {
  if (vocabularies.length <= 1) return 1.0;

  var sumSimilarity = 0.0;
  var countPairs = 0;

  for (var i = 0; i < vocabularies.length; i++) {
    for (var j = i + 1; j < vocabularies.length; j++) {
      final vocabA = vocabularies[i];
      final vocabB = vocabularies[j];

      final intersectionSize = vocabA.intersection(vocabB).length;
      final denominator = math.sqrt(vocabA.length * vocabB.length);

      final similarity = denominator == 0 ? 0.0 : intersectionSize / denominator;
      sumSimilarity += similarity;
      countPairs++;
    }
  }

  if (countPairs == 0) return 1.0;
  return sumSimilarity / countPairs;
}
