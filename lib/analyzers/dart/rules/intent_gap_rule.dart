/// Rule: Intent Gap — detects complex functions lacking intent documentation.
///
/// **Mathematical basis**: Cross-references cyclomatic complexity (CC)
/// against the presence of intent-bearing comments.
///
/// A function is flagged when:
///   CC(f) ≥ min_complexity AND intentComments(f) = 0
///
/// Intent comments are those containing keywords: why, because, reason,
/// purpose, intent, rationale, note, important, hack, workaround, todo.
///
/// AI-generated code frequently has correct structure but zero
/// explanation of *why* — this rule surfaces that gap.
library;

import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/token.dart';
import 'package:analyzer/dart/ast/visitor.dart';

import 'package:vetro/analyzers/dart/ast_utils.dart';
import 'package:vetro/core/adapters/dart/dart_complexity.dart';
import 'package:vetro/core/models/finding.dart';
import 'package:vetro/core/rules/rule.dart';

/// Intent keywords that signal a comment explains *why*, not just *what*.
const _intentKeywords = [
  'why',
  'because',
  'reason',
  'purpose',
  'intent',
  'rationale',
  'note',
  'important',
  'hack',
  'workaround',
  'todo',
];

/// Detects functions with high complexity but no intent documentation.
///
/// **Threshold**: `min_complexity` (default 5). Only functions with
/// CC ≥ this value are checked for intent comments.
///
/// Evidence includes the CC value and the fact that zero intent
/// comments were found.
final class IntentGapRule extends Rule {
  /// Creates an [IntentGapRule] with the given [config].
  const IntentGapRule({required super.config});

  @override
  String get id => 'intent_gap';

  @override
  String get name => 'Intent Gap';

  @override
  String get description =>
      'Flags complex functions that lack intent documentation '
      '(comments explaining why).';

  @override
  List<Finding> analyze(
    CompilationUnit unit,
    String filePath,
    String source,
  ) {
    final minCC =
        config.threshold('min_complexity', defaultValue: 5.0).toInt();
    final findings = <Finding>[];

    // We extract both functions and methods because complex business logic
    // can reside in either top-level or object-oriented structures, and both
    // require documentation explaining why design decisions were made.
    for (final decl in extractDeclarations(unit)) {
      final body = decl.body;
      if (body == null) continue;

      final cc = cyclomaticComplexity(body);
      if (cc >= minCC) {
        final hasIntent = _hasIntentComment(decl.node, unit, source);
        if (!hasIntent) {
          findings.add(
            _buildFinding(
              filePath: filePath,
              unit: unit,
              node: decl.node,
              name: decl.name,
              cc: cc,
            ),
          );
        }
      }
    }

    return findings;
  }

  /// Checks if a function/method has intent-bearing comments.
  ///
  /// Inspects:
  /// 1. Doc comments on the declaration
  /// 2. Preceding comments (above the function)
  /// 3. Inline comments within the function body
  bool _hasIntentComment(
    AstNode node,
    CompilationUnit unit,
    String source,
  ) {
    // Check doc comments on the declaration.
    final docComment = switch (node) {
      FunctionDeclaration(:final documentationComment) => documentationComment,
      MethodDeclaration(:final documentationComment) => documentationComment,
      _ => null,
    };

    if (docComment != null && _containsIntentKeyword(docComment.toString())) {
      return true;
    }

    // Check preceding and inline comments by scanning the token stream.
    final beginToken = node.beginToken;

    // Scan preceding comments attached to the begin token.
    var comment = beginToken.precedingComments;
    while (comment != null) {
      if (_containsIntentKeyword(comment.lexeme)) return true;
      comment = comment.next as CommentToken?;
    }

    // Scan inline comments within the body by traversing tokens.
    final visitor = _CommentScanVisitor();
    node.accept(visitor);
    for (final commentText in visitor.comments) {
      if (_containsIntentKeyword(commentText)) return true;
    }

    return false;
  }

  /// Returns true if the text contains any intent keyword.
  bool _containsIntentKeyword(String text) {
    final lower = text.toLowerCase();
    return _intentKeywords.any(lower.contains);
  }

  Finding _buildFinding({
    required String filePath,
    required CompilationUnit unit,
    required AstNode node,
    required String name,
    required int cc,
  }) {
    final line = unit.lineInfo.getLocation(node.offset).lineNumber;
    return Finding(
      ruleId: id,
      ruleName: this.name,
      severity: severity,
      filePath: filePath,
      line: line,
      message: 'Function "$name" has complexity $cc but no intent '
          'documentation (no comments explaining why).',
      evidence: {
        'cyclomatic_complexity': '$cc',
        'intent_comments': '0',
      },
    );
  }
}

/// Visitor that collects comment text from token preceding-comment chains.
final class _CommentScanVisitor extends GeneralizingAstVisitor<void> {
  final List<String> comments = [];

  @override
  void visitNode(AstNode node) {
    var comment = node.beginToken.precedingComments;
    while (comment != null) {
      comments.add(comment.lexeme);
      comment = comment.next as CommentToken?;
    }
    super.visitNode(node);
  }
}
