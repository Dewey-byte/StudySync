import 'package:flutter/foundation.dart';

/// A StudySync account holder.
///
/// Deliberately carries no password material, so a user object can be held in
/// UI state or logged without exposing credentials.
@immutable
class AppUser {
  const AppUser({
    required this.id,
    required this.fullName,
    required this.email,
    required this.createdAt,
  });

  final String id;
  final String fullName;
  final String email;
  final DateTime createdAt;

  String get initials {
    final parts = fullName.trim().split(RegExp(r'\s+'))
      ..removeWhere((part) => part.isEmpty);
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts.first[0].toUpperCase();
    return (parts.first[0] + parts.last[0]).toUpperCase();
  }

  String get firstName {
    final parts = fullName.trim().split(RegExp(r'\s+'));
    return parts.isEmpty ? fullName : parts.first;
  }

  AppUser copyWith({String? fullName, String? email}) => AppUser(
    id: id,
    fullName: fullName ?? this.fullName,
    email: email ?? this.email,
    createdAt: createdAt,
  );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AppUser &&
          other.id == id &&
          other.fullName == fullName &&
          other.email == email;

  @override
  int get hashCode => Object.hash(id, fullName, email);
}
