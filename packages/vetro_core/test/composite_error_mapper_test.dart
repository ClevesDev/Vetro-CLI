import 'package:test/test.dart';
import 'package:vetro_core/vetro_core.dart';

// Domain-specific failures
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

sealed class CheckoutFailure extends Failure {
  const CheckoutFailure({required super.message, super.code});
}

final class PaymentDeclinedFailure extends CheckoutFailure {
  final String declineReason;
  const PaymentDeclinedFailure(this.declineReason)
    : super(
        message: 'Payment was declined: $declineReason',
        code: 'CHECKOUT_PAYMENT_DECLINED',
      );
}

// Feature error mappers
final class AuthErrorMapper extends BaseFeatureErrorMapper<AuthFailure> {
  const AuthErrorMapper();

  @override
  UserMessage mapFailure(AuthFailure failure) => switch (failure) {
    InvalidCredentialsFailure() => const UserMessage(
      title: 'Authentication Failed',
      message: 'The email or password you entered is incorrect.',
      code: 'AUTH_001',
      actionLabel: 'Try Again',
    ),
    SessionExpiredFailure() => const UserMessage(
      title: 'Session Expired',
      message: 'Please sign in again to continue.',
      code: 'AUTH_002',
      actionLabel: 'Sign In',
    ),
  };
}

final class CheckoutErrorMapper
    extends BaseFeatureErrorMapper<CheckoutFailure> {
  const CheckoutErrorMapper();

  @override
  UserMessage mapFailure(CheckoutFailure failure) => switch (failure) {
    PaymentDeclinedFailure(:final declineReason) => UserMessage(
      title: 'Payment Declined',
      message: 'Unable to charge your card: $declineReason',
      code: 'CHECKOUT_001',
      actionLabel: 'Update Card',
    ),
  };
}

