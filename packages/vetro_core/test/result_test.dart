import 'package:test/test.dart';
import 'package:vetro_core/vetro_core.dart';

void main() {
  group('Result<T, E> Primitives', () {
    const successResult = Result<int, NetworkFailure>.success(42);
    const failureResult = Result<int, NetworkFailure>.failure(
      NetworkFailure(message: 'Timeout', isTimeout: true),
    );

    test('isSuccess and isFailure flags work symmetrically', () {
      expect(successResult.isSuccess, isTrue);
      expect(successResult.isFailure, isFalse);
      expect(successResult.dataOrNull, 42);
      expect(successResult.errorOrNull, isNull);

      expect(failureResult.isSuccess, isFalse);
      expect(failureResult.isFailure, isTrue);
      expect(failureResult.dataOrNull, isNull);
      expect(failureResult.errorOrNull?.message, 'Timeout');
    });

    test('pattern matching with Dart 3 switch expressions', () {
      final successMsg = switch (successResult) {
        Success(:final data) => 'OK: $data',
        FailureResult(:final error) => 'ERR: ${error.message}',
      };
      expect(successMsg, 'OK: 42');

      final failureMsg = switch (failureResult) {
        Success(:final data) => 'OK: $data',
        FailureResult(:final error) => 'ERR: ${error.message}',
      };
      expect(failureMsg, 'ERR: Timeout');
    });

    test('when invokes the appropriate callback', () {
      final s = successResult.when(
        success: (data) => 'Value: $data',
        failure: (err) => 'Failed: ${err.message}',
      );
      expect(s, 'Value: 42');

      final f = failureResult.when(
        success: (data) => 'Value: $data',
        failure: (err) => 'Failed: ${err.message}',
      );
      expect(f, 'Failed: Timeout');
    });

    test('map transforms success value and leaves failure untouched', () {
      final mappedSuccess = successResult.map((val) => 'val_$val');
      expect(
        mappedSuccess,
        equals(const Success<String, NetworkFailure>('val_42')),
      );

      final mappedFailure = failureResult.map((val) => 'val_$val');
      expect(mappedFailure, equals(failureResult));
    });

    test('mapError transforms error and leaves success untouched', () {
      final mappedSuccess = successResult.mapError(
        (err) => ServerFailure(message: err.message),
      );
      expect(mappedSuccess, equals(successResult));

      final mappedFailure = failureResult.mapError(
        (err) =>
            ServerFailure(message: 'Server: ${err.message}', statusCode: 504),
      );
      expect(
        mappedFailure,
        equals(
          const FailureResult<int, ServerFailure>(
            ServerFailure(message: 'Server: Timeout', statusCode: 504),
          ),
        ),
      );
    });

    test('flatMap chains dependent computations', () {
      Result<String, NetworkFailure> doubleToString(int n) =>
          Success('result_${n * 2}');

      final chainedSuccess = successResult.flatMap(doubleToString);
      expect(
        chainedSuccess,
        equals(const Success<String, NetworkFailure>('result_84')),
      );

      final chainedFailure = failureResult.flatMap(doubleToString);
      expect(chainedFailure, equals(failureResult));
    });

    test('fold resolves result to a single value', () {
      final s = successResult.fold((err) => -1, (data) => data * 2);
      expect(s, 84);

      final f = failureResult.fold((err) => -1, (data) => data * 2);
      expect(f, -1);
    });

    test('getOrElse returns value or executes fallback', () {
      expect(successResult.getOrElse((err) => 0), 42);
      expect(failureResult.getOrElse((err) => 999), 999);
    });

    test('getOrThrow returns data on success or throws failure/cause', () {
      expect(successResult.getOrThrow(), 42);

      expect(() => failureResult.getOrThrow(), throwsA(isA<NetworkFailure>()));

      final withCause = FailureResult<int, UnexpectedFailure>(
        UnexpectedFailure(
          message: 'Error with cause',
          cause: const FormatException('Invalid number'),
        ),
      );
      expect(() => withCause.getOrThrow(), throwsA(isA<FormatException>()));
    });

    test('equality and hashCode work as expected', () {
      const s1 = Success<int, NetworkFailure>(100);
      const s2 = Success<int, NetworkFailure>(100);
      const s3 = Success<int, NetworkFailure>(200);

      expect(s1, equals(s2));
      expect(s1.hashCode, equals(s2.hashCode));
      expect(s1, isNot(equals(s3)));

      const f1 = FailureResult<int, ServerFailure>(
        ServerFailure(message: 'fail', statusCode: 500),
      );
      const f2 = FailureResult<int, ServerFailure>(
        ServerFailure(message: 'fail', statusCode: 500),
      );
      const f3 = FailureResult<int, ServerFailure>(
        ServerFailure(message: 'fail', statusCode: 502),
      );

      expect(f1, equals(f2));
      expect(f1.hashCode, equals(f2.hashCode));
      expect(f1, isNot(equals(f3)));
      expect(s1, isNot(equals(f1)));
    });

    test('Result.guard captures synchronous computations and exceptions', () {
      final success = Result.guard(() => 10 + 5);
      expect(success, equals(const Success<int, Failure>(15)));

      final caughtFailure = Result.guard<int>(
        () => throw const ServerFailure(message: 'Explicit server failure'),
      );
      expect(caughtFailure.isFailure, isTrue);
      expect(
        caughtFailure.errorOrNull,
        equals(const ServerFailure(message: 'Explicit server failure')),
      );

      final caughtException = Result.guard<int>(
        () => throw const FormatException('Bad format'),
      );
      expect(caughtException.isFailure, isTrue);
      expect(caughtException.errorOrNull, isA<UnexpectedFailure>());
      expect(caughtException.errorOrNull?.cause, isA<FormatException>());
    });

    test(
      'Result.guardAsync captures asynchronous computations and errors',
      () async {
        final success = await Result.guardAsync(() async => 'hello');
        expect(success, equals(const Success<String, Failure>('hello')));

        final caughtFailure = await Result.guardAsync<String>(
          () async => throw const NotFoundFailure(message: 'Missing async doc'),
        );
        expect(caughtFailure.isFailure, isTrue);
        expect(
          caughtFailure.errorOrNull,
          equals(const NotFoundFailure(message: 'Missing async doc')),
        );

        final caughtException = await Result.guardAsync<String>(
          () async => throw StateError('Async crash'),
        );
        expect(caughtException.isFailure, isTrue);
        expect(caughtException.errorOrNull, isA<UnexpectedFailure>());
        expect(caughtException.errorOrNull?.cause, isA<StateError>());
      },
    );
  });
}
