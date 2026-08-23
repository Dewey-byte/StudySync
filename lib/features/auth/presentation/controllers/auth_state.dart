import 'package:flutter/foundation.dart';

import '../../domain/entities/app_user.dart';

enum AuthStatus {
  /// Still restoring a stored session; the UI shows a splash.
  unknown,
  unauthenticated,

  /// Signed in, but app lock is on and biometrics have not been passed yet.
  locked,
  authenticated,
}

@immutable
class AuthState {
  const AuthState({required this.status, this.user});

  const AuthState.unknown() : this(status: AuthStatus.unknown);

  const AuthState.signedOut() : this(status: AuthStatus.unauthenticated);

  const AuthState.locked(AppUser user)
    : this(status: AuthStatus.locked, user: user);

  const AuthState.signedIn(AppUser user)
    : this(status: AuthStatus.authenticated, user: user);

  final AuthStatus status;
  final AppUser? user;

  bool get isResolved => status != AuthStatus.unknown;

  bool get isAuthenticated => status == AuthStatus.authenticated;

  bool get isLocked => status == AuthStatus.locked;

  /// The signed-in user. Only call from screens that sit behind the router
  /// guard, where the session is guaranteed to exist.
  AppUser get requireUser {
    final current = user;
    if (current == null) {
      throw StateError('No authenticated user in state $status');
    }
    return current;
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AuthState && other.status == status && other.user == user;

  @override
  int get hashCode => Object.hash(status, user);
}
