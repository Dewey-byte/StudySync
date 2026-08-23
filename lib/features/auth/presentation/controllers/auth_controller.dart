import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/providers/core_providers.dart';
import '../../../../core/result/result.dart';
import '../../../../core/security/biometric_service.dart';
import '../../../../core/security/secure_key_store.dart';
import '../../data/datasources/auth_local_data_source.dart';
import '../../data/repositories/auth_repository_impl.dart';
import '../../domain/entities/app_user.dart';
import '../../domain/repositories/auth_repository.dart';
import 'auth_state.dart';

final authRepositoryProvider = Provider<AuthRepository>(
  (ref) => AuthRepositoryImpl(
    localDataSource: AuthLocalDataSource(ref.watch(appDatabaseProvider)),
    passwordHasher: ref.watch(passwordHasherProvider),
    secureKeyStore: ref.watch(secureKeyStoreProvider),
    idGenerator: ref.watch(uuidProvider),
  ),
);

final authControllerProvider = NotifierProvider<AuthController, AuthState>(
  AuthController.new,
);

/// The signed-in user, or null. Feature controllers watch this so their data
/// is automatically scoped to the current account.
final currentUserProvider = Provider<AppUser?>(
  (ref) => ref.watch(authControllerProvider).user,
);

/// Owns the session lifecycle: restore, sign in/up/out, and app lock.
///
/// Methods return a nullable error message rather than throwing, so screens can
/// show inline feedback without try/catch blocks.
class AuthController extends Notifier<AuthState> {
  AuthRepository get _repository => ref.read(authRepositoryProvider);

  SecureKeyStore get _keyStore => ref.read(secureKeyStoreProvider);

  BiometricService get _biometrics => ref.read(biometricServiceProvider);

  @override
  AuthState build() {
    // build() must stay synchronous; restoring the session is kicked off
    // immediately and the UI shows a splash until it resolves.
    Future<void>.microtask(restoreSession);
    return const AuthState.unknown();
  }

  Future<void> restoreSession() async {
    final result = await _repository.restoreSession();

    state = await result.fold(
      onSuccess: (user) async {
        if (user == null) return const AuthState.signedOut();
        final lockEnabled = await _keyStore.isBiometricUnlockEnabled();
        return lockEnabled && await _biometrics.isAvailable()
            ? AuthState.locked(user)
            : AuthState.signedIn(user);
      },
      onFailure: (_) async => const AuthState.signedOut(),
    );
  }

  Future<String?> signUp({
    required String fullName,
    required String email,
    required String password,
  }) async {
    final result = await _repository.signUp(
      fullName: fullName,
      email: email,
      password: password,
    );
    return _applySignedIn(result);
  }

  Future<String?> signIn({
    required String email,
    required String password,
  }) async {
    final result = await _repository.signIn(email: email, password: password);
    return _applySignedIn(result);
  }

  Future<void> signOut() async {
    await _repository.signOut();
    await ref.read(notificationServiceProvider).cancelAll();
    state = const AuthState.signedOut();
  }

  /// Attempts a biometric unlock for a session that is currently [AuthStatus.locked].
  Future<BiometricResult> unlockWithBiometrics() async {
    final user = state.user;
    if (user == null) return BiometricResult.failed;

    final result = await _biometrics.authenticate();
    if (result == BiometricResult.success) {
      await _keyStore.writeFailedUnlockAttempts(0);
      state = AuthState.signedIn(user);
      return result;
    }

    // Repeated failures end the session, so a lost phone cannot be brute
    // forced against the biometric sensor indefinitely.
    if (result == BiometricResult.failed) {
      final attempts = await _keyStore.readFailedUnlockAttempts() + 1;
      await _keyStore.writeFailedUnlockAttempts(attempts);
      if (attempts >= 5) await signOut();
    }
    return result;
  }

  /// Falls back to the password when biometrics are unavailable or refused.
  Future<String?> unlockWithPassword(String password) async {
    final user = state.user;
    if (user == null) return 'Your session has expired. Please sign in again.';

    final result = await _repository.signIn(
      email: user.email,
      password: password,
    );
    return _applySignedIn(result);
  }

  /// Re-locks on demand, e.g. from the settings screen.
  void lock() {
    final user = state.user;
    if (user != null) state = AuthState.locked(user);
  }

  Future<String?> updateProfile(String fullName) async {
    final user = state.user;
    if (user == null) return 'You are not signed in.';

    final result = await _repository.updateProfile(
      userId: user.id,
      fullName: fullName,
    );
    return result.fold(
      onSuccess: (updated) {
        state = AuthState.signedIn(updated);
        return null;
      },
      onFailure: (error) => error.message,
    );
  }

  Future<String?> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    final user = state.user;
    if (user == null) return 'You are not signed in.';

    final result = await _repository.changePassword(
      userId: user.id,
      currentPassword: currentPassword,
      newPassword: newPassword,
    );
    return result.errorOrNull?.message;
  }

  Future<String?> deleteAccount(String password) async {
    final user = state.user;
    if (user == null) return 'You are not signed in.';

    final result = await _repository.deleteAccount(
      userId: user.id,
      password: password,
    );
    return result.fold(
      onSuccess: (_) async {
        await ref.read(notificationServiceProvider).cancelAll();
        state = const AuthState.signedOut();
        return null;
      },
      onFailure: (error) async => error.message,
    );
  }

  Future<bool> setBiometricUnlock(bool enabled) async {
    if (!enabled) {
      await _keyStore.setBiometricUnlockEnabled(false);
      return false;
    }
    // Prove the biometric works before relying on it to guard the session.
    if (await _biometrics.authenticate(
          reason: 'Confirm your identity to turn on biometric unlock',
        ) !=
        BiometricResult.success) {
      return false;
    }
    await _keyStore.setBiometricUnlockEnabled(true);
    return true;
  }

  String? _applySignedIn(Result<AppUser> result) => result.fold(
    onSuccess: (user) {
      state = AuthState.signedIn(user);
      return null;
    },
    onFailure: (error) => error.message,
  );
}
