import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:test/test.dart';
import 'package:vetro/analyzers/dart/adapters/dart_complexity.dart';

void main() {
  group('Cognitive Complexity', () {
    test('Flat function with no control flow has complexity 0', () {
      final source = '''
        void foo() {
          print(1);
          print(2);
        }
      ''';
      final unit = parseString(content: source).unit;
      final fn = unit.declarations.first;
      expect(cognitiveComplexity(fn), equals(0));
    });

    test('Nested if statements accumulate nesting penalty', () {
      final source = '''
        void foo(bool a, bool b, bool c) {
          if (a) {       // +1 (nesting 0)
            if (b) {     // +2 (nesting 1)
              if (c) {   // +3 (nesting 2)
                print(1);
              }
            }
          }
        }
      ''';
      final unit = parseString(content: source).unit;
      final fn = unit.declarations.first;
      // Total: 1 + 2 + 3 = 6
      expect(cognitiveComplexity(fn), equals(6));
    });

    test('Sequential if statements do not accumulate nesting penalty', () {
      final source = '''
        void foo(bool a, bool b) {
          if (a) { // +1
            print(1);
          }
          if (b) { // +1
            print(2);
          }
        }
      ''';
      final unit = parseString(content: source).unit;
      final fn = unit.declarations.first;
      // Total: 1 + 1 = 2
      expect(cognitiveComplexity(fn), equals(2));
    });

    test('Else-if chain receives no nesting penalty for the else-if', () {
      final source = '''
        void foo(bool a, bool b, bool c) {
          if (a) {          // +1
            print(1);
          } else if (b) {   // +1 (no nesting penalty)
            print(2);
          } else if (c) {   // +1 (no nesting penalty)
            print(3);
          }
        }
      ''';
      final unit = parseString(content: source).unit;
      final fn = unit.declarations.first;
      // Total: 1 + 1 + 1 = 3
      expect(cognitiveComplexity(fn), equals(3));
    });

    test('Switch statement increments by 1 and increases nesting level', () {
      final source = '''
        void foo(int x, bool a) {
          switch (x) {    // +1 (nesting 0)
            case 1:
              if (a) {    // +2 (nesting 1)
                print(1);
              }
              break;
          }
        }
      ''';
      final unit = parseString(content: source).unit;
      final fn = unit.declarations.first;
      // Total: 1 + 2 = 3
      expect(cognitiveComplexity(fn), equals(3));
    });

    test('Ternary operators increment and respect nesting level', () {
      final source = '''
        void foo(bool a, bool b) {
          if (a) {             // +1 (nesting 0)
            final x = b ? 1 : 2; // +2 (nesting 1)
          }
        }
      ''';
      final unit = parseString(content: source).unit;
      final fn = unit.declarations.first;
      // Total: 1 + 2 = 3
      expect(cognitiveComplexity(fn), equals(3));
    });

    test('Logical operator chains of same type group into single increment', () {
      final source = '''
        bool foo(bool a, bool b, bool c) {
          return a && b && c; // +1 for the whole && sequence
        }
      ''';
      final unit = parseString(content: source).unit;
      final fn = unit.declarations.first;
      expect(cognitiveComplexity(fn), equals(1));
    });

    test('Logical operator chains of alternate types increment per type change', () {
      final source = '''
        bool foo(bool a, bool b, bool c) {
          return a && b || c; // +2 (+1 for &&, +1 for ||)
        }
      ''';
      final unit = parseString(content: source).unit;
      final fn = unit.declarations.first;
      expect(cognitiveComplexity(fn), equals(2));
    });
  });
}
