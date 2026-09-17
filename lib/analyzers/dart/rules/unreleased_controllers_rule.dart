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
            message:
                'Controller "$controllerName" is declared but not disposed. '
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
  _ControllerVisitor({required this.onFinding});
  final void Function(AstNode node, String name) onFinding;

  @override
  void visitClassDeclaration(ClassDeclaration node) {
    final extendsClause = node.extendsClause;
    if (extendsClause == null) {
      super.visitClassDeclaration(node);
      return;
    }

    final superclass = extendsClause.superclass.toString();
    // Typical state classes: extends State<MyWidget> or ConsumerState<MyWidget>
    final isStateClass = superclass == 'State' ||
        superclass.startsWith('State<') ||
        superclass == 'ConsumerState' ||
        superclass.startsWith('ConsumerState<');

    if (!isStateClass) {
      super.visitClassDeclaration(node);
      return;
    }

    // Collect constructor-injected fields (this.foo)
    final injectedFields = <String>{};
    for (final member in node.members) {
      if (member is ConstructorDeclaration) {
        for (final param in member.parameters.parameters) {
          if (param is FieldFormalParameter) {
            injectedFields.add(param.name.lexeme);
          }
        }
      }
    }

    // Map of declared controller names to their variable nodes
    final declaredControllers = <String, VariableDeclaration>{};

    for (final member in node.members) {
      if (member is FieldDeclaration) {
        final typeStr = member.fields.type?.toString() ?? '';
        final isControllerType = typeStr.endsWith('Controller');

        for (final variable in member.fields.variables) {
          final varName = variable.name.lexeme;
          if (injectedFields.contains(varName)) {
            continue;
          }

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
            declaredControllers[varName] = variable;
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
      onDisposeCall: disposedVariables.add,
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
  _DisposeBodyVisitor({required this.onDisposeCall});
  final void Function(String name) onDisposeCall;

  @override
  void visitMethodInvocation(MethodInvocation node) {
    final target = node.target?.toString();
    final methodName = node.methodName.name;

    if (methodName == 'dispose' && target != null) {
      onDisposeCall(target);
    }

    // Handle collection forEach: [_ctrl1, _ctrl2].forEach((c) => c.dispose());
    if (methodName == 'forEach') {
      final listTarget = node.target;
      if (listTarget is ListLiteral && node.argumentList.arguments.isNotEmpty) {
        final callback = node.argumentList.arguments.first;
        if (callback is FunctionExpression) {
          final paramName =
              callback.parameters?.parameters.firstOrNull?.name?.lexeme;
          if (paramName != null &&
              _containsDisposeCallFor(callback.body, paramName)) {
            for (final element in listTarget.elements) {
              if (element is SimpleIdentifier) {
                onDisposeCall(element.name);
              }
            }
          }
        }
      }
    }

    super.visitMethodInvocation(node);
  }

  @override
  void visitForStatement(ForStatement node) {
    // Handle for-in loops: for (final c in [_ctrl1, _ctrl2]) { c.dispose(); }
    final parts = node.forLoopParts;
    if (parts is ForEachParts) {
      final iterable = parts.iterable;
      if (iterable is ListLiteral) {
        String? loopVar;
        if (parts is ForEachPartsWithDeclaration) {
          loopVar = parts.loopVariable.name.lexeme;
        } else if (parts is ForEachPartsWithIdentifier) {
          loopVar = parts.identifier.name;
        }

        if (loopVar != null && _containsDisposeCallFor(node.body, loopVar)) {
          for (final element in iterable.elements) {
            if (element is SimpleIdentifier) {
              onDisposeCall(element.name);
            }
          }
        }
      }
    }

    super.visitForStatement(node);
  }

  static bool _containsDisposeCallFor(AstNode body, String varName) {
    var found = false;
    body.accept(
      _DisposeTargetFinder(
        varName: varName,
        onFound: () => found = true,
      ),
    );
    return found;
  }
}

class _DisposeTargetFinder extends RecursiveAstVisitor<void> {
  _DisposeTargetFinder({required this.varName, required this.onFound});
  final String varName;
  final void Function() onFound;

  @override
  void visitMethodInvocation(MethodInvocation node) {
    if (node.methodName.name == 'dispose' &&
        node.target?.toString() == varName) {
      onFound();
    }
    super.visitMethodInvocation(node);
  }
}
