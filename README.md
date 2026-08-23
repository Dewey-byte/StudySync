# StudySync

A native mobile app that helps college students manage class schedules, assignment
deadlines and group project work in one place.

Built with Flutter for **Android and iOS**. It runs entirely offline: everything is
stored in an encrypted SQLite database on the device, and no data is sent to a server.

---

## The three key features

### 1. Smart Assignment Tracker

Record assignments, projects, quizzes and exams with a due date, a priority level and
an optional linked course. The app schedules an OS-level reminder ahead of each
deadline, and the list can be filtered by **Upcoming**, **Overdue**, **Completed** or
**All**. Reminders are withdrawn automatically when an item is ticked off.

### 2. Class Schedule Manager

Build a weekly timetable from your courses. Each class meeting has a weekday, a start
and end time, a room and its own reminder lead time. The timetable warns you before you
double-book a slot, highlights the class that is running right now, and any meeting can
be pushed to the device calendar as a recurring event.

### 3. Group Collaboration Hub

Create a group per project or organisation. Each group has members, shared tasks with
assignees and due dates, an announcement feed, and scheduled meetings with reminders.
Every group gets a short join code that can be shared with classmates.

A **dashboard** ties the three together: counts of what is due today, what is overdue
and what is done, plus the classes left today and the next deadlines and meetings.

---

## Why a native app rather than a web app

| Native capability | How StudySync uses it |
| --- | --- |
| Push / local notifications | Deadline, class and meeting reminders are handed to the OS scheduler, so they fire even when the app is closed |
| Offline access | All data lives in a local SQLite database; the app is fully usable with no connectivity |
| Calendar integration | Class meetings can be exported to the device calendar as recurring events |
| Background processing | Reminders are re-registered after a reboot through a boot receiver |
| Biometric authentication | Fingerprint or face unlock gates access to an existing session |

---

## Security

Security was a design constraint rather than an afterthought.

- **Encrypted database at rest.** All records live in a SQLCipher-encrypted SQLite
  file. The encryption key is generated on the device at first launch and stored in the
  Android Keystore / iOS Keychain, never in the database or in shared preferences. A
  copy of the database file taken off the device is unreadable.
- **Password hashing.** Passwords are salted per-user and hashed with PBKDF2-HMAC-SHA256
  at 150,000 iterations, run on a background isolate. Plaintext passwords are never
  stored or logged. Digests carry their own iteration count so the work factor can be
  raised later, and older digests are transparently upgraded on the next sign-in.
- **Constant-time verification.** Digest comparison does not short-circuit, so timing
  cannot reveal how much of a guess was correct.
- **No user enumeration.** Signing in with an unknown email verifies against a decoy
  digest, so an unregistered address takes the same time and returns the same message as
  a wrong password.
- **Biometric app lock.** Optional, and it only unlocks an existing session. Changing
  the password or deleting the account always requires the password, so an unlocked
  device is not enough to destroy a semester of records. Five consecutive failed
  biometric attempts end the session.
- **SQL injection.** Every statement binds values as parameters; no user input is ever
  concatenated into SQL.
- **Ownership checks in the data layer.** Reads and writes are scoped by `user_id` (or
  by the owning group) in the `WHERE` clause, not just in the UI.
- **Input validation at the boundary.** Repositories re-run the same validation rules as
  the forms, so a UI bug cannot write a malformed row.
- **Backups disabled.** Android cloud backup and device transfer are excluded, so the
  encrypted file is not copied somewhere its key cannot follow.

---

## Architecture

Feature-first clean architecture. Each feature owns three layers and depends only
inwards, so the local database could be swapped for a remote API without touching the
UI.

```
lib/
├── main.dart                      app entry point
├── app/                           cross-cutting app shell
│   ├── app.dart                   root MaterialApp
│   ├── router/                    go_router config + auth route guard
│   ├── shell/                     bottom navigation shell
│   └── theme/                     Material 3 theme
├── core/                          infrastructure shared by all features
│   ├── database/                  encrypted SQLite connection + schema
│   ├── errors/                    typed exception hierarchy
│   ├── notifications/             local notification scheduling
│   ├── providers/                 dependency injection composition root
│   ├── result/                    Result<T> success/failure wrapper
│   ├── security/                  password hashing, key store, biometrics
│   └── utils/                     validators, date formatting
├── features/
│   ├── assignments/               Smart Assignment Tracker
│   ├── auth/                      accounts, session, app lock
│   ├── dashboard/                 home summary
│   ├── groups/                    Group Collaboration Hub
│   ├── schedule/                  Class Schedule Manager
│   └── settings/                  security and account settings
└── shared/widgets/                reusable UI components
```

Every feature follows the same shape:

```
feature/
├── domain/          entities and repository interfaces (no Flutter, no SQL)
├── data/            SQL data sources, row mappers, repository implementations
└── presentation/    Riverpod controllers, pages and widgets
```

**State management** is Riverpod. Repositories return `Result<T>`, which forces callers
to handle the failure branch. A single `dataRevisionProvider` is bumped after every
write so a change in one feature refreshes any screen showing the affected data,
without features importing each other's providers.

---

## Getting started

### Requirements

- Flutter SDK 3.47 or newer (Dart 3.13+)
- Android Studio with the Android SDK, and/or Xcode for iOS
- A physical device is recommended: biometrics and exact-alarm reminders do not behave
  realistically on all emulators

### Run it

```bash
flutter pub get
flutter run
```

### Tests and static analysis

```bash
flutter analyze
flutter test
```

### Build status

Verified on Flutter 3.47.0 with JDK 21, Android SDK platform 36 and build-tools 36.0.0:
`flutter analyze` reports no issues, all 53 tests pass, and both `flutter build apk
--debug` and `flutter build apk --release` succeed. The iOS project targets iOS 15.0,
which clears the deployment target of every plugin used; building the iOS binary
requires macOS with Xcode.

Two toolchain workarounds are checked in and worth knowing about:

- `android/build.gradle.kts` clamps plugin modules to the app's `compileSdk`.
  `flutter_secure_storage` 11 asks for SDK 37, which the SDK manager now installs as
  `android-37.0` while AGP still resolves it as `android-37`. Drop the clamp once the
  two agree.
- `android/gradle.properties` disables Kotlin incremental compilation. Its caches store
  paths relative to the project root and fail outright when the pub cache sits on a
  different drive than the checkout, which is common on Windows.

---

## Notes on permissions

The app requests permissions only at the point they are needed:

- **Notifications** are requested from Settings → Reminders, which also re-registers
  every upcoming reminder. This is the repair path if alarms were lost to a reboot or
  the permission was granted late.
- **Exact alarms** (Android 12+) are requested alongside notifications so deadline
  reminders land on the minute rather than being batched.
- **Biometrics** are requested when biometric app lock is switched on, and the toggle
  only sticks if the verification actually succeeds.

If a reminder cannot be scheduled because a permission was denied, saving the record
still succeeds; the app never loses data because the OS refused an alarm.

---

## Known limitations

- Accounts are local to one device. There is no password reset, because there is no
  server that could verify identity, and the database key is device-bound.
- Group collaboration is modelled locally: the join code is intended for coordinating
  with classmates, but data is not synchronised between devices. The repository
  interfaces are written so a remote implementation can be added behind them.

---

## Credits

Built for **IT 126 – Mobile Development, Asynchronous Activity 1**
by Cleentson Dewey A. Lenterna, BSIT-4.
