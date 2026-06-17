import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:vetro/core/metrics/cohesion.dart';

/// Computes the semantic cohesion of a class [node] based on the average
/// pairwise cosine similarity of identifier vocabularies between its methods.
double classCohesion(ClassDeclaration node) {
  final methods = node.members.whereType<MethodDeclaration>().toList();
  if (methods.length <= 1) return 1.0;

  final methodVocabularies = <Set<String>>[];
  for (final method in methods) {
    final collector = IdentifierCollector();
    method.accept(collector);
    methodVocabularies.add(collector.identifiers);
  }

  return averagePairwiseVocabularySimilarity(methodVocabularies);
}

final class IdentifierCollector extends RecursiveAstVisitor<void> {
  final Set<String> identifiers = {};

  @override
  void visitSimpleIdentifier(SimpleIdentifier node) {
    final name = node.name;
    if (name.isNotEmpty && !isKeyword(name)) {
      identifiers.add(name);
    }
    super.visitSimpleIdentifier(node);
  }

  bool isKeyword(String name) {
    return const {
      'void', 'int', 'double', 'num', 'String', 'bool', 'List', 'Map', 'Set',
      'dynamic', 'var', 'final', 'const', 'true', 'false', 'null'
    }.contains(name);
  }
}
