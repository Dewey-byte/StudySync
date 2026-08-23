import '../errors/app_exception.dart';

/// A success-or-failure wrapper used as the return type of every repository
/// method, so callers are forced by the type system to handle both branches.
sealed class Result<T> {
  const Result();

  const factory Result.success(T value) = Success<T>;

  const factory Result.failure(AppException error) = Failure<T>;

  bool get isSuccess => this is Success<T>;

  T? get valueOrNull => switch (this) {
    Success<T>(:final value) => value,
    Failure<T>() => null,
  };

  AppException? get errorOrNull => switch (this) {
    Success<T>() => null,
    Failure<T>(:final error) => error,
  };

  R fold<R>({
    required R Function(T value) onSuccess,
    required R Function(AppException error) onFailure,
  }) => switch (this) {
    Success<T>(:final value) => onSuccess(value),
    Failure<T>(:final error) => onFailure(error),
  };

  Result<R> map<R>(R Function(T value) transform) => switch (this) {
    Success<T>(:final value) => Result<R>.success(transform(value)),
    Failure<T>(:final error) => Result<R>.failure(error),
  };
}

final class Success<T> extends Result<T> {
  const Success(this.value);

  final T value;
}

final class Failure<T> extends Result<T> {
  const Failure(this.error);

  final AppException error;
}

/// Runs [action] and converts anything thrown into a [Failure], keeping
/// low-level exceptions from leaking past the data layer.
Future<Result<T>> guard<T>(
  Future<T> Function() action, {
  String fallbackMessage = 'Something went wrong. Please try again.',
}) async {
  try {
    return Result.success(await action());
  } on AppException catch (e) {
    return Result.failure(e);
  } catch (e) {
    return Result.failure(StorageException(fallbackMessage, cause: e));
  }
}
