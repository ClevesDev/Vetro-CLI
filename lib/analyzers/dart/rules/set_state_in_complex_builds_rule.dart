import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:vetro/analyzers/dart/adapters/dart_complexity.dart';
import 'package:vetro/core/models/context.dart';
import 'package:vetro/core/models/finding.dart';
import 'package:vetro/core/rules/rule.dart';

/// Rule that flags calls to `setState()` inside State classes whose `build`
/// method has a high cyclomatic complexity.
///
/// **Mathematical/architectural basis**: Calling `setState` triggers a rebuild
/// of the entire widget subtree returned by `build`. If `build` is highly complex
/// (high cyclomatic complexity / many branch decisions), rebuilding it frequently
/// degrades rendering performance, drop frames, and creates CPU/GPU overhead.
/// The correct solution is to decompose the complex widget tree into smaller
/// independent widgets to isolate rebuilding.
final class SetStateInComplexBuildsRule extends AnalysisRule {
  const SetStateInComplexBuildsRule({required super.config});

  @override
  String get id => 'setState_in_complex_builds';

  @override
  String get name => 'setState in Complex Build';

  @override
  String get description =>
      'Flags State classes that use setState() while having a highly complex build() method, suggesting widget decomposition.';

  @override
  List<Finding> analyzeFile(FileContext context) {
    if (!context.projectContext.isFlutterProject) {
      return const [];
    }

    final unit = context.nativeAst as CompilationUnit?;
    if (unit == null) return const [];

    final maxBuildCC =
        config.threshold('max_build_complexity', defaultValue: 12.0).toInt();

    final findings = <Finding>[];
    final visitor = _SetStateComplexityVisitor(
      maxCC: maxBuildCC,
      onViolation: (node, cc) {
        final line = unit.lineInfo.getLocation(node.offset).lineNumber;
        findings.add(
          Finding(
            ruleId: id,
            ruleName: name,
            severity: severity,
            filePath: context.filePath,
            line: line,
            message: 'Class uses "setState()" but its "build" method has a high cyclomatic complexity of $cc (threshold: $maxBuildCC). '
                'Decompose this complex widget tree into smaller stateless/stateful sub-widgets to isolate rebuilding and optimize rendering performance.',
            evidence: {
              'build_complexity': '$cc',
              'threshold': '$maxBuildCC',
              'class': node.toString(),
            },
          ),
        );
      },
    );

    unit.accept(visitor);
    return findings;
  }
}

class _SetStateComplexityVisitor extends RecursiveAstVisitor<void> {
  final int maxCC;
  final void Function(ClassDeclaration node, int cc) onViolation;

  _SetStateComplexityVisitor({
    required this.maxCC,
    required this.onViolation,
  });

  @override
  void visitClassDeclaration(ClassDeclaration node) {
    final extendsClause = node.extendsClause;
    if (extendsClause == null) {
      super.visitClassDeclaration(node);
      return;
    }

    final superclass = extendsClause.superclass.toString();
    final isStateClass = superclass.startsWith('State') || superclass.contains('State<');

    if (!isStateClass) {
      super.visitClassDeclaration(node);
      return;
    }

    // Find the build method and compute its complexity
    MethodDeclaration? buildMethod;
    for (final member in node.members) {
      if (member is MethodDeclaration &&
          member.name.lexeme == 'build' &&
          member.parameters != null &&
          member.parameters!.parameters.isNotEmpty) {
        buildMethod = member;
        break;
      }
    }

    if (buildMethod == null || buildMethod.body == null) {
      super.visitClassDeclaration(node);
      return;
    }

    final cc = cyclomaticComplexity(buildMethod.body!);
    if (cc < maxCC) {
      super.visitClassDeclaration(node);
      return;
    }

    // Check if there are any setState calls in this class (excluding build method itself to avoid recursion)
    var hasSetState = false;
    final setStateSearcher = _SetStateSearcher(
      onSetStateFound: () {
        hasSetState = true;
      },
    );

    for (final member in node.members) {
      // Look for calls to setState in event handlers / callbacks / helper methods
      if (member != buildMethod) {
        member.accept(setStateSearcher);
        if (hasSetState) break;
      }
    }

    // Also look inside build method event handlers (inline closures calling setState)
    if (!hasSetState) {
      buildMethod.body.accept(setStateSearcher);
    }

    if (hasSetState) {
      onViolation(node, cc);
    }

    super.visitClassDeclaration(node);
  }
}

class _SetStateSearcher extends RecursiveAstVisitor<void> {
  final void Function() onSetStateFound;

  _SetStateSearcher({required this.onSetStateFound});

  @override
  void visitMethodInvocation(MethodInvocation node) {
    if (node.methodName.name == 'setState') {
      onSetStateFound();
      return; // Stop searching once found
    }
    super.visitMethodInvocation(node);
  }
}
