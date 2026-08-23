import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../database/app_database.dart';
import '../notifications/notification_service.dart';
import '../security/biometric_service.dart';
import '../security/password_hasher.dart';
import '../security/secure_key_store.dart';

/// Single composition root for infrastructure. Features depend on these
/// providers rather than constructing services themselves, which keeps them
/// substitutable in tests via `ProviderScope(overrides: ...)`.

final secureKeyStoreProvider = Provider<SecureKeyStore>(
  (ref) => SecureKeyStore(),
);

final appDatabaseProvider = Provider<AppDatabase>((ref) {
  final database = AppDatabase(ref.watch(secureKeyStoreProvider));
  ref.onDispose(database.close);
  return database;
});

final passwordHasherProvider = Provider<PasswordHasher>(
  (ref) => const PasswordHasher(),
);

final biometricServiceProvider = Provider<BiometricService>(
  (ref) => BiometricService(),
);

final notificationServiceProvider = Provider<NotificationService>(
  (ref) => NotificationService(),
);

final uuidProvider = Provider<Uuid>((ref) => const Uuid());
