import 'package:flutter/foundation.dart';

/// Application user profile stored in the public `users` table.
@immutable
class AppUser {
  final String id; // matches auth.users.id
  final String? email;
  final String? displayName;
  final DateTime createdAt;
  final DateTime updatedAt;

  const AppUser({
    required this.id,
    required this.createdAt,
    required this.updatedAt,
    this.email,
    this.displayName,
  });

  AppUser copyWith({
    String? id,
    String? email,
    String? displayName,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return AppUser(
      id: id ?? this.id,
      email: email ?? this.email,
      displayName: displayName ?? this.displayName,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'email': email,
        'display_name': displayName,
        'created_at': createdAt.toIso8601String(),
        'updated_at': updatedAt.toIso8601String(),
      };

  static AppUser fromJson(Map<String, dynamic> json) {
    DateTime parseDate(dynamic v) {
      if (v is DateTime) return v;
      if (v is String) return DateTime.parse(v);
      throw ArgumentError('Invalid datetime value: $v');
    }

    return AppUser(
      id: (json['id'] ?? '') as String,
      email: json['email'] as String?,
      displayName: json['display_name'] as String?,
      createdAt: parseDate(json['created_at']),
      updatedAt: parseDate(json['updated_at']),
    );
  }
}
