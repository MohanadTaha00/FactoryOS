/// Domain enumerations.  These map 1:1 to the PostgreSQL enums declared
/// in `supabase/01_schema.sql`.

import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';

/// Three "operational" roles plus an admin (super-user).
enum UserRole {
  manager,
  worker,
  qa,
  admin;

  static UserRole fromString(String? raw) {
    switch (raw) {
      case 'manager':
        return UserRole.manager;
      case 'worker':
        return UserRole.worker;
      case 'qa':
        return UserRole.qa;
      case 'admin':
        return UserRole.admin;
      default:
        return UserRole.worker;
    }
  }

  String get wire => name;

  String get label => switch (this) {
        UserRole.manager => 'Manager',
        UserRole.worker => 'Worker',
        UserRole.qa => 'Quality Assurance',
        UserRole.admin => 'Administrator',
      };

  IconData get icon => switch (this) {
        UserRole.manager => Icons.business_center_outlined,
        UserRole.worker => Icons.engineering_outlined,
        UserRole.qa => Icons.fact_check_outlined,
        UserRole.admin => Icons.admin_panel_settings_outlined,
      };
}

/// Deterministic Finite Automaton over a work order.  Allowed transitions:
///
/// ```text
///   pending ──assign──▶ assigned ──start──▶ in_progress ──submit──▶ ready_for_qa
///                                                ▲                        │
///                                                │                        ├─ approve ─▶ approved ─▶ completed
///                                                └────────────────────────┘
///                                                          reject
///   (any non-terminal) ──cancel──▶ cancelled
/// ```
enum WorkOrderStatus {
  pending,
  assigned,
  inProgress,
  readyForQa,
  approved,
  rejected,
  completed,
  cancelled;

  static WorkOrderStatus fromString(String? raw) {
    switch (raw) {
      case 'pending':
        return WorkOrderStatus.pending;
      case 'assigned':
        return WorkOrderStatus.assigned;
      case 'in_progress':
        return WorkOrderStatus.inProgress;
      case 'ready_for_qa':
        return WorkOrderStatus.readyForQa;
      case 'approved':
        return WorkOrderStatus.approved;
      case 'rejected':
        return WorkOrderStatus.rejected;
      case 'completed':
        return WorkOrderStatus.completed;
      case 'cancelled':
        return WorkOrderStatus.cancelled;
      default:
        return WorkOrderStatus.pending;
    }
  }

  String get wire => switch (this) {
        WorkOrderStatus.pending => 'pending',
        WorkOrderStatus.assigned => 'assigned',
        WorkOrderStatus.inProgress => 'in_progress',
        WorkOrderStatus.readyForQa => 'ready_for_qa',
        WorkOrderStatus.approved => 'approved',
        WorkOrderStatus.rejected => 'rejected',
        WorkOrderStatus.completed => 'completed',
        WorkOrderStatus.cancelled => 'cancelled',
      };

  String get label => switch (this) {
        WorkOrderStatus.pending => 'Pending',
        WorkOrderStatus.assigned => 'Assigned',
        WorkOrderStatus.inProgress => 'In progress',
        WorkOrderStatus.readyForQa => 'Ready for QA',
        WorkOrderStatus.approved => 'Approved',
        WorkOrderStatus.rejected => 'Rejected',
        WorkOrderStatus.completed => 'Completed',
        WorkOrderStatus.cancelled => 'Cancelled',
      };

  Color get color => switch (this) {
        WorkOrderStatus.pending => AppTheme.statusPending,
        WorkOrderStatus.assigned => AppTheme.statusAssigned,
        WorkOrderStatus.inProgress => AppTheme.statusInProgress,
        WorkOrderStatus.readyForQa => AppTheme.statusReadyForQa,
        WorkOrderStatus.approved => AppTheme.statusApproved,
        WorkOrderStatus.rejected => AppTheme.statusRejected,
        WorkOrderStatus.completed => AppTheme.statusCompleted,
        WorkOrderStatus.cancelled => AppTheme.statusCancelled,
      };

  bool get isTerminal => switch (this) {
        WorkOrderStatus.approved ||
        WorkOrderStatus.completed ||
        WorkOrderStatus.cancelled =>
          true,
        _ => false,
      };

  /// State-machine: which states can `this` transition into?  Used for
  /// client-side button enabling.  The authoritative copy lives in
  /// `transition_work_order` (PL/pgSQL).
  Set<WorkOrderStatus> get allowedNext => switch (this) {
        WorkOrderStatus.pending => {
            WorkOrderStatus.assigned,
            WorkOrderStatus.cancelled,
          },
        WorkOrderStatus.assigned => {
            WorkOrderStatus.inProgress,
            WorkOrderStatus.cancelled,
          },
        WorkOrderStatus.inProgress => {
            WorkOrderStatus.readyForQa,
            WorkOrderStatus.cancelled,
          },
        WorkOrderStatus.readyForQa => {
            WorkOrderStatus.approved,
            WorkOrderStatus.rejected,
          },
        WorkOrderStatus.rejected => {WorkOrderStatus.inProgress},
        WorkOrderStatus.approved => {WorkOrderStatus.completed},
        WorkOrderStatus.completed => const <WorkOrderStatus>{},
        WorkOrderStatus.cancelled => const <WorkOrderStatus>{},
      };
}

enum QaResult {
  pass,
  fail;

  static QaResult fromString(String? raw) =>
      raw == 'fail' ? QaResult.fail : QaResult.pass;

  String get wire => name;

  String get label => this == QaResult.pass ? 'Pass' : 'Fail';
}

enum NotificationKind {
  taskAssigned,
  readyForQa,
  approved,
  rejected,
  taskFinished,
  lowStock,
  generic;

  static NotificationKind fromString(String? raw) {
    switch (raw) {
      case 'task_assigned':
        return NotificationKind.taskAssigned;
      case 'ready_for_qa':
        return NotificationKind.readyForQa;
      case 'approved':
        return NotificationKind.approved;
      case 'rejected':
        return NotificationKind.rejected;
      case 'task_finished':
        return NotificationKind.taskFinished;
      case 'low_stock':
        return NotificationKind.lowStock;
      default:
        return NotificationKind.generic;
    }
  }

  String get wire => switch (this) {
        NotificationKind.taskAssigned => 'task_assigned',
        NotificationKind.readyForQa => 'ready_for_qa',
        NotificationKind.approved => 'approved',
        NotificationKind.rejected => 'rejected',
        NotificationKind.taskFinished => 'task_finished',
        NotificationKind.lowStock => 'low_stock',
        NotificationKind.generic => 'generic',
      };

  IconData get icon => switch (this) {
        NotificationKind.taskAssigned => Icons.assignment_outlined,
        NotificationKind.readyForQa => Icons.fact_check_outlined,
        NotificationKind.approved => Icons.check_circle_outline,
        NotificationKind.rejected => Icons.error_outline,
        NotificationKind.taskFinished => Icons.flag_outlined,
        NotificationKind.lowStock => Icons.warning_amber_outlined,
        NotificationKind.generic => Icons.notifications_outlined,
      };
}
