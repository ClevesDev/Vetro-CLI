import 'dart:math' as math;
import 'package:path/path.dart' as p;
import 'package:vetro/core/models/context.dart';
import 'package:vetro/core/models/ts_node.dart';
import 'package:vetro/analyzers/typescript/adapters/typescript_halstead.dart';

final class TsAdapter {
  final Set<String> allFiles;

  const TsAdapter({required this.allFiles});

  FileContext adapt(TsNode root, String filePath, String source) {
    final functions = <FunctionContext>[];
    final classes = <ClassContext>[];
    final imports = <ImportEdge>[];

    // Get all comments from root
    final commentsList = root.raw['comments'];
    final comments = <Map<String, dynamic>>[];
    if (commentsList is List) {
      for (final c in commentsList) {
        if (c is Map<String, dynamic>) {
          comments.add(c);
        }
      }
    }

    // 1. Extract classes and their methods
    final classNodes = root.descendentNodes((node) => node.type == 'ClassDeclaration');
    final classMethodStarts = <int>{};

    for (final cls in classNodes) {
      final classMethods = <FunctionContext>[];
      final methodVocabularies = <Set<String>>[];

      final methods = cls.descendentNodes((node) => const {
            'ClassMethod',
          }.contains(node.type));

      for (final method in methods) {
        classMethodStarts.add(method.start);
        final methodName = '${_getClassName(cls)}.${_getFunctionName(method, root)}';
        classMethods.add(_mapFunction(method, methodName, root, source, comments));

        methodVocabularies.add(_extractMethodIdentifiers(method));
      }

      classes.add(
        ClassContext(
          name: _getClassName(cls),
          startLine: cls.line,
          methodVocabularies: methodVocabularies,
          methods: classMethods,
        ),
      );
    }

    // 2. Extract non-class-method functions (top-level and other functions)
    final functionNodes = root.descendentNodes((node) => const {
          'FunctionDeclaration',
          'FunctionExpression',
          'ArrowFunctionExpression',
          'ObjectMethod',
          'ClassMethod',
        }.contains(node.type));

    for (final fn in functionNodes) {
      // Avoid mapping class methods again here
      if (classMethodStarts.contains(fn.start)) continue;

      final fnName = _getFunctionName(fn, root);
      functions.add(_mapFunction(fn, fnName, root, source, comments));
    }

    // 3. Extract imports and resolve them
    final importNodes = root.descendentNodes((node) => const {
          'ImportDeclaration',
          'ExportNamedDeclaration',
          'ExportAllDeclaration',
        }.contains(node.type));

    for (final node in importNodes) {
      final sourceVal = node.raw['source'];
      if (sourceVal is Map && sourceVal['value'] is String) {
        final importUri = sourceVal['value'] as String;
        final resolvedPath = _resolveImport(importUri, filePath);
        final importString = (node.start >= 0 && node.end <= source.length && node.start <= node.end)
            ? source.substring(node.start, node.end)
            : '';
        imports.add(
          ImportEdge(
            fromPath: filePath,
            targetUri: importUri,
            resolvedPath: resolvedPath,
            line: node.line,
            importString: importString,
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
      nativeAst: root,
    );
  }

  FunctionContext _mapFunction(
    TsNode fnNode,
    String displayName,
    TsNode root,
    String source,
    List<Map<String, dynamic>> comments,
  ) {
    // Find the body/block of the function to count nodes & compute metrics
    final bodyNode = fnNode.children.firstWhere(
      (child) => const {'BlockStatement', 'ClassBody'}.contains(child.type) ||
          fnNode.type == 'ArrowFunctionExpression',
      orElse: () => fnNode,
    );

    final fnSource = (fnNode.start >= 0 && fnNode.end <= source.length && fnNode.start <= fnNode.end)
        ? source.substring(fnNode.start, fnNode.end)
        : '';

    // Precalculate structural tokens and raw tokens.
    final structuralTokens = bodyNode.extractNodeTypes();
    final rawTokens = _tokenizeRawString(fnSource);

    // Precalculate complexity.
    final cc = _computeCyclomaticComplexity(fnNode);
    final cognitive = _computeCognitiveComplexity(fnNode);

    // Precalculate entropy.
    final shannon = _computeShannonEntropy(bodyNode);
    final ident = _computeIdentifierEntropy(bodyNode);

    // Precalculate comment intent.
    final hasIntent = _hasIntentComment(fnNode, comments);
    final intentRatio = hasIntent ? 1.0 : 0.0;

    // Precalculate Halstead stats.
    final halstead = computeTsHalstead(rawTokens);

    // Estimate endLine
    // Since we don't have direct endLine from Babel easily, we can find line count of source:
    final lines = fnSource.split('\n');
    final endLine = fnNode.line + lines.length - 1;

    return FunctionContext(
      name: displayName,
      startLine: fnNode.line,
      endLine: endLine,
      structuralTokens: structuralTokens,
      rawTokens: rawTokens,
      nodeCount: _countNodes(bodyNode),
      cyclomaticComplexity: cc,
      cognitiveComplexity: cognitive,
      commentIntentRatio: intentRatio,
      shannonEntropy: shannon,
      identifierEntropy: ident,
      halsteadStats: halstead,
    );
  }

  int _countNodes(TsNode node) {
    var count = 1;
    for (final child in node.children) {
      count += _countNodes(child);
    }
    return count;
  }

  List<String> _tokenizeRawString(String source) {
    final regExp = RegExp(r'[a-zA-Z_][a-zA-Z0-9_]*|\d+|[+\-*/%=<>!&|^~]+|[{}[\]().,;]');
    return regExp.allMatches(source).map((m) => m.group(0)!).toList();
  }

  int _computeCyclomaticComplexity(TsNode fnNode) {
    var decisionPoints = 0;

    void count(TsNode node) {
      if (node != fnNode &&
          const {
            'FunctionDeclaration',
            'FunctionExpression',
            'ArrowFunctionExpression',
            'ClassMethod',
            'ObjectMethod',
          }.contains(node.type)) {
        return;
      }

      if (const {
        'IfStatement',
        'ForStatement',
        'ForInStatement',
        'ForOfStatement',
        'WhileStatement',
        'DoWhileStatement',
        'CatchClause',
        'ConditionalExpression',
      }.contains(node.type)) {
        decisionPoints++;
      }

      if (node.type == 'LogicalExpression') {
        final op = node.raw['operator']?.toString();
        if (op == '&&' || op == '||' || op == '??') {
          decisionPoints++;
        }
      }

      if (node.type == 'SwitchCase') {
        final test = node.raw['test'];
        if (test != null) {
          decisionPoints++;
        }
      }

      for (final child in node.children) {
        count(child);
      }
    }

    final bodyNode = fnNode.children.firstWhere(
      (child) => const {'BlockStatement', 'ClassBody'}.contains(child.type) ||
          fnNode.type == 'ArrowFunctionExpression',
      orElse: () => fnNode,
    );

    count(bodyNode);
    return 1 + decisionPoints;
  }

  int _computeCognitiveComplexity(TsNode fnNode) {
    var complexity = 0;

    void visit(TsNode node, TsNode? parent, int nestingLevel, String? parentLogicalOp) {
      if (node != fnNode &&
          const {
            'FunctionDeclaration',
            'FunctionExpression',
            'ArrowFunctionExpression',
            'ClassMethod',
            'ObjectMethod',
          }.contains(node.type)) {
        return;
      }

      var currentNesting = nestingLevel;
      var currentLogicalOp = parentLogicalOp;

      if (node.type == 'IfStatement') {
        final isElseIf = parent != null &&
            parent.type == 'IfStatement' &&
            parent.raw['alternate'] is Map &&
            node.start == (parent.raw['alternate'] as Map)['start'];

        if (isElseIf) {
          complexity += 1;
        } else {
          complexity += 1 + nestingLevel;
        }
        currentNesting = nestingLevel + 1;
        currentLogicalOp = null;
      } else if (const {'ForStatement', 'ForInStatement', 'ForOfStatement'}
          .contains(node.type)) {
        complexity += 1 + nestingLevel;
        currentNesting = nestingLevel + 1;
        currentLogicalOp = null;
      } else if (const {'WhileStatement', 'DoWhileStatement'}
          .contains(node.type)) {
        complexity += 1 + nestingLevel;
        currentNesting = nestingLevel + 1;
        currentLogicalOp = null;
      } else if (node.type == 'SwitchStatement') {
        complexity += 1;
        currentNesting = nestingLevel + 1;
        currentLogicalOp = null;
      } else if (node.type == 'CatchClause') {
        complexity += 1 + nestingLevel;
        currentNesting = nestingLevel + 1;
        currentLogicalOp = null;
      } else if (node.type == 'ConditionalExpression') {
        complexity += 1 + nestingLevel;
        currentNesting = nestingLevel + 1;
        currentLogicalOp = null;
      } else if (node.type == 'LogicalExpression') {
        final op = node.raw['operator']?.toString();
        if (op == '&&' || op == '||' || op == '??') {
          if (parentLogicalOp != op) {
            complexity += 1;
          }
          currentLogicalOp = op;
        }
      }

      for (final child in node.children) {
        visit(child, node, currentNesting, currentLogicalOp);
      }
    }

    final bodyNode = fnNode.children.firstWhere(
      (child) => const {'BlockStatement', 'ClassBody'}.contains(child.type) ||
          fnNode.type == 'ArrowFunctionExpression',
      orElse: () => fnNode,
    );

    visit(bodyNode, fnNode, 0, null);
    return complexity;
  }

  double _computeShannonEntropy(TsNode rootNode) {
    final counts = <String, int>{};
    var total = 0;

    void count(TsNode n) {
      counts[n.type] = (counts[n.type] ?? 0) + 1;
      total++;
      for (final child in n.children) {
        count(child);
      }
    }

    count(rootNode);
    if (total == 0) return 0.0;

    var entropy = 0.0;
    for (final countVal in counts.values) {
      final p = countVal / total;
      entropy -= p * (math.log(p) / math.log(2));
    }
    return entropy;
  }

  double _computeIdentifierEntropy(TsNode rootNode) {
    final counts = <String, int>{};
    var total = 0;

    const keywords = {
      'break', 'case', 'catch', 'class', 'const', 'continue', 'debugger',
      'default', 'delete', 'do', 'else', 'export', 'extends', 'false',
      'finally', 'for', 'function', 'if', 'import', 'in', 'instanceof',
      'new', 'null', 'return', 'super', 'switch', 'this', 'throw', 'true',
      'try', 'typeof', 'var', 'void', 'while', 'with', 'yield',
      'let', 'package', 'private', 'protected', 'public', 'static',
      'any', 'boolean', 'constructor', 'declare', 'get', 'module',
      'require', 'number', 'readonly', 'set', 'string', 'symbol',
      'type', 'from', 'of', 'as', 'keyof', 'is'
    };

    void count(TsNode n) {
      if (n.type == 'Identifier') {
        final name = n.raw['name']?.toString();
        if (name != null && name.isNotEmpty && !keywords.contains(name)) {
          counts[name] = (counts[name] ?? 0) + 1;
          total++;
        }
      }
      for (final child in n.children) {
        count(child);
      }
    }

    count(rootNode);
    if (total == 0) return 0.0;

    var entropy = 0.0;
    for (final countVal in counts.values) {
      final p = countVal / total;
      entropy -= p * (math.log(p) / math.log(2));
    }
    return entropy;
  }

  bool _hasIntentComment(TsNode fnNode, List<Map<String, dynamic>> comments) {
    const intentKeywords = {
      'why', 'because', 'reason', 'purpose', 'intent',
      'rationale', 'note', 'important', 'hack', 'workaround', 'todo'
    };

    for (final comment in comments) {
      final start = comment['start'] is int ? comment['start'] as int : 0;
      final end = comment['end'] is int ? comment['end'] as int : 0;
      final value = comment['value']?.toString() ?? '';

      final isPreceding = end <= fnNode.start && end >= fnNode.start - 200;
      final isInline = start >= fnNode.start && end <= fnNode.end;

      if (isPreceding || isInline) {
        final lower = value.toLowerCase();
        for (final kw in intentKeywords) {
          if (lower.contains(kw)) {
            return true;
          }
        }
      }
    }
    return false;
  }

  Set<String> _extractMethodIdentifiers(TsNode methodNode) {
    final counts = <String>{};
    const keywords = {
      'break', 'case', 'catch', 'class', 'const', 'continue', 'debugger',
      'default', 'delete', 'do', 'else', 'export', 'extends', 'false',
      'finally', 'for', 'function', 'if', 'import', 'in', 'instanceof',
      'new', 'null', 'return', 'super', 'switch', 'this', 'throw', 'true',
      'try', 'typeof', 'var', 'void', 'while', 'with', 'yield',
      'let', 'package', 'private', 'protected', 'public', 'static',
      'any', 'boolean', 'constructor', 'declare', 'get', 'module',
      'require', 'number', 'readonly', 'set', 'string', 'symbol',
      'type', 'from', 'of', 'as', 'keyof', 'is'
    };

    void collect(TsNode n) {
      if (n.type == 'Identifier') {
        final name = n.raw['name']?.toString();
        if (name != null && name.isNotEmpty && !keywords.contains(name)) {
          counts.add(name);
        }
      }
      for (final child in n.children) {
        collect(child);
      }
    }

    collect(methodNode);
    return counts;
  }

  String _getFunctionName(TsNode fnNode, TsNode root) {
    if (fnNode.type == 'FunctionDeclaration') {
      final idMap = fnNode.raw['id'];
      if (idMap is Map && idMap['name'] != null) {
        return idMap['name'].toString();
      }
    } else if (fnNode.type == 'ClassMethod' || fnNode.type == 'ObjectMethod') {
      final keyMap = fnNode.raw['key'];
      if (keyMap is Map && keyMap['name'] != null) {
        return keyMap['name'].toString();
      }
    }

    final declarator = root.descendentNodes((node) =>
        node.type == 'VariableDeclarator' &&
        node.children.any((c) => c.start == fnNode.start && c.end == fnNode.end));

    if (declarator.isNotEmpty) {
      final idMap = declarator.first.raw['id'];
      if (idMap is Map && idMap['name'] != null) {
        return idMap['name'].toString();
      }
    }

    return 'anonymous';
  }

  String _getClassName(TsNode classNode) {
    final idMap = classNode.raw['id'];
    if (idMap is Map && idMap['name'] != null) {
      return idMap['name'].toString();
    }
    return 'anonymous';
  }

  String? _resolveImport(String importUri, String filePath) {
    if (!importUri.startsWith('.') && !importUri.startsWith('/')) {
      return null;
    }

    final dir = p.dirname(filePath);
    final targetPath = p.normalize(p.join(dir, importUri));

    final candidates = [
      targetPath,
      '$targetPath.ts',
      '$targetPath.tsx',
      p.join(targetPath, 'index.ts'),
      p.join(targetPath, 'index.tsx'),
    ];

    for (final candidate in candidates) {
      if (allFiles.contains(candidate)) {
        return candidate;
      }
    }
    return null;
  }
}
