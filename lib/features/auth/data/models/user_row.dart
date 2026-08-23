import '../../domain/entities/app_user.dart';

/// Database representation of a user, including the password digest.
///
/// Kept separate from [AppUser] so the hash stays inside the data layer and
/// cannot accidentally be handed to a widget.
class UserRow {
  const UserRow({
    required this.id,
    required this.fullName,
    required this.email,
    required this.passwordHash,
    required this.createdAt,
    required this.updatedAt,
  });

  factory UserRow.fromMap(Map<String, Object?> map) => UserRow(
    id: map['id']! as String,
    fullName: map['full_name']! as String,
    email: map['email']! as String,
    passwordHash: map['password_hash']! as String,
    createdAt: DateTime.fromMillisecondsSinceEpoch(map['created_at']! as int),
    updatedAt: DateTime.fromMillisecondsSinceEpoch(map['updated_at']! as int),
  );

  final String id;
  final String fullName;
  final String email;
  final String passwordHash;
  final DateTime createdAt;
  final DateTime updatedAt;

  Map<String, Object?> toMap() => <String, Object?>{
    'id': id,
    'full_name': fullName,
    'email': email,
    'password_hash': passwordHash,
    'created_at': createdAt.millisecondsSinceEpoch,
    'updated_at': updatedAt.millisecondsSinceEpoch,
  };

  AppUser toEntity() => AppUser(
    id: id,
    fullName: fullName,
    email: email,
    createdAt: createdAt,
  );
}
