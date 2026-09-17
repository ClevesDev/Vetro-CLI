/// Rule that detects presentation controllers catching raw exceptions without mapping them to a domain Failure.
library;

import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:vetro/core/models/context.dart';
import 'package:vetro/core/models/finding.dart';
import 'package:vetro/core/rules/rule.dart';

/// Architecture rule that flags presentation controllers and UI state holders
/// capturing raw exceptions without translating them via a domain `Failure` or error mapper.
///
/// **Architectural rationale**: Presentation controllers should not handle raw
/// infrastructure exceptions (`HttpException`, `SocketException`, `DatabaseException`,
/// or generic `Exception`). Raw exceptions expose internal implementation details to the UI,
/// cause unlocalized error messages, and bypass domain error hierarchies.
/// Errors should either arrive as a `Result` from domain layers or be translated
/// into a sanitized `UserMessage` via an error mapper.
final class UncheckedBoundaryRule extends AnalysisRule {
  const UncheckedBoundaryRule({required super.config});

  @override
  String get id => 'unchecked_boundary';

  @override
  String get name => 'Unchecked Presentation Boundary';

  @override
  String get description =>
      'Detects presentation controllers catching raw exceptions without mapping to a domain Failure or Result.';

  @override
  List<Finding> analyzeFile(FileContext context) {
    final unit = context.nativeAst as CompilationUnit?;
    if (unit == null) return const [];

    final isPresentationFile = _isPresentationPath(context.filePath);

    final findings = <Finding>[];
    final visitor = _PresentationClassVisitor(
      isPresentationFile: isPresentationFile,
      onViolation: (CatchClause node, String className, String reason) {
        final line = unit.lineInfo.getLocation(node.offset).lineNumber;
        // Traverse up to find enclosing method or function declaration
        var current = node.parent;
        while (current != null) {
          if (current is MethodDeclaration || current is FunctionDeclaration) {
            break;
          }
          current = current.parent;
        }

        final evidence = <String, String>{
          'class': className,
          'clause': node.toSource(),
          'reason': reason,
        };

        if (current != null) {
          evidence['enclosing_declaration'] = current.toSource();
          if (current is MethodDeclaration) {
            evidence['enclosing_name'] = current.name.lexeme;
          } else if (current is FunctionDeclaration) {
            evidence['enclosing_name'] = current.name.lexeme;
          }
        }

        findings.add(
          Finding(
            ruleId: id,
            ruleName: name,
            severity: severity,
            filePath: context.filePath,
            line: line,
            message:
                'Presentation class "$className" captures raw exceptions without domain Failure mapping ($reason).',
            evidence: evidence,
          ),
        );
      },
    );

    unit.accept(visitor);
    return findings;
  }

  static bool _isPresentationPath(String path) {
    final lower = path.toLowerCase();
    return lower.contains('/presentation/') ||
        lower.contains('/controllers/') ||
        lower.contains('/notifiers/') ||
        lower.contains('/bloc/') ||
        lower.contains('/cubit/') ||
        lower.contains('/ui/') ||
        lower.contains('/views/');
  }
}

class _PresentationClassVisitor extends RecursiveAstVisitor<void> {
  _PresentationClassVisitor({
    required this.isPresentationFile,
    required this.onViolation,
  });

  final bool isPresentationFile;
  final void Function(CatchClause node, String className, String reason)
  onViolation;

  static const _presentationSuffixes = [
    'Controller',
    'Notifier',
    'ViewModel',
    'Presenter',
    'Cubit',
    'Bloc',
  ];

  @override
  void visitClassDeclaration(ClassDeclaration node) {
    final className = node.name.lexeme;
    final isPresentationClass =
        isPresentationFile || _presentationSuffixes.any(className.endsWith);

    if (isPresentationClass) {
      final boundaryVisitor = _BoundaryCatchVisitor(
        className: className,
        onViolation: onViolation,
      );
      node.accept(boundaryVisitor);
    }

    super.visitClassDeclaration(node);
  }
}

class _BoundaryCatchVisitor extends RecursiveAstVisitor<void> {
  _BoundaryCatchVisitor({required this.className, required this.onViolation});

  final String className;
  final void Function(CatchClause node, String className, String reason)
  onViolation;

  static const _mapperOrFailureIdentifiers = {
    'Failure',
    'StandardFailure',
    'Result',
    'CompositeErrorMapper',
    'FeatureErrorMapper',
    'StandardErrorMapper',
    'UserMessage',
    'mapFailure',
    'mapError',
    'AppError',
    'DomainError',
    'UiError',
    'UIError',
    'ErrorHandler',
  };

  @override
  void visitCatchClause(CatchClause node) {
    // Check if the catch clause specifies an explicit domain Failure type:
    // e.g. on AuthFailure catch (e)
    final exceptionType = node.exceptionType?.toSource();
    if (exceptionType != null &&
        _mapperOrFailureIdentifiers.any(exceptionType.contains)) {
      // Catching domain Failure is clean
      super.visitCatchClause(node);
      return;
    }

    // If catching raw Object, Exception, Error, or untyped catch(e),
    // check if the body delegates to an error mapper or translates to Failure:
    final inspector = _BoundaryCatchBodyInspector();
    node.body.accept(inspector);

    if (!inspector.hasDomainMapping) {
      onViolation(
        node,
        className,
        'catches raw ${exceptionType ?? 'exception'} without mapping to domain Failure or calling an error mapper',
      );
    }

    super.visitCatchClause(node);
  }
}

class _BoundaryCatchBodyInspector extends RecursiveAstVisitor<void> {
  bool hasDomainMapping = false;

  static const _mappingIdentifiers = {
    'Failure',
    'FailureResult',
    'Result',
    'UserMessage',
    'mapFailure',
    'mapError',
    'errorMapper',
    'CompositeErrorMapper',
    'FeatureErrorMapper',
    'AppError',
    'DomainError',
    'UiError',
    'UIError',
    'ErrorHandler',
    'fromObject',
    'fromException',
    'fromError',
  };

  @override
  void visitMethodInvocation(MethodInvocation node) {
    final methodName = node.methodName.name.toLowerCase();
    final targetName = node.target?.toSource().toLowerCase() ?? '';

    // Check for error mapper calls: e.g. errorMapper.map(e), mapper.map(e),
    // and factory methods on error/failure classes e.g. AppError.fromObject(e)
    if ((targetName.contains('mapper') ||
            targetName.contains('error') ||
            targetName.contains('failure') ||
            targetName.contains('handler')) &&
        (methodName.startsWith('map') ||
            methodName.startsWith('from') ||
            methodName == 'handle' ||
            methodName == 'recorderror')) {
      hasDomainMapping = true;
    }

    for (final id in _mappingIdentifiers) {
      if (methodName == id.toLowerCase() ||
          targetName.contains(id.toLowerCase())) {
        hasDomainMapping = true;
        break;
      }
    }

    super.visitMethodInvocation(node);
  }

  @override
  void visitInstanceCreationExpression(InstanceCreationExpression node) {
    final typeName = node.constructorName.type.name2.lexeme;
    for (final id in _mappingIdentifiers) {
      if (typeName.contains(id)) {
        hasDomainMapping = true;
        break;
      }
    }
    super.visitInstanceCreationExpression(node);
  }
}
