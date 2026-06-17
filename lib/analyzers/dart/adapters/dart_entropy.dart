import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:vetro/core/metrics/entropy.dart';

/// Computes the Shannon entropy of the AST node types in [node].
double shannonEntropy(AstNode node) {
  final counts = <String, int>{};

  void countNode(AstNode n) {
    final typeStr = n.runtimeType.toString();
    counts[typeStr] = (counts[typeStr] ?? 0) + 1;
    n.visitChildren(SimpleVisitor(countNode));
  }

  countNode(node);

  return shannonEntropyFromCounts(counts);
}

/// Computes the Shannon entropy of user-defined identifiers within [node].
double identifierEntropy(AstNode node) {
  final counts = <String, int>{};

  final keywords = const {
    'void', 'int', 'double', 'num', 'String', 'bool', 'dynamic', 'null',
    'true', 'false', 'this', 'super', 'override', 'var', 'final', 'const',
    'class', 'extends', 'implements', 'with', 'import', 'export', 'part', 'of',
    'show', 'hide', 'as', 'is', 'in', 'if', 'else', 'switch', 'case', 'default',
    'for', 'while', 'do', 'break', 'continue', 'return', 'yield', 'throw',
    'try', 'on', 'catch', 'finally', 'async', 'await', 'sync', 'get', 'set',
    'library', 'external', 'typedef', 'operator', 'factory', 'mixin', 'extension',
    'enum', 'abstract', 'covariant', 'deferred', 'late', 'required', 'interface',
    'sealed', 'base', 'when'
  };

  void visit(AstNode n) {
    if (n is SimpleIdentifier) {
      final lexeme = n.name;
      if (!keywords.contains(lexeme)) {
        counts[lexeme] = (counts[lexeme] ?? 0) + 1;
      }
    }
    n.visitChildren(SimpleVisitor(visit));
  }

  visit(node);

  return shannonEntropyFromCounts(counts);
}

final class SimpleVisitor extends GeneralizingAstVisitor<void> {
  SimpleVisitor(this.callback);
  final void Function(AstNode) callback;

  @override
  void visitNode(AstNode node) {
    callback(node);
  }
}
