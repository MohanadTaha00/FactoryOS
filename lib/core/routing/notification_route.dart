import '../../data/models/app_notification.dart';
import '../../data/models/enums.dart';

/// Deep-link target for in-app / OS notifications (worker, QA, manager).
String notificationTargetRoute({
  required AppNotification notification,
  required UserRole role,
}) {
  final wo = notification.workOrderId;

  if (wo == null) {
    switch (notification.kind) {
      case NotificationKind.lowStock:
        return '/manager/inventory';
      default:
        return '/notifications';
    }
  }

  switch (role) {
    case UserRole.manager:
    case UserRole.admin:
      return '/manager/orders/$wo';
    case UserRole.worker:
      return '/worker/tasks/$wo';
    case UserRole.qa:
      return '/qa/review/$wo';
  }
}
