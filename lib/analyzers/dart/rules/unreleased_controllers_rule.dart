import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:vetro/core/models/context.dart';
import 'package:vetro/core/models/finding.dart';
import 'package:vetro/core/rules/rule.dart';

/// Rule that flags unreleased controller instances (e.g. TextEditingController,
/// AnimationController, ScrollController) that are declared in State classes
/// but not disposed within the `dispose()` lifecycle method.
///
/// **Mathematical/architectural basis**: Failing to dispose of stateful controllers
/// leaks underlying system and native handles, causing memory usage to monotonically
/// increase and leading to eventual Out-Of-Memory (OOM) crashes in production.
final class UnreleasedControllersRule extends AnalysisRule {
  const UnreleasedControllersRule({required super.config});

  @override
  String get id => 'unreleased_controllers';

  @override
  String get name => 'Unreleased Controllers';

  @override
  String get description =>
      'Detects controller fields in State classes that are not properly disposed in the dispose() method.';

  @override
  List<Finding> analyzeFile(FileContext context) {
    if (!context.projectContext.isFlutterProject) {
      return const [];
    }

    final unit = context.nativeAst as CompilationUnit?;
    if (unit == null) return const [];

    final findings = <Finding>[];
    final visitor = _ControllerVisitor(
      onFinding: (node, controllerName) {
        final line = unit.lineInfo.getLocation(node.offset).lineNumber;
        findings.add(
          Finding(
            ruleId: id,
            ruleName: name,
            severity: severity,
            filePath: context.filePath,
            line: line,
            message: 'Controller "$controllerName" is declared but not disposed. '
                'Override the dispose() method and call "$controllerName.dispose()" to prevent memory leaks.',
            evidence: {
              'controller': controllerName,
              'class': node.parent?.parent.toString() ?? '',
            },
          ),
        );
      },
    );

    unit.accept(visitor);
    return findings;
  }
}

class _ControllerVisitor extends RecursiveAstVisitor<void> {
  final void Function(AstNode node, String name) onFinding;

  _ControllerVisitor({required this.onFinding});

  @override
  void visitClassDeclaration(ClassDeclaration node) {
    final extendsClause = node.extendsClause;
    if (extendsClause == null) {
      super.visitClassDeclaration(node);
      return;
    }

    final superclass = extendsClause.superclass.toString();
    // Typical state classes: extends State<MyWidget> or State, etc.
    final isStateClass = superclass.startsWith('State') || superclass.contains('State<');

    if (!isStateClass) {
      super.visitClassDeclaration(node);
      return;
    }

    // Map of declared controller names to their variable nodes
    final declaredControllers = <String, VariableDeclaration>{};

    for (final member in node.members) {
      if (member is FieldDeclaration) {
        final typeStr = member.fields.type?.toString() ?? '';
        final isControllerType = typeStr.endsWith('Controller');

        for (final variable in member.fields.variables) {
          var isController = isControllerType;

          if (!isController && variable.initializer != null) {
            final init = variable.initializer;
            if (init is InstanceCreationExpression) {
              final className = init.constructorName.type.name2.lexeme;
              if (className.endsWith('Controller')) {
                isController = true;
              }
            } else if (init is MethodInvocation) {
              final methodName = init.methodName.name;
              if (init.target == null && methodName.endsWith('Controller')) {
                isController = true;
              }
            }
          }

          if (isController) {
            declaredControllers[variable.name.lexeme] = variable;
          }
        }
      }
    }

    if (declaredControllers.isEmpty) {
      super.visitClassDeclaration(node);
      return;
    }

    // Look for the dispose method
    MethodDeclaration? disposeMethod;
    for (final member in node.members) {
      if (member is MethodDeclaration && member.name.lexeme == 'dispose') {
        disposeMethod = member;
        break;
      }
    }

    if (disposeMethod == null) {
      // If there is no dispose method, all controllers are unreleased
      declaredControllers.forEach((name, variable) {
        onFinding(variable, name);
      });
      super.visitClassDeclaration(node);
      return;
    }

    // If dispose method exists, check which controllers are disposed
    final disposedVariables = <String>{};
    final disposeBodyVisitor = _DisposeBodyVisitor(
      onDisposeCall: (varName) {
        disposedVariables.add(varName);
      },
    );

    disposeMethod.body.accept(disposeBodyVisitor);

    declaredControllers.forEach((name, variable) {
      if (!disposedVariables.contains(name)) {
        onFinding(variable, name);
      }
    });

    super.visitClassDeclaration(node);
  }
}

class _DisposeBodyVisitor extends RecursiveAstVisitor<void> {
  final void Function(String name) onDisposeCall;

  _DisposeBodyVisitor({required this.onDisposeCall});

  @override
  void visitMethodInvocation(MethodInvocation node) {
    final target = node.target?.toString();
    final methodName = node.methodName.name;

    if (methodName == 'dispose' && target != null) {
      onDisposeCall(target);
    }
    super.visitMethodInvocation(node);
  }
}
