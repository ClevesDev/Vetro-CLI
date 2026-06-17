/// Rule: Fragile Test — detects test functions with excessive mocking.
///
/// **Mathematical basis**: Mock density analysis.
///
/// For each test function `t` in a `_test.dart` file:
///   mockCount(t) = |{ id ∈ identifiers(t) : id contains 'Mock' ∨ 'Fake' }|
///   verifyCount(t) = |{ calls ∈ invocations(t) : call ∈ {verify, verifyInOrder, verifyNever} }|
///   whenCount(t) = |{ calls ∈ invocations(t) : call = 'when' }|
///
/// Report when mockCount(t) > max_mocks threshold (default 3).
///
/// AI-generated tests tend to heavily mock everything rather than
/// testing real behavior. High mock counts indicate fragile tests
/// that break on any refactor.
library;

import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';

import 'package:vetro/analyzers/dart/ast_utils.dart';
import 'package:vetro/core/models/finding.dart';
import 'package:vetro/core/rules/rule.dart';

/// Detects test functions with excessive mock usage.
///
/// Only analyzes files whose path ends with `_test.dart`.
///
/// **Threshold**: `max_mocks` (default 3).
///
/// Evidence includes mock count, verify count, and when count.
final class FragileTestRule extends Rule {
  /// Creates a [FragileTestRule] with the given [config].
  const FragileTestRule({required super.config});

  @override
  String get id => 'fragile_test';

  @override
  String get name => 'Fragile Test';

  @override
  String get description =>
      'Flags test functions with excessive mock/fake usage, '
      'indicating fragile tests coupled to implementation details.';

  @override
  List<Finding> analyze(
    CompilationUnit unit,
    String filePath,
    String source,
  ) {
    // Only analyze test files.
    if (!isTestFile(filePath)) return const [];

    final maxMocks =
        config.threshold('max_mocks', defaultValue: 3.0).toInt();
    final findings = <Finding>[];

    // We use extractDeclarations because both top-level test helper functions
    // and method declarations in custom test fixtures or suites might configure mocks.
    for (final decl in extractDeclarations(unit)) {
      final body = decl.body;
      if (body == null) continue;

      _analyzeNode(
        node: body,
        name: decl.name,
        filePath: filePath,
        unit: unit,
        declarationNode: decl.node,
        maxMocks: maxMocks,
        findings: findings,
      );
    }

    // Scan test() and group() calls at the top level.
    final testCallVisitor = _TestCallVisitor(
      maxMocks: maxMocks,
      filePath: filePath,
      unit: unit,
      findings: findings,
      severity: severity,
      ruleId: id,
      ruleName: name,
    );
    unit.accept(testCallVisitor);

    return findings;
  }

  void _analyzeNode({
    required AstNode node,
    required String name,
    required String filePath,
    required CompilationUnit unit,
    required AstNode declarationNode,
    required int maxMocks,
    required List<Finding> findings,
  }) {
    // Note: Analysis helper.
    final stats = _MockStats.fromNode(node);

    if (stats.mockCount > maxMocks) {
      final line =
          unit.lineInfo.getLocation(declarationNode.offset).lineNumber;
      _reportMockLimitExceeded(
        ruleId: id,
        ruleName: this.name,
        severity: severity,
        filePath: filePath,
        line: line,
        entityName: name,
        stats: stats,
        maxMocks: maxMocks,
        findings: findings,
        isTest: false,
      );
    }
  }
}

/// Aggregated mock usage statistics for a function body.
final class _MockStats {
  const _MockStats({
    required this.mockCount,
    required this.verifyCount,
    required this.whenCount,
  });

  /// Analyzes an AST node and returns mock usage statistics.
  factory _MockStats.fromNode(AstNode node) {
    final visitor = _MockUsageVisitor();
    node.accept(visitor);
    return _MockStats(
      mockCount: visitor.mockIdentifiers.length,
      verifyCount: visitor.verifyCount,
      whenCount: visitor.whenCount,
    );
  }

  final int mockCount;
  final int verifyCount;
  final int whenCount;
}

/// Visitor that counts mock-related identifiers and calls.
final class _MockUsageVisitor extends RecursiveAstVisitor<void> {
  final Set<String> mockIdentifiers = {};
  int verifyCount = 0;
  int whenCount = 0;

  /// Patterns that indicate a mock/fake instantiation or reference.
  static final _mockPattern = RegExp('Mock|Fake');

