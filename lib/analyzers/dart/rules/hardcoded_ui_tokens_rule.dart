import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:vetro/core/models/context.dart';
import 'package:vetro/core/models/finding.dart';
import 'package:vetro/core/rules/rule.dart';

/// Rule that flags hardcoded UI tokens (such as raw `Color(0xFF...)` values or
/// inline `TextStyle(...)` instantiations) directly inside widget `build` methods.
///
/// **Mathematical/architectural basis**: UI configurations should decouple from
/// representation details by referencing centralized theme trees (`Theme.of(context)`).
/// Hardcoding visual values inline destroys dark/light mode compatibility, makes styling
/// inconsistent across screens, and represents significant maintenance debt.
final class HardcodedUiTokensRule extends AnalysisRule {
  const HardcodedUiTokensRule({required super.config});

  @override
  String get id => 'hardcoded_ui_tokens';

  @override
  String get name => 'Hardcoded UI Tokens';

  @override
  String get description =>
      'Flags inline Color and TextStyle instantiations inside widget build methods, recommending Theme-based values.';

  @override
  List<Finding> analyzeFile(FileContext context) {
    if (!context.projectContext.isFlutterProject) {
      return const [];
    }

    final unit = context.nativeAst as CompilationUnit?;
    if (unit == null) return const [];

    final findings = <Finding>[];
    final visitor = _BuildMethodVisitor(
      onViolation: (node, message) {
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
            },
          ),
        );
      },
    );

    unit.accept(visitor);
    return findings;
  }
}

class _BuildMethodVisitor extends RecursiveAstVisitor<void> {
  final void Function(AstNode node, String message) onViolation;

  _BuildMethodVisitor({required this.onViolation});

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
  final void Function(AstNode node, String message) onViolation;

  _BuildBodyVisitor({required this.onViolation});

  void _checkTypeName(AstNode node, String typeName) {
    if (typeName == 'Color') {
      onViolation(
        node,
        'Avoid instantiating raw "Color" values inline. '
        'Reference colors from your theme (e.g. Theme.of(context).colorScheme.primary) or a centralized AppColors class.',
      );
    } else if (typeName == 'TextStyle') {
      onViolation(
        node,
        'Avoid defining inline "TextStyle" objects inside the build method. '
        'Extend the existing text theme (e.g. Theme.of(context).textTheme.bodyMedium.copyWith(...)) to ensure UI styling consistency.',
      );
    }
  }

  @override
  void visitInstanceCreationExpression(InstanceCreationExpression node) {
    final typeName = node.constructorName.type.name2.lexeme;
    _checkTypeName(node, typeName);
    super.visitInstanceCreationExpression(node);
  }

  @override
  void visitMethodInvocation(MethodInvocation node) {
    final methodName = node.methodName.name;
    if (node.target == null) {
      _checkTypeName(node, methodName);
    }
    super.visitMethodInvocation(node);
  }
}
