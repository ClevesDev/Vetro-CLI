/// Python AST node model for Vetro.
///
/// Represents a deserialized AST node from the Python stdlib ast JSON format.
/// Provides helper methods for identifier extraction and tokenization.
library;

/// A node in the Python Abstract Syntax Tree.
final class PyNode {
  const PyNode({
    required this.type,
    required this.raw,
    required this.children,
    required this.start,
    required this.end,
    required this.line,
  });

  /// Factory constructor to recursively parse a Python JSON AST node.
  factory PyNode.fromJson(Map<String, dynamic> json) {
    final type = json['type']?.toString() ?? 'Unknown';
    final start = json['start'] is int ? json['start'] as int : 0;
    final end = json['end'] is int ? json['end'] as int : 0;
    final line = json['line'] is int ? json['line'] as int : 1;

    final children = <PyNode>[];
    for (final key in json.keys) {
      if (key == 'type' || key == 'start' || key == 'end' || key == 'line') {
        continue;
      }
      _extractChildrenFromJson(json[key], children);
    }

    return PyNode(
      type: type,
      raw: json,
      children: children,
      start: start,
      end: end,
      line: line,
    );
  }

  /// The type of AST node (e.g. 'FunctionDef', 'If', 'While').
  final String type;

  /// The raw JSON map representing the node.
  final Map<String, dynamic> raw;

  /// Recursively parsed child nodes.
  final List<PyNode> children;

  /// 0-based start offset in the source file.
  final int start;

  /// 0-based end offset in the source file.
  final int end;

  /// 1-based start line number.
  final int line;

  static void _extractChildrenFromJson(dynamic value, List<PyNode> collector) {
    if (value is Map) {
      if (value.containsKey('type') && value['type'] is String) {
        collector.add(PyNode.fromJson(Map<String, dynamic>.from(value)));
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
    if (type == 'Name') {
      final id = raw['id']?.toString();
      if (id != null && id.isNotEmpty) {
        collector.add(id);
      }
    } else if (type == 'arg') {
      final name = raw['arg']?.toString();
      if (name != null && name.isNotEmpty) {
        collector.add(name);
      }
    } else if (type == 'Attribute') {
      final attr = raw['attr']?.toString();
      if (attr != null && attr.isNotEmpty) {
        collector.add(attr);
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
  List<PyNode> descendentNodes(bool Function(PyNode) predicate) {
    final result = <PyNode>[];
    _collectDescendents(predicate, result);
    return result;
  }

  void _collectDescendents(bool Function(PyNode) predicate, List<PyNode> collector) {
    if (predicate(this)) {
      collector.add(this);
    }
    for (final child in children) {
      child._collectDescendents(predicate, collector);
    }
  }
}