  /// Verify-family function names.
  static const _verifyNames = {'verify', 'verifyInOrder', 'verifyNever'};

  @override
  void visitInstanceCreationExpression(InstanceCreationExpression node) {
    final typeName = node.constructorName.type.name2.lexeme;
    if (_mockPattern.hasMatch(typeName)) {
      mockIdentifiers.add(typeName);
    }
    super.visitInstanceCreationExpression(node);
  }

  @override
  void visitSimpleIdentifier(SimpleIdentifier node) {
    // Track mock/fake variable references.
    if (_mockPattern.hasMatch(node.name)) {
      mockIdentifiers.add(node.name);
    }
    super.visitSimpleIdentifier(node);
  }

  @override
  void visitMethodInvocation(MethodInvocation node) {
    final methodName = node.methodName.name;

    if (_verifyNames.contains(methodName)) {
      verifyCount++;
    } else if (methodName == 'when') {
      whenCount++;
    }

    super.visitMethodInvocation(node);
  }

  @override
  void visitFunctionExpressionInvocation(
    FunctionExpressionInvocation node,
  ) {
    // Handle top-level function calls like verify(...).
    final function = node.function;
    if (function is SimpleIdentifier) {
      final name = function.name;
      if (_verifyNames.contains(name)) {
        verifyCount++;
      } else if (name == 'when') {
        whenCount++;
      }
    }
    super.visitFunctionExpressionInvocation(node);
  }
}

/// Visitor that finds test() and group() invocations and analyzes their
/// callback bodies for mock usage.
final class _TestCallVisitor extends RecursiveAstVisitor<void> {
  _TestCallVisitor({
    required this.maxMocks,
    required this.filePath,
    required this.unit,
    required this.findings,
    required this.severity,
    required this.ruleId,
    required this.ruleName,
  });

  final int maxMocks;
  final String filePath;
  final CompilationUnit unit;
  final List<Finding> findings;
  final Severity severity;
  final String ruleId;
  final String ruleName;

  @override
  void visitMethodInvocation(MethodInvocation node) {
    final name = node.methodName.name;
    if (name == 'test' || name == 'testWidgets') {
      _analyzeTestCall(node);
    }
    // Don't recurse into nested test calls — each is analyzed independently.
  }

  void _analyzeTestCall(MethodInvocation node) {
    // We check that there are at least two arguments because a valid test() invocation
    // always has a description (argument 0) and a body callback (argument 1).
    final args = node.argumentList.arguments;
    if (args.length < 2) return;

    // We extract the string value if the description is a string literal, otherwise
    // default to 'anonymous' because descriptions can theoretically be variables/expressions.
    final testName = args.first is StringLiteral
        ? (args.first as StringLiteral).stringValue ?? 'anonymous'
        : 'anonymous';

    // We skip the callback check if it is not a FunctionExpression because we only analyze
    // inline closures directly passed to the test call.
    final callback = args[1];
    if (callback is! FunctionExpression) return;

    final stats = _MockStats.fromNode(callback.body);
    if (stats.mockCount > maxMocks) {
      final line = unit.lineInfo.getLocation(node.offset).lineNumber;
      _reportMockLimitExceeded(
        ruleId: ruleId,
        ruleName: ruleName,
        severity: severity,
        filePath: filePath,
        line: line,
        entityName: testName,
        stats: stats,
        maxMocks: maxMocks,
        findings: findings,
        isTest: true,
      );
    }
  }
}

void _reportMockLimitExceeded({
  required String ruleId,
  required String ruleName,
  required Severity severity,
  required String filePath,
  required int line,
  required String entityName,
  required _MockStats stats,
  required int maxMocks,
  required List<Finding> findings,
  required bool isTest,
}) {
  // Note: The purpose of this helper is to consolidate finding reporting for mock violations.
  final entityType = isTest ? 'Test' : 'Function';
  findings.add(
    Finding(
      ruleId: ruleId,
      ruleName: ruleName,
      severity: severity,
      filePath: filePath,
      line: line,
      message: '$entityType "$entityName" uses ${stats.mockCount} mocks/fakes '
          '(threshold: $maxMocks). Consider testing real behavior.',
      evidence: {
        'mock_count': '${stats.mockCount}',
        'verify_count': '${stats.verifyCount}',
        'when_count': '${stats.whenCount}',
        'threshold': '$maxMocks',
      },
    ),
  );
}
