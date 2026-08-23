/// Base type for every error the app raises deliberately.
///
/// Anything that escapes a repository is wrapped in one of these so the
/// presentation layer never has to reason about SQLite or platform errors.
sealed class AppException implements Exception {
  const AppException(this.message, {this.cause});

  final String message;
  final Object? cause;

  @override
  String toString() => '$runtimeType: $message';
}

/// The user supplied data that failed a domain rule.
class ValidationException extends AppException {
  const ValidationException(super.message, {super.cause});
}

/// Credentials were rejected, or the session is no longer trusted.
class AuthException extends AppException {
  const AuthException(super.message, {super.cause});
}

/// The local database or secure storage could not complete an operation.
class StorageException extends AppException {
  const StorageException(super.message, {super.cause});
}

/// A record was requested that does not exist (or is not owned by the caller).
class NotFoundException extends AppException {
  const NotFoundException(super.message, {super.cause});
}

/// The OS denied or does not offer a capability (biometrics, notifications).
class PlatformCapabilityException extends AppException {
  const PlatformCapabilityException(super.message, {super.cause});
}
