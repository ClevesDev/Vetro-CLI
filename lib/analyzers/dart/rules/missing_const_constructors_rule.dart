import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:vetro/core/models/context.dart';
import 'package:vetro/core/models/finding.dart';
import 'package:vetro/core/rules/rule.dart';

/// Rule that flags instantiations of standard static Flutter widgets and tokens
/// (such as `SizedBox`, `Padding`, `Text`, `Icon`, `EdgeInsets`) inside build methods
/// that could be declared as `const` but are currently instantiated dynamically.
///
/// **Mathematical/architectural basis**: In Flutter, `const` widgets are evaluated
/// at compile-time and cached. During state changes and rebuilds, Flutter performs a
/// simple pointer comparison (`identical`) on `const` widgets, bypassing element tree
/// reconstruction, layout, and repaint computations for those subtrees. Omitting `const`
/// forces runtime re-allocation and redundantly triggers widget rebuilds.
final class MissingConstConstructorsRule extends AnalysisRule {
  const MissingConstConstructorsRule({required super.config});

  @override
  String get id => 'missing_const_constructors';

  @override
  String get name => 'Missing const Constructor';

  @override
  String get description =>
      'Recommends using const constructors for static widgets and styles inside the build method to optimize rendering.';

  @override
  List<Finding> analyzeFile(FileContext context) {
    if (!context.projectContext.isFlutterProject) {
      return const [];
    }

    final unit = context.nativeAst as CompilationUnit?;
    if (unit == null) return const [];

    final findings = <Finding>[];
    final visitor = _BuildMethodVisitor(
      onViolation: (node, widgetName) {
        final line = unit.lineInfo.getLocation(node.offset).lineNumber;
        findings.add(
          Finding(
            ruleId: id,
            ruleName: name,
            severity: severity,
            filePath: context.filePath,
            line: line,
            message: 'Use a "const" constructor when instantiating static widget or token "$widgetName". '
                'This allows Flutter to cache the widget instance and optimize build/render cycles.',
            evidence: {
              'expression': node.toString(),
              'widget': widgetName,
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
  final void Function(AstNode node, String widgetName) onViolation;

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
  final void Function(AstNode node, String widgetName) onViolation;

  _BuildBodyVisitor({required this.onViolation});

  static const _candidateConstClasses = {
    'SizedBox',
    'Spacer',
    'Divider',
    'VerticalDivider',
    'Padding',
    'Align',
    'Center',
    'Text',
    'Icon',
    'TextStyle',
    'EdgeInsets',
  };

  bool _isConstantExpression(Expression expr) {
    if (expr is Literal) return true;

    if (expr is PrefixedIdentifier) {
      final prefix = expr.prefix.name;
      return prefix.isNotEmpty && RegExp(r'^[A-Z]').hasMatch(prefix.substring(0, 1));
    }

    if (expr is PropertyAccess) {
      final targetStr = expr.realTarget.toString();
      return targetStr.isNotEmpty &&
          RegExp(r'^[A-Z]').hasMatch(targetStr.substring(0, 1)) &&
          !targetStr.contains('(');
    }

    if (expr is SimpleIdentifier) {
      return false;
    }

    if (expr is InstanceCreationExpression) {
      return expr.isConst;
    }

    if (expr is MethodInvocation) {
      final target = expr.target;
      final methodName = expr.methodName.name;
      
      if (target == null) {
        // Constructor invocation without new (e.g. Text('Hello'))
        if (_candidateConstClasses.contains(methodName)) {
          var allArgsConstant = true;
          for (final arg in expr.argumentList.arguments) {
            if (!_isConstantExpression(arg)) {
              allArgsConstant = false;
              break;
            }
          }
          return allArgsConstant;
        }
      } else {
        // Named static class constructor/factory (e.g. EdgeInsets.all(8.0))
        final targetStr = target.toString();
        final isStaticClass = targetStr.isNotEmpty &&
            RegExp(r'^[A-Z]').hasMatch(targetStr.substring(0, 1)) &&
            !targetStr.contains('(');

        if (isStaticClass) {
          var allArgsConstant = true;
          for (final arg in expr.argumentList.arguments) {
            if (!_isConstantExpression(arg)) {
              allArgsConstant = false;
              break;
            }
          }
          return allArgsConstant;
        }
      }
      return false;
    }

    if (expr is NamedExpression) {
      return _isConstantExpression(expr.expression);
    }

    return false;
  }

  void _checkConstPossibility(AstNode node, String typeName, ArgumentList argumentList) {
    if (_candidateConstClasses.contains(typeName)) {
      // Check if all arguments are syntactically constant
      var allArgsConstant = true;
      for (final arg in argumentList.arguments) {
        if (!_isConstantExpression(arg)) {
          allArgsConstant = false;
          break;
        }
      }

      if (allArgsConstant) {
        // Also check if any parent in the tree is already marked as const
        var hasConstParent = false;
        AstNode? parent = node.parent;
        while (parent != null) {
          if (parent is InstanceCreationExpression && parent.isConst) {
            hasConstParent = true;
            break;
          }
          if (parent is MethodDeclaration) break; // Don't go beyond build method boundary
          parent = parent.parent;
        }

        if (!hasConstParent) {
          onViolation(node, typeName);
        }
      }
    }
  }

  @override
  void visitInstanceCreationExpression(InstanceCreationExpression node) {
    if (node.isConst) {
      super.visitInstanceCreationExpression(node);
      return;
    }

    final typeName = node.constructorName.type.name2.lexeme;
    _checkConstPossibility(node, typeName, node.argumentList);
    super.visitInstanceCreationExpression(node);
  }

  @override
  void visitMethodInvocation(MethodInvocation node) {
    final target = node.target;
    final methodName = node.methodName.name;

    if (target == null) {
      // Normal class constructor invocation without new
      _checkConstPossibility(node, methodName, node.argumentList);
    } else {
      // Named constructor call without new (e.g. EdgeInsets.all(8.0))
      final targetStr = target.toString();
      final isStaticClass = targetStr.isNotEmpty &&
          RegExp(r'^[A-Z]').hasMatch(targetStr.substring(0, 1)) &&
          !targetStr.contains('(');

      if (isStaticClass) {
        _checkConstPossibility(node, targetStr, node.argumentList);
      }
    }
    super.visitMethodInvocation(node);
  }
}
