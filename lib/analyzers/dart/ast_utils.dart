/// Helper functions for Dart AST navigation and extraction.
///
/// Provides convenient accessors over `package:analyzer` AST nodes,
/// abstracting the visitor pattern into simple list-returning functions.
/// All functions are pure — no side effects, no IO.
library;

import 'dart:io';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:path/path.dart' as p;

/// Extracts all top-level function declarations from a [CompilationUnit].
///
/// Returns functions declared at the top level of the file,
/// excluding methods inside classes.
List<FunctionDeclaration> extractTopLevelFunctions(CompilationUnit unit) =>
    unit.declarations.whereType<FunctionDeclaration>().toList();

/// Extracts all method declarations from all classes in a [CompilationUnit].
///
/// Traverses every class declaration and collects their method members.
List<MethodDeclaration> extractMethods(CompilationUnit unit) {
  final methods = <MethodDeclaration>[];
  for (final cls in extractClasses(unit)) {
    methods.addAll(cls.members.whereType<MethodDeclaration>());
  }
  return methods;
}

/// Extracts all class declarations from a [CompilationUnit].
List<ClassDeclaration> extractClasses(CompilationUnit unit) =>
    unit.declarations.whereType<ClassDeclaration>().toList();

/// Extracts all import URIs from a [CompilationUnit].
///
/// Returns the string value of each import directive's URI
/// (e.g., `'package:analyzer/dart/ast/ast.dart'`).
List<String> extractImports(CompilationUnit unit) => unit.directives
    .whereType<ImportDirective>()
    .map((d) => d.uri.stringValue)
    .whereType<String>()
    .toList();

/// Returns `true` if [cls] has the `abstract` keyword.
bool isAbstractClass(ClassDeclaration cls) => cls.abstractKeyword != null;

/// Returns `true` if [filePath] ends with `_test.dart`.
///
/// This is the standard Dart convention for test files.
bool isTestFile(String filePath) => filePath.endsWith('_test.dart');

/// Counts the number of lines in [source].
///
/// An empty string has 0 lines. A string with no newlines has 1 line.
int lineCount(String source) {
  if (source.isEmpty) return 0;
  var count = 1;
  for (var i = 0; i < source.length; i++) {
    if (source.codeUnitAt(i) == 0x0A) count++;
  }
  return count;
}

/// Extracts all function and method bodies as a list of
/// `(name, filePath, line, bodyNode)` tuples.
///
/// Useful for cross-file comparison rules that need to iterate
/// all callable bodies in a project.
List<FunctionBodyInfo> extractAllBodies(
  CompilationUnit unit,
  String filePath,
) {
  final visitor = _BodyExtractorVisitor(filePath);
  unit.accept(visitor);
  return visitor.bodies;
}

/// Information about a function/method body extracted from the AST.
final class FunctionBodyInfo {
  const FunctionBodyInfo({
    required this.name,
    required this.filePath,
    required this.line,
    required this.body,
    required this.declaration,
  });

  /// The function or method name.
  final String name;

  /// The file containing this function.
  final String filePath;

  /// 1-based line number of the function declaration.
  final int line;

  /// The AST node of the function body.
  final FunctionBody body;

  /// The parent declaration node.
  final Declaration declaration;
}

/// Visitor that extracts function and method bodies.
final class _BodyExtractorVisitor extends RecursiveAstVisitor<void> {
  _BodyExtractorVisitor(this.filePath);

  final String filePath;
  final List<FunctionBodyInfo> bodies = [];

  @override
  void visitFunctionDeclaration(FunctionDeclaration node) {
    final body = node.functionExpression.body;
    final line = _lineOf(node);
    bodies.add(
      FunctionBodyInfo(
        name: node.name.lexeme,
        filePath: filePath,
        line: line,
        body: body,
        declaration: node,
      ),
    );
    super.visitFunctionDeclaration(node);
  }

  @override
  void visitMethodDeclaration(MethodDeclaration node) {
    final body = node.body;
    final line = _lineOf(node);
    final className = node.parent is ClassDeclaration
        ? (node.parent! as ClassDeclaration).name.lexeme
        : '';
    final qualifiedName =
        className.isEmpty ? node.name.lexeme : '$className.${node.name.lexeme}';
    bodies.add(
      FunctionBodyInfo(
        name: qualifiedName,
        filePath: filePath,
        line: line,
        body: body,
        declaration: node,
      ),
    );
    super.visitMethodDeclaration(node);
  }

  int _lineOf(AstNode node) {
    final unit = node.root as CompilationUnit;
    return unit.lineInfo.getLocation(node.offset).lineNumber;
  }
}

/// Counts the total number of AST nodes in a subtree.
///
/// We do this because rules need to determine if a function body is
/// non-trivial (e.g. contains enough nodes to warrant structural analysis).
int nodeCount(AstNode node) {
  final visitor = _NodeCountVisitor();
  node.accept(visitor);
  return visitor.count;
}

/// Visitor that counts all AST nodes under a subtree.
final class _NodeCountVisitor extends GeneralizingAstVisitor<void> {
  int count = 0;

