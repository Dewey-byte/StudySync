import 'package:sqflite_sqlcipher/sqflite.dart';

import '../../../../core/database/app_database.dart';
import '../../../../core/database/schema.dart';
import '../../domain/entities/assignment.dart';
import '../models/assignment_mapper.dart';

/// SQL for the assignment tracker.
///
/// Reads join the owning course so a list can be rendered from a single query,
/// and every predicate is parameterised.
class AssignmentLocalDataSource {
  AssignmentLocalDataSource(this._database);

  static const String _selectWithCourse =
      '''
      SELECT a.*, c.code AS course_code, c.color_value AS course_color
      FROM ${Tables.assignments} a
      LEFT JOIN ${Tables.courses} c ON c.id = a.course_id
      ''';

  /// Highest priority first when two items fall due at the same moment.
  static const String _priorityOrder =
      "CASE a.priority WHEN 'high' THEN 0 WHEN 'medium' THEN 1 ELSE 2 END";

  final AppDatabase _database;

  Future<List<Assignment>> fetchForUser(
    String userId, {
    required AssignmentFilter filter,
  }) async {
    final db = await _database.instance;
    final now = DateTime.now().millisecondsSinceEpoch;

    final (String predicate, List<Object?> args) = switch (filter) {
      AssignmentFilter.upcoming => (
        "a.user_id = ? AND a.status != 'completed' AND a.due_at >= ?",
        <Object?>[userId, now],
      ),
      AssignmentFilter.overdue => (
        "a.user_id = ? AND a.status != 'completed' AND a.due_at < ?",
        <Object?>[userId, now],
      ),
      AssignmentFilter.completed => (
        "a.user_id = ? AND a.status = 'completed'",
        <Object?>[userId],
      ),
      AssignmentFilter.all => ('a.user_id = ?', <Object?>[userId]),
    };

    final descending = filter == AssignmentFilter.completed;
    final rows = await db.rawQuery(
      '$_selectWithCourse WHERE $predicate '
      'ORDER BY a.due_at ${descending ? 'DESC' : 'ASC'}, $_priorityOrder ASC',
      args,
    );
    return rows.map(AssignmentMapper.fromRow).toList(growable: false);
  }

  /// The soonest unfinished items, used by the dashboard summary.
  Future<List<Assignment>> fetchUpcoming(String userId, {int limit = 5}) async {
    final db = await _database.instance;
    final rows = await db.rawQuery(
      '$_selectWithCourse '
      "WHERE a.user_id = ? AND a.status != 'completed' "
      'ORDER BY a.due_at ASC, $_priorityOrder ASC LIMIT ?',
      <Object?>[userId, limit],
    );
    return rows.map(AssignmentMapper.fromRow).toList(growable: false);
  }

  Future<Assignment?> findById(String id, String userId) async {
    final db = await _database.instance;
    final rows = await db.rawQuery(
      '$_selectWithCourse WHERE a.id = ? AND a.user_id = ? LIMIT 1',
      <Object?>[id, userId],
    );
    return rows.isEmpty ? null : AssignmentMapper.fromRow(rows.first);
  }

  /// Counts by bucket for the dashboard, in one pass over the index.
  Future<({int dueToday, int overdue, int completed})> counts(
    String userId,
  ) async {
    final db = await _database.instance;
    final now = DateTime.now();
    final startOfDay = DateTime(now.year, now.month, now.day);
    final endOfDay = startOfDay.add(const Duration(days: 1));

    final rows = await db.rawQuery(
      '''
      SELECT
        SUM(CASE WHEN status != 'completed' AND due_at >= ? AND due_at < ?
                 THEN 1 ELSE 0 END) AS due_today,
        SUM(CASE WHEN status != 'completed' AND due_at < ?
                 THEN 1 ELSE 0 END) AS overdue,
        SUM(CASE WHEN status = 'completed' THEN 1 ELSE 0 END) AS completed
      FROM ${Tables.assignments}
      WHERE user_id = ?
      ''',
      <Object?>[
        startOfDay.millisecondsSinceEpoch,
        endOfDay.millisecondsSinceEpoch,
        now.millisecondsSinceEpoch,
        userId,
      ],
    );

    final row = rows.first;
    return (
      dueToday: (row['due_today'] as int?) ?? 0,
      overdue: (row['overdue'] as int?) ?? 0,
      completed: (row['completed'] as int?) ?? 0,
    );
  }

  Future<void> insert(Assignment assignment) async {
    final db = await _database.instance;
    await db.insert(
      Tables.assignments,
      AssignmentMapper.toColumns(assignment),
      conflictAlgorithm: ConflictAlgorithm.abort,
    );
  }

  /// Scoped by `user_id` as well as `id`, so a stale or tampered identifier
  /// cannot modify another account's row.
  Future<int> update(Assignment assignment) async {
    final db = await _database.instance;
    return db.update(
      Tables.assignments,
      AssignmentMapper.toColumns(assignment),
      where: 'id = ? AND user_id = ?',
      whereArgs: <Object?>[assignment.id, assignment.userId],
    );
  }

  Future<int> delete(String id, String userId) async {
    final db = await _database.instance;
    return db.delete(
      Tables.assignments,
      where: 'id = ? AND user_id = ?',
      whereArgs: <Object?>[id, userId],
    );
  }

  Future<List<Assignment>> fetchPendingWithReminders(String userId) async {
    final db = await _database.instance;
    final rows = await db.rawQuery(
      '$_selectWithCourse '
      "WHERE a.user_id = ? AND a.status != 'completed' AND a.due_at >= ? "
      'ORDER BY a.due_at ASC',
      <Object?>[userId, DateTime.now().millisecondsSinceEpoch],
    );
    return rows.map(AssignmentMapper.fromRow).toList(growable: false);
  }
}
