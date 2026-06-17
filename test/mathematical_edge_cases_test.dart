import 'dart:math' as math;
import 'package:test/test.dart';
import 'package:vetro/core/metrics/cohesion.dart';
import 'package:vetro/core/metrics/dependency_graph.dart';
import 'package:vetro/core/metrics/entropy.dart';
import 'package:vetro/core/metrics/similarity.dart';

void main() {
  group('Mathematical Edge Cases — Cosine & LCS Similarity', () {
    test('Zero inputs: Empty token sequences return 0.0', () {
      expect(cosineSimilarity([], []), equals(0.0));
      expect(cosineSimilarity(['a'], []), equals(0.0));
      expect(cosineSimilarity([], ['b']), equals(0.0));

      expect(lcsSimilarity([], []), equals(0.0));
      expect(lcsSimilarity(['a'], []), equals(0.0));
      expect(lcsSimilarity([], ['b']), equals(0.0));
    });

    test('Orthogonal sequences: Disjoint vocabularies return 0.0 similarity', () {
      final seqA = ['a', 'b', 'c'];
      final seqB = ['d', 'e', 'f'];
      expect(cosineSimilarity(seqA, seqB), equals(0.0));
      expect(lcsSimilarity(seqA, seqB), equals(0.0));
    });

    test('Identical sequences: Identity holds at 1.0', () {
      final seq = ['class', 'FunctionDef', 'If', 'While', 'Constant'];
      expect(cosineSimilarity(seq, seq), closeTo(1.0, 1e-9));
      expect(lcsSimilarity(seq, seq), closeTo(1.0, 1e-9));
    });

    test('Extreme asymmetry: Handling heavily scaled counts', () {
      final seqA = ['a'];
      final seqB = List.filled(10000, 'a');
      final sim = cosineSimilarity(seqA, seqB);
      // Because cosine similarity is normalized by magnitude:
      // freqA = {'a': 1}, freqB = {'a': 10000}
      // dot = 10000, magA = sqrt(1) = 1, magB = sqrt(10000^2) = 10000
      // dot / (magA * magB) = 10000 / 10000 = 1.0
      expect(sim, closeTo(1.0, 1e-9));
      
      // But LCS similarity is length-sensitive:
      // 2 * 1 / (1 + 10000) = 2 / 10001
      expect(lcsSimilarity(seqA, seqB), closeTo(2 / 10001, 1e-9));
    });

    test('LCS length edge cases', () {
      expect(lcsLength([], []), equals(0));
      expect(lcsLength(['a'], ['b']), equals(0));
      expect(lcsLength(['a', 'b'], ['b', 'a']), equals(1));
    });
  });

  group('Mathematical Edge Cases — Shannon Entropy', () {
    test('Zero input: Empty sequence or counts returns 0.0', () {
      expect(shannonEntropyFromSequence([]), equals(0.0));
      expect(shannonEntropyFromCounts({}), equals(0.0));
    });

    test('Homogeneous inputs: Minimal information variety yields 0.0 entropy', () {
      final seq = List.filled(1000, 'FunctionDef');
      expect(shannonEntropyFromSequence(seq), equals(0.0));
      expect(shannonEntropyFromCounts({'FunctionDef': 1000}), equals(0.0));
    });

    test('Uniform distribution: Entropy equals log2(K) for K unique categories', () {
      // For K = 8 unique categories distributed evenly:
      // H(X) = - 8 * (1/8 * log2(1/8)) = - log2(1/8) = log2(8) = 3.0
      final seq8 = ['a', 'b', 'c', 'd', 'e', 'f', 'g', 'h'];
      expect(shannonEntropyFromSequence(seq8), closeTo(3.0, 1e-9));

      // For K = 4 unique categories:
      // H(X) = log2(4) = 2.0
      final seq4 = ['a', 'b', 'c', 'd'];
      expect(shannonEntropyFromSequence(seq4), closeTo(2.0, 1e-9));
    });

    test('Inequality bounds property: H(X) <= log2(N)', () {
      final seq = ['a', 'a', 'b', 'c', 'd', 'd', 'd'];
      final h = shannonEntropyFromSequence(seq);
      final maxTheoretical = math.log(seq.length) / math.log(2);
      expect(h, lessThanOrEqualTo(maxTheoretical + 1e-9));
    });
  });

  group('Mathematical Edge Cases — Class Cohesion', () {
    test('Empty or single vocabulary: Default cohesion holds at 1.0', () {
      expect(averagePairwiseVocabularySimilarity([]), equals(1.0));
      expect(averagePairwiseVocabularySimilarity([{'a', 'b'}]), equals(1.0));
    });

    test('Ortogonal class methods: Perfect disjointness yields 0.0 cohesion', () {
      final vocabularies = [
        {'x', 'y'},
        {'z', 'w'},
        {'a', 'b'},
      ];
      expect(averagePairwiseVocabularySimilarity(vocabularies), equals(0.0));
    });

    test('Identical class methods: Perfect overlap yields 1.0 cohesion', () {
      final vocabularies = [
        {'a', 'b', 'c'},
        {'a', 'b', 'c'},
        {'a', 'b', 'c'},
      ];
      expect(averagePairwiseVocabularySimilarity(vocabularies), closeTo(1.0, 1e-9));
    });

    test('Partial class methods overlap: Calculation correctness', () {
      // V1 = {a, b}, V2 = {b, c}
      // intersection = {b} (size 1)
      // denominator = sqrt(2 * 2) = 2
      // similarity = 1 / 2 = 0.5
      final vocabularies = [
        {'a', 'b'},
        {'b', 'c'},
      ];
      expect(averagePairwiseVocabularySimilarity(vocabularies), closeTo(0.5, 1e-9));
    });
  });

  group('Mathematical Edge Cases — Graph Centrality & Clustering Coefficient', () {
    test('Empty Graph: returns empty map and doesn\'t crash', () {
      final graph = DependencyGraph();
      expect(graph.eigenvectorCentrality(), isEmpty);
    });

    test('N disconnected nodes: returns uniform or empty centrality', () {
      final graph = DependencyGraph();
      graph.addNode('A');
      graph.addNode('B');
      graph.addNode('C');
      
      final centrality = graph.eigenvectorCentrality();
      // Since there are no edges, PageRank / eigenvector centrality with damping
      // should distribute uniformly.
      // Sum of squares (L2-norm) must be 1.0.
      expect(centrality, isNotEmpty);
      var sumSq = 0.0;
      for (final val in centrality.values) {
        sumSq += val * val;
      }
      expect(sumSq, closeTo(1.0, 1e-6));
      expect(centrality['A'], closeTo(centrality['B']!, 1e-6));
      expect(centrality['A'], closeTo(centrality['C']!, 1e-6));
    });

    test('Symmetric ring cycle: All nodes receive identical PageRank', () {
      // Ring A -> B -> C -> A
      final graph = DependencyGraph();
      graph.addEdge('A', 'B');
      graph.addEdge('B', 'C');
      graph.addEdge('C', 'A');

      final centrality = graph.eigenvectorCentrality();
      expect(centrality, hasLength(3));
      
      // By symmetry, all values must be identical: 1/sqrt(3) ≈ 0.57735
      final expected = 1.0 / math.sqrt(3);
      expect(centrality['A'], closeTo(expected, 1e-5));
      expect(centrality['B'], closeTo(expected, 1e-5));
      expect(centrality['C'], closeTo(expected, 1e-5));
    });

    test('Sink node (Sumidero): Damping prevents score propagation traps', () {
      // A -> B (B has no outgoing edges - spider trap)
      final graph = DependencyGraph();
      graph.addEdge('A', 'B');

      final centrality = graph.eigenvectorCentrality();
      // Without damping, B would accumulate all score. With damping (0.85),
      // A still retains some score (> 0).
      expect(centrality['A'], greaterThan(0.0));
      expect(centrality['B'], greaterThan(centrality['A']!));
      
      // L2 Norm conservation check
      var sumSq = 0.0;
      for (final val in centrality.values) {
        sumSq += val * val;
      }
      expect(sumSq, closeTo(1.0, 1e-6));
    });

    test('Local Clustering Coefficient: Less than 2 neighbors returns 0.0', () {
      final graph = DependencyGraph();
      // Node A has only 1 neighbor (B)
      graph.addEdge('A', 'B');
      expect(graph.localClusteringCoefficient('A'), equals(0.0));
    });

    test('Local Clustering Coefficient: Star graph center returns 0.0', () {
      final graph = DependencyGraph();
      // B <- A -> C (A is connected to B and C, but B and C are disconnected)
      graph.addEdge('A', 'B');
      graph.addEdge('A', 'C');
      
      expect(graph.localClusteringCoefficient('A'), equals(0.0));
    });

    test('Local Clustering Coefficient: Complete Clique Kn returns 1.0', () {
      final graph = DependencyGraph();
      // Clique K3: A, B, C are fully connected.
      // Edges: A <-> B, B <-> C, C <-> A
      graph.addEdge('A', 'B');
      graph.addEdge('B', 'A');
      graph.addEdge('B', 'C');
      graph.addEdge('C', 'B');
      graph.addEdge('C', 'A');
      graph.addEdge('A', 'C');

      expect(graph.localClusteringCoefficient('A'), closeTo(1.0, 1e-9));
      expect(graph.localClusteringCoefficient('B'), closeTo(1.0, 1e-9));
      expect(graph.localClusteringCoefficient('C'), closeTo(1.0, 1e-9));
    });
  });

  group('Hashing Edge Cases — FNV-1a 32-bit', () {
    test('FNV-1a: Empty token list returns offset basis', () {
      // Offset basis: 2166136261 (0x811c9dc5)
      expect(fnv1a32([]), equals('811c9dc5'));
    });

    test('FNV-1a: Renaming variables keeps same hash if AST normalizer ignores names', () {
      final tokens1 = ['void', 'Identifier', '(', 'int', 'Identifier', ')', '{', '}'];
      final tokens2 = ['void', 'Identifier', '(', 'int', 'Identifier', ')', '{', '}'];
      expect(fnv1a32(tokens1), equals(fnv1a32(tokens2)));
    });

    test('FNV-1a: Determinism and collision resistance', () {
      final h1 = fnv1a32(['a', 'b']);
      final h2 = fnv1a32(['a', 'c']);
      expect(h1, isNot(equals(h2)));
      expect(h1, hasLength(8));
    });
  });

  group('Advanced Algebraic Properties & Mathematical Theorems', () {
    test('Perron-Frobenius Theorem: Power iteration converges to positive eigenvector in connected graphs', () {
      // Strongly connected graph: A -> B -> C -> A
      final graph = DependencyGraph();
      graph.addEdge('A', 'B');
      graph.addEdge('B', 'C');
      graph.addEdge('C', 'A');

      final centrality = graph.eigenvectorCentrality();
      expect(centrality.keys, containsAll(['A', 'B', 'C']));
      for (final score in centrality.values) {
        expect(score, greaterThan(0.0),
            reason: 'Perron-Frobenius theorem guarantees strictly positive eigenvector components for strongly connected graphs');
      }
    });

    test('Transitivity of Perfect Similarity: If Sim(A, B) == 1.0 and Sim(B, C) == 1.0, then Sim(A, C) == 1.0', () {
      final a = ['class', 'Identifier', '{', '}'];
      final b = ['class', 'Identifier', '{', '}'];
      final c = ['class', 'Identifier', '{', '}'];

      final simAB = cosineSimilarity(a, b);
      final simBC = cosineSimilarity(b, c);
      final simAC = cosineSimilarity(a, c);

      expect(simAB, closeTo(1.0, 1e-9));
      expect(simBC, closeTo(1.0, 1e-9));
      expect(simAC, closeTo(1.0, 1e-9));

      final lcsAB = lcsSimilarity(a, b);
      final lcsBC = lcsSimilarity(b, c);
      final lcsAC = lcsSimilarity(a, c);

      expect(lcsAB, closeTo(1.0, 1e-9));
      expect(lcsBC, closeTo(1.0, 1e-9));
      expect(lcsAC, closeTo(1.0, 1e-9));
    });

    test('LCS Inversion resilience: Sim(A, A_reversed) depends strictly on symmetry of elements', () {
      final seq = ['a', 'b', 'c', 'b', 'a'];
      final seqRev = seq.reversed.toList();
      
      // Since it is a palindrome, LCS similarity with its reversed self must be exactly 1.0
      expect(lcsSimilarity(seq, seqRev), closeTo(1.0, 1e-9));

      // For non-palindrome: ['a', 'b', 'c'] and ['c', 'b', 'a']
      // LCS is ['b'] (or any single element), length 1.
      // Sim = 2 * 1 / (3 + 3) = 2/6 = 0.333333333
      final nonPal = ['a', 'b', 'c'];
      final nonPalRev = nonPal.reversed.toList();
      expect(lcsSimilarity(nonPal, nonPalRev), closeTo(1 / 3, 1e-9));
    });

    test('Information Entropy Monotonicity: Adding unique tokens increases or maintains Shannon Entropy', () {
      final seqA = ['a', 'b', 'a', 'b'];
      final hA = shannonEntropyFromSequence(seqA);

      // Add a completely new unique token 'c'
      final seqB = ['a', 'b', 'a', 'b', 'c'];
      final hB = shannonEntropyFromSequence(seqB);

      expect(hB, greaterThan(hA),
          reason: 'Introducing a new unique element increases overall Shannon entropy (uncertainty increases)');
    });
  });
}
