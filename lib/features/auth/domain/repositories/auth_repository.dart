import '../../../../core/result/result.dart';
import '../entities/app_user.dart';

/// Contract the presentation layer depends on, so the local-database
/// implementation can be swapped for a remote one without touching the UI.
abstract interface class AuthRepository {
  Future<Result<AppUser>> signUp({
    required String fullName,
    required String email,
    required String password,
  });

  Future<Result<AppUser>> signIn({
    required String email,
    required String password,
  });

  /// Returns the user referenced by the stored session, or null if there is
  /// no valid session to resume.
  Future<Result<AppUser?>> restoreSession();

  Future<Result<void>> signOut();

  Future<Result<AppUser>> updateProfile({
    required String userId,
    required String fullName,
  });

  Future<Result<void>> changePassword({
    required String userId,
    required String currentPassword,
    required String newPassword,
  });

  /// Removes the account and every record that cascades from it.
  Future<Result<void>> deleteAccount({
    required String userId,
    required String password,
  });
}
