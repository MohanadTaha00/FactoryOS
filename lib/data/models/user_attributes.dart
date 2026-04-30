import 'package:equatable/equatable.dart';

import 'enums.dart';

/// User-attributes object as described in section 4.3 of the report.
/// Encapsulates identity + role and exposes `getDashboardView()` for
/// role-based routing.
class UserAttributes extends Equatable {
  const UserAttributes({
    required this.id,
    required this.fullName,
    required this.role,
    this.email,
    this.createdAt,
  });

  final String id;
  final String fullName;
  final UserRole role;
  final String? email;
  final DateTime? createdAt;

  factory UserAttributes.fromMap(Map<String, dynamic> map) => UserAttributes(
        id: map['id'] as String,
        fullName: (map['full_name'] ?? map['fullName'] ?? '') as String,
        role: UserRole.fromString(map['role'] as String?),
        email: map['email'] as String?,
        createdAt: _parseDate(map['created_at']),
      );

  Map<String, dynamic> toMap() => {
        'id': id,
        'full_name': fullName,
        'role': role.wire,
        'email': email,
        'created_at': createdAt?.toIso8601String(),
      };

  /// Returns the route the app should redirect this user to after login.
  String getDashboardView() => switch (role) {
        UserRole.manager => '/manager',
        UserRole.worker => '/worker',
        UserRole.qa => '/qa',
        UserRole.admin => '/manager',
      };

  UserAttributes copyWith({
    String? fullName,
    UserRole? role,
    String? email,
  }) =>
      UserAttributes(
        id: id,
        fullName: fullName ?? this.fullName,
        role: role ?? this.role,
        email: email ?? this.email,
        createdAt: createdAt,
      );

  @override
  List<Object?> get props => [id, fullName, role, email];
}

DateTime? _parseDate(Object? value) {
  if (value == null) return null;
  if (value is DateTime) return value;
  return DateTime.tryParse(value.toString());
}
