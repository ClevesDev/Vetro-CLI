import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:test/test.dart';
import 'package:vetro/core/metrics/entropy.dart';

void main() {
  group('Identifier Entropy', () {
    test('Flat function with no identifiers has entropy 0', () {
      final source = '''
        void foo() {}
      ''';
      final unit = parseString(content: source).unit;
      final fn = unit.declarations.first;
      // Keywords 'void' and 'foo' (or function name) are ignored or not present inside body
      // SimpleIdentifier in foo body is empty
      expect(identifierEntropy(fn), equals(0.0));
    });

    test('Function with repetitive identifier naming has low entropy', () {
      final source = '''
        void foo() {
          final x = 1;
          final y = x + x;
          final z = x + x + x + x + x;
          print(x);
        }
      ''';
      final unit = parseString(content: source).unit;
      final fn = unit.declarations.first;

      final entropy = identifierEntropy(fn);
      expect(entropy, greaterThan(0.0));
      // Repetitive identifier 'x' pulls down entropy compared to a function with diverse naming
      expect(entropy, lessThan(2.2));
    });

    test('Function with diverse vocabulary has higher entropy', () {
      final source = '''
        void rich(int first, int second, int third) {
          final sum = first + second;
          final result = sum * third;
          print(result);
        }
      ''';
      final unit = parseString(content: source).unit;
      final fn = unit.declarations.first;

      final entropy = identifierEntropy(fn);
      // More diverse identifiers -> higher Shannon entropy
      expect(entropy, greaterThan(2.2));
    });
  });
}
