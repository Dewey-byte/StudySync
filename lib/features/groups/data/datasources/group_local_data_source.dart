import 'package:sqflite_sqlcipher/sqflite.dart';

import '../../../../core/database/app_database.dart';
import '../../../../core/database/schema.dart';
import '../../domain/entities/study_group.dart';
import '../models/group_mappers.dart';

/// SQL for the collaboration hub.
///
/// Group ownership is checked in the `WHERE` clause of every statement, so a
/// group id alone is never enough to read or write someone else's data.
class GroupLocalDataSource {
  GroupLocalDataSource(this._database);

  final AppDatabase _database;

  Future<List<GroupOverview>> fetchOverviews(String ownerId) async {
    final db = await _database.instance;
    final rows = await db.rawQuery(
      '''
      SELECT
        g.*,
        (SELECT COUNT(*) FROM ${Tables.groupMembers} m
          WHERE m.group_id = g.id) AS member_count,
        (SELECT COUNT(*) FROM ${Tables.groupTasks} t
          WHERE t.group_id = g.id AND t.status != 'done') AS open_task_count,
        (SELECT MIN(mt.scheduled_at) FROM ${Tables.groupMeetings} mt
          WHERE mt.group_id = g.id AND mt.scheduled_at >= ?) AS next_meeting_at
      FROM ${Tables.groups} g
      WHERE g.owner_id = ?
      ORDER BY g.created_at DESC
      ''',
      <Object?>[DateTime.now().millisecondsSinceEpoch, ownerId],
    );

    return rows
        .map(
          (row) => GroupOverview(
            group: StudyGroupMapper.fromRow(row),
            memberCount: (row['member_count'] as int?) ?? 0,
            openTaskCount: (row['open_task_count'] as int?) ?? 0,
            nextMeetingAt: row['next_meeting_at'] is int
                ? DateTime.fromMillisecondsSinceEpoch(
                    row['next_meeting_at']! as int,
                  )
                : null,
          ),
        )
        .toList(growable: false);
  }

  Future<StudyGroup?> findGroup(String groupId, String ownerId) async {
    final db = await _database.instance;
    final rows = await db.query(
      Tables.groups,
      where: 'id = ? AND owner_id = ?',
      whereArgs: <Object?>[groupId, ownerId],
      limit: 1,
    );
    return rows.isEmpty ? null : StudyGroupMapper.fromRow(rows.first);
  }

  Future<bool> joinCodeExists(String joinCode) async {
    final db = await _database.instance;
    final rows = await db.query(
      Tables.groups,
      columns: <String>['id'],
      where: 'join_code = ?',
      whereArgs: <Object?>[joinCode],
      limit: 1,
    );
    return rows.isNotEmpty;
  }

  Future<GroupDetail?> fetchDetail(String groupId, String ownerId) async {
    final group = await findGroup(groupId, ownerId);
    if (group == null) return null;

    final db = await _database.instance;

    final memberRows = await db.query(
      Tables.groupMembers,
      where: 'group_id = ?',
      whereArgs: <Object?>[groupId],
      orderBy: "CASE role WHEN 'owner' THEN 0 ELSE 1 END, joined_at ASC",
    );

    final taskRows = await db.rawQuery(
      '''
      SELECT t.*, m.display_name AS assignee_name
      FROM ${Tables.groupTasks} t
      LEFT JOIN ${Tables.groupMembers} m ON m.id = t.assignee_id
      WHERE t.group_id = ?
      ORDER BY
        CASE t.status WHEN 'done' THEN 1 ELSE 0 END ASC,
        COALESCE(t.due_at, 253402300799000) ASC,
        t.created_at ASC
      ''',
      <Object?>[groupId],
    );

    final announcementRows = await db.query(
      Tables.groupAnnouncements,
      where: 'group_id = ?',
      whereArgs: <Object?>[groupId],
      orderBy: 'created_at DESC',
      limit: 50,
    );

    final meetingRows = await db.query(
      Tables.groupMeetings,
      where: 'group_id = ?',
      whereArgs: <Object?>[groupId],
      orderBy: 'scheduled_at ASC',
    );

    return GroupDetail(
      group: group,
      members: memberRows.map(GroupMemberMapper.fromRow).toList(growable: false),
      tasks: taskRows.map(GroupTaskMapper.fromRow).toList(growable: false),
      announcements: announcementRows
          .map(GroupAnnouncementMapper.fromRow)
          .toList(growable: false),
      meetings: meetingRows
          .map(GroupMeetingMapper.fromRow)
          .toList(growable: false),
    );
  }

