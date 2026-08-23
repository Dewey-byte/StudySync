import 'package:path/path.dart' as p;
import 'package:sqflite_sqlcipher/sqflite.dart';

import '../errors/app_exception.dart';
import '../security/secure_key_store.dart';
import 'schema.dart';

/// Opens and owns the single encrypted SQLite connection.
///
/// The file is encrypted with SQLCipher using a device-generated key held in
/// the platform keystore, so academic data at rest is unreadable without the
/// device unlocking that key.
class AppDatabase {
  AppDatabase(this._keyStore);

  static const int _schemaVersion = 1;
  static const String _databaseFileName = 'studysync.db';
  static const String _notificationCounterKey = 'notification_id_counter';

  final SecureKeyStore _keyStore;

  Database? _db;
  Future<Database>? _opening;

  Future<Database> get instance {
    final open = _db;
    if (open != null && open.isOpen) return Future<Database>.value(open);
    return _opening ??= _open();
  }

  Future<Database> _open() async {
    try {
      final key = await _keyStore.readOrCreateDatabaseKey();
      final path = p.join(await getDatabasesPath(), _databaseFileName);

      final db = await openDatabase(
        path,
        password: key,
        version: _schemaVersion,
        onConfigure: (db) async {
          // Referential integrity is off by default in SQLite.
          await db.execute('PRAGMA foreign_keys = ON');
        },
        onCreate: (db, version) async {
          final batch = db.batch();
          for (final statement in kSchemaV1) {
            batch.execute(statement);
          }
          batch.insert(Tables.appMeta, <String, Object?>{
            'key': _notificationCounterKey,
            'value': '1000',
          });
          await batch.commit(noResult: true);
        },
        onUpgrade: (db, oldVersion, newVersion) async {
          // Reserved for future migrations; v1 is the initial schema.
        },
      );

      _db = db;
      return db;
    } catch (e) {
      _opening = null;
      throw StorageException('Could not open the secure local database.',
          cause: e);
    }
  }

  /// Reserves a unique 31-bit id for an OS notification.
  ///
  /// Derived from a counter rather than a hash of the row id so two records can
  /// never silently overwrite each other's scheduled reminder.
  Future<int> reserveNotificationId() async {
    final db = await instance;
    return db.transaction<int>((txn) async {
      final rows = await txn.query(
        Tables.appMeta,
        columns: <String>['value'],
        where: 'key = ?',
        whereArgs: <Object?>[_notificationCounterKey],
        limit: 1,
      );
      final current = rows.isEmpty
          ? 1000
          : int.tryParse(rows.first['value'] as String? ?? '') ?? 1000;
      final next = current >= 0x7ffffffe ? 1000 : current + 1;
      await txn.update(
        Tables.appMeta,
        <String, Object?>{'value': next.toString()},
        where: 'key = ?',
        whereArgs: <Object?>[_notificationCounterKey],
      );
      return current;
    });
  }

  Future<void> close() async {
    await _db?.close();
    _db = null;
    _opening = null;
  }

  /// Deletes the encrypted database file. Paired with [SecureKeyStore.wipe]
  /// when the user asks for their data to be removed.
  Future<void> deleteDatabaseFile() async {
    await close();
    await deleteDatabase(p.join(await getDatabasesPath(), _databaseFileName));
  }
}
