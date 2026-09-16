import 'dart:io';

import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:vetro/analyzers/dart/rules/empty_catch_rule.dart';
import 'package:vetro/analyzers/dart/rules/unchecked_boundary_rule.dart';
import 'package:vetro/cli/scaffolding/scaffolding.dart';
import 'package:vetro/core/models/config.dart';
import 'package:vetro/core/models/context.dart';
import 'package:vetro/core/models/finding.dart';
import 'package:vetro/core/models/project_context.dart';

void main() {
  group('FeatureGenerator', () {
    const generator = FeatureGenerator();
    late Directory tempDir;

    setUp(() {
      tempDir = Directory.systemTemp.createTempSync('vetro_scaffold_test');
    });

    tearDown(() {
      tempDir.deleteSync(recursive: true);
    });

    test('scaffolds standard 5-file feature structure', () async {
      final result = await generator.generate(
        const FeatureScaffoldOptions(name: 'user_profile'),
        workingDirectory: tempDir.path,
      );

      expect(result.featureName, 'UserProfile');
      expect(result.createdFiles, hasLength(5));

      final featureDir = p.join(
        tempDir.path,
        'lib',
        'features',
        'user_profile',
      );
      expect(Directory(featureDir).existsSync(), isTrue);

      final failureFile = File(
        p.join(featureDir, 'domain', 'user_profile_failure.dart'),
      );
      final repoFile = File(
        p.join(featureDir, 'domain', 'user_profile_repository.dart'),
      );
      final mapperFile = File(
        p.join(featureDir, 'domain', 'user_profile_error_mapper.dart'),
      );
      final controllerFile = File(
        p.join(featureDir, 'presentation', 'user_profile_controller.dart'),
      );
      final barrelFile = File(p.join(featureDir, 'user_profile.dart'));

      expect(failureFile.existsSync(), isTrue);
      expect(repoFile.existsSync(), isTrue);
      expect(mapperFile.existsSync(), isTrue);
      expect(controllerFile.existsSync(), isTrue);
      expect(barrelFile.existsSync(), isTrue);

      // Verify failure content
      final failureContent = failureFile.readAsStringSync();
      expect(
        failureContent,
        contains('sealed class UserProfileFailure extends Failure'),
      );
      expect(failureContent, contains('UserProfileNotFoundFailure'));
      expect(failureContent, contains('UserProfileNetworkFailure'));

      // Verify repository content
      final repoContent = repoFile.readAsStringSync();
      expect(
        repoContent,
        contains('abstract interface class UserProfileRepository'),
      );
      expect(repoContent, contains('Result<String, UserProfileFailure>'));
      expect(repoContent, contains('Result.guardAsync'));

      // Verify mapper content
      final mapperContent = mapperFile.readAsStringSync();
      expect(mapperContent, contains('class UserProfileErrorMapper'));
      expect(
        mapperContent,
        contains('extends BaseFeatureErrorMapper<UserProfileFailure>'),
      );
      expect(mapperContent, contains('UserMessage mapFeatureError'));

      // Verify controller content
      final controllerContent = controllerFile.readAsStringSync();
      expect(controllerContent, contains('class UserProfileController'));
      expect(controllerContent, contains('class UserProfileState'));
      expect(controllerContent, contains('_repository.getById(id)'));

      // Verify barrel content
      final barrelContent = barrelFile.readAsStringSync();
      expect(
        barrelContent,
        contains("export 'domain/user_profile_failure.dart';"),
      );
      expect(
        barrelContent,
        contains("export 'domain/user_profile_repository.dart';"),
      );
      expect(
        barrelContent,
        contains("export 'domain/user_profile_error_mapper.dart';"),
      );
      expect(
        barrelContent,
        contains("export 'presentation/user_profile_controller.dart';"),
      );
    });

    test('supports custom target directory via targetPath', () async {
      final customPath = p.join(tempDir.path, 'custom', 'modules', 'billing');
      final result = await generator.generate(
        FeatureScaffoldOptions(name: 'billing_service', targetPath: customPath),
      );

      expect(result.featureName, 'BillingService');
      expect(result.targetDirectory, p.normalize(customPath));
      expect(
        File(p.join(customPath, 'billing_service.dart')).existsSync(),
        isTrue,
      );
    });

    test(
      'prevents overwriting without force flag and succeeds with force',
      () async {
        await generator.generate(
          const FeatureScaffoldOptions(name: 'auth'),
          workingDirectory: tempDir.path,
        );

        // Attempting second generate without force should throw StateError
        expect(
          () => generator.generate(
            const FeatureScaffoldOptions(name: 'auth', force: false),
            workingDirectory: tempDir.path,
          ),
          throwsA(isA<StateError>()),
        );

        // Generating with force should succeed
        final result = await generator.generate(
          const FeatureScaffoldOptions(name: 'auth', force: true),
          workingDirectory: tempDir.path,
        );
        expect(result.createdFiles, hasLength(5));
      },
    );

    test('throws ArgumentError on empty feature name', () async {
      expect(
        () => generator.generate(
          const FeatureScaffoldOptions(name: '   '),
          workingDirectory: tempDir.path,
        ),
        throwsA(isA<ArgumentError>()),
      );
    });

    test(
      'dogfooding: generated files pass Dart AST parsing and error handling rules with 0 findings',
      () async {
        final result = await generator.generate(
          const FeatureScaffoldOptions(name: 'payment_method'),
          workingDirectory: tempDir.path,
        );

        const emptyCatchRule = EmptyCatchRule(
          config: RuleConfig(enabled: true, severity: Severity.warning),
        );
        const boundaryRule = UncheckedBoundaryRule(
          config: RuleConfig(enabled: true, severity: Severity.warning),
        );

        const projectContext = ProjectContext(
          projectPath: '.',
          isFlutterProject: true,
        );

        for (final filePath in result.createdFiles) {
          final content = File(filePath).readAsStringSync();
          final parseResult = parseString(content: content);

          // Verify valid Dart 3 syntax (zero syntax parse errors)
          expect(
            parseResult.errors,
            isEmpty,
            reason: 'Syntax error found in $filePath: ${parseResult.errors}',
          );

          final context = FileContext(
            filePath: filePath,
            sourceCode: content,
            functions: const [],
            classes: const [],
            imports: const [],
            projectContext: projectContext,
            nativeAst: parseResult.unit,
          );

          // Verify EmptyCatchRule yields 0 findings
          final emptyCatchFindings = emptyCatchRule.analyzeFile(context);
          expect(
            emptyCatchFindings,
            isEmpty,
            reason: 'EmptyCatchRule failed on $filePath',
          );

          // Verify UncheckedBoundaryRule yields 0 findings
          final boundaryFindings = boundaryRule.analyzeFile(context);
          expect(
            boundaryFindings,
            isEmpty,
            reason: 'UncheckedBoundaryRule failed on $filePath',
          );
        }
      },
    );
  });
}
