/// Rule: Orphaned Abstraction — detects abstractions with ≤ 1 implementation.
///
/// **Mathematical basis**: Implementation count analysis.
///
/// For each abstract class or mixin `A` found across all files:
///   implementations(A) = |{ C : C extends A ∨ C implements A ∨ C with A }|
///
/// Report when implementations(A) ≤ 1.
///
/// AI tools frequently generate speculative abstractions — interfaces
/// and abstract classes "for flexibility" that are never actually
/// extended. This rule quantifies that overhead.
library;

import 'package:analyzer/dart/ast/ast.dart';

import 'package:vetro/analyzers/dart/ast_utils.dart';
import 'package:vetro/core/models/finding.dart';
import 'package:vetro/core/rules/rule.dart';

/// Detects abstract classes and mixins that have zero or one implementation.
///
/// A cross-file rule: it scans all files to find abstractions and then
/// scans all files again to count implementations.
///
/// Evidence includes the abstraction name and implementation count.
final class OrphanedAbstractionRule extends CrossFileRule {
  /// Creates an [OrphanedAbstractionRule] with the given [config].
  const OrphanedAbstractionRule({required super.config});

  @override
  String get id => 'orphaned_abstraction';

  @override
  String get name => 'Orphaned Abstraction';

  @override
  String get description =>
      'Detects abstract classes/mixins with zero or one implementation.';

  @override
  Future<List<Finding>> analyzeProject(
    Map<String, CompilationUnit> units,
    Map<String, String> sources,
  ) async {
    // We execute in three sequential phases to accurately count implementations
    // across all files in the project.
    final abstractions = _collectAbstractions(units);
    if (abstractions.isEmpty) return const [];

    final abstractionNames = abstractions.map((a) => a.name).toSet();
    final implCounts = _countImplementations(units, abstractionNames);

    return _buildFindings(abstractions, implCounts);
  }

  /// Collects all abstract classes and mixins across the project.
  ///
  /// We do this because we need to establish the complete list of abstractions
  /// before counting how many concrete classes implement or extend them.
  List<_AbstractionInfo> _collectAbstractions(Map<String, CompilationUnit> units) {
    final abstractions = <_AbstractionInfo>[];
    for (final entry in units.entries) {
      final filePath = entry.key;
      final unit = entry.value;

      for (final cls in extractClasses(unit)) {
        if (isAbstractClass(cls)) {
          final line = unit.lineInfo.getLocation(cls.offset).lineNumber;
          abstractions.add(
            _AbstractionInfo(
              name: cls.name.lexeme,
              filePath: filePath,
              line: line,
            ),
          );
        }
      }

      for (final decl in unit.declarations) {
        if (decl is MixinDeclaration) {
          final line = unit.lineInfo.getLocation(decl.offset).lineNumber;
          abstractions.add(
            _AbstractionInfo(
              name: decl.name.lexeme,
              filePath: filePath,
              line: line,
            ),
          );
        }
      }
    }
    return abstractions;
  }

  /// Counts implementation references for all abstractions in the project.
  ///
  /// We traverse all concrete classes and check extends, implements, and with clauses.
  Map<String, int> _countImplementations(
    Map<String, CompilationUnit> units,
    Set<String> abstractionNames,
  ) {
    // We traverse all concrete classes across the project because an abstraction's 
    // implementations can reside in any file.
    final implCounts = {for (final name in abstractionNames) name: 0};

    for (final unit in units.values) {
      for (final cls in extractClasses(unit)) {
        if (isAbstractClass(cls)) continue;

        final extendsClause = cls.extendsClause;
        if (extendsClause != null) {
          final superName = extendsClause.superclass.name2.lexeme;
          if (abstractionNames.contains(superName)) {
            implCounts[superName] = (implCounts[superName] ?? 0) + 1;
          }
        }

        final implementsClause = cls.implementsClause;
        if (implementsClause != null) {
          for (final iface in implementsClause.interfaces) {
            final ifaceName = iface.name2.lexeme;
            if (abstractionNames.contains(ifaceName)) {
              implCounts[ifaceName] = (implCounts[ifaceName] ?? 0) + 1;
            }
          }
        }

        final withClause = cls.withClause;
        if (withClause != null) {
          for (final mixin in withClause.mixinTypes) {
            final mixinName = mixin.name2.lexeme;
            if (abstractionNames.contains(mixinName)) {
              implCounts[mixinName] = (implCounts[mixinName] ?? 0) + 1;
            }
          }
        }
      }
    }
    return implCounts;
  }

  /// Builds the findings list for abstractions that have zero or one implementation.
  ///
  /// This helps detect speculative design where interfaces are defined but never utilized.
  List<Finding> _buildFindings(
    List<_AbstractionInfo> abstractions,
    Map<String, int> implCounts,
  ) {
    // We evaluate abstractions to check if they are orphaned because abstractions with
    // 0 or 1 implementation represent over-engineered speculative design.
    final findings = <Finding>[];
    for (final abstraction in abstractions) {
      final count = implCounts[abstraction.name] ?? 0;
      if (count <= 1) {
        findings.add(
          Finding(
            ruleId: id,
            ruleName: name,
            severity: severity,
            filePath: abstraction.filePath,
            line: abstraction.line,
            message: count == 0
                ? 'Abstract class "${abstraction.name}" has no implementations.'
                : 'Abstract class "${abstraction.name}" has only '
                    '1 implementation — the abstraction may be unnecessary.',
            evidence: {
              'abstraction': abstraction.name,
              'implementation_count': '$count',
            },
          ),
        );
      }
    }
    return findings;
  }
}

/// Internal representation of a discovered abstraction.
final class _AbstractionInfo {
  const _AbstractionInfo({
    required this.name,
    required this.filePath,
    required this.line,
  });

  final String name;
  final String filePath;
  final int line;
}
