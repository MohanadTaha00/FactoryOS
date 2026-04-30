import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

/// Wraps `flutter_local_notifications` for cross-platform display of in-app
/// alerts (ready_for_qa, rejected, low_stock, etc.).  No-ops on platforms
/// where it is unsupported instead of throwing.
class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  bool _initialized = false;

  Future<void> init() async {
    if (_initialized) return;
    try {
      const android = AndroidInitializationSettings('@mipmap/ic_launcher');
      const init = InitializationSettings(android: android);
      await _plugin.initialize(settings: init);
      _initialized = true;
    } catch (e) {
      debugPrint('NotificationService init failed: $e');
    }
  }

  Future<void> show({
    required int id,
    required String title,
    String? body,
    String channelId = 'factoryos_default',
    String channelName = 'FactoryOS',
  }) async {
    if (!_initialized) await init();
    if (!_initialized) return;
    final android = AndroidNotificationDetails(
      channelId,
      channelName,
      importance: Importance.high,
      priority: Priority.high,
    );
    final details = NotificationDetails(android: android);
    try {
      await _plugin.show(
        id: id,
        title: title,
        body: body,
        notificationDetails: details,
      );
    } catch (e) {
      debugPrint('NotificationService.show failed: $e');
    }
  }
}