  @override
  void visitNode(AstNode node) {
    count++;
    super.visitNode(node);
  }
}

/// Checks if the given function/method name matches typical Flutter/Widget boilerplate.
///
/// This helps filter out declarative UI definitions (like build, initState, etc.)
/// which naturally share high structural similarity across standard widgets.
bool isFlutterBoilerplate(String name) {
  final parts = name.split('.');
  final methodName = parts.last.toLowerCase();
  return methodName == 'build' ||
      methodName.startsWith('build') ||
      methodName.startsWith('_build') ||
      methodName == 'dispose' ||
      methodName == 'initstate' ||
      methodName == 'createstate';
}

/// Checks if a [Declaration] node is a boilerplate method or function.
///
/// Filters out declarations annotated with `@override` (when they are simple
/// getters/setters or delegate calls) or annotated with `@riverpod` / `@Riverpod`.
bool isBoilerplateDeclaration(Declaration node) {
  for (final annotation in node.metadata) {
    final name = annotation.name.name;
    if (name == 'riverpod' || name == 'Riverpod') {
      return true;
    }
    if (name == 'override') {
      final body = node is MethodDeclaration
          ? node.body
          : (node is FunctionDeclaration ? node.functionExpression.body : null);
      if (body != null) {
        if (nodeCount(body) < 25) {
          return true;
        }
      } else {
        return true;
      }
    }
  }
  return false;
}

/// Creates a canonical key for a function pair to prevent duplicates in reports.
///
/// The key is order-independent: canonicalKey(A, B) == canonicalKey(B, A).
String canonicalKey(FunctionBodyInfo a, FunctionBodyInfo b) {
  final keyA = '${a.filePath}:${a.line}:${a.name}';
  final keyB = '${b.filePath}:${b.line}:${b.name}';
  return keyA.compareTo(keyB) < 0 ? '$keyA|$keyB' : '$keyB|$keyA';
}

/// A unified representation of a function or method declaration.
final class DeclarationInfo {
  const DeclarationInfo({
    required this.node,
    required this.name,
    required this.body,
  });

  /// The AST node representing the declaration (either [FunctionDeclaration] or [MethodDeclaration]).
  final AstNode node;

  /// The name of the function or method.
  final String name;

  /// The body of the function or method, or null if it does not have one (e.g., abstract methods).
  final FunctionBody? body;
}

/// Extracts all top-level function declarations and class/mixin methods from a [CompilationUnit].
///
/// We unify them into a list of [DeclarationInfo] because most analysis rules need to
/// iterate over both functions and methods identically.
List<DeclarationInfo> extractDeclarations(CompilationUnit unit) {
  final declarations = <DeclarationInfo>[];
  
  // Check top-level functions
  for (final fn in extractTopLevelFunctions(unit)) {
    declarations.add(
      DeclarationInfo(
        node: fn,
        name: fn.name.lexeme,
        body: fn.functionExpression.body,
      ),
    );
  }

  // Check methods inside classes
  for (final method in extractMethods(unit)) {
    declarations.add(
      DeclarationInfo(
        node: method,
        name: method.name.lexeme,
        body: method.body,
      ),
    );
  }

  return declarations;
}

/// Finds the project root directory containing a `pubspec.yaml` by scanning upwards from [filePath].
///
/// We do this because cross-file rules need to locate the project's pubspec to
/// resolve package imports and locate project assets.
String? findProjectRoot(String filePath) {
  var dir = p.dirname(filePath);
  while (dir != p.rootPrefix(dir)) {
    final pubspec = File(p.join(dir, 'pubspec.yaml'));
    if (pubspec.existsSync()) {
      return dir;
    }
    dir = p.dirname(dir);
  }
  return null;
}

/// Reads the package name from `pubspec.yaml` in the [projectRoot].
///
/// We do this because package imports (e.g. package:vetro/...) start with
/// the project name, and we need this name to resolve them to file paths.
String? getPackageName(String projectRoot) {
  try {
    final pubspec = File(p.join(projectRoot, 'pubspec.yaml'));
    if (pubspec.existsSync()) {
      final content = pubspec.readAsStringSync();
      final match = RegExp(r'^name:\s*([a-zA-Z0-9_]+)', multiLine: true).firstMatch(content);
      return match?.group(1);
    }
  } catch (_) {}
  return null;
}

/// Resolves an [importUri] to its absolute file path, returning null if it is external.
///
/// We do this because we need to build a file-level dependency graph, which requires
/// mapping internal relative and package imports to their actual file paths.
String? resolveImport(
  String importUri,
  String currentFilePath,
  String projectRoot,
  String packageName,
) {
  // Skip Dart core library imports.
  if (importUri.startsWith('dart:')) return null;

  // Resolve package imports within this project.
  if (importUri.startsWith('package:')) {
    final prefix = 'package:$packageName/';
    if (importUri.startsWith(prefix)) {
      final relativePart = importUri.substring(prefix.length);
      return p.normalize(p.join(projectRoot, 'lib', relativePart));
    }
    return null;
  }

  // Resolve relative imports.
  return p.normalize(p.join(p.dirname(currentFilePath), importUri));
}
