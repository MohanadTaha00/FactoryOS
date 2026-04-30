import 'package:equatable/equatable.dart';

import 'enums.dart';

class AppNotification extends Equatable {
  const AppNotification({
    required this.id,
    required this.recipientId,
    required this.title,
    required this.kind,
    required this.createdAt,
    this.workOrderId,
    this.body,
    this.readAt,
  });

  final String id;
  final String recipientId;
  final String? workOrderId;
  final String title;
  final String? body;
  final NotificationKind kind;
  final DateTime? readAt;
  final DateTime createdAt;

  bool get isUnread => readAt == null;

  factory AppNotification.fromMap(Map<String, dynamic> map) => AppNotification(
        id: map['id'] as String,
        recipientId: map['recipient_id'] as String,
        workOrderId: map['work_order_id'] as String?,
        title: map['title'] as String,
        body: map['body'] as String?,
        kind: NotificationKind.fromString(map['kind'] as String?),
        readAt: _date(map['read_at']),
        createdAt: DateTime.parse(map['created_at'] as String),
      );

  @override
  List<Object?> get props => [id, title, body, kind, readAt, createdAt];
}

DateTime? _date(Object? v) {
  if (v == null) return null;
  if (v is DateTime) return v;
  return DateTime.tryParse(v.toString());
}
