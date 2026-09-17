import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:test/test.dart';
import 'package:vetro/analyzers/dart/rules/empty_catch_rule.dart';
import 'package:vetro/analyzers/dart/rules/unchecked_boundary_rule.dart';
import 'package:vetro/core/models/config.dart';
import 'package:vetro/core/models/context.dart';
import 'package:vetro/core/models/finding.dart';
import 'package:vetro/core/models/project_context.dart';

void main() {
  const projectContext = ProjectContext(
    projectPath: '.',
    isFlutterProject: true,
  );

  FileContext createContext(String source, {String path = 'lib/file.dart'}) {
    final unit = parseString(content: source).unit;
    return FileContext(
      filePath: path,
      sourceCode: source,
      functions: const [],
      classes: const [],
      imports: const [],
      projectContext: projectContext,
      nativeAst: unit,
    );
  }

  group('EmptyCatchRule', () {
    const config = RuleConfig(enabled: true, severity: Severity.warning);
    const rule = EmptyCatchRule(config: config);

    test('flags completely empty catch clause', () {
      const source = '''
        void doWork() {
          try {
            dangerousOp();
          } catch (e) {}
        }
      ''';
      final findings = rule.analyzeFile(createContext(source));
      expect(findings, hasLength(1));
      expect(findings.first.ruleId, 'empty_catch');
      expect(findings.first.message, contains('empty body'));
      expect(findings.first.evidence['enclosing_name'], 'doWork');
      expect(
        findings.first.evidence['enclosing_declaration'],
        contains('void doWork()'),
      );
    });

    test('flags catch clause with underscore parameter that does nothing', () {
      const source = '''
        void doWork() {
          try {
            dangerousOp();
          } catch (_) {}
        }
      ''';
      final findings = rule.analyzeFile(createContext(source));
      expect(findings, hasLength(1));
    });

    test('flags silent catch clause without log, rethrow, or mapping', () {
      const source = '''
        void doWork() {
          try {
            dangerousOp();
          } catch (e) {
            var x = 10;
            x += 5;
          }
        }
      ''';
      final findings = rule.analyzeFile(createContext(source));
      expect(findings, hasLength(1));
      expect(
        findings.first.message,
        contains('no log, rethrow, throw, or error mapper call'),
      );
    });

    test('does not flag catch clause that logs the error', () {
      const source = '''
        void doWork() {
          try {
            dangerousOp();
          } catch (e) {
            logger.error('Failed op', e);
          }
        }
      ''';
      final findings = rule.analyzeFile(createContext(source));
      expect(findings, isEmpty);
    });

    test('does not flag catch clause that rethrows', () {
      const source = '''
        void doWork() {
          try {
            dangerousOp();
          } catch (e) {
            cleanup();
            rethrow;
          }
        }
      ''';
      final findings = rule.analyzeFile(createContext(source));
      expect(findings, isEmpty);
    });

    test(
      'does not flag catch clause that returns FailureResult or wraps in Failure',
      () {
        const source = '''
        Result<int, Failure> doWork() {
          try {
            return Success(dangerousOp());
          } catch (e) {
            return FailureResult(UnexpectedFailure(message: e.toString()));
          }
        }
      ''';
        final findings = rule.analyzeFile(createContext(source));
        expect(findings, isEmpty);
      },
    );
  });

  group('UncheckedBoundaryRule', () {
    const config = RuleConfig(enabled: true, severity: Severity.warning);
    const rule = UncheckedBoundaryRule(config: config);

    test(
      'flags presentation controller catching raw exception without domain mapping',
      () {
        const source = '''
        class AuthController {
          void login() {
            try {
              api.login();
            } catch (e) {
              state = 'Error: \$e';
            }
          }
        }
      ''';
        final findings = rule.analyzeFile(
          createContext(source, path: 'lib/presentation/auth_controller.dart'),
        );
        expect(findings, hasLength(1));
        expect(findings.first.ruleId, 'unchecked_boundary');
        expect(findings.first.message, contains('AuthController'));
        expect(findings.first.evidence['enclosing_name'], 'login');
        expect(
          findings.first.evidence['enclosing_declaration'],
          contains('void login()'),
        );
      },
    );

    test(
      'flags presentation notifier capturing on Exception without mapper',
      () {
        const source = '''
        class UserNotifier {
          void loadUser() {
            try {
              repository.getUser();
            } on Exception catch (e) {
              errorMessage = e.toString();
            }
          }
        }
      ''';
        final findings = rule.analyzeFile(createContext(source));
        expect(findings, hasLength(1));
      },
    );

    test('does not flag controller catching explicit domain Failure', () {
      const source = '''
        class AuthController {
          void login() {
            try {
              api.login();
            } on AuthFailure catch (e) {
              state = e.message;
            }
          }
        }
      ''';
      final findings = rule.analyzeFile(
        createContext(source, path: 'lib/presentation/auth_controller.dart'),
      );
      expect(findings, isEmpty);
    });

    test('does not flag controller delegating to errorMapper.map', () {
      const source = '''
        class CheckoutController {
          void checkout() {
            try {
              paymentService.charge();
            } catch (e) {
              final userMessage = errorMapper.map(e);
              showSnackbar(userMessage.message);
            }
          }
        }
      ''';
      final findings = rule.analyzeFile(createContext(source));
      expect(findings, isEmpty);
    });

    test('does not flag controller delegating to AppError.fromObject or DomainError', () {
      const source = '''
        class PaymentController {
          void process() {
            try {
              gateway.charge();
            } catch (e) {
              final err = AppError.fromObject(e);
              notify(err);
            }
          }
        }
      ''';
      final findings = rule.analyzeFile(
        createContext(source, path: 'lib/presentation/payment_controller.dart'),
      );
      expect(findings, isEmpty);
    });

    test('does not flag controller delegating to ErrorHandler.handle', () {
      const source = '''
        class SyncNotifier {
          void sync() {
            try {
              syncService.run();
            } catch (e) {
              ErrorHandler.handle(e);
            }
          }
        }
      ''';
      final findings = rule.analyzeFile(
        createContext(source, path: 'lib/presentation/sync_notifier.dart'),
      );
      expect(findings, isEmpty);
    });

    test('does not flag non-presentation classes (e.g. data source)', () {
      const source = '''
        class RemoteUserDataSource {
          void request() {
            try {
              client.get('/user');
            } catch (e) {
              cache.clear();
            }
          }
        }
      ''';
      final findings = rule.analyzeFile(
        createContext(source, path: 'lib/data/remote_user_data_source.dart'),
      );
      expect(findings, isEmpty);
    });
  });
}
