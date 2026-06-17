import 'dart:math' as math;
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';

/// Computes the semantic cohesion of a class [node] based on the average
/// pairwise cosine similarity of identifier vocabularies between its methods.
///
/// Note: The purpose of this metric is to identify classes with low cohesion
/// (disjoint method vocabularies) which suggest a violation of Single Responsibility Principle.
double classCohesion(ClassDeclaration node) {
  final methods = node.members.whereType<MethodDeclaration>().toList();
  if (methods.length <= 1) return 1.0;

  final methodVocabularies = <Set<String>>[];
  for (final method in methods) {
    final collector = _IdentifierCollector();
    method.accept(collector);
    methodVocabularies.add(collector.identifiers);
  }

  var sumSimilarity = 0.0;
  var countPairs = 0;

  for (var i = 0; i < methodVocabularies.length; i++) {
    for (var j = i + 1; j < methodVocabularies.length; j++) {
      final vocabA = methodVocabularies[i];
      final vocabB = methodVocabularies[j];

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

final class _IdentifierCollector extends RecursiveAstVisitor<void> {
  final Set<String> identifiers = {};

  @override
  void visitSimpleIdentifier(SimpleIdentifier node) {
    final name = node.name;
    if (name.isNotEmpty && !_isKeyword(name)) {
      identifiers.add(name);
    }
    super.visitSimpleIdentifier(node);
  }

  bool _isKeyword(String name) {
    return const {
      'void', 'int', 'double', 'num', 'String', 'bool', 'List', 'Map', 'Set',
      'dynamic', 'var', 'final', 'const', 'true', 'false', 'null'
    }.contains(name);
  }
}
