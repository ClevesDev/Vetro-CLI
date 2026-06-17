import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:test/test.dart';
import 'package:vetro/core/adapters/dart/dart_similarity.dart';

void main() {
  group('AST Structural Hashing', () {
    test('Identical structure with renamed variables yields identical hash', () {
      final sourceA = '''
        int add(int x, int y) {
          final sum = x + y;
          return sum;
        }
      ''';
      final sourceB = '''
        int sum(int a, int b) {
          final res = a + b;
          return res;
        }
      ''';

      final unitA = parseString(content: sourceA).unit;
      final unitB = parseString(content: sourceB).unit;

      final fnA = unitA.declarations.first;
      final fnB = unitB.declarations.first;

      final hashA = computeAstHash(fnA);
      final hashB = computeAstHash(fnB);

      expect(hashA, equals(hashB));
      expect(hashA.length, equals(8));
    });

    test('Different structure yields different hash', () {
      final sourceA = '''
        int add(int x, int y) {
          final sum = x + y;
          return sum;
        }
      ''';
      final sourceB = '''
        int multiply(int x, int y) {
          return x * y;
        }
      ''';

      final unitA = parseString(content: sourceA).unit;
      final unitB = parseString(content: sourceB).unit;

      final fnA = unitA.declarations.first;
      final fnB = unitB.declarations.first;

      final hashA = computeAstHash(fnA);
      final hashB = computeAstHash(fnB);

      expect(hashA, isNot(equals(hashB)));
    });
  });
}
