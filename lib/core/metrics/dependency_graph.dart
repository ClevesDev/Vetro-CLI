/// A directed graph for analyzing file-level import dependencies.
///
/// Models the project's dependency structure as a directed graph where:
/// - Each **node** is a file path (or module identifier).
/// - Each **edge** (from → to) represents an import dependency.
///
/// Key metrics:
/// - **Fan-in**: Number of files that import a given file.
///   High fan-in = widely depended upon = high-impact changes.
/// - **Fan-out**: Number of files a given file imports.
///   High fan-out = many dependencies = fragile to changes elsewhere.
/// - **Coupling**: (fanIn + fanOut) / totalNodes — normalized measure
///   of how interconnected a node is within the graph. Range [0.0, 1.0].
///
/// All methods are pure — the graph is built incrementally via
/// `addEdge`, and all query methods are side-effect-free reads.
library;

import 'dart:math' as math;


/// A simple directed graph for import/dependency analysis.
///
/// Edges represent "A depends on B" (A imports B).
/// The graph supports efficient fan-in, fan-out, and coupling queries.
final class DependencyGraph {
  /// Creates an empty dependency graph.
  DependencyGraph();

  /// Adjacency list: node → set of nodes it depends on (outgoing edges).
  final Map<String, Set<String>> _adjacency = {};

  /// Adds a directed edge from [from] to [to].
  ///
  /// Semantics: [from] depends on (imports) [to].
  /// Both nodes are registered in the graph even if they have no
  /// other connections.
  void addEdge(String from, String to) {
    _adjacency.putIfAbsent(from, () => <String>{}).add(to);
    // Ensure 'to' also exists as a node even if it has no outgoing edges.
    _adjacency.putIfAbsent(to, () => <String>{});
  }

  /// Adds a single node to the graph with no outgoing edges.
  ///
  /// We do this because cross-file rules must register all files as nodes
  /// even if they do not import anything and have no dependents.
  void addNode(String node) {
    _adjacency.putIfAbsent(node, () => <String>{});
  }

  /// Returns the set of direct dependencies of [node] (outgoing edges).
  ///
  /// These are the files that [node] imports.
  /// Returns an empty set if [node] is not in the graph.
  Set<String> dependenciesOf(String node) =>
      Set<String>.unmodifiable(_adjacency[node] ?? const <String>{});

  /// Returns the set of nodes that depend on [node] (incoming edges).
  ///
  /// These are the files that import [node].
  /// Returns an empty set if no node depends on [node].
  ///
  /// Time complexity: O(V + E) where V is the number of nodes and
  /// E is the total number of edges, since we must scan all adjacency
  /// lists.
  Set<String> dependentsOf(String node) {
    final result = <String>{};
    for (final entry in _adjacency.entries) {
      if (entry.value.contains(node)) {
        result.add(entry.key);
      }
    }
    return result;
  }

  /// Number of incoming edges to [node] (how many files import this).
  ///
  /// High fan-in indicates a heavily-reused module. Changes to
  /// high fan-in nodes have wide blast radius.
  ///
  /// **Formula**: fanIn(v) = |{u ∈ V : (u, v) ∈ E}|
  int fanIn(String node) {
    var count = 0;
    for (final deps in _adjacency.values) {
      if (deps.contains(node)) count++;
    }
    return count;
  }

  /// Number of outgoing edges from [node] (how many files this imports).
  ///
  /// High fan-out indicates a module with many dependencies.
  /// It's more likely to break when any dependency changes.
  ///
  /// **Formula**: fanOut(v) = |{u ∈ V : (v, u) ∈ E}|
  int fanOut(String node) => _adjacency[node]?.length ?? 0;

