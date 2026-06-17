import 'dart:io';
import 'package:vetro/vetro.dart';

void main() async {
  final projects = [
    ('Vetro (Self)', '/home/dimas/development/Vetro'),
    ('Proyecto_XXX_A', '/home/dimas/development/proyectos/Proyecto_XXX_A'),
    ('Proyecto_XXX_C', '/home/dimas/development/proyectos/Proyecto_XXX_C'),
    ('Proyecto_XXX_B', '/home/dimas/development/proyectos/Proyecto_XXX_B'),
    ('Proyecto_XXX_D', '/home/dimas/development/Proyecto_XXX_D'),
  ];

  print('================================━━━━━━━━━━━━━━━━━━');
  print('       VETRO ENGINE PERFORMANCE BENCHMARK         ');
  print('================================━━━━━━━━━━━━━━━━━━');

  for (final proj in projects) {
    final name = proj.$1;
    final path = proj.$2;
    if (!Directory(path).existsSync()) {
      print('\nSkipping $name (Path not found: $path)');
      continue;
    }

    final config = VetroConfig.defaults();
    final analyzer = DartAnalyzer();

    // Warm-up run to JIT compile/cache Dart analysis contexts
    final warmUpReport = await analyzer.analyze(path, config);
    final totalFiles = warmUpReport.fileReports.length;
    final totalLoc = warmUpReport.fileReports.fold<int>(0, (sum, r) => sum + r.lineCount);

    // Trial runs
    const runs = 3;
    var totalMs = 0;

    for (var i = 0; i < runs; i++) {
      final sw = Stopwatch()..start();
      await analyzer.analyze(path, config);
      sw.stop();
      totalMs += sw.elapsedMilliseconds;
    }

    final avgTimeMs = totalMs / runs;
    final avgTimeSec = avgTimeMs / 1000.0;
    final throughput = avgTimeSec > 0 ? totalLoc / avgTimeSec : 0.0;

    print('\n🚀 Project: $name');
    print('   📁 Files analyzed: $totalFiles');
    print('   📝 Lines of code:  $totalLoc');
    print('   ⏱️  Avg Run Time:   ${avgTimeMs.toStringAsFixed(1)} ms (${avgTimeSec.toStringAsFixed(3)} s)');
    print('   ⚡ Throughput:     ${throughput.toStringAsFixed(1)} lines/sec');
  }
  print('================================━━━━━━━━━━━━━━━━━━');
}
