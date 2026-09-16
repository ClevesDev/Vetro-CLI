/// Rule that detects empty or silent catch clauses swallowing exceptions.
library;

import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:vetro/core/models/context.dart';
import 'package:vetro/core/models/finding.dart';
import 'package:vetro/core/rules/rule.dart';

/// Architecture rule that flags empty or silent `catch` clauses in Dart code.
///
/// **Architectural rationale**: Silently swallowing exceptions via empty or
/// logger-less `catch (e) {}` blocks conceals runtime bugs, corrupts application
/// state, and prevents automated error tracking from diagnosing critical failures.
/// In resilient systems, every catch block must either log, rethrow, or map
/// the error to a typed `Result` or `Failure`.
final class EmptyCatchRule extends AnalysisRule {
  const EmptyCatchRule({required super.config});

  @override
  String get id => 'empty_catch';

  @override
  String get name => 'Empty or Silent Catch Block';

  @override
  String get description =>
      'Flags catch blocks that swallow errors without logging, rethrowing, or mapping.';

  @override
  List<Finding> analyzeFile(FileContext context) {
    final unit = context.nativeAst as CompilationUnit?;
    if (unit == null) return const [];

    final findings = <Finding>[];
    final visitor = _EmptyCatchVisitor(
      onViolation: (CatchClause node, String reason) {
        final line = unit.lineInfo.getLocation(node.offset).lineNumber;
        findings.add(
          Finding(
            ruleId: id,
            ruleName: name,
            severity: severity,
            filePath: context.filePath,
            line: line,
            message:
                'Catch block swallows errors without logging, rethrowing, or mapping ($reason).',
            evidence: {'clause': node.toSource(), 'reason': reason},
          ),
        );
      },
    );

    unit.accept(visitor);
    return findings;
  }
}

class _EmptyCatchVisitor extends RecursiveAstVisitor<void> {
  _EmptyCatchVisitor({required this.onViolation});

  final void Function(CatchClause node, String reason) onViolation;

  @override
  void visitCatchClause(CatchClause node) {
    final body = node.body;
    final statements = body.statements;

    // 1. Completely empty catch block: catch (e) {}
    if (statements.isEmpty) {
      onViolation(node, 'empty body');
      super.visitCatchClause(node);
      return;
    }

    // 2. Check if the block has active error-handling constructs.
    final inspector = _CatchBodyInspector();
    body.accept(inspector);

    if (!inspector.hasHandlingAction) {
      onViolation(node, 'no log, rethrow, throw, or error mapper call');
    }

    super.visitCatchClause(node);
  }
}

class _CatchBodyInspector extends RecursiveAstVisitor<void> {
  bool hasHandlingAction = false;

  static const _loggingIdentifiers = {
    'log',
    'logger',
    'print',
    'debugPrint',
    'warn',
    'warning',
    'error',
    'severe',
    'info',
    'report',
    'recordError',
    'crashlytics',
  };

  static const _mapperOrResultIdentifiers = {
    'map',
    'mapError',
    'mapFailure',
    'FailureResult',
    'Result',
    'Failure',
    'UserMessage',
    'CompositeErrorMapper',
    'FeatureErrorMapper',
  };

  @override
  void visitRethrowExpression(RethrowExpression node) {
    hasHandlingAction = true;
    super.visitRethrowExpression(node);
  }

  @override
  void visitThrowExpression(ThrowExpression node) {
    hasHandlingAction = true;
    super.visitThrowExpression(node);
  }

  @override
  void visitMethodInvocation(MethodInvocation node) {
    final methodName = node.methodName.name.toLowerCase();
    final targetName = node.target?.toSource().toLowerCase() ?? '';

    // Check for logging calls: e.g. log(...), logger.error(...), print(...)
    for (final logId in _loggingIdentifiers) {
      if (methodName == logId ||
          methodName.contains(logId) ||
          targetName.contains(logId)) {
        hasHandlingAction = true;
        break;
      }
    }

    // Check for mapper or error handling calls
    for (final mapId in _mapperOrResultIdentifiers) {
      if (methodName == mapId.toLowerCase() ||
          targetName.contains(mapId.toLowerCase())) {
        hasHandlingAction = true;
        break;
      }
    }

    super.visitMethodInvocation(node);
  }

  @override
  void visitInstanceCreationExpression(InstanceCreationExpression node) {
    final typeName = node.constructorName.type.name2.lexeme;
    for (final identifier in _mapperOrResultIdentifiers) {
      if (typeName == identifier || typeName.endsWith(identifier)) {
        hasHandlingAction = true;
        break;
      }
    }
    super.visitInstanceCreationExpression(node);
  }
}
