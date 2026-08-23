import 'package:flutter/material.dart';

/// A subject the student is enrolled in. Class meetings hang off this record.
@immutable
class Course {
  const Course({
    required this.id,
    required this.userId,
    required this.code,
    required this.title,
    required this.instructor,
    required this.colorValue,
    required this.createdAt,
    required this.updatedAt,
  });

  /// Palette offered when creating a course, chosen to stay legible as a chip
  /// background in both light and dark themes.
  static const List<int> palette = <int>[
    0xFF4F46E5,
    0xFF0EA5E9,
    0xFF10B981,
    0xFFF59E0B,
    0xFFE11D48,
    0xFF8B5CF6,
    0xFF14B8A6,
    0xFFEC4899,
  ];

  final String id;
  final String userId;
  final String code;
  final String title;
  final String instructor;
  final int colorValue;
  final DateTime createdAt;
  final DateTime updatedAt;

  Color get color => Color(colorValue);

  String get displayName => code.isEmpty ? title : '$code — $title';

  Course copyWith({
    String? code,
    String? title,
    String? instructor,
    int? colorValue,
    DateTime? updatedAt,
  }) => Course(
    id: id,
    userId: userId,
    code: code ?? this.code,
    title: title ?? this.title,
    instructor: instructor ?? this.instructor,
    colorValue: colorValue ?? this.colorValue,
    createdAt: createdAt,
    updatedAt: updatedAt ?? DateTime.now(),
  );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Course && other.id == id && other.updatedAt == updatedAt;

  @override
  int get hashCode => Object.hash(id, updatedAt);
}
