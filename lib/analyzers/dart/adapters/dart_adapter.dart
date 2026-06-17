import 'dart:io';
import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/token.dart';
import 'package:vetro/analyzers/dart/ast_utils.dart' as ast_utils;
import 'package:vetro/analyzers/dart/adapters/dart_cohesion.dart';
import 'package:vetro/analyzers/dart/adapters/dart_complexity.dart';
import 'package:vetro/analyzers/dart/adapters/dart_entropy.dart';
import 'package:vetro/analyzers/dart/adapters/dart_similarity.dart';
import 'package:vetro/analyzers/dart/adapters/dart_halstead.dart';
import 'package:vetro/core/metrics/entropy.dart';
import 'package:vetro/core/models/context.dart';

/// Adapter that translates Dart compilation units (AST) into unified FileContexts.
final class DartAdapter {
  const DartAdapter();

  /// Maps a parsed Dart AST [unit] to a language-agnostic [FileContext].
  FileContext adapt(CompilationUnit unit, String filePath, String source) {
    final functions = <FunctionContext>[];
    final classes = <ClassContext>[];
    final imports = <ImportEdge>[];

    // 1. Map top-level functions.
    for (final fn in ast_utils.extractTopLevelFunctions(unit)) {
      functions.add(_mapFunction(fn, fn.name.lexeme, unit, source));
    }

    // 2. Map classes.
    for (final cls in ast_utils.extractClasses(unit)) {
      final classMethods = <FunctionContext>[];
      final methodVocabularies = <Set<String>>[];

      for (final member in cls.members) {
        if (member is MethodDeclaration) {
          final methodName = '${cls.name.lexeme}.${member.name.lexeme}';
          classMethods.add(_mapFunction(member, methodName, unit, source));

          final collector = IdentifierCollector();
          member.accept(collector);
          methodVocabularies.add(collector.identifiers);
        }
      }

      final startLine = unit.lineInfo.getLocation(cls.offset).lineNumber;
      classes.add(
        ClassContext(
          name: cls.name.lexeme,
          startLine: startLine,
          methodVocabularies: methodVocabularies,
          methods: classMethods,
        ),
      );
    }

    // 3. Map imports.
    final projectRoot = ast_utils.findProjectRoot(filePath);
    final packageName = projectRoot != null ? (ast_utils.getPackageName(projectRoot) ?? '') : '';

    for (final directive in unit.directives.whereType<ImportDirective>()) {
      final importUri = directive.uri.stringValue;
      if (importUri != null) {
        final line = unit.lineInfo.getLocation(directive.offset).lineNumber;
        final resolvedPath = projectRoot != null
            ? ast_utils.resolveImport(importUri, filePath, projectRoot, packageName)
            : null;
        imports.add(
          ImportEdge(
            fromPath: filePath,
            targetUri: importUri,
            resolvedPath: resolvedPath,
            line: line,
            importString: directive.toString().trim(),
          ),
        );
      }
    }

    return FileContext(
      filePath: filePath,
      sourceCode: source,
      functions: functions,
      classes: classes,
      imports: imports,
      nativeAst: unit,
    );
  }

  FunctionContext _mapFunction(
    AstNode node,
    String displayName,
    CompilationUnit unit,
    String source,
  ) {
    final startLoc = unit.lineInfo.getLocation(node.offset);
    final endLoc = unit.lineInfo.getLocation(node.end);

    final fnSource = source.substring(node.offset, node.end);

    // Pre-calculate structural and raw tokens.
    final structuralTokens = tokenizeAst(node);
    final rawTokens = tokenizeRaw(node);

    // Pre-calculate complexity.
    final cc = cyclomaticComplexity(node);
    final cognitive = cognitiveComplexity(node);

    // Pre-calculate entropy.
    final shannon = shannonEntropy(node);
    final ident = identifierEntropy(node);

    // Pre-calculate comment intent.
    // Scan the preceding comments of the node as well as the body comments.
    var commentText = '';
    var comment = node.beginToken.precedingComments;
    while (comment != null) {
      commentText += '${comment.lexeme}\n';
      comment = comment.next as CommentToken?;
    }
    commentText += fnSource;

    final intentRatio = commentIntentRatio(commentText);

    final halstead = halsteadMetrics(node);

    return FunctionContext(
      name: displayName,
      startLine: startLoc.lineNumber,
      endLine: endLoc.lineNumber,
      structuralTokens: structuralTokens,
      rawTokens: rawTokens,
      nodeCount: ast_utils.nodeCount(node),
      cyclomaticComplexity: cc,
      cognitiveComplexity: cognitive,
      commentIntentRatio: intentRatio,
      shannonEntropy: shannon,
      identifierEntropy: ident,
      halsteadStats: halstead,
    );
  }
}
