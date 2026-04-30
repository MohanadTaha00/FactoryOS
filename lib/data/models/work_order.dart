import 'package:equatable/equatable.dart';

import 'enums.dart';
import 'material_consumption.dart';
import 'quality_log.dart';

/// Class WorkOrder -- centre of the system's domain model.
/// Encapsulates production task data + state-machine helpers
/// (per section 4.3 of the report).
class WorkOrder extends Equatable {
  const WorkOrder({
    required this.id,
    required this.code,
    required this.title,
    required this.status,
    required this.priority,
    required this.createdBy,
    required this.quantityTarget,
    required this.quantityProduced,
    required this.createdAt,
    this.description,
    this.assignedTo,
    this.qaAssignedTo,
    this.dueAt,
    this.startedAt,
    this.submittedForQaAt,
    this.approvedAt,
    this.completedAt,
    this.updatedAt,
    this.materials = const <MaterialConsumption>[],
    this.qualityLogs = const <QualityLog>[],
    this.assignedToName,
    this.qaAssignedToName,
    this.createdByName,
    this.attachmentUrl,
  });

  final String id;
  final String code;
  final String title;
  final String? description;
  final WorkOrderStatus status;
  final int priority;
  final String createdBy;
  final String? assignedTo;
  final String? qaAssignedTo;
  final int quantityTarget;
  final int quantityProduced;
  final DateTime createdAt;
  final DateTime? dueAt;
  final DateTime? startedAt;
  final DateTime? submittedForQaAt;
  final DateTime? approvedAt;
  final DateTime? completedAt;
  final DateTime? updatedAt;

  final List<MaterialConsumption> materials;
  final List<QualityLog> qualityLogs;

  // Joined display fields.
  final String? assignedToName;
  final String? qaAssignedToName;
  final String? createdByName;
  final String? attachmentUrl;

  // ----- Behaviour -----------------------------------------------------------

  /// Heuristic: estimated completion date.  Uses started_at + a per-priority
  /// nominal duration when the order is in flight, falls back to due date
  /// otherwise.
  DateTime? calculateCompletionDate() {
    if (completedAt != null) return completedAt;
    if (approvedAt != null) return approvedAt;
    if (startedAt != null) {
      final hours = switch (priority) {
        1 => 4,
        2 => 8,
        3 => 16,
        4 => 32,
        _ => 48,
      };
      return startedAt!.add(Duration(hours: hours));
    }
    return dueAt;
  }

  /// Time spent on the production floor.
  Duration? productionDuration() {
    final start = startedAt;
    final end = submittedForQaAt ?? approvedAt ?? completedAt ?? DateTime.now();
    if (start == null) return null;
    return end.difference(start);
  }

  /// Sync-latency metric used in the report.  Returns the wall-clock delay
  /// between creation and the order first appearing as `assigned`.
  Duration? assignmentLatency() {
    final assignedEvent = startedAt ?? submittedForQaAt;
    if (assignedEvent == null) return null;
    return assignedEvent.difference(createdAt);
  }

  bool get canBeStartedBy {
    return status == WorkOrderStatus.assigned ||
        status == WorkOrderStatus.rejected;
  }

  String? get latestRevisionNotes {
    for (final log in qualityLogs.reversed) {
      if (log.result == QaResult.fail &&
          (log.notes?.trim().isNotEmpty ?? false)) {
        return log.notes!.trim();
      }
    }
    return null;
  }

  factory WorkOrder.fromMap(Map<String, dynamic> map) {
    List<MaterialConsumption> materials = const [];
    if (map['material_consumption'] is List) {
      materials = (map['material_consumption'] as List)
          .whereType<Map<String, dynamic>>()
          .map(MaterialConsumption.fromMap)
          .toList();
    }
    List<QualityLog> logs = const [];
    if (map['quality_logs'] is List) {
      logs = (map['quality_logs'] as List)
          .whereType<Map<String, dynamic>>()
          .map(QualityLog.fromMap)
          .toList();
    }

    final assigned = map['assigned_user'] as Map<String, dynamic>?;
    final qa = map['qa_user'] as Map<String, dynamic>?;
    final creator = map['creator'] as Map<String, dynamic>?;

    return WorkOrder(
      id: map['id'] as String,
      code: map['code'] as String,
      title: map['title'] as String,
      description: map['description'] as String?,
      status: WorkOrderStatus.fromString(map['status'] as String?),
      priority: (map['priority'] ?? 3) as int,
      createdBy: map['created_by'] as String,
      assignedTo: map['assigned_to'] as String?,
      qaAssignedTo: map['qa_assigned_to'] as String?,
      quantityTarget: (map['quantity_target'] ?? 1) as int,
      quantityProduced: (map['quantity_produced'] ?? 0) as int,
      createdAt: DateTime.parse(map['created_at'] as String),
      dueAt: _date(map['due_at']),
      startedAt: _date(map['started_at']),
      submittedForQaAt: _date(map['submitted_for_qa_at']),
      approvedAt: _date(map['approved_at']),
      completedAt: _date(map['completed_at']),
      updatedAt: _date(map['updated_at']),
      materials: materials,
      qualityLogs: logs,
      assignedToName: assigned?['full_name'] as String?,
      qaAssignedToName: qa?['full_name'] as String?,
      createdByName: creator?['full_name'] as String?,
      attachmentUrl: map['attachment_url'] as String?,
    );
  }

  Map<String, dynamic> toInsertMap() => {
    'code': code,
    'title': title,
    'description': description,
    'status': status.wire,
    'priority': priority,
    'created_by': createdBy,
    'assigned_to': assignedTo,
    'qa_assigned_to': qaAssignedTo,
    'quantity_target': quantityTarget,
    'quantity_produced': quantityProduced,
    'due_at': dueAt?.toIso8601String(),
    'attachment_url': attachmentUrl,
  };

  WorkOrder copyWith({
    WorkOrderStatus? status,
    String? assignedTo,
    String? qaAssignedTo,
    int? priority,
    int? quantityProduced,
    DateTime? dueAt,
    String? title,
    String? description,
    String? attachmentUrl,
  }) => WorkOrder(
    id: id,
    code: code,
    title: title ?? this.title,
    description: description ?? this.description,
    status: status ?? this.status,
    priority: priority ?? this.priority,
    createdBy: createdBy,
    assignedTo: assignedTo ?? this.assignedTo,
    qaAssignedTo: qaAssignedTo ?? this.qaAssignedTo,
    quantityTarget: quantityTarget,
    quantityProduced: quantityProduced ?? this.quantityProduced,
    createdAt: createdAt,
    dueAt: dueAt ?? this.dueAt,
    startedAt: startedAt,
    submittedForQaAt: submittedForQaAt,
    approvedAt: approvedAt,
    completedAt: completedAt,
    updatedAt: updatedAt,
    materials: materials,
    qualityLogs: qualityLogs,
    assignedToName: assignedToName,
    qaAssignedToName: qaAssignedToName,
    createdByName: createdByName,
    attachmentUrl: attachmentUrl ?? this.attachmentUrl,
  );

  @override
  List<Object?> get props => [
    id,
    code,
    status,
    priority,
    assignedTo,
    qaAssignedTo,
    updatedAt,
  ];
}

DateTime? _date(Object? v) {
  if (v == null) return null;
  if (v is DateTime) return v;
  return DateTime.tryParse(v.toString());
}
