/// Table and column names in one place so queries never rely on loose strings
/// scattered across data sources.
abstract final class Tables {
  static const String users = 'users';
  static const String courses = 'courses';
  static const String classSessions = 'class_sessions';
  static const String assignments = 'assignments';
  static const String groups = 'study_groups';
  static const String groupMembers = 'group_members';
  static const String groupTasks = 'group_tasks';
  static const String groupAnnouncements = 'group_announcements';
  static const String groupMeetings = 'group_meetings';
  static const String appMeta = 'app_meta';
}

/// DDL for schema version 1.
///
/// Every child table declares `ON DELETE CASCADE` back to its owner so removing
/// an account cannot leave orphaned academic data behind.
const List<String> kSchemaV1 = <String>[
  '''
  CREATE TABLE ${Tables.users} (
    id            TEXT    PRIMARY KEY,
    full_name     TEXT    NOT NULL,
    email         TEXT    NOT NULL UNIQUE COLLATE NOCASE,
    password_hash TEXT    NOT NULL,
    created_at    INTEGER NOT NULL,
    updated_at    INTEGER NOT NULL
  )
  ''',
  '''
  CREATE TABLE ${Tables.courses} (
    id          TEXT    PRIMARY KEY,
    user_id     TEXT    NOT NULL REFERENCES ${Tables.users}(id) ON DELETE CASCADE,
    code        TEXT    NOT NULL,
    title       TEXT    NOT NULL,
    instructor  TEXT    NOT NULL DEFAULT '',
    color_value INTEGER NOT NULL,
    created_at  INTEGER NOT NULL,
    updated_at  INTEGER NOT NULL
  )
  ''',
  'CREATE INDEX idx_courses_user ON ${Tables.courses}(user_id)',
  '''
  CREATE TABLE ${Tables.classSessions} (
    id               TEXT    PRIMARY KEY,
    course_id        TEXT    NOT NULL REFERENCES ${Tables.courses}(id) ON DELETE CASCADE,
    day_of_week      INTEGER NOT NULL CHECK (day_of_week BETWEEN 1 AND 7),
    start_minute     INTEGER NOT NULL CHECK (start_minute BETWEEN 0 AND 1439),
    end_minute       INTEGER NOT NULL CHECK (end_minute BETWEEN 0 AND 1439),
    room             TEXT    NOT NULL DEFAULT '',
    reminder_minutes INTEGER NOT NULL DEFAULT 15,
    notification_id  INTEGER NOT NULL,
    created_at       INTEGER NOT NULL,
    updated_at       INTEGER NOT NULL
  )
  ''',
  'CREATE INDEX idx_sessions_course ON ${Tables.classSessions}(course_id)',
  'CREATE INDEX idx_sessions_day ON ${Tables.classSessions}(day_of_week)',
  '''
  CREATE TABLE ${Tables.assignments} (
    id               TEXT    PRIMARY KEY,
    user_id          TEXT    NOT NULL REFERENCES ${Tables.users}(id) ON DELETE CASCADE,
    course_id        TEXT             REFERENCES ${Tables.courses}(id) ON DELETE SET NULL,
    title            TEXT    NOT NULL,
    details          TEXT    NOT NULL DEFAULT '',
    category         TEXT    NOT NULL,
    priority         TEXT    NOT NULL,
    status           TEXT    NOT NULL,
    due_at           INTEGER NOT NULL,
    reminder_minutes INTEGER NOT NULL DEFAULT 1440,
    notification_id  INTEGER NOT NULL,
    completed_at     INTEGER,
    created_at       INTEGER NOT NULL,
    updated_at       INTEGER NOT NULL
  )
  ''',
  'CREATE INDEX idx_assignments_user_due ON ${Tables.assignments}(user_id, due_at)',
  'CREATE INDEX idx_assignments_status ON ${Tables.assignments}(user_id, status)',
  '''
  CREATE TABLE ${Tables.groups} (
    id          TEXT    PRIMARY KEY,
    owner_id    TEXT    NOT NULL REFERENCES ${Tables.users}(id) ON DELETE CASCADE,
    name        TEXT    NOT NULL,
    description TEXT    NOT NULL DEFAULT '',
    join_code   TEXT    NOT NULL UNIQUE,
    created_at  INTEGER NOT NULL,
    updated_at  INTEGER NOT NULL
  )
  ''',
  'CREATE INDEX idx_groups_owner ON ${Tables.groups}(owner_id)',
  '''
  CREATE TABLE ${Tables.groupMembers} (
    id           TEXT    PRIMARY KEY,
    group_id     TEXT    NOT NULL REFERENCES ${Tables.groups}(id) ON DELETE CASCADE,
    display_name TEXT    NOT NULL,
    role         TEXT    NOT NULL,
    joined_at    INTEGER NOT NULL
  )
  ''',
  'CREATE INDEX idx_members_group ON ${Tables.groupMembers}(group_id)',
  '''
  CREATE TABLE ${Tables.groupTasks} (
    id          TEXT    PRIMARY KEY,
    group_id    TEXT    NOT NULL REFERENCES ${Tables.groups}(id) ON DELETE CASCADE,
    assignee_id TEXT             REFERENCES ${Tables.groupMembers}(id) ON DELETE SET NULL,
    title       TEXT    NOT NULL,
    details     TEXT    NOT NULL DEFAULT '',
    status      TEXT    NOT NULL,
    due_at      INTEGER,
    created_at  INTEGER NOT NULL,
    updated_at  INTEGER NOT NULL
  )
  ''',
  'CREATE INDEX idx_group_tasks_group ON ${Tables.groupTasks}(group_id)',
  '''
  CREATE TABLE ${Tables.groupAnnouncements} (
    id          TEXT    PRIMARY KEY,
    group_id    TEXT    NOT NULL REFERENCES ${Tables.groups}(id) ON DELETE CASCADE,
    author_name TEXT    NOT NULL,
    message     TEXT    NOT NULL,
    created_at  INTEGER NOT NULL
  )
  ''',
  'CREATE INDEX idx_announcements_group ON ${Tables.groupAnnouncements}(group_id, created_at)',
  '''
  CREATE TABLE ${Tables.groupMeetings} (
    id               TEXT    PRIMARY KEY,
    group_id         TEXT    NOT NULL REFERENCES ${Tables.groups}(id) ON DELETE CASCADE,
    title            TEXT    NOT NULL,
    location         TEXT    NOT NULL DEFAULT '',
    scheduled_at     INTEGER NOT NULL,
    reminder_minutes INTEGER NOT NULL DEFAULT 30,
    notification_id  INTEGER NOT NULL,
    created_at       INTEGER NOT NULL
  )
  ''',
  'CREATE INDEX idx_meetings_group ON ${Tables.groupMeetings}(group_id, scheduled_at)',
  '''
  CREATE TABLE ${Tables.appMeta} (
    key   TEXT PRIMARY KEY,
    value TEXT NOT NULL
  )
  ''',
];
