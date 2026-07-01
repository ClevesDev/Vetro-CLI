import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:vetro/core/models/context.dart';
import 'package:vetro/core/models/finding.dart';
import 'package:vetro/core/rules/rule.dart';

/// Layout rule that flags flexible widgets (Expanded, Flexible, Spacer)
/// that are placed inside containers other than Row, Column, or Flex.
///
/// **Mathematical/logical basis**: Flex layouts calculate children flex ratios
/// during layout constraints resolution. If a flexible widget is placed inside a non-flex
/// parent (e.g. Container, Stack, Padding), the constraints resolution fails,
/// leading to runtime assertions (RenderFlex overflow/incorrect child constraints).
final class MisplacedLayoutConstraintsRule extends AnalysisRule {
  const MisplacedLayoutConstraintsRule({required super.config});

  @override
  String get id => 'misplaced_layout_constraints';

  @override
  String get name => 'Misplaced Layout Constraints';

  @override
  String get description =>
      'Flags flexible widgets (Expanded, Flexible, Spacer) that are not direct descendants of a Row, Column, or Flex.';

  @override
  List<Finding> analyzeFile(FileContext context) {
    if (!context.projectContext.isFlutterProject) {
      return const [];
    }

    final unit = context.nativeAst as CompilationUnit?;
    if (unit == null) return const [];

    final findings = <Finding>[];
    final visitor = _FlexibleWidgetVisitor(
      onViolation: (node, parentName) {
        final widgetName = _getWidgetTypeName(node) ?? 'Flexible';
        final line = unit.lineInfo.getLocation(node.offset).lineNumber;
        findings.add(
          Finding(
            ruleId: id,
            ruleName: name,
            severity: severity,
            filePath: context.filePath,
            line: line,
            message: 'Misplaced "$widgetName" widget. '
                'Flexible widgets must be placed directly inside a Row, Column, or Flex. '
                'It is currently placed inside a "$parentName" container.',
            evidence: {
              'flexible_widget': widgetName,
              'actual_parent': parentName,
            },
          ),
        );
      },
    );

    unit.accept(visitor);
    return findings;
  }

  static String? _getWidgetTypeName(AstNode node) {
    if (node is InstanceCreationExpression) {
      return node.constructorName.type.name2.lexeme;
    }
    if (node is MethodInvocation) {
      if (node.target == null) {
        return node.methodName.name;
      }
      final targetStr = node.target.toString();
      if (targetStr.isNotEmpty) {
        final firstChar = targetStr.substring(0, 1);
        if (firstChar == firstChar.toUpperCase()) {
          return targetStr;
        }
      }
    }
    return null;
  }
}

class _FlexibleWidgetVisitor extends RecursiveAstVisitor<void> {
  final void Function(AstNode node, String parentName) onViolation;

  _FlexibleWidgetVisitor({required this.onViolation});

  void _checkWidget(AstNode node, String typeName) {
    if (typeName == 'Expanded' || typeName == 'Flexible' || typeName == 'Spacer') {
      final parentWidget = _findParentWidgetInstance(node);
      if (parentWidget != null) {
        final parentTypeName = MisplacedLayoutConstraintsRule._getWidgetTypeName(parentWidget);
        if (parentTypeName != null &&
            parentTypeName != 'Row' &&
            parentTypeName != 'Column' &&
            parentTypeName != 'Flex') {
          onViolation(node, parentTypeName);
        }
      }
    }
  }

  @override
  void visitInstanceCreationExpression(InstanceCreationExpression node) {
    final typeName = node.constructorName.type.name2.lexeme;
    _checkWidget(node, typeName);
    super.visitInstanceCreationExpression(node);
  }

  @override
  void visitMethodInvocation(MethodInvocation node) {
    final name = node.methodName.name;
    _checkWidget(node, name);
    super.visitMethodInvocation(node);
  }

  AstNode? _findParentWidgetInstance(AstNode node) {
    AstNode? current = node.parent;
    while (current != null) {
      if (current is InstanceCreationExpression) {
        return current;
      }
      if (current is MethodInvocation) {
        final name = current.methodName.name;
        if (name.isNotEmpty) {
          final firstChar = name.substring(0, 1);
          if (firstChar == firstChar.toUpperCase()) {
            return current;
          }
        }
      }
      if (current is MethodDeclaration || current is FunctionDeclaration) {
        break;
      }
      current = current.parent;
    }
    return null;
  }
}
