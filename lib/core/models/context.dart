/// Unified representation of code elements (files, classes, functions)
/// across different programming languages for Vetro rules.
library;

/// Represents the context of an individual function or method.
final class FunctionContext {
  final String name;
  final int startLine;
  final int endLine;

  /// Structural tokens normalized (e.g. variable/method names replaced by '_id_').
  final List<String> structuralTokens;

  /// Raw tokens (preserving original lexemes for copy-mutate analysis).
  final List<String> rawTokens;

  /// Total number of syntactic nodes in this function's subtree.
  final int nodeCount;

  /// Complexity metrics pre-computed by the language adapter.
  final int cyclomaticComplexity;
  final int cognitiveComplexity;

  /// Ratio of explaining comments inside or preceding the function.
  final double commentIntentRatio;

  /// AST node type Shannon entropy.
  final double shannonEntropy;

  /// User-defined identifier Shannon entropy.
  final double identifierEntropy;

  const FunctionContext({
    required this.name,
    required this.startLine,
    required this.endLine,
    required this.structuralTokens,
    required this.rawTokens,
    required this.nodeCount,
    required this.cyclomaticComplexity,
    required this.cognitiveComplexity,
    required this.commentIntentRatio,
    required this.shannonEntropy,
    required this.identifierEntropy,
  });
}

/// Represents the context of a class declaration.
final class ClassContext {
  final String name;
  final int startLine;

  /// Method-level vocabularies (identifiers used by each method in the class)
  /// used to compute class cohesion (LCOM).
  final List<Set<String>> methodVocabularies;

  /// Methods belonging to this class.
  final List<FunctionContext> methods;

  const ClassContext({
    required this.name,
    required this.startLine,
    required this.methodVocabularies,
    required this.methods,
  });
}

/// Represents an import dependency edge between files.
final class ImportEdge {
  final String fromPath;
  final String targetUri;
  final String? resolvedPath;
  final int line;
  final String importString;

  const ImportEdge({
    required this.fromPath,
    required this.targetUri,
    this.resolvedPath,
    required this.line,
    required this.importString,
  });
}

/// Represents the full context of a source file.
final class FileContext {
  final String filePath;
  final String sourceCode;

  /// Top-level functions (outside any class).
  final List<FunctionContext> functions;

  /// Classes defined inside this file.
  final List<ClassContext> classes;

  /// Imports declared in this file.
  final List<ImportEdge> imports;

  /// Opaque payload to temporarily store the native AST (e.g. CompilationUnit or TsNode)
  /// during incremental migration phases. Will be removed once all rules are migrated.
  final Object? nativeAst;

  const FileContext({
    required this.filePath,
    required this.sourceCode,
    required this.functions,
    required this.classes,
    required this.imports,
    this.nativeAst,
  });
}
