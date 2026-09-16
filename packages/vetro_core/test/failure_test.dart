import 'package:test/test.dart';
import 'package:vetro_core/vetro_core.dart';

// Test domain failure hierarchy extending base Failure
sealed class AuthFailure extends Failure {
  const AuthFailure({required super.message, super.code, super.cause});
}

final class InvalidCredentialsFailure extends AuthFailure {
  const InvalidCredentialsFailure()
    : super(
        message: 'Invalid credentials provided',
        code: 'AUTH_INVALID_CREDENTIALS',
      );
}

final class SessionExpiredFailure extends AuthFailure {
  const SessionExpiredFailure()
    : super(message: 'Session has expired', code: 'AUTH_SESSION_EXPIRED');
}

void main() {
  group('Failure & StandardFailure Hierarchy', () {
    test('supports custom domain failure extensions', () {
      const AuthFailure failure = InvalidCredentialsFailure();
      expect(failure.message, 'Invalid credentials provided');
      expect(failure.code, 'AUTH_INVALID_CREDENTIALS');
      expect(failure, isA<AuthFailure>());
      expect(failure, isA<Failure>());

      final message = switch (failure) {
        InvalidCredentialsFailure() => 'Bad credentials',
        SessionExpiredFailure() => 'Re-authenticate',
      };
      expect(message, 'Bad credentials');
    });

    test('NetworkFailure stores timeout and connection details', () {
      const failure1 = NetworkFailure(
        message: 'Connection timed out',
        code: 'NET_TIMEOUT',
        isTimeout: true,
      );
      const failure2 = NetworkFailure(
        message: 'Connection timed out',
        code: 'NET_TIMEOUT',
        isTimeout: true,
      );
      const failure3 = NetworkFailure(
        message: 'DNS lookup failed',
        code: 'NET_DNS',
        isTimeout: false,
      );

      expect(failure1.isTimeout, isTrue);
      expect(failure1, equals(failure2));
      expect(failure1.hashCode, equals(failure2.hashCode));
      expect(failure1, isNot(equals(failure3)));
      expect(
        failure1.toString(),
        'NetworkFailure(message: Connection timed out, code: NET_TIMEOUT, isTimeout: true)',
      );
    });

    test('ServerFailure stores status code', () {
      const failure = ServerFailure(
        message: 'Internal Server Error',
        code: 'HTTP_500',
        statusCode: 500,
      );
      const identicalFailure = ServerFailure(
        message: 'Internal Server Error',
        code: 'HTTP_500',
        statusCode: 500,
      );
      const differentFailure = ServerFailure(
        message: 'Bad Gateway',
        code: 'HTTP_502',
        statusCode: 502,
      );

      expect(failure.statusCode, 500);
      expect(failure, equals(identicalFailure));
      expect(failure, isNot(equals(differentFailure)));
      expect(
        failure.toString(),
        'ServerFailure(message: Internal Server Error, code: HTTP_500, statusCode: 500)',
      );
    });

    test('ValidationFailure stores and compares field errors', () {
      const failure1 = ValidationFailure(
        message: 'Invalid form input',
        code: 'VAL_ERR',
        fieldErrors: {'email': 'Invalid format', 'password': 'Too short'},
      );
      const failure2 = ValidationFailure(
        message: 'Invalid form input',
        code: 'VAL_ERR',
        fieldErrors: {'email': 'Invalid format', 'password': 'Too short'},
      );
      const failure3 = ValidationFailure(
        message: 'Invalid form input',
        code: 'VAL_ERR',
        fieldErrors: {'email': 'Invalid format'},
      );

      expect(failure1.fieldErrors['email'], 'Invalid format');
      expect(failure1, equals(failure2));
      expect(failure1.hashCode, equals(failure2.hashCode));
      expect(failure1, isNot(equals(failure3)));
    });

    test('NotFoundFailure stores resource information', () {
      const failure = NotFoundFailure(
        message: 'User not found',
        code: 'NOT_FOUND',
        resourceType: 'User',
        resourceId: 'usr-123',
      );

      expect(failure.resourceType, 'User');
      expect(failure.resourceId, 'usr-123');
      expect(
        failure.toString(),
        'NotFoundFailure(message: User not found, code: NOT_FOUND, resourceType: User, resourceId: usr-123)',
      );
    });

    test('UnexpectedFailure captures underlying cause and stack trace', () {
      final stateError = StateError('Corrupted memory');
      final stackTrace = StackTrace.current;
      final failure = UnexpectedFailure(
        message: 'Unexpected crash',
        cause: stateError,
        stackTrace: stackTrace,
      );

      expect(failure.cause, equals(stateError));
      expect(failure.stackTrace, equals(stackTrace));
      expect(
        failure.toString(),
        'UnexpectedFailure(message: Unexpected crash, code: null, cause: Bad state: Corrupted memory)',
      );
    });

    test('StandardFailure exhaustive pattern matching', () {
      final List<StandardFailure> failures = [
        const NetworkFailure(message: 'net'),
        const ServerFailure(message: 'srv'),
        const ValidationFailure(message: 'val'),
        const NotFoundFailure(message: '404'),
        const UnexpectedFailure(message: 'unexp'),
      ];

      for (final f in failures) {
        final category = switch (f) {
          NetworkFailure() => 'network',
          ServerFailure() => 'server',
          ValidationFailure() => 'validation',
          NotFoundFailure() => 'not_found',
          UnexpectedFailure() => 'unexpected',
        };
        expect(category, isNotEmpty);
      }
    });
  });
}
