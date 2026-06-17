/// TypeScript AST node model for Vetro.
///
/// Represents a deserialized AST node from the Babel/ESTree JSON format.
/// Provides helper methods for identifier extraction and tokenization.
library;

/// A node in the TypeScript Abstract Syntax Tree.
final class TsNode {
  const TsNode({
    required this.type,
    required this.raw,
    required this.children,
    required this.start,
    required this.end,
    required this.line,
  });

  /// Factory constructor to recursively parse a Babel JSON AST node.
  factory TsNode.fromJson(Map<String, dynamic> json) {
    final type = json['type']?.toString() ?? 'Unknown';
    final start = json['start'] is int ? json['start'] as int : 0;
    final end = json['end'] is int ? json['end'] as int : 0;
    final line = json['loc']?['start']?['line'] is int
        ? json['loc']['start']['line'] as int
        : (json['line'] is int ? json['line'] as int : 1);

    final children = <TsNode>[];
    for (final key in json.keys) {
      if (key == 'type' || key == 'start' || key == 'end' || key == 'loc') {
        continue;
      }
      _extractChildrenFromJson(json[key], children);
    }

    return TsNode(
      type: type,
      raw: json,
      children: children,
      start: start,
      end: end,
      line: line,
    );
  }

  /// The type of AST node (e.g. 'FunctionDeclaration', 'IfStatement').
  final String type;

  /// The raw JSON map representing the node.
  final Map<String, dynamic> raw;

  /// Recursively parsed child nodes.
  final List<TsNode> children;

  /// 0-based start offset in the source file.
  final int start;

  /// 0-based end offset in the source file.
  final int end;

  /// 1-based start line number.
  final int line;

  static void _extractChildrenFromJson(dynamic value, List<TsNode> collector) {
    if (value is Map) {
      if (value.containsKey('type') && value['type'] is String) {
        collector.add(TsNode.fromJson(Map<String, dynamic>.from(value)));
      } else {
        for (final val in value.values) {
          _extractChildrenFromJson(val, collector);
        }
      }
    } else if (value is List) {
      for (final val in value) {
        _extractChildrenFromJson(val, collector);
      }
    }
  }

  /// Extracts all identifier names within this node and its descendants.
  List<String> extractIdentifiers() {
    final result = <String>[];
    _collectIdentifiers(result);
    return result;
  }

  void _collectIdentifiers(List<String> collector) {
    if (type == 'Identifier') {
      final name = raw['name']?.toString();
      if (name != null && name.isNotEmpty) {
        collector.add(name);
      }
    }
    for (final child in children) {
      child._collectIdentifiers(collector);
    }
  }

  /// Extracts the sequence of AST node types for structural comparison.
  List<String> extractNodeTypes() {
    final result = <String>[];
    _collectNodeTypes(result);
    return result;
  }

  void _collectNodeTypes(List<String> collector) {
    collector.add(type);
    for (final child in children) {
      child._collectNodeTypes(collector);
    }
  }

  /// Traverses descendants and returns all nodes matching [predicate].
  List<TsNode> descendentNodes(bool Function(TsNode) predicate) {
    final result = <TsNode>[];
    _collectDescendents(predicate, result);
    return result;
  }

  void _collectDescendents(bool Function(TsNode) predicate, List<TsNode> collector) {
    if (predicate(this)) {
      collector.add(this);
    }
    for (final child in children) {
      child._collectDescendents(predicate, collector);
    }
  }
}
