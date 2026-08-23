import 'package:uuid/uuid.dart';

import '../../../../core/errors/app_exception.dart';
import '../../../../core/result/result.dart';
import '../../../../core/security/password_hasher.dart';
import '../../../../core/security/secure_key_store.dart';
import '../../../../core/utils/validators.dart';
import '../../domain/entities/app_user.dart';
import '../../domain/repositories/auth_repository.dart';
import '../datasources/auth_local_data_source.dart';
import '../models/user_row.dart';

class AuthRepositoryImpl implements AuthRepository {
  AuthRepositoryImpl({
    required AuthLocalDataSource localDataSource,
    required PasswordHasher passwordHasher,
    required SecureKeyStore secureKeyStore,
    Uuid idGenerator = const Uuid(),
  }) : _local = localDataSource,
       _hasher = passwordHasher,
       _keyStore = secureKeyStore,
       _uuid = idGenerator;

  /// Digest of a throwaway password, used to spend the same amount of time on
  /// a missing account as on a real one.
  static const String _decoyHash =
      r'pbkdf2_sha256$150000$c3R1ZHlzeW5jLWRlY295LXNhbHQ=$'
      r'MHhkZWNveWRpZ2VzdGZvcnRpbWluZ2VxdWFsaXNhdGlvbg==';

  static const String _invalidCredentials = 'Incorrect email or password.';

  final AuthLocalDataSource _local;
  final PasswordHasher _hasher;
  final SecureKeyStore _keyStore;
  final Uuid _uuid;

  @override
  Future<Result<AppUser>> signUp({
    required String fullName,
    required String email,
    required String password,
  }) => guard(() async {
    final cleanName = Validators.sanitize(fullName, maxLength: 80);
    final cleanEmail = Validators.sanitize(email, maxLength: 254).toLowerCase();

    final error = Validators.name(cleanName) ??
        Validators.email(cleanEmail) ??
        Validators.password(password);
    if (error != null) throw ValidationException(error);

    if (await _local.emailExists(cleanEmail)) {
      throw const ValidationException(
        'An account already exists for this email address.',
      );
    }

    final now = DateTime.now();
    final row = UserRow(
      id: _uuid.v4(),
      fullName: cleanName,
      email: cleanEmail,
      passwordHash: await _hasher.hash(password),
      createdAt: now,
      updatedAt: now,
    );

    await _local.insert(row);
    await _keyStore.writeSessionUserId(row.id);
    return row.toEntity();
  });

  @override
  Future<Result<AppUser>> signIn({
    required String email,
    required String password,
  }) => guard(() async {
    final cleanEmail = Validators.sanitize(email, maxLength: 254).toLowerCase();
    if (cleanEmail.isEmpty || password.isEmpty) {
      throw const AuthException(_invalidCredentials);
    }

    final row = await _local.findByEmail(cleanEmail);

    // Verify against a decoy when the account is unknown, so response time
    // does not disclose which email addresses are registered.
    if (row == null) {
      await _hasher.verify(password, _decoyHash);
      throw const AuthException(_invalidCredentials);
    }

    if (!await _hasher.verify(password, row.passwordHash)) {
      throw const AuthException(_invalidCredentials);
    }

    // Transparently strengthen digests created under older parameters.
    if (_hasher.needsRehash(row.passwordHash)) {
      await _local.updatePasswordHash(
        id: row.id,
        passwordHash: await _hasher.hash(password),
        updatedAt: DateTime.now(),
      );
    }

    await _keyStore.writeSessionUserId(row.id);
    return row.toEntity();
  });

  @override
  Future<Result<AppUser?>> restoreSession() => guard(() async {
    final userId = await _keyStore.readSessionUserId();
    if (userId == null) return null;

    final row = await _local.findById(userId);
    if (row == null) {
      // The account was removed; do not leave a dangling session behind.
      await _keyStore.clearSession();
      return null;
    }
    return row.toEntity();
  });

  @override
  Future<Result<void>> signOut() => guard(() => _keyStore.clearSession());

  @override
  Future<Result<AppUser>> updateProfile({
    required String userId,
    required String fullName,
  }) => guard(() async {
    final cleanName = Validators.sanitize(fullName, maxLength: 80);
    final error = Validators.name(cleanName);
    if (error != null) throw ValidationException(error);

    final now = DateTime.now();
    await _local.updateProfile(
      id: userId,
      fullName: cleanName,
      updatedAt: now,
    );

    final row = await _local.findById(userId);
    if (row == null) throw const NotFoundException('Account no longer exists.');
    return row.toEntity();
  });

  @override
  Future<Result<void>> changePassword({
    required String userId,
    required String currentPassword,
    required String newPassword,
  }) => guard(() async {
    final error = Validators.password(newPassword);
    if (error != null) throw ValidationException(error);
    if (currentPassword == newPassword) {
      throw const ValidationException(
        'Choose a password different from your current one.',
      );
    }

    final row = await _local.findById(userId);
    if (row == null) throw const NotFoundException('Account no longer exists.');

    if (!await _hasher.verify(currentPassword, row.passwordHash)) {
      throw const AuthException('Your current password is incorrect.');
    }

    await _local.updatePasswordHash(
      id: userId,
      passwordHash: await _hasher.hash(newPassword),
      updatedAt: DateTime.now(),
    );
  });

  @override
  Future<Result<void>> deleteAccount({
    required String userId,
    required String password,
  }) => guard(() async {
    final row = await _local.findById(userId);
    if (row == null) throw const NotFoundException('Account no longer exists.');

    // Re-authenticate: an unlocked device alone must not be enough to
    // destroy a semester's worth of records.
    if (!await _hasher.verify(password, row.passwordHash)) {
      throw const AuthException('Password is incorrect.');
    }

    await _local.delete(userId);
    await _keyStore.clearSession();
  });
}
