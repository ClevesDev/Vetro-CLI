import 'dart:math' as math;
import 'package:path/path.dart' as p;
import 'package:vetro/core/models/context.dart';
import 'package:vetro/core/models/py_node.dart';
import 'package:vetro/analyzers/python/adapters/python_halstead.dart';

final class PythonAdapter {
  final Set<String> allFiles;

  const PythonAdapter({required this.allFiles});

  FileContext adapt(PyNode root, String filePath, String source) {
    final functions = <FunctionContext>[];
    final classes = <ClassContext>[];
    final imports = <ImportEdge>[];

    // Get all comments from root
    final commentsList = root.raw['comments'];
    final comments = <Map<String, dynamic>>[];
    if (commentsList is List) {
      for (final c in commentsList) {
        if (c is Map) {
          comments.add(Map<String, dynamic>.from(c));
        }
      }
    }

    // 1. Extract classes and their methods
    final classNodes = root.descendentNodes((node) => node.type == 'ClassDef');
    final classMethodStarts = <int>{};

    for (final cls in classNodes) {
      final classMethods = <FunctionContext>[];
      final methodVocabularies = <Set<String>>[];

      // Extract only methods belonging directly to this class
      final methods = cls.children.where((node) => const {
            'FunctionDef',
            'AsyncFunctionDef',
          }.contains(node.type));

      for (final method in methods) {
        // En Python, una función anidada puede estar dentro de un método.
        // Para simplificar, si el padre de la función no es la clase, podría ser una función local.
        // Pero para el propósito de cohesión, todos los métodos declarados son válidos.
        classMethodStarts.add(method.start);
        final methodName = '${cls.raw['name']}.${method.raw['name']}';
        classMethods.add(_mapFunction(method, methodName, root, source, comments));

        methodVocabularies.add(_extractMethodIdentifiers(method));
      }

      classes.add(
        ClassContext(
          name: cls.raw['name']?.toString() ?? 'anonymous',
          startLine: cls.line,
          methodVocabularies: methodVocabularies,
          methods: classMethods,
        ),
      );
    }

    // 2. Extract top-level and standalone functions
    final functionNodes = root.children.where((node) => const {
          'FunctionDef',
          'AsyncFunctionDef',
        }.contains(node.type));

    for (final fn in functionNodes) {
      if (classMethodStarts.contains(fn.start)) continue;

      final fnName = fn.raw['name']?.toString() ?? 'anonymous';
      functions.add(_mapFunction(fn, fnName, root, source, comments));
    }

    // 3. Extract imports
    final importNodes = root.descendentNodes((node) => const {
          'Import',
          'ImportFrom',
        }.contains(node.type));

    for (final node in importNodes) {
      final line = node.line;
      final importString = (node.start >= 0 && node.end <= source.length && node.start <= node.end)
          ? source.substring(node.start, node.end)
          : '';

      if (node.type == 'Import') {
        final namesList = node.raw['names'];
        if (namesList is List) {
          for (final nameNode in namesList) {
            if (nameNode is Map) {
              final importUri = nameNode['name']?.toString() ?? '';
              final resolvedPath = _resolveImport(importUri, 0, filePath);
              imports.add(
                ImportEdge(
                  fromPath: filePath,
                  targetUri: importUri,
                  resolvedPath: resolvedPath,
                  line: line,
                  importString: importString,
                ),
              );
            }
          }
        }
      } else if (node.type == 'ImportFrom') {
        final module = node.raw['module']?.toString() ?? '';
        final level = node.raw['level'] is int ? node.raw['level'] as int : 0;
        final resolvedPath = _resolveImport(module, level, filePath);
        imports.add(
          ImportEdge(
            fromPath: filePath,
            targetUri: module,
            resolvedPath: resolvedPath,
            line: line,
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
    PyNode fnNode,
    String displayName,
    PyNode root,
    String source,
    List<Map<String, dynamic>> comments,
  ) {
    final fnSource = (fnNode.start >= 0 && fnNode.end <= source.length && fnNode.start <= fnNode.end)
        ? source.substring(fnNode.start, fnNode.end)
        : '';

    // Precalculate structural and raw tokens.
    final structuralTokens = fnNode.extractNodeTypes();
    final rawTokens = _tokenizeRawString(fnSource);

    // Precalculate complexity.
    final cc = _computeCyclomaticComplexity(fnNode);
    final cognitive = _computeCognitiveComplexity(fnNode);

    // Precalculate entropy.
    final shannon = _computeShannonEntropy(fnNode);
    final ident = _computeIdentifierEntropy(fnNode);

    // Precalculate comment intent.
    final hasIntent = _hasIntentComment(fnNode, comments);
    final intentRatio = hasIntent ? 1.0 : 0.0;

    // Precalculate Halstead stats.
    final halstead = computePyHalstead(rawTokens);

    final lines = fnSource.split('\n');
    final endLine = fnNode.line + lines.length - 1;

    return FunctionContext(
      name: displayName,
      startLine: fnNode.line,
      endLine: endLine,
      structuralTokens: structuralTokens,
      rawTokens: rawTokens,
      nodeCount: _countNodes(fnNode),
      cyclomaticComplexity: cc,
      cognitiveComplexity: cognitive,
      commentIntentRatio: intentRatio,
      shannonEntropy: shannon,
      identifierEntropy: ident,
      halsteadStats: halstead,
    );
  }

  int _countNodes(PyNode node) {
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

  int _computeCyclomaticComplexity(PyNode fnNode) {
    var decisionPoints = 0;

    void count(PyNode node) {
      // Evitar contar funciones internas anidadas
      if (node != fnNode && const {'FunctionDef', 'AsyncFunctionDef'}.contains(node.type)) {
        return;
      }

      if (const {
        'If',
        'While',
        'For',
        'AsyncFor',
        'ExceptHandler',
        'IfExp',
      }.contains(node.type)) {
        decisionPoints++;
      }

      if (node.type == 'BoolOp') {
        final values = node.raw['values'];
        if (values is List) {
          decisionPoints += values.length - 1;
        }
      }

      if (node.type == 'match_case') {
        // En Python 3.10+, cada caso en match añade complejidad, excepto el comodín de capturas (case _)
        // Para simplificar, contamos todos los match_case.
        decisionPoints++;
      }

      for (final child in node.children) {
        count(child);
      }
    }

    count(fnNode);
    return 1 + decisionPoints;
  }

  int _computeCognitiveComplexity(PyNode fnNode) {
    var complexity = 0;

    void visit(PyNode node, PyNode? parent, int nestingLevel, String? parentLogicalOp) {
      if (node != fnNode && const {'FunctionDef', 'AsyncFunctionDef'}.contains(node.type)) {
        return;
      }

      var currentNesting = nestingLevel;
      var currentLogicalOp = parentLogicalOp;

      if (node.type == 'If') {
        // En Python AST, un 'elif' se representa como un nodo 'If' anidado
        // dentro del campo 'orelse' de su padre 'If', y es el único elemento o el inicio del orelse.
        final isElif = parent != null &&
            parent.type == 'If' &&
            parent.raw['orelse'] is List &&
            (parent.raw['orelse'] as List).isNotEmpty &&
            (parent.raw['orelse'] as List).first['start'] == node.start;

        if (isElif) {
          complexity += 1;
        } else {
          complexity += 1 + nestingLevel;
        }
        currentNesting = nestingLevel + 1;
        currentLogicalOp = null;
      } else if (const {'For', 'AsyncFor', 'While'}.contains(node.type)) {
        complexity += 1 + nestingLevel;
        currentNesting = nestingLevel + 1;
        currentLogicalOp = null;
      } else if (node.type == 'ExceptHandler') {
        complexity += 1 + nestingLevel;
        currentNesting = nestingLevel + 1;
        currentLogicalOp = null;
      } else if (node.type == 'IfExp') {
        complexity += 1 + nestingLevel;
        currentNesting = nestingLevel + 1;
        currentLogicalOp = null;
      } else if (node.type == 'BoolOp') {
        final opMap = node.raw['op'];
        final op = (opMap is Map) ? opMap['type']?.toString() : null;
        if (op == 'And' || op == 'Or') {
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

    visit(fnNode, null, 0, null);
    return complexity;
  }

  double _computeShannonEntropy(PyNode rootNode) {
    final counts = <String, int>{};
    var total = 0;

    void count(PyNode n) {
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

  double _computeIdentifierEntropy(PyNode rootNode) {
    final counts = <String, int>{};
    var total = 0;

    const keywords = {
      'False', 'None', 'True', 'and', 'as', 'assert', 'async', 'await',
      'break', 'class', 'continue', 'def', 'del', 'elif', 'else', 'except',
      'finally', 'for', 'from', 'global', 'if', 'import', 'in', 'is', 'lambda',
      'nonlocal', 'not', 'or', 'pass', 'raise', 'return', 'try', 'while',
      'with', 'yield', 'self', 'cls'
    };

    void count(PyNode n) {
      if (n.type == 'Name') {
        final id = n.raw['id']?.toString();
        if (id != null && id.isNotEmpty && !keywords.contains(id)) {
          counts[id] = (counts[id] ?? 0) + 1;
          total++;
        }
      } else if (n.type == 'arg') {
        final name = n.raw['arg']?.toString();
        if (name != null && name.isNotEmpty && !keywords.contains(name)) {
          counts[name] = (counts[name] ?? 0) + 1;
          total++;
        }
      } else if (n.type == 'Attribute') {
        final attr = n.raw['attr']?.toString();
        if (attr != null && attr.isNotEmpty && !keywords.contains(attr)) {
          counts[attr] = (counts[attr] ?? 0) + 1;
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

  bool _hasIntentComment(PyNode fnNode, List<Map<String, dynamic>> comments) {
    const intentKeywords = {
      'why', 'because', 'reason', 'purpose', 'intent',
      'rationale', 'note', 'important', 'hack', 'workaround', 'todo'
    };

    // 1. Evaluar docstrings en el AST.
    // En Python AST, un docstring es un nodo Expr(value=Constant(value="..."))
    // como primer elemento en el body.
    final body = fnNode.raw['body'];
    if (body is List && body.isNotEmpty) {
      final firstStmt = body.first;
      if (firstStmt is Map && firstStmt['type'] == 'Expr') {
        final valNode = firstStmt['value'];
        if (valNode is Map && valNode['type'] == 'Constant') {
          final doc = valNode['value']?.toString() ?? '';
          final lower = doc.toLowerCase();
          for (final kw in intentKeywords) {
            if (lower.contains(kw)) {
              return true;
            }
          }
        }
      }
    }

    // 2. Evaluar comentarios físicos extraídos del tokenize.
    for (final comment in comments) {
      final start = comment['start'] is int ? comment['start'] as int : 0;
      final end = comment['end'] is int ? comment['end'] as int : 0;
      final value = comment['value']?.toString() ?? '';

      // Comentario precedente inmediato o inline
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

  Set<String> _extractMethodIdentifiers(PyNode methodNode) {
    final counts = <String>{};
    const keywords = {
      'False', 'None', 'True', 'and', 'as', 'assert', 'async', 'await',
      'break', 'class', 'continue', 'def', 'del', 'elif', 'else', 'except',
      'finally', 'for', 'from', 'global', 'if', 'import', 'in', 'is', 'lambda',
      'nonlocal', 'not', 'or', 'pass', 'raise', 'return', 'try', 'while',
      'with', 'yield', 'self', 'cls'
    };

    void collect(PyNode n) {
      if (n.type == 'Name') {
        final id = n.raw['id']?.toString();
        if (id != null && id.isNotEmpty && !keywords.contains(id)) {
          counts.add(id);
        }
      } else if (n.type == 'arg') {
        final name = n.raw['arg']?.toString();
        if (name != null && name.isNotEmpty && !keywords.contains(name)) {
          counts.add(name);
        }
      } else if (n.type == 'Attribute') {
        final attr = n.raw['attr']?.toString();
        if (attr != null && attr.isNotEmpty && !keywords.contains(attr)) {
          counts.add(attr);
        }
      }
      for (final child in n.children) {
        collect(child);
      }
    }

    collect(methodNode);
    return counts;
  }

  String? _resolveImport(String importUri, int level, String filePath) {
    if (importUri.isEmpty && level == 0) return null;

    final dir = p.dirname(filePath);

    // Relativos con puntos: e.g. from .utils import xyz (level = 1)
    if (level > 0) {
      var relativeDir = dir;
      for (var i = 1; i < level; i++) {
        relativeDir = p.dirname(relativeDir);
      }

      final targetPath = p.normalize(p.join(relativeDir, importUri.replaceAll('.', '/')));

      final candidates = [
        targetPath,
        '$targetPath.py',
        p.join(targetPath, '__init__.py'),
      ];

      for (final candidate in candidates) {
        if (allFiles.contains(candidate)) {
          return candidate;
        }
      }
      return null;
    }

    // Absolutos locales (e.g. import my_module o from my_module import x)
    final parts = importUri.split('.');
    final targetPath = p.normalize(p.join(dir, parts.join('/')));
    final candidates = [
      targetPath,
      '$targetPath.py',
      p.join(targetPath, '__init__.py'),
    ];

    for (final candidate in candidates) {
      if (allFiles.contains(candidate)) {
        return candidate;
      }
    }

    // O también buscar desde la raíz del proyecto para imports absolutos
    // basados en la raíz del proyecto (e.g. sys.path configurado en la raíz).
    for (final file in allFiles) {
      final normalizedFile = p.normalize(file);
      final suffix = parts.join('/') + '.py';
      final initSuffix = parts.join('/') + '/__init__.py';
      if (normalizedFile.endsWith(suffix) || normalizedFile.endsWith(initSuffix)) {
        return normalizedFile;
      }
    }

    return null;
  }
}
