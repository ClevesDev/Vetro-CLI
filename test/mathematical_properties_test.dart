import 'dart:io';
import 'dart:math' as math;
import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:vetro/analyzers/dart/ast_utils.dart';
import 'package:vetro/core/metrics/cohesion.dart';
import 'package:vetro/core/metrics/dependency_graph.dart';
import 'package:vetro/core/metrics/entropy.dart';
import 'package:vetro/core/metrics/similarity.dart';

void main() {
  final corpus = <CompilationUnit>[];
  final corpusSources = <String>[];

  setUpAll(() async {
    final dir = Directory('lib');
    await for (final file in dir.list(recursive: true)) {
      if (file is File && file.path.endsWith('.dart')) {
        final source = await file.readAsString();
        final unit = parseString(content: source).unit;
        corpus.add(unit);
        corpusSources.add(source);
      }
    }
  });

  group('Algebraic & Property-Based Tests on Vetro Corpus', () {
    test('Shannon Entropy bounds: 0 <= H(X) <= log2(N)', () {
      expect(corpus, isNotEmpty, reason: 'Corpus should be populated');
      for (final unit in corpus) {
        for (final decl in extractDeclarations(unit)) {
          if (decl.body case final body?) {
            final h = shannonEntropy(body);
            final n = nodeCount(body);
            expect(h, greaterThanOrEqualTo(0.0),
                reason: 'Entropy should be non-negative');
            if (n > 1) {
              final maxEntropy = math.log(n) / math.log(2);
              expect(h, lessThanOrEqualTo(maxEntropy + 1e-9),
                  reason: 'Entropy cannot exceed log2(N)');
            } else {
              expect(h, equals(0.0),
                  reason: 'Single node should have zero entropy');
            }
          }
        }
      }
    });

    test('Cosine Similarity Algebraic Properties (Symmetry and Identity)', () {
      final declarations = <({String name, AstNode node})>[];
      for (final unit in corpus) {
        for (final decl in extractDeclarations(unit)) {
          declarations.add((name: decl.name, node: decl.node));
        }
      }

      // Check identity: Sim(A, A) == 1.0
      for (final decl in declarations) {
        final tokens = tokenizeRaw(decl.node);
        if (tokens.isNotEmpty) {
          final sim = cosineSimilarity(tokens, tokens);
          expect(sim, closeTo(1.0, 1e-6),
              reason: 'Similarity of a function with itself must be 1.0');
        }
      }

      // Check symmetry: Sim(A, B) == Sim(B, A)
      final limit = declarations.length.clamp(0, 30);
      for (var i = 0; i < limit; i++) {
        for (var j = 0; j < limit; j++) {
          final tokensA = tokenizeRaw(declarations[i].node);
          final tokensB = tokenizeRaw(declarations[j].node);
          final simAB = cosineSimilarity(tokensA, tokensB);
          final simBA = cosineSimilarity(tokensB, tokensA);
          expect(simAB, closeTo(simBA, 1e-6),
              reason: 'Cosine similarity must be symmetric');
        }
      }
    });

    test('Class Cohesion bounds: 0.0 <= Cohesion <= 1.0', () {
      for (final unit in corpus) {
        for (final cls in extractClasses(unit)) {
          final cohesion = classCohesion(cls);
          expect(cohesion, greaterThanOrEqualTo(0.0),
              reason: 'Cohesion must be non-negative');
          expect(cohesion, lessThanOrEqualTo(1.0),
              reason: 'Cohesion cannot exceed 1.0');
        }
      }
    });

    test('Dependency Graph Centrality Conservation & L2 Normalization', () {
      final graph = DependencyGraph();
      final random = math.Random(42);
      
      // Construct a random directed network
      for (var i = 0; i < 30; i++) {
        final from = 'Node_$i';
        final to = 'Node_${random.nextInt(30)}';
        if (from != to) {
          graph.addEdge(from, to);
        }
      }

      final centrality = graph.eigenvectorCentrality();
      if (centrality.isNotEmpty) {
        var sumSq = 0.0;
        for (final val in centrality.values) {
          expect(val, greaterThanOrEqualTo(0.0),
              reason: 'Centrality scores must be non-negative');
          sumSq += val * val;
        }
        expect(sumSq, closeTo(1.0, 1e-6),
            reason: 'L2-normalized centrality scores must sum of squares to 1.0');
      }
    });
  });
}
