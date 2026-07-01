import 'dart:convert';
import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:yaml/yaml.dart';

/// Represents a parsed semantic version for robust SDK compatibility checks.
class Version implements Comparable<Version> {
  final int major;
  final int minor;
  final int patch;

  const Version(this.major, this.minor, this.patch);

  /// Parses a version string (e.g. "3.22.2" or "3.44.0-3.0.pre").
  static Version? parse(String? versionString) {
    if (versionString == null) return null;
    final clean = versionString.split('-').first.split('+').first.trim();
    final parts = clean.split('.');
    if (parts.isEmpty) return null;
    final major = int.tryParse(parts[0]) ?? 0;
    final minor = parts.length > 1 ? (int.tryParse(parts[1]) ?? 0) : 0;
    final patch = parts.length > 2 ? (int.tryParse(parts[2]) ?? 0) : 0;
    return Version(major, minor, patch);
  }

  @override
  int compareTo(Version other) {
    if (major != other.major) return major.compareTo(other.major);
    if (minor != other.minor) return minor.compareTo(other.minor);
    return patch.compareTo(other.patch);
  }

  bool operator >=(Version other) => compareTo(other) >= 0;
  bool operator >(Version other) => compareTo(other) > 0;
  bool operator <=(Version other) => compareTo(other) <= 0;
  bool operator <(Version other) => compareTo(other) < 0;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Version &&
          runtimeType == other.runtimeType &&
          major == other.major &&
          minor == other.minor &&
          patch == other.patch;

  @override
  int get hashCode => major.hashCode ^ minor.hashCode ^ patch.hashCode;

  @override
  String toString() => '$major.$minor.$patch';
}

/// Holds the environment context of the project under analysis,
/// specifically the Dart and Flutter SDK versions.
class ProjectContext {
  final String projectPath;
  final bool isFlutterProject;
  final Version? flutterVersion;
  final String? dartVersionConstraint;

  const ProjectContext({
    required this.projectPath,
    required this.isFlutterProject,
    this.flutterVersion,
    this.dartVersionConstraint,
  });

  /// Creates a default, empty [ProjectContext] when no configuration is available.
  const ProjectContext.empty({required this.projectPath})
      : isFlutterProject = false,
        flutterVersion = null,
        dartVersionConstraint = null;

  /// Resolves the SDK versions of the target project by reading `pubspec.yaml`
  /// and `.dart_tool/package_config.json`.
  static Future<ProjectContext> resolve(String projectPath) async {
    final pubspecFile = File(p.join(projectPath, 'pubspec.yaml'));
    if (!await pubspecFile.exists()) {
      return ProjectContext.empty(projectPath: projectPath);
    }

    try {
      final pubspecContent = await pubspecFile.readAsString();
      final pubspec = loadYaml(pubspecContent) as YamlMap;

      // Extract Dart SDK constraints
      String? dartConstraint;
      if (pubspec['environment'] is YamlMap) {
        final env = pubspec['environment'] as YamlMap;
        dartConstraint = env['sdk']?.toString();
      }

      // Check if project depends on flutter
      bool hasFlutterDep = false;
      if (pubspec['dependencies'] is YamlMap) {
        final deps = pubspec['dependencies'] as YamlMap;
        hasFlutterDep = deps.containsKey('flutter');
      }

      if (!hasFlutterDep) {
        return ProjectContext(
          projectPath: projectPath,
          isFlutterProject: false,
          dartVersionConstraint: dartConstraint,
        );
      }

      // Attempt to resolve the exact Flutter version using package_config.json
      final packageConfigFile = File(p.join(projectPath, '.dart_tool', 'package_config.json'));
      Version? resolvedFlutterVersion;

      if (await packageConfigFile.exists()) {
        try {
          final content = await packageConfigFile.readAsString();
          final json = jsonDecode(content) as Map<String, dynamic>;
          final packages = json['packages'] as List<dynamic>;

          final flutterPkg = packages.firstWhere(
            (pkg) => pkg['name'] == 'flutter',
            orElse: () => null,
          );

          if (flutterPkg != null && flutterPkg['rootUri'] != null) {
            final rootUriStr = flutterPkg['rootUri'] as String;
            final rootUri = Uri.parse(rootUriStr);
            if (rootUri.isScheme('file')) {
              final flutterPkgPath = rootUri.toFilePath();
              // flutter packages are located under: <flutter_sdk>/packages/flutter
              // Backtracking 2 directories resolves to the root of the SDK
              final sdkRoot = p.dirname(p.dirname(flutterPkgPath));
              final versionFile = File(p.join(sdkRoot, 'version'));
              if (await versionFile.exists()) {
                final versionStr = (await versionFile.readAsString()).trim();
                resolvedFlutterVersion = Version.parse(versionStr);
              }
            }
          }
        } catch (_) {
          // Fail silently and leave flutterVersion as null if parsing fails
        }
      }

      return ProjectContext(
        projectPath: projectPath,
        isFlutterProject: true,
        flutterVersion: resolvedFlutterVersion,
        dartVersionConstraint: dartConstraint,
      );
    } catch (_) {
      return ProjectContext.empty(projectPath: projectPath);
    }
  }
}
