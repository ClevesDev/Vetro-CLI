import 'dart:math' as math;
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';

/// Computes the ratio of intent comments to total comments in the source string.
double commentIntentRatio(String source) {
  final lines = source.split('\n');
  var commentCount = 0;
  var intentCount = 0;
  final intentKeywords = const {
    'why', 'because', 'reason', 'purpose', 'intent',
    'rationale', 'note', 'important', 'hack', 'workaround', 'todo'
  };

  for (final line in lines) {
    final trimmed = line.trim();
    if (trimmed.startsWith('//') || trimmed.startsWith('///')) {
      commentCount++;
      final lower = trimmed.toLowerCase();
      for (final kw in intentKeywords) {
        if (lower.contains(kw)) {
          intentCount++;
          break;
        }
      }
    }
  }

  if (commentCount == 0) return 0.0;
  return intentCount / commentCount;
}


/// Computes the Shannon entropy of the AST node types in [node].
///
/// Note: The purpose of this function is to estimate the informational complexity/variety
/// of AST node type distributions, helping flag repetitive patterns or boilerplate blocks.
double shannonEntropy(AstNode node) {
  final counts = <String, int>{};
  var total = 0;

  void countNode(AstNode n) {
    final typeStr = n.runtimeType.toString();
    counts[typeStr] = (counts[typeStr] ?? 0) + 1;
    total++;
    n.visitChildren(_SimpleVisitor(countNode));
  }

  countNode(node);

  if (total == 0) return 0.0;

  var entropy = 0.0;
  for (final count in counts.values) {
    final p = count / total;
    entropy -= p * (math.log(p) / math.log(2));
  }

  return entropy;
}

/// Computes the Shannon entropy of user-defined identifiers within [node].
///
/// High identifier entropy indicates high vocabulary variety.
/// Low identifier entropy indicates highly repetitive naming typical of AI-generated
/// or boilerplated code.
double identifierEntropy(AstNode node) {
  final counts = <String, int>{};
  var total = 0;

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
        total++;
      }
    }
    n.visitChildren(_SimpleVisitor(visit));
  }

  visit(node);

  if (total == 0) return 0.0;

  var entropy = 0.0;
  for (final count in counts.values) {
    final p = count / total;
    entropy -= p * (math.log(p) / math.log(2));
  }

  return entropy;
}

final class _SimpleVisitor extends GeneralizingAstVisitor<void> {
  _SimpleVisitor(this.callback);
  final void Function(AstNode) callback;

  @override
  void visitNode(AstNode node) {
    callback(node);
  }
}
