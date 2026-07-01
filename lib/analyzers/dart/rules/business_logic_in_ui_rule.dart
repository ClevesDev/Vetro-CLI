import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:vetro/core/models/context.dart';
import 'package:vetro/core/models/finding.dart';
import 'package:vetro/core/rules/rule.dart';

/// Architecture rule that flags business logic or infrastructure dependencies
/// instantiations/executions directly inside widget `build` methods.
///
/// **Mathematical/architectural basis**: Widget build methods should be pure
/// projection functions that transform state into UI representation: `UI = f(State)`.
/// Doing asynchronous tasks, HTTP calls, or local cache instantiations inside `build`
/// violates unidirectional data flow, couples logic, and degrades performance.
final class BusinessLogicInUiRule extends AnalysisRule {
  const BusinessLogicInUiRule({required super.config});

  @override
  String get id => 'business_logic_in_ui';

  @override
  String get name => 'Business Logic in UI';

  @override
  String get description =>
      'Flags business logic, network operations, and repository instantiations inside widget build methods.';

  @override
  List<Finding> analyzeFile(FileContext context) {
    if (!context.projectContext.isFlutterProject) {
      return const [];
    }

    final unit = context.nativeAst as CompilationUnit?;
    if (unit == null) return const [];

    final findings = <Finding>[];
    final visitor = _BuildMethodLogicVisitor(
      onViolation: (node, message, type) {
        final line = unit.lineInfo.getLocation(node.offset).lineNumber;
        findings.add(
          Finding(
            ruleId: id,
            ruleName: name,
            severity: severity,
            filePath: context.filePath,
            line: line,
            message: message,
            evidence: {
              'expression': node.toString(),
              'violation_type': type,
            },
          ),
        );
      },
    );

    unit.accept(visitor);
    return findings;
  }
}

class _BuildMethodLogicVisitor extends RecursiveAstVisitor<void> {
  final void Function(AstNode node, String message, String type) onViolation;

  _BuildMethodLogicVisitor({required this.onViolation});

  @override
  void visitMethodDeclaration(MethodDeclaration node) {
    if (node.name.lexeme == 'build' &&
        node.parameters != null &&
        node.parameters!.parameters.isNotEmpty) {
      final bodyVisitor = _BuildBodyVisitor(onViolation: onViolation);
      node.body.accept(bodyVisitor);
    }
    super.visitMethodDeclaration(node);
  }
}

class _BuildBodyVisitor extends RecursiveAstVisitor<void> {
  final void Function(AstNode node, String message, String type) onViolation;

  _BuildBodyVisitor({required this.onViolation});

  static const _uiControllerExceptions = {
    'DefaultTabController',
    'TabController',
    'ScrollController',
    'PageController',
    'UndoHistoryController',
    'AnimationController',
    'TextEditingController',
  };

  static bool isBusinessClass(String className) {
    var clean = className;
    while (clean.startsWith('_')) {
      clean = clean.substring(1);
    }
    if (clean.isEmpty) return false;

    // Must start with an uppercase letter from A to Z (ignore private _ prefix)
    final firstChar = clean.substring(0, 1);
    if (!RegExp(r'^[A-Z]').hasMatch(firstChar)) return false;

    // Ignore native Flutter UI controllers
    if (_uiControllerExceptions.contains(clean)) return false;

    final lower = clean.toLowerCase();
    return lower.endsWith('repository') ||
        lower.endsWith('service') ||
        lower.endsWith('api') ||
        lower.endsWith('controller') ||
        lower.endsWith('client') ||
        lower.endsWith('bloc') ||
        lower.endsWith('cubit');
  }

  @override
  void visitInstanceCreationExpression(InstanceCreationExpression node) {
    final typeName = node.constructorName.type.name2.lexeme;

    if (isBusinessClass(typeName)) {
      onViolation(
        node,
        'Avoid instantiating business services, blocs, or controllers ("$typeName") directly inside the build method. '
        'This leads to high coupling and redundant instantiation during widget rebuilds.',
        'business_instance_creation',
      );
    }
    super.visitInstanceCreationExpression(node);
  }

  @override
  void visitAwaitExpression(AwaitExpression node) {
    onViolation(
      node,
      'Avoid using "await" expressions inside the build method. UI build methods must be pure, synchronous, and fast. '
      'Use FutureBuilder, StreamBuilder, or state management classes to handle asynchronous values.',
      'await_in_build',
    );
    super.visitAwaitExpression(node);
  }

  @override
  void visitMethodInvocation(MethodInvocation node) {
    final methodName = node.methodName.name;
    final target = node.target?.toString() ?? '';
    final lowerTarget = target.toLowerCase();

    // Check for instantiations without new (parsed as MethodInvocation)
    String? suspectedClassName;
    if (node.target == null) {
      suspectedClassName = methodName;
    } else if (node.target is SimpleIdentifier) {
      suspectedClassName = target;
    }

    if (suspectedClassName != null && isBusinessClass(suspectedClassName)) {
      onViolation(
        node,
        'Avoid instantiating business services, blocs, or controllers ("$suspectedClassName") directly inside the build method. '
        'This leads to high coupling and redundant instantiation during widget rebuilds.',
        'business_instance_creation',
      );
    }

    if (methodName == 'then' &&
        (lowerTarget.contains('future') ||
            lowerTarget.contains('api') ||
            lowerTarget.contains('service'))) {
      onViolation(
        node,
        'Avoid calling ".then()" on futures directly inside the build method. Use state management or FutureBuilder instead.',
        'then_on_future',
      );
    }

    if (methodName == 'get' ||
        methodName == 'post' ||
        methodName == 'put' ||
        methodName == 'delete') {
      if (lowerTarget == 'http' ||
          lowerTarget.contains('dio') ||
          lowerTarget.contains('client') ||
          lowerTarget.contains('api')) {
        onViolation(
          node,
          'Avoid making HTTP network requests ("$target.$methodName") inside the build method. Move network requests to the Controller, Bloc, or initState.',
          'network_request_in_build',
        );
      }
    }

    super.visitMethodInvocation(node);
  }
}