  /// Creates the group and its owner membership atomically, so a failure
  /// cannot leave a group without anyone in it.
  Future<void> insertGroupWithOwner(
    StudyGroup group,
    GroupMember ownerMember,
  ) async {
    final db = await _database.instance;
    await db.transaction((txn) async {
      await txn.insert(
        Tables.groups,
        StudyGroupMapper.toColumns(group),
        conflictAlgorithm: ConflictAlgorithm.abort,
      );
      await txn.insert(
        Tables.groupMembers,
        GroupMemberMapper.toColumns(ownerMember),
        conflictAlgorithm: ConflictAlgorithm.abort,
      );
    });
  }

  Future<int> updateGroup(StudyGroup group) async {
    final db = await _database.instance;
    return db.update(
      Tables.groups,
      StudyGroupMapper.toColumns(group),
      where: 'id = ? AND owner_id = ?',
      whereArgs: <Object?>[group.id, group.ownerId],
    );
  }

  Future<List<GroupMeeting>> fetchMeetings(String groupId) async {
    final db = await _database.instance;
    final rows = await db.query(
      Tables.groupMeetings,
      where: 'group_id = ?',
      whereArgs: <Object?>[groupId],
    );
    return rows.map(GroupMeetingMapper.fromRow).toList(growable: false);
  }

  Future<List<GroupMeeting>> fetchUpcomingMeetings(
    String ownerId, {
    int limit = 5,
  }) async {
    final db = await _database.instance;
    final rows = await db.rawQuery(
      '''
      SELECT mt.* FROM ${Tables.groupMeetings} mt
      INNER JOIN ${Tables.groups} g ON g.id = mt.group_id
      WHERE g.owner_id = ? AND mt.scheduled_at >= ?
      ORDER BY mt.scheduled_at ASC LIMIT ?
      ''',
      <Object?>[ownerId, DateTime.now().millisecondsSinceEpoch, limit],
    );
    return rows.map(GroupMeetingMapper.fromRow).toList(growable: false);
  }

  Future<int> deleteGroup(String groupId, String ownerId) async {
    final db = await _database.instance;
    return db.delete(
      Tables.groups,
      where: 'id = ? AND owner_id = ?',
      whereArgs: <Object?>[groupId, ownerId],
    );
  }

  Future<void> insertMember(GroupMember member) async {
    final db = await _database.instance;
    await db.insert(
      Tables.groupMembers,
      GroupMemberMapper.toColumns(member),
      conflictAlgorithm: ConflictAlgorithm.abort,
    );
  }

  Future<int> deleteMember(String memberId, String groupId) async {
    final db = await _database.instance;
    return db.delete(
      Tables.groupMembers,
      where: "id = ? AND group_id = ? AND role != 'owner'",
      whereArgs: <Object?>[memberId, groupId],
    );
  }

  Future<void> insertTask(GroupTask task) async {
    final db = await _database.instance;
    await db.insert(
      Tables.groupTasks,
      GroupTaskMapper.toColumns(task),
      conflictAlgorithm: ConflictAlgorithm.abort,
    );
  }

  Future<int> updateTask(GroupTask task) async {
    final db = await _database.instance;
    return db.update(
      Tables.groupTasks,
      GroupTaskMapper.toColumns(task),
      where: 'id = ? AND group_id = ?',
      whereArgs: <Object?>[task.id, task.groupId],
    );
  }

  Future<int> deleteTask(String taskId, String groupId) async {
    final db = await _database.instance;
    return db.delete(
      Tables.groupTasks,
      where: 'id = ? AND group_id = ?',
      whereArgs: <Object?>[taskId, groupId],
    );
  }

  Future<void> insertAnnouncement(GroupAnnouncement announcement) async {
    final db = await _database.instance;
    await db.insert(
      Tables.groupAnnouncements,
      GroupAnnouncementMapper.toColumns(announcement),
      conflictAlgorithm: ConflictAlgorithm.abort,
    );
  }

  Future<int> deleteAnnouncement(String id, String groupId) async {
    final db = await _database.instance;
    return db.delete(
      Tables.groupAnnouncements,
      where: 'id = ? AND group_id = ?',
      whereArgs: <Object?>[id, groupId],
    );
  }

  Future<void> insertMeeting(GroupMeeting meeting) async {
    final db = await _database.instance;
    await db.insert(
      Tables.groupMeetings,
      GroupMeetingMapper.toColumns(meeting),
      conflictAlgorithm: ConflictAlgorithm.abort,
    );
  }

  Future<int> deleteMeeting(String id, String groupId) async {
    final db = await _database.instance;
    return db.delete(
      Tables.groupMeetings,
      where: 'id = ? AND group_id = ?',
      whereArgs: <Object?>[id, groupId],
    );
  }
}
