import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:vetro/core/models/context.dart';
import 'package:vetro/core/models/finding.dart';
import 'package:vetro/core/models/project_context.dart';
import 'package:vetro/core/rules/rule.dart';

/// Performance rule that advises using `MediaQuery.sizeOf(context)`
/// instead of `MediaQuery.of(context).size` to optimize rebuilds in Flutter.
///
/// **Mathematical/logical basis**: Calling `MediaQuery.of(context)` registers
/// a dependency on the entire `MediaQueryData`. Any change (e.g. keyboard visibility,
/// orientation) triggers a rebuild. `MediaQuery.sizeOf(context)` only listens
/// to changes in size, avoiding unnecessary rebuild cycles.
///
/// Only triggers if the target project uses Flutter >= 3.10.0.
final class PerformanceMediaQueryRule extends AnalysisRule {
  const PerformanceMediaQueryRule({required super.config});

  @override
  String get id => 'performance_media_query';

  @override
  String get name => 'MediaQuery Performance';

  @override
  String get description =>
      'Recommends using MediaQuery.sizeOf(context) instead of MediaQuery.of(context).size to prevent unnecessary widget rebuilds.';

  @override
  List<Finding> analyzeFile(FileContext context) {
    final flutterVersion = context.projectContext.flutterVersion;
    if (!context.projectContext.isFlutterProject ||
        flutterVersion == null ||
        flutterVersion < const Version(3, 10, 0)) {
      return const [];
    }

    final unit = context.nativeAst as CompilationUnit?;
    if (unit == null) return const [];

    final findings = <Finding>[];
    final visitor = _MediaQueryVisitor(
      onFinding: (node) {
        final line = unit.lineInfo.getLocation(node.offset).lineNumber;
        findings.add(
          Finding(
            ruleId: id,
            ruleName: name,
            severity: severity,
            filePath: context.filePath,
            line: line,
            message: 'Use "MediaQuery.sizeOf(context)" instead of "MediaQuery.of(context).size" to prevent unnecessary widget rebuilds when other MediaQuery properties change.',
            evidence: {
              'expression': node.toString(),
              'flutter_version': flutterVersion.toString(),
            },
          ),
        );
      },
    );

    unit.accept(visitor);
    return findings;
  }
}

class _MediaQueryVisitor extends RecursiveAstVisitor<void> {
  final void Function(AstNode node) onFinding;

  _MediaQueryVisitor({required this.onFinding});

  @override
  void visitPropertyAccess(PropertyAccess node) {
    if (node.propertyName.name == 'size') {
      final target = node.target;
      if (target != null && _isMediaQueryOfCall(target)) {
        onFinding(node);
      }
    }
    super.visitPropertyAccess(node);
  }

  @override
  void visitPrefixedIdentifier(PrefixedIdentifier node) {
    if (node.identifier.name == 'size') {
      final prefix = node.prefix;
      if (_isMediaQueryOfCall(prefix)) {
        onFinding(node);
      }
    }
    super.visitPrefixedIdentifier(node);
  }

  bool _isMediaQueryOfCall(AstNode node) {
    if (node is MethodInvocation) {
      final method = node.methodName.name;
      final target = node.target;
      if (method == 'of' && target is SimpleIdentifier && target.name == 'MediaQuery') {
        return true;
      }
    }
    return false;
  }
}
