/// Rule: Copy-Mutate — detects copy-paste-modify code patterns.
///
/// **Mathematical basis**: Structural similarity via AST comparison.
///
/// For each pair of function bodies (A, B) in the project:
///   similarity(A, B) = 2 × LCS(types(A), types(B)) / (|types(A)| + |types(B)|)
///
/// where types() flattens AST nodes into their runtime type labels,
/// and LCS is the Longest Common Subsequence length.
///
/// This is the Sørensen–Dice coefficient on ordered AST sequences.
///
/// Report when similarity ≥ threshold (default 0.70) and the two
/// functions are not the exact same function.
///
/// This detects the classic AI pattern: generate a function, copy it,
/// tweak a few lines for a variant case.
library;

import 'dart:io';
import 'dart:isolate';

import 'package:analyzer/dart/ast/ast.dart';

import 'package:vetro/analyzers/dart/ast_utils.dart';
import 'package:vetro/core/metrics/similarity.dart';
import 'package:vetro/core/models/finding.dart';
import 'package:vetro/core/rules/rule.dart';

/// Detects pairs of functions whose AST structure is highly similar,
/// indicating copy-paste-modify patterns.
///
/// **Threshold**: `similarity` (default 0.70).
///
/// Evidence includes the similarity percentage and both locations.
final class CopyMutateRule extends CrossFileRule {
  /// Creates a [CopyMutateRule] with the given [config].
  const CopyMutateRule({required super.config});

  @override
  String get id => 'copy_mutate';

  @override
  String get name => 'Copy-Mutate Pattern';

  @override
  String get description =>
      'Detects functions with high structural similarity, '
      'indicating copy-paste-modify patterns.';

  /// Minimum number of AST nodes in a function body to consider it
  /// for comparison. Trivial functions (getters, one-liners, simple providers) are skipped.
  static const _minBodyNodes = 40;

  @override
  Future<List<Finding>> analyzeProject(
    Map<String, CompilationUnit> units,
    Map<String, String> sources,
  ) async {
    final threshold =
        config.threshold('similarity', defaultValue: 0.70);

    // Collect, pre-filter, and cache all function/method bodies across the project.
    final cachedBodies = <_BodyAnalysisCache>[];
    for (final entry in units.entries) {
      final bodies = extractAllBodies(entry.value, entry.key);
      for (final b in bodies) {
        if (b.body is EmptyFunctionBody ||
            b.body is NativeFunctionBody ||
            isFlutterBoilerplate(b.name) ||
            isBoilerplateDeclaration(b.declaration)) {
          continue;
        }
        if (nodeCount(b.body) < _minBodyNodes) {
          continue;
        }
        final tokens = tokenizeRaw(b.body);
        cachedBodies.add(_BodyAnalysisCache(b, tokens));
      }
    }

    // Compare all pairs.
    // If the workload is small, run sequentially to avoid Isolate spawn overhead.
    if (cachedBodies.length < 100) {
      return _compareCopyMutateSequential(cachedBodies, threshold);
    }

    final numWorkers = Platform.numberOfProcessors;
    final futures = <Future<List<Finding>>>[];

    for (var k = 0; k < numWorkers; k++) {
      futures.add(
        Isolate.run(
          () => _compareCopyMutateChunk({
            'cachedBodies': cachedBodies,
            'threshold': threshold,
            'workerId': k,
            'numWorkers': numWorkers,
            'ruleId': id,
            'ruleName': name,
            'severity': severity,
          }),
        ),
      );
    }

    final results = await Future.wait(futures);
    final allFindings = <Finding>[];
    for (final findings in results) {
      allFindings.addAll(findings);
    }
    return allFindings;
  }

  /// Sequential fallback for comparison.
  List<Finding> _compareCopyMutateSequential(
    List<_BodyAnalysisCache> cachedBodies,
    double threshold,
  ) {
    final findings = <Finding>[];
    final reported = <String>{};

    for (var i = 0; i < cachedBodies.length; i++) {
      for (var j = i + 1; j < cachedBodies.length; j++) {
        final a = cachedBodies[i];
        final b = cachedBodies[j];

        final sim = cosineSimilarity(a.rawTokens, b.rawTokens);

        if (sim >= threshold) {
          final key = canonicalKey(a.info, b.info);
          if (reported.contains(key)) continue;
          reported.add(key);

          final percentage = (sim * 100).toStringAsFixed(1);
          findings.add(
            Finding(
              ruleId: id,
              ruleName: name,
              severity: severity,
              filePath: a.info.filePath,
              line: a.info.line,
              message: 'Function "${a.info.name}" is $percentage% structurally '
                  'similar to "${b.info.name}" at ${b.info.filePath}:${b.info.line}.',
              evidence: {
                'similarity': '$percentage%',
                'function_a': '${a.info.filePath}:${a.info.line} (${a.info.name})',
                'function_b': '${b.info.filePath}:${b.info.line} (${b.info.name})',
              },
            ),
          );
        }
      }
    }
    return findings;
  }

  /// Parallel comparison worker.
  static List<Finding> _compareCopyMutateChunk(Map<String, dynamic> args) {
    final cachedBodies = args['cachedBodies'] as List<_BodyAnalysisCache>;
    final threshold = args['threshold'] as double;
    final workerId = args['workerId'] as int;
    final numWorkers = args['numWorkers'] as int;
    final ruleId = args['ruleId'] as String;
    final ruleName = args['ruleName'] as String;
    final severity = args['severity'] as Severity;

    final findings = <Finding>[];
    final reported = <String>{};

    for (var i = workerId; i < cachedBodies.length; i += numWorkers) {
      for (var j = i + 1; j < cachedBodies.length; j++) {
        final a = cachedBodies[i];
        final b = cachedBodies[j];

        final sim = cosineSimilarity(a.rawTokens, b.rawTokens);

        if (sim >= threshold) {
          final key = canonicalKey(a.info, b.info);
          if (reported.contains(key)) continue;
          reported.add(key);

          final percentage = (sim * 100).toStringAsFixed(1);
          findings.add(
            Finding(
              ruleId: ruleId,
              ruleName: ruleName,
              severity: severity,
              filePath: a.info.filePath,
              line: a.info.line,
              message: 'Function "${a.info.name}" is $percentage% structurally '
                  'similar to "${b.info.name}" at ${b.info.filePath}:${b.info.line}.',
              evidence: {
                'similarity': '$percentage%',
                'function_a': '${a.info.filePath}:${a.info.line} (${a.info.name})',
                'function_b': '${b.info.filePath}:${b.info.line} (${b.info.name})',
              },
            ),
          );
        }
      }
    }
    return findings;
  }
}

/// Helper container holding precomputed properties of a function body for fast comparison.
final class _BodyAnalysisCache {
  final FunctionBodyInfo info;
  final List<String> rawTokens;

  const _BodyAnalysisCache(this.info, this.rawTokens);
}

