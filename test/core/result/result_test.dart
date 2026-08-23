import 'package:flutter_test/flutter_test.dart';
import 'package:studysync/core/errors/app_exception.dart';
import 'package:studysync/core/result/result.dart';

void main() {
  group('Result', () {
    test('success carries its value', () {
      const result = Result<int>.success(42);

      expect(result.isSuccess, isTrue);
      expect(result.valueOrNull, 42);
      expect(result.errorOrNull, isNull);
    });

    test('failure carries its error', () {
      const result = Result<int>.failure(ValidationException('bad input'));

      expect(result.isSuccess, isFalse);
      expect(result.valueOrNull, isNull);
      expect(result.errorOrNull?.message, 'bad input');
    });

    test('fold runs exactly one branch', () {
      expect(
        const Result<int>.success(2).fold(
          onSuccess: (value) => 'ok $value',
          onFailure: (error) => 'err',
        ),
        'ok 2',
      );
      expect(
        const Result<int>.failure(AuthException('nope')).fold(
          onSuccess: (value) => 'ok',
          onFailure: (error) => 'err ${error.message}',
        ),
        'err nope',
      );
    });

    test('map transforms a success and passes a failure through', () {
      expect(const Result<int>.success(3).map((v) => v * 2).valueOrNull, 6);

      const failure = Result<int>.failure(StorageException('disk'));
      expect(failure.map((v) => v * 2).errorOrNull?.message, 'disk');
    });
  });

  group('guard', () {
    test('wraps a returned value in a success', () async {
      final result = await guard<int>(() async => 7);

      expect(result.valueOrNull, 7);
    });

    test('passes an AppException through unchanged', () async {
      final result = await guard<int>(
        () async => throw const ValidationException('too long'),
      );

      expect(result.errorOrNull, isA<ValidationException>());
      expect(result.errorOrNull?.message, 'too long');
    });

    test('converts an unexpected error into a StorageException', () async {
      final result = await guard<int>(
        () async => throw StateError('unexpected'),
        fallbackMessage: 'Could not save.',
      );

      expect(result.errorOrNull, isA<StorageException>());
      expect(result.errorOrNull?.message, 'Could not save.');
      expect(result.errorOrNull?.cause, isA<StateError>());
    });
  });
}
