import 'package:test/test.dart';
import 'package:vetro/core/metrics/dependency_graph.dart';

void main() {
  group('Local Clustering Coefficient', () {
    test('Clustering coefficient is 0.0 for nodes with less than 2 neighbors', () {
      final graph = DependencyGraph();
      graph.addEdge('A', 'B'); // A has 1 neighbor
      expect(graph.localClusteringCoefficient('A'), equals(0.0));
      expect(graph.localClusteringCoefficient('B'), equals(0.0));
    });

    test('Clustering coefficient is 0.0 when neighbors are completely disconnected', () {
      final graph = DependencyGraph();
      graph.addEdge('A', 'B');
      graph.addEdge('A', 'C');
      graph.addEdge('A', 'D');
      // Neighbors: B, C, D. No edges exist between B, C, D.
      expect(graph.localClusteringCoefficient('A'), equals(0.0));
    });

    test('Clustering coefficient is 1.0 when neighbors are fully connected (clique)', () {
      final graph = DependencyGraph();
      graph.addEdge('A', 'B');
      graph.addEdge('A', 'C');
      graph.addEdge('A', 'D');

      // Fully connect B, C, D in both directions
      graph.addEdge('B', 'C');
      graph.addEdge('C', 'B');
      graph.addEdge('B', 'D');
      graph.addEdge('D', 'B');
      graph.addEdge('C', 'D');
      graph.addEdge('D', 'C');

      expect(graph.localClusteringCoefficient('A'), equals(1.0));
    });

    test('Clustering coefficient is correct for partially connected neighbors', () {
      final graph = DependencyGraph();
      graph.addEdge('A', 'B');
      graph.addEdge('A', 'C');
      graph.addEdge('A', 'D');

      // Add only one directed edge B -> C among neighbors
      graph.addEdge('B', 'C');

      // Neighbors of A: B, C, D (3 neighbors)
      // Max possible directed edges: 3 * (3 - 1) = 6
      // Actual edges between neighbors: 1 (B -> C)
      // Coefficient = 1 / 6 = ~0.1667
      expect(graph.localClusteringCoefficient('A'), closeTo(1 / 6, 0.0001));
    });
  });
}
