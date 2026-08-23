import 'package:sqflite_sqlcipher/sqflite.dart';

import '../../../../core/database/app_database.dart';
import '../../../../core/database/schema.dart';
import '../models/user_row.dart';

/// Raw persistence for accounts.
///
/// Every statement binds values as parameters rather than interpolating them
/// into SQL, which is what keeps user-supplied text from being executed.
class AuthLocalDataSource {
  AuthLocalDataSource(this._database);

  final AppDatabase _database;

  Future<UserRow?> findByEmail(String email) async {
    final db = await _database.instance;
    final rows = await db.query(
      Tables.users,
      where: 'email = ? COLLATE NOCASE',
      whereArgs: <Object?>[email],
      limit: 1,
    );
    return rows.isEmpty ? null : UserRow.fromMap(rows.first);
  }

  Future<UserRow?> findById(String id) async {
    final db = await _database.instance;
    final rows = await db.query(
      Tables.users,
      where: 'id = ?',
      whereArgs: <Object?>[id],
      limit: 1,
    );
    return rows.isEmpty ? null : UserRow.fromMap(rows.first);
  }

  Future<bool> emailExists(String email) async {
    final db = await _database.instance;
    final rows = await db.query(
      Tables.users,
      columns: <String>['id'],
      where: 'email = ? COLLATE NOCASE',
      whereArgs: <Object?>[email],
      limit: 1,
    );
    return rows.isNotEmpty;
  }

  Future<void> insert(UserRow user) async {
    final db = await _database.instance;
    await db.insert(
      Tables.users,
      user.toMap(),
      conflictAlgorithm: ConflictAlgorithm.abort,
    );
  }

  Future<void> updateProfile({
    required String id,
    required String fullName,
    required DateTime updatedAt,
  }) async {
    final db = await _database.instance;
    await db.update(
      Tables.users,
      <String, Object?>{
        'full_name': fullName,
        'updated_at': updatedAt.millisecondsSinceEpoch,
      },
      where: 'id = ?',
      whereArgs: <Object?>[id],
    );
  }

  Future<void> updatePasswordHash({
    required String id,
    required String passwordHash,
    required DateTime updatedAt,
  }) async {
    final db = await _database.instance;
    await db.update(
      Tables.users,
      <String, Object?>{
        'password_hash': passwordHash,
        'updated_at': updatedAt.millisecondsSinceEpoch,
      },
      where: 'id = ?',
      whereArgs: <Object?>[id],
    );
  }

  /// Child tables cascade, so this single delete clears all academic data.
  Future<void> delete(String id) async {
    final db = await _database.instance;
    await db.delete(Tables.users, where: 'id = ?', whereArgs: <Object?>[id]);
  }
}
