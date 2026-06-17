import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:test/test.dart';
import 'package:vetro/core/metrics/complexity.dart';
import 'package:vetro/core/metrics/entropy.dart';
import 'package:vetro/core/metrics/similarity.dart';

void main() {
  group('Similarity Metrics', () {
    test('cosineSimilarity computes exact cosine similarity', () {
      final vecA = ['a', 'b', 'c'];
      final vecB = ['a', 'b', 'd'];
      // A = {a:1, b:1, c:1, d:0}
      // B = {a:1, b:1, c:0, d:1}
      // Dot product = 1*1 + 1*1 = 2
      // Magnitude A = sqrt(3), Magnitude B = sqrt(3)
      // Similarity = 2 / 3 = ~0.667
      expect(cosineSimilarity(vecA, vecB), closeTo(2 / 3, 0.001));
    });

    test('cosineSimilarity returns 1.0 for identical lists', () {
      final vecA = ['foo', 'bar'];
      expect(cosineSimilarity(vecA, vecA), closeTo(1.0, 0.000001));
    });

    test('cosineSimilarity returns 0.0 for disjoint lists', () {
      final vecA = ['foo'];
      final vecB = ['bar'];
      expect(cosineSimilarity(vecA, vecB), equals(0.0));
    });

    test('astStructuralSimilarity detects renaming', () {
      final sourceA = '''
        int add(int x, int y) {
          final sum = x + y;
          return sum;
        }
      ''';
      final sourceB = '''
        int sumNumbers(int a, int b) {
          final result = a + b;
          return result;
        }
      ''';

      final unitA = parseString(content: sourceA).unit;
      final unitB = parseString(content: sourceB).unit;

      final fnA = unitA.declarations.first;
      final fnB = unitB.declarations.first;

      final sim = astStructuralSimilarity(fnA, fnB);
      expect(sim, equals(1.0)); // Identical after identifier normalization!
    });

    test('astCosineSimilarity computes similarity using raw tokens and cosine similarity', () {
      final sourceA = '''
        int add(int x, int y) {
          final sum = x + y;
          return sum;
        }
      ''';
      final sourceB = '''
        int sumNumbers(int a, int b) {
          final result = a + b;
          return result;
        }
      ''';

      final unitA = parseString(content: sourceA).unit;
      final unitB = parseString(content: sourceB).unit;

      final fnA = unitA.declarations.first;
      final fnB = unitB.declarations.first;

      final simRenamed = astCosineSimilarity(fnA, fnB);
      // Since it preserves names, renaming lowers the similarity
      expect(simRenamed, closeTo(0.458, 0.01));

      final simIdentical = astCosineSimilarity(fnA, fnA);
      expect(simIdentical, equals(1.0));
    });
  });

  group('Complexity Metrics', () {
    test('cyclomaticComplexity counts decision points correctly', () {
      final source = '''
        void check(int value) {
          if (value > 10) {
            print('large');
          } else if (value > 5) {
            print('medium');
          } else {
            print('small');
          }
        }
      ''';
      final unit = parseString(content: source).unit;
      final fn = unit.declarations.first;
      // Cyclomatic complexity starts at 1, adds 1 for each 'if' and 'else if'. Total = 3.
      expect(cyclomaticComplexity(fn), equals(3));
    });
  });

  group('Entropy Metrics', () {
    test('shannonEntropy computes entropy for AST nodes', () {
      final source = 'void foo() {}';
      final unit = parseString(content: source).unit;
      final fn = unit.declarations.first;
      final entropy = shannonEntropy(fn);
      expect(entropy, greaterThan(0.0));
    });

    test('commentIntentRatio detects intent keywords', () {
      final source = '''
        // TODO: implement this function
        // because of a bug we had to do this
        // print value
        void foo() {}
      ''';
      expect(commentIntentRatio(source), greaterThan(0.0));
    });
  });
}
