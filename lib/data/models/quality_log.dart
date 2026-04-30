import 'package:equatable/equatable.dart';

import 'enums.dart';

class QualityLog extends Equatable {
  const QualityLog({
    required this.id,
    required this.workOrderId,
    required this.inspectorId,
    required this.result,
    required this.inspectedAt,
    this.notes,
    this.inspectorName,
  });

  final String id;
  final String workOrderId;
  final String inspectorId;
  final QaResult result;
  final DateTime inspectedAt;
  final String? notes;
  final String? inspectorName;

  factory QualityLog.fromMap(Map<String, dynamic> map) {
    final inspector = map['user_profiles'] as Map<String, dynamic>?;
    return QualityLog(
      id: map['id'] as String,
      workOrderId: map['work_order_id'] as String,
      inspectorId: map['inspector_id'] as String,
      result: QaResult.fromString(map['result'] as String?),
      notes: map['notes'] as String?,
      inspectedAt: DateTime.parse(map['inspected_at'] as String),
      inspectorName: inspector?['full_name'] as String?,
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'work_order_id': workOrderId,
        'inspector_id': inspectorId,
        'result': result.wire,
        'notes': notes,
        'inspected_at': inspectedAt.toIso8601String(),
      };

  @override
  List<Object?> get props =>
      [id, workOrderId, inspectorId, result, notes, inspectedAt];
}
