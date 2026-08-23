import 'package:sqflite_sqlcipher/sqflite.dart';

import '../../../../core/database/app_database.dart';
import '../../../../core/database/schema.dart';
import '../../domain/entities/class_session.dart';
import '../../domain/entities/course.dart';
import '../models/schedule_mappers.dart';

/// SQL for courses and their weekly meetings.
class ScheduleLocalDataSource {
  ScheduleLocalDataSource(this._database);

  /// Course columns are aliased so they survive the join with `class_sessions`,
  /// which has columns of the same name.
  static const String _selectScheduledClass =
      '''
      SELECT
        s.*,
        c.id          AS c_id,
        c.user_id     AS c_user_id,
        c.code        AS c_code,
        c.title       AS c_title,
        c.instructor  AS c_instructor,
        c.color_value AS c_color_value,
        c.created_at  AS c_created_at,
        c.updated_at  AS c_updated_at
      FROM ${Tables.classSessions} s
      INNER JOIN ${Tables.courses} c ON c.id = s.course_id
      ''';

  final AppDatabase _database;

  Future<List<Course>> fetchCourses(String userId) async {
    final db = await _database.instance;
    final rows = await db.query(
      Tables.courses,
      where: 'user_id = ?',
      whereArgs: <Object?>[userId],
      orderBy: 'code COLLATE NOCASE ASC, title COLLATE NOCASE ASC',
    );
    return rows.map(CourseMapper.fromRow).toList(growable: false);
  }

  Future<Course?> findCourse(String id, String userId) async {
    final db = await _database.instance;
    final rows = await db.query(
      Tables.courses,
      where: 'id = ? AND user_id = ?',
      whereArgs: <Object?>[id, userId],
      limit: 1,
    );
    return rows.isEmpty ? null : CourseMapper.fromRow(rows.first);
  }

  Future<void> insertCourse(Course course) async {
    final db = await _database.instance;
    await db.insert(
      Tables.courses,
      CourseMapper.toColumns(course),
      conflictAlgorithm: ConflictAlgorithm.abort,
    );
  }

  Future<int> updateCourse(Course course) async {
    final db = await _database.instance;
    return db.update(
      Tables.courses,
      CourseMapper.toColumns(course),
      where: 'id = ? AND user_id = ?',
      whereArgs: <Object?>[course.id, course.userId],
    );
  }

  /// Sessions cascade with the course, so the caller only needs to cancel the
  /// matching notifications first.
  Future<int> deleteCourse(String id, String userId) async {
    final db = await _database.instance;
    return db.delete(
      Tables.courses,
      where: 'id = ? AND user_id = ?',
      whereArgs: <Object?>[id, userId],
    );
  }

  /// Every meeting for the week, ordered for direct rendering.
  Future<List<ScheduledClass>> fetchWeek(String userId) async {
    final db = await _database.instance;
    final rows = await db.rawQuery(
      '$_selectScheduledClass WHERE c.user_id = ? '
      'ORDER BY s.day_of_week ASC, s.start_minute ASC',
      <Object?>[userId],
    );
    return rows.map(ScheduledClassMapper.fromJoinedRow).toList(growable: false);
  }

  Future<List<ScheduledClass>> fetchForDay(String userId, int dayOfWeek) async {
    final db = await _database.instance;
    final rows = await db.rawQuery(
      '$_selectScheduledClass WHERE c.user_id = ? AND s.day_of_week = ? '
      'ORDER BY s.start_minute ASC',
      <Object?>[userId, dayOfWeek],
    );
    return rows.map(ScheduledClassMapper.fromJoinedRow).toList(growable: false);
  }

  Future<List<ClassSession>> fetchSessionsForCourse(String courseId) async {
    final db = await _database.instance;
    final rows = await db.query(
      Tables.classSessions,
      where: 'course_id = ?',
      whereArgs: <Object?>[courseId],
      orderBy: 'day_of_week ASC, start_minute ASC',
    );
    return rows.map(ClassSessionMapper.fromRow).toList(growable: false);
  }

  /// Overlapping meetings on the same weekday, excluding [excludeSessionId].
  ///
  /// Used to warn the student before they double-book themselves.
  Future<List<ScheduledClass>> findConflicts({
    required String userId,
    required int dayOfWeek,
    required int startMinute,
    required int endMinute,
    String? excludeSessionId,
  }) async {
    final db = await _database.instance;
    final rows = await db.rawQuery(
      '$_selectScheduledClass '
      'WHERE c.user_id = ? AND s.day_of_week = ? '
      'AND s.start_minute < ? AND s.end_minute > ? AND s.id != ? '
      'ORDER BY s.start_minute ASC',
      <Object?>[userId, dayOfWeek, endMinute, startMinute, excludeSessionId ?? ''],
    );
    return rows.map(ScheduledClassMapper.fromJoinedRow).toList(growable: false);
  }

  Future<void> insertSession(ClassSession session) async {
    final db = await _database.instance;
    await db.insert(
      Tables.classSessions,
      ClassSessionMapper.toColumns(session),
      conflictAlgorithm: ConflictAlgorithm.abort,
    );
  }

  Future<int> updateSession(ClassSession session) async {
    final db = await _database.instance;
    return db.update(
      Tables.classSessions,
      ClassSessionMapper.toColumns(session),
      where: 'id = ?',
      whereArgs: <Object?>[session.id],
    );
  }

  /// Ownership is enforced through the course, since sessions have no
  /// `user_id` of their own.
  Future<int> deleteSession(String sessionId, String userId) async {
    final db = await _database.instance;
    return db.delete(
      Tables.classSessions,
      where:
          'id = ? AND course_id IN '
          '(SELECT id FROM ${Tables.courses} WHERE user_id = ?)',
      whereArgs: <Object?>[sessionId, userId],
    );
  }
}