void main() {
  group('UserMessage', () {
    test('value equality and hashing work symmetrically', () {
      const msg1 = UserMessage(
        title: 'Error',
        message: 'Something broke',
        code: 'ERR_1',
        metadata: {'field': 'email'},
      );
      const msg2 = UserMessage(
        title: 'Error',
        message: 'Something broke',
        code: 'ERR_1',
        metadata: {'field': 'email'},
      );
      const msg3 = UserMessage(
        title: 'Error',
        message: 'Something else broke',
        code: 'ERR_2',
      );

      expect(msg1, equals(msg2));
      expect(msg1.hashCode, equals(msg2.hashCode));
      expect(msg1, isNot(equals(msg3)));
    });

    test('generic fallback constructor produces default values', () {
      const fallback = UserMessage.generic();
      expect(fallback.title, 'Something went wrong');
      expect(fallback.message, contains('unexpected error'));
      expect(fallback.actionLabel, 'Dismiss');
    });
  });

  group('StandardErrorMapper', () {
    const mapper = StandardErrorMapper();

    test('maps NetworkFailure timeout and connection loss', () {
      const timeout = NetworkFailure(
        message: 'Deadline exceeded',
        isTimeout: true,
      );
      final timeoutMsg = mapper.map(timeout);
      expect(timeoutMsg.title, 'Connection Timeout');
      expect(timeoutMsg.actionLabel, 'Retry');

      const noInternet = NetworkFailure(
        message: 'Socket exception',
        isTimeout: false,
      );
      final noNetMsg = mapper.map(noInternet);
      expect(noNetMsg.title, 'No Internet Connection');
      expect(noNetMsg.actionLabel, 'Retry');
    });

    test('maps ServerFailure with and without status code', () {
      const server500 = ServerFailure(
        message: 'Internal error',
        statusCode: 500,
      );
      final msg500 = mapper.map(server500);
      expect(msg500.title, 'Server Error');
      expect(msg500.message, contains('Status 500'));

      const serverNoCode = ServerFailure(message: 'Unknown crash');
      final msgNoCode = mapper.map(serverNoCode);
      expect(msgNoCode.title, 'Server Error');
      expect(msgNoCode.message, isNot(contains('Status')));
    });

    test('maps ValidationFailure preserving field error metadata', () {
      const valFailure = ValidationFailure(
        message: 'Form has invalid fields',
        fieldErrors: {'email': 'Invalid format', 'password': 'Too short'},
      );
      final msg = mapper.map(valFailure);
      expect(msg.title, 'Validation Error');
      expect(
        msg.metadata,
        equals({'email': 'Invalid format', 'password': 'Too short'}),
      );
    });

    test('maps NotFoundFailure and UnexpectedFailure', () {
      const notFound = NotFoundFailure(
        message: 'Document missing',
        resourceType: 'Order',
      );
      final notFoundMsg = mapper.map(notFound);
      expect(notFoundMsg.title, 'Order Not Found');

      const unexpected = UnexpectedFailure(message: 'Unknown state');
      final unexpectedMsg = mapper.map(unexpected);
      expect(unexpectedMsg.title, 'Unexpected Error');
      expect(unexpectedMsg.actionLabel, 'Dismiss');
    });

    test('throws ArgumentError when passed an unsupported failure', () {
      const customFailure = InvalidCredentialsFailure();
      expect(mapper.canHandle(customFailure), isFalse);
      expect(() => mapper.map(customFailure), throwsA(isA<ArgumentError>()));
    });
  });

  group('BaseFeatureErrorMapper', () {
    const authMapper = AuthErrorMapper();

    test('correctly identifies handled failure types', () {
      expect(authMapper.canHandle(const InvalidCredentialsFailure()), isTrue);
      expect(authMapper.canHandle(const SessionExpiredFailure()), isTrue);
      expect(
        authMapper.canHandle(const NetworkFailure(message: 'net')),
        isFalse,
      );
    });

    test('throws ArgumentError if invoked with an unmatched failure type', () {
      expect(
        () => authMapper.map(const NetworkFailure(message: 'net')),
        throwsA(isA<ArgumentError>()),
      );
    });
  });

  group('CompositeErrorMapper Delegation Architecture', () {
    test('delegates to registered feature mappers in priority order', () {
      final composite = CompositeErrorMapper()
        ..register(const AuthErrorMapper())
        ..register(const CheckoutErrorMapper());

      final authMsg = composite.map(const InvalidCredentialsFailure());
      expect(authMsg.title, 'Authentication Failed');
      expect(authMsg.code, 'AUTH_001');

      final checkoutMsg = composite.map(
        const PaymentDeclinedFailure('Insufficient funds'),
      );
      expect(checkoutMsg.title, 'Payment Declined');
      expect(checkoutMsg.message, contains('Insufficient funds'));
    });

    test(
      'falls back to StandardErrorMapper for unhandled standard failures',
      () {
        final composite = CompositeErrorMapper()
          ..register(const AuthErrorMapper());

        final netMsg = composite.map(
          const NetworkFailure(message: 'Socket drop', isTimeout: false),
        );
        expect(netMsg.title, 'No Internet Connection');
        expect(netMsg.actionLabel, 'Retry');
      },
    );

    test('feature mappers take precedence over StandardErrorMapper', () {
      // Create a custom mapper that overrides NetworkFailure
      final customNetMapper = _CustomNetworkErrorMapper();
      final composite = CompositeErrorMapper()..register(customNetMapper);

      final netMsg = composite.map(
        const NetworkFailure(message: 'Socket drop', isTimeout: true),
      );
      expect(netMsg.title, 'Custom Network Alert');
    });

    test('highPriority inserts mapper at index 0', () {
      final composite = CompositeErrorMapper();
      composite.register(const AuthErrorMapper());
      composite.register(const _PriorityAuthMapper(), highPriority: true);

      final msg = composite.map(const InvalidCredentialsFailure());
      expect(msg.title, 'High Priority Override');
    });

    test(
      'translates raw unexpected runtime exceptions to fallback message',
      () {
        final composite = CompositeErrorMapper();
        final rawException = const FormatException('Corrupted JSON input');

        final msg = composite.map(rawException);
        expect(msg.title, 'Something went wrong');
        expect(msg.metadata?['cause'], contains('Corrupted JSON input'));
      },
    );

    test('custom fallback handler is called for unhandled errors', () {
      final composite = CompositeErrorMapper(
        includeStandardMapper: false,
        fallbackHandler: (err) =>
            UserMessage(title: 'Custom Fallback', message: 'Error was: $err'),
      );

      final msg = composite.map('string_error');
      expect(msg.title, 'Custom Fallback');
      expect(msg.message, 'Error was: string_error');
    });
  });
}

class _CustomNetworkErrorMapper implements FeatureErrorMapper {
  @override
  bool canHandle(Failure failure) => failure is NetworkFailure;

  @override
  UserMessage map(Failure failure) => const UserMessage(
    title: 'Custom Network Alert',
    message: 'Please check your router.',
  );
}

class _PriorityAuthMapper implements FeatureErrorMapper {
  const _PriorityAuthMapper();

  @override
  bool canHandle(Failure failure) => failure is InvalidCredentialsFailure;

  @override
  UserMessage map(Failure failure) => const UserMessage(
    title: 'High Priority Override',
    message: 'Overridden authentication failure.',
  );
}
