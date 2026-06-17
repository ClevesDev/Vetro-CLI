/// Rule: Semantic Duplication — detects structurally identical code
/// after normalizing identifiers and literals.
///
/// **Mathematical basis**: Normalized AST similarity via LCS.
///
/// For each pair of function bodies (A, B):
///   normalize(X) = replace all identifiers with 'ID', all literals with 'LIT'
///   similarity = 2 × LCS(normalize(A), normalize(B)) / (|A'| + |B'|)
///
/// This is the Sørensen–Dice coefficient on the normalized AST.
///
/// Report when similarity ≥ threshold (default 0.80).
///
/// Unlike the copy-mutate rule, this strips identifiers and literals
/// before comparison, detecting deeper semantic duplication even when
/// variable names have been completely renamed.
library;

import 'dart:io';
import 'dart:isolate';

import 'package:analyzer/dart/ast/ast.dart';

import 'package:vetro/analyzers/dart/ast_utils.dart';
import 'package:vetro/core/metrics/similarity.dart';
import 'package:vetro/core/adapters/dart/dart_similarity.dart';
import 'package:vetro/core/models/finding.dart';
import 'package:vetro/core/rules/rule.dart';

/// Detects pairs of functions whose normalized AST structure is
/// highly similar, indicating semantic duplication.
///
/// **Threshold**: `similarity` (default 0.80).
///
/// Evidence includes the similarity percentage, function names,
/// and both locations.
final class SemanticDuplicationRule extends CrossFileRule {
  /// Creates a [SemanticDuplicationRule] with the given [config].
  const SemanticDuplicationRule({required super.config});

  @override
  String get id => 'semantic_duplication';

  @override
  String get name => 'Semantic Duplication';

  @override
  String get description =>
      'Detects functions with high normalized structural similarity, '
      'indicating semantic duplication even with different names.';

  /// Minimum number of AST nodes to consider a body non-trivial.
  static const _minBodyNodes = 40;

  @override
  Future<List<Finding>> analyzeProject(
    Map<String, CompilationUnit> units,
    Map<String, String> sources,
  ) async {
    final threshold =
        config.threshold('similarity', defaultValue: 0.80);

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
        final tokens = tokenizeAst(b.body);
        final hash = fnv1a32(tokens);
        cachedBodies.add(_BodyAnalysisCache(b, tokens, hash));
      }
    }

    // Compare all pairs.
    // If the workload is small, run sequentially to avoid Isolate spawn overhead.
    if (cachedBodies.length < 100) {
      return _compareSemanticDuplicationSequential(cachedBodies, threshold);
    }

    final numWorkers = Platform.numberOfProcessors;
    final futures = <Future<List<Finding>>>[];

    for (var k = 0; k < numWorkers; k++) {
      futures.add(
        Isolate.run(
          () => _compareSemanticDuplicationChunk({
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
  List<Finding> _compareSemanticDuplicationSequential(
    List<_BodyAnalysisCache> cachedBodies,
    double threshold,
  ) {
    final findings = <Finding>[];
    final reported = <String>{};

    for (var i = 0; i < cachedBodies.length; i++) {
      for (var j = i + 1; j < cachedBodies.length; j++) {
        final a = cachedBodies[i];
        final b = cachedBodies[j];

        var sim = 0.0;
        if (a.astHash == b.astHash) {
          sim = 1.0;
        } else {
          final lenA = a.astTokens.length;
          final lenB = b.astTokens.length;
          final minLen = lenA < lenB ? lenA : lenB;
          final maxLen = lenA > lenB ? lenA : lenB;

          // Mathematical LCS Pruning
          if (minLen < maxLen * (threshold / (2.0 - threshold))) {
            continue;
          }

          sim = lcsSimilarity(a.astTokens, b.astTokens);
        }

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
              message: 'Function "${a.info.name}" is $percentage% semantically '
                  'similar to "${b.info.name}" at ${b.info.filePath}:${b.info.line}.',
              evidence: {
                'similarity': '$percentage%',
                'function_a': a.info.name,
                'function_b': b.info.name,
                'location_a': '${a.info.filePath}:${a.info.line}',
                'location_b': '${b.info.filePath}:${b.info.line}',
              },
            ),
          );
        }
      }
    }
    return findings;
  }

  /// Parallel comparison worker.
  static List<Finding> _compareSemanticDuplicationChunk(Map<String, dynamic> args) {
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

        var sim = 0.0;
        if (a.astHash == b.astHash) {
          sim = 1.0;
        } else {
          final lenA = a.astTokens.length;
          final lenB = b.astTokens.length;
          final minLen = lenA < lenB ? lenA : lenB;
          final maxLen = lenA > lenB ? lenA : lenB;

          // Mathematical LCS Pruning
          if (minLen < maxLen * (threshold / (2.0 - threshold))) {
            continue;
          }

          sim = lcsSimilarity(a.astTokens, b.astTokens);
        }

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
              message: 'Function "${a.info.name}" is $percentage% semantically '
                  'similar to "${b.info.name}" at ${b.info.filePath}:${b.info.line}.',
              evidence: {
                'similarity': '$percentage%',
                'function_a': a.info.name,
                'function_b': b.info.name,
                'location_a': '${a.info.filePath}:${a.info.line}',
                'location_b': '${b.info.filePath}:${b.info.line}',
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
  final List<String> astTokens;
  final String astHash;

  const _BodyAnalysisCache(this.info, this.astTokens, this.astHash);
}

