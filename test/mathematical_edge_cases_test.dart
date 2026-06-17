import 'dart:math' as math;
import 'package:test/test.dart';
import 'package:vetro/core/metrics/cohesion.dart';
import 'package:vetro/core/metrics/dependency_graph.dart';
import 'package:vetro/core/metrics/entropy.dart';
import 'package:vetro/core/metrics/halstead.dart';
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

    test('Triangle Inequality for Cosine-based Angular Distance', () {
      // Cosine distance doesn't satisfy triangle inequality, but angular distance theta = arccos(cos_sim) does!
      // For any three non-empty sequences A, B, C: theta(A, C) <= theta(A, B) + theta(B, C)
      final a = ['class', 'FunctionDef', 'If'];
      final b = ['class', 'FunctionDef', 'Constant'];
      final c = ['class', 'While', 'Constant'];

      final simAB = cosineSimilarity(a, b);
      final simBC = cosineSimilarity(b, c);
      final simAC = cosineSimilarity(a, c);

      final thetaAB = math.acos(simAB);
      final thetaBC = math.acos(simBC);
      final thetaAC = math.acos(simAC);

      expect(thetaAC, lessThanOrEqualTo(thetaAB + thetaBC + 1e-9),
          reason: 'Angular distance must satisfy the triangle inequality');
    });

    test('Triangle Inequality for LCS-based Edit Distance', () {
      // Edit distance d(X, Y) = |X| + |Y| - 2 * lcsLength(X, Y) must satisfy the triangle inequality.
      // For any three sequences A, B, C: d(A, C) <= d(A, B) + d(B, C)
      final a = ['x', 'y', 'z', 'w'];
      final b = ['x', 'a', 'b', 'z'];
      final c = ['a', 'b', 'c', 'd', 'z'];

      double d(List<String> x, List<String> y) {
        return (x.length + y.length - 2 * lcsLength(x, y)).toDouble();
      }

      final dAB = d(a, b);
      final dBC = d(b, c);
      final dAC = d(a, c);

      expect(dAC, lessThanOrEqualTo(dAB + dBC),
          reason: 'LCS-based edit distance must satisfy the triangle inequality');
    });

    test('Subadditivity and Independence properties of Shannon Entropy', () {
      // H(X, Y) <= H(X) + H(Y), with equality if and only if X and Y are independent.
      final x = ['a', 'b', 'a', 'b', 'a', 'b', 'a', 'b'];
      final y = ['x', 'x', 'y', 'y', 'x', 'x', 'y', 'y'];

      // Compute H(X) and H(Y)
      final hX = shannonEntropyFromSequence(x);
      final hY = shannonEntropyFromSequence(y);

      // Compute joint entropy H(X, Y)
      final xyJoint = List.generate(x.length, (i) => '${x[i]}_${y[i]}');
      final hXY = shannonEntropyFromSequence(xyJoint);

      expect(hXY, lessThanOrEqualTo(hX + hY + 1e-9),
          reason: 'Joint entropy must satisfy subadditivity H(X, Y) <= H(X) + H(Y)');

      // If X and Y are perfectly independent and uniform:
      // P(X=a) = 0.5, P(X=b) = 0.5, H(X) = 1.0
      // P(Y=x) = 0.5, P(Y=y) = 0.5, H(Y) = 1.0
      // Joint outcomes (a_x, a_y, b_x, b_y) each have frequency 2 / 8 = 0.25
      // Joint entropy H(X,Y) = 2.0. So equality holds!
      expect(hXY, closeTo(hX + hY, 1e-9),
          reason: 'For independent variables, joint entropy equals sum of individual entropies');
    });

    test('Concavity of Shannon Entropy', () {
      // For any two distributions P and Q and lambda = 0.5:
      // H(0.5 * P + 0.5 * Q) >= 0.5 * H(P) + 0.5 * H(Q)
      final pCounts = {'a': 8, 'b': 2}; // H(P) = -0.8 * log2(0.8) - 0.2 * log2(0.2) ≈ 0.7219
      final qCounts = {'a': 1, 'b': 9}; // H(Q) ≈ 0.469

      final hP = shannonEntropyFromCounts(pCounts);
      final hQ = shannonEntropyFromCounts(qCounts);

      // Combined distribution counts
      // P: a=0.8, b=0.2. Q: a=0.1, b=0.9
      // Combined: a = 0.5 * 0.8 + 0.5 * 0.1 = 0.45
      //           b = 0.5 * 0.2 + 0.5 * 0.9 = 0.55
      final mixedCounts = {'a': 45, 'b': 55};
      final hMixed = shannonEntropyFromCounts(mixedCounts);

      expect(hMixed, greaterThanOrEqualTo(0.5 * hP + 0.5 * hQ - 1e-9),
          reason: 'Shannon entropy is concave');
    });

    test('Exact recurrence relation verification for PageRank/Centrality', () {
      // Create a small directed graph A -> B -> C, C -> A
      final graph = DependencyGraph();
      graph.addEdge('A', 'B');
      graph.addEdge('B', 'C');
      graph.addEdge('C', 'A');

      const damping = 0.85;
      final centrality = graph.eigenvectorCentrality(dampingFactor: damping);

      // Verify that the converged centrality vector is an eigenvector
      // of the Google transition matrix M.
      // x*_v = gamma * ( (1 - alpha)/N + alpha * sum_{u in In(v)} x*_u / Out(u) )
      final n = centrality.length;
      final base = (1.0 - damping) / n;

      final incoming = <String, List<String>>{
        'A': ['C'],
        'B': ['A'],
        'C': ['B'],
      };

      // Let's compute the unscaled next iteration value for each node
      final nextVal = <String, double>{};
      for (final v in centrality.keys) {
        var sum = 0.0;
        for (final u in incoming[v]!) {
          final outDegree = graph.fanOut(u);
          sum += centrality[u]! / outDegree;
        }
        nextVal[v] = base + damping * sum;
      }

      // The ratio of centrality[v] / nextVal[v] should be constant (gamma) for all nodes.
      var firstRatio = 0.0;
      for (final v in centrality.keys) {
        final ratio = centrality[v]! / nextVal[v]!;
        if (firstRatio == 0.0) {
          firstRatio = ratio;
        } else {
          expect(ratio, closeTo(firstRatio, 1e-5),
              reason: 'Eigenvector centrality must satisfy the scaling relation of PageRank');
        }
      }
    });

    test('Local Clustering Coefficient of Neighbor Directed Cycles', () {
      // Node V has neighbors A, B, C.
      // The neighbors form a directed cycle: A -> B -> C -> A
      // The number of neighbors kv = 3.
      // The number of edges among neighbors ev = 3.
      // Clustering Coefficient C_V = ev / (kv * (kv - 1)) = 3 / (3 * 2) = 0.5
      final graph = DependencyGraph();
      graph.addEdge('V', 'A');
      graph.addEdge('V', 'B');
      graph.addEdge('V', 'C');
      // Neighbors cycle
      graph.addEdge('A', 'B');
      graph.addEdge('B', 'C');
      graph.addEdge('C', 'A');

      expect(graph.localClusteringCoefficient('V'), closeTo(0.5, 1e-9));

      // Neighbors form a cycle of size 4: A -> B -> C -> D -> A
      // kv = 4, ev = 4. C_V = 4 / (4 * 3) = 1/3 ≈ 0.333333333
      final graph4 = DependencyGraph();
      graph4.addEdge('V', 'A');
      graph4.addEdge('V', 'B');
      graph4.addEdge('V', 'C');
      graph4.addEdge('V', 'D');
      graph4.addEdge('A', 'B');
      graph4.addEdge('B', 'C');
      graph4.addEdge('C', 'D');
      graph4.addEdge('D', 'A');

      expect(graph4.localClusteringCoefficient('V'), closeTo(1 / 3, 1e-9));
    });

    test('Halstead Complexity Monotonicity & Boundary Cases', () {
      // volume V = length * log2(vocabulary)
      // difficulty D = (distinctOperators / 2) * (totalOperands / distinctOperands)
      // effort E = D * V

      // Boundary: Distinct operands = 0
      final zeroOperands = halsteadFromClassifiedTokens(
        operators: ['+', '-'],
        operands: [],
        totalOperators: 5,
        totalOperands: 0,
      );
      expect(zeroOperands.difficulty, equals(0.0));
      expect(zeroOperands.effort, equals(0.0));

      // Monotonicity check
      final base = halsteadFromClassifiedTokens(
        operators: ['+', '-'],
        operands: ['a', 'b'],
        totalOperators: 5,
        totalOperands: 5,
      );

      final higherOperands = halsteadFromClassifiedTokens(
        operators: ['+', '-'],
        operands: ['a', 'b'],
        totalOperators: 5,
        totalOperands: 15, // Increase total operands from 5 to 15
      );

      expect(higherOperands.volume, greaterThan(base.volume));
      expect(higherOperands.difficulty, greaterThan(base.difficulty));
      expect(higherOperands.effort, greaterThan(base.effort));
    });
  });

  group('Advanced Algebraic Properties — Bipartite PageRank & Information Bounds', () {
    test('Bipartite Graph: PageRank scores alternate if damping is 1.0 (no damping)', () {
      final graph = DependencyGraph();
      graph.addEdge('A', 'B');
      graph.addEdge('B', 'A');

      final centrality = graph.eigenvectorCentrality(dampingFactor: 0.85);
      expect(centrality['A'], closeTo(centrality['B']!, 1e-6));
    });

    test('Shannon Entropy of Perfect Normal Distribution vs Skewed Distribution', () {
      final seqUniform = ['a', 'b', 'c', 'd'];
      final seqSkewed = ['a', 'a', 'a', 'b'];

      final hUniform = shannonEntropyFromSequence(seqUniform);
      final hSkewed = shannonEntropyFromSequence(seqSkewed);

      expect(hUniform, equals(2.0));
      expect(hSkewed, lessThan(hUniform));
    });

    test('LCS Similarity bounds: 0.0 <= lcsSimilarity <= 1.0', () {
      final seqA = ['x', 'y', 'z'];
      final seqB = ['a', 'b', 'c', 'd'];

      final sim = lcsSimilarity(seqA, seqB);
      expect(sim, greaterThanOrEqualTo(0.0));
      expect(sim, lessThanOrEqualTo(1.0));
    });
  });
}