  /// Normalized coupling metric for [node].
  ///
  /// **Formula**: coupling(v) = (fanIn(v) + fanOut(v)) / |V|
  ///
  /// where |V| is the total number of nodes in the graph.
  ///
  /// Returns 0.0 if the graph is empty or [node] is not in the graph.
  /// Range: [0.0, ∞) theoretically, but practically [0.0, 2.0] for
  /// well-structured projects (each node can have at most |V|-1 in
  /// each direction).
  double coupling(String node) {
    // We normalize the coupling metric by dividing the sum of fan-in and fan-out
    // by the total number of nodes in the project to obtain a relative measure of 
    // how interconnected this node is compared to the rest of the codebase.
    final totalNodes = _adjacency.length;
    if (totalNodes == 0) return 0.0;
    return (fanIn(node) + fanOut(node)) / totalNodes;
  }

  /// All nodes currently in the graph.
  ///
  /// Includes nodes that were added as dependencies (targets of edges)
  /// even if they themselves have no outgoing edges.
  List<String> get nodes => _adjacency.keys.toList();

  /// Computes the Eigenvector Centrality for all nodes in the graph using the power iteration method.
  ///
  /// Note: The purpose of eigenvector centrality is to measure the global import importance of a file,
  /// where connections from other highly-depended-upon files contribute more than connections from isolated files.
  Map<String, double> eigenvectorCentrality({
    int maxIterations = 50,
    double tolerance = 1e-6,
    double dampingFactor = 0.85,
  }) {
    final allNodes = nodes;
    final n = allNodes.length;
    if (n == 0) return const {};

    // Initialize scores to 1 / n
    var scores = <String, double>{
      for (final node in allNodes) node: 1.0 / n,
    };

    // Precompute incoming connections to avoid O(V^2) scan in each iteration
    final incoming = <String, List<String>>{
      for (final node in allNodes) node: [],
    };
    for (final entry in _adjacency.entries) {
      final from = entry.key;
      for (final to in entry.value) {
        if (incoming.containsKey(to)) {
          incoming[to]!.add(from);
        }
      }
    }

    final base = (1.0 - dampingFactor) / n;

    for (var iter = 0; iter < maxIterations; iter++) {
      final newScores = <String, double>{};

      for (final v in allNodes) {
        var sum = 0.0;
        for (final u in incoming[v]!) {
          final outDegree = fanOut(u);
          if (outDegree > 0) {
            sum += scores[u]! / outDegree;
          }
        }
        newScores[v] = base + dampingFactor * sum;
      }

      // Check convergence using Euclidean distance
      var diff = 0.0;
      for (final v in allNodes) {
        final newVal = newScores[v]!;
        final oldVal = scores[v]!;
        diff += (newVal - oldVal) * (newVal - oldVal);
      }

      scores = newScores;
      if (math.sqrt(diff) < tolerance) {
        break;
      }
    }

    // Normalize final scores to have L2 norm = 1.0
    var sumSq = 0.0;
    for (final score in scores.values) {
      sumSq += score * score;
    }
    final norm = math.sqrt(sumSq);
    if (norm > 1e-9) {
      scores = {
        for (final entry in scores.entries) entry.key: entry.value / norm,
      };
    }

    return scores;
  }

  /// Computes the local clustering coefficient of [node] in the graph,
  /// treating neighbors in an undirected fashion, but counting directed edges.
  ///
  /// **Formula**: C_v = e_v / (k_v * (k_v - 1))
  /// where k_v is the number of distinct neighbors (both imports and dependents) of v,
  /// and e_v is the number of directed edges between those neighbors.
  ///
  /// Returns 0.0 if k_v < 2.
  double localClusteringCoefficient(String node) {
    if (!_adjacency.containsKey(node)) return 0.0;

    final neighbors = <String>{
      ...dependenciesOf(node),
      ...dependentsOf(node),
    }..remove(node);

    final kv = neighbors.length;
    if (kv < 2) return 0.0;

    var ev = 0;
    final neighborList = neighbors.toList();
    for (var i = 0; i < kv; i++) {
      for (var j = 0; j < kv; j++) {
        if (i == j) continue;
        final u = neighborList[i];
        final w = neighborList[j];
        if (_adjacency[u]?.contains(w) ?? false) {
          ev++;
        }
      }
    }

    return ev / (kv * (kv - 1));
  }
}
