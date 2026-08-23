import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../errors/app_exception.dart';

/// Owns every secret the app keeps on device.
///
/// Values live in the Android Keystore / iOS Keychain rather than in
/// SharedPreferences, so they are not readable from a filesystem dump or an
/// `adb backup`.
class SecureKeyStore {
  SecureKeyStore({FlutterSecureStorage? storage})
    : _storage =
          storage ??
          const FlutterSecureStorage(
            // AES-GCM with a hardware-backed, RSA-OAEP wrapped key.
            aOptions: AndroidOptions(storageNamespace: 'studysync'),
            iOptions: IOSOptions(
              // Readable after the first unlock so scheduled reminders can be
              // rebuilt in the background, but never synced to iCloud or
              // restored onto a different device.
              accessibility: KeychainAccessibility.first_unlock_this_device,
              synchronizable: false,
            ),
          );

  static const String _databaseKeyEntry = 'studysync.db.key';
  static const String _sessionUserEntry = 'studysync.session.user_id';
  static const String _biometricEnabledEntry = 'studysync.biometric.enabled';
  static const String _failedUnlockEntry = 'studysync.lock.failed_attempts';

  final FlutterSecureStorage _storage;

  /// Returns the SQLCipher passphrase, creating one on first launch.
  ///
  /// The key is generated on device and never leaves the keystore, so the
  /// encrypted database file is useless if copied off the phone.
  Future<String> readOrCreateDatabaseKey() async {
    try {
      final existing = await _storage.read(key: _databaseKeyEntry);
      if (existing != null && existing.isNotEmpty) return existing;

      final generated = _randomBase64(32);
      await _storage.write(key: _databaseKeyEntry, value: generated);
      return generated;
    } catch (e) {
      throw StorageException(
        'Could not initialise secure storage on this device.',
        cause: e,
      );
    }
  }

  Future<String?> readSessionUserId() => _storage.read(key: _sessionUserEntry);

  Future<void> writeSessionUserId(String userId) =>
      _storage.write(key: _sessionUserEntry, value: userId);

  Future<void> clearSession() async {
    await _storage.delete(key: _sessionUserEntry);
    await _storage.delete(key: _failedUnlockEntry);
  }

  Future<bool> isBiometricUnlockEnabled() async =>
      await _storage.read(key: _biometricEnabledEntry) == 'true';

  Future<void> setBiometricUnlockEnabled(bool enabled) => _storage.write(
    key: _biometricEnabledEntry,
    value: enabled ? 'true' : 'false',
  );

  Future<int> readFailedUnlockAttempts() async {
    final raw = await _storage.read(key: _failedUnlockEntry);
    return int.tryParse(raw ?? '') ?? 0;
  }

  Future<void> writeFailedUnlockAttempts(int attempts) => _storage.write(
    key: _failedUnlockEntry,
    value: attempts.toString(),
  );

  /// Wipes secrets, including the database key. Used by "delete my data"; the
  /// encrypted database becomes permanently unreadable afterwards.
  Future<void> wipe() => _storage.deleteAll();

  static String _randomBase64(int byteLength) {
    final random = Random.secure();
    final bytes = Uint8List(byteLength);
    for (var i = 0; i < byteLength; i++) {
      bytes[i] = random.nextInt(256);
    }
    return base64UrlEncode(bytes);
  }
}
