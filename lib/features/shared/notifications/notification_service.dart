import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

/// Local notifications + navigation when user taps an OS notification.
class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  bool _initialized = false;

  static const _channelId = 'factoryos_default';
  static const _channelName = 'FactoryOS';

  /// Called after [MaterialApp.router] mounts so [GoRouter.of] works.
  static void Function(String location)? onNavigateToRoute;

  /// Payload route when app was opened from a terminated state via notification.
  static String? pendingLaunchRoute;

  Future<String?> initializeAndConsumeLaunchPayload() async {
    if (_initialized) return null;
    if (kIsWeb) {
      _initialized = true;
      return null;
    }

    try {
      await _plugin.initialize(
        settings: const InitializationSettings(
          android: AndroidInitializationSettings('@mipmap/ic_launcher'),
          iOS: DarwinInitializationSettings(),
        ),
        onDidReceiveNotificationResponse: _onNotificationResponse,
      );

      final androidImpl = _plugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >();
      await androidImpl?.createNotificationChannel(
        const AndroidNotificationChannel(
          _channelId,
          _channelName,
          importance: Importance.high,
        ),
      );

      final launch = await _plugin.getNotificationAppLaunchDetails();
      if (launch?.didNotificationLaunchApp ?? false) {
        final payload = launch!.notificationResponse?.payload;
        if (payload != null && payload.isNotEmpty) {
          pendingLaunchRoute = payload;
        }
      }
    } catch (e, st) {
      debugPrint('NotificationService plugin init failed: $e $st');
    }

    _initialized = true;
    final pending = pendingLaunchRoute;
    pendingLaunchRoute = null;
    return pending;
  }

  static void _onNotificationResponse(NotificationResponse response) {
    final payload = response.payload;
    if (payload == null || payload.isEmpty) return;
    final navigate = onNavigateToRoute;
    if (navigate != null) {
      navigate(payload);
      return;
    }
    pendingLaunchRoute = payload;
  }

  Future<void> show({
    required int id,
    required String title,
    String? body,
    String? payload,
    String channelId = _channelId,
    String channelName = _channelName,
  }) async {
    if (kIsWeb) return;
    if (!_initialized) await initializeAndConsumeLaunchPayload();
    if (!_initialized) return;

    final android = AndroidNotificationDetails(
      channelId,
      channelName,
      importance: Importance.high,
      priority: Priority.high,
    );
    const ios = DarwinNotificationDetails();
    final details = NotificationDetails(android: android, iOS: ios);

    try {
      await _plugin.show(
        id: id,
        title: title,
        body: body,
        notificationDetails: details,
        payload: payload,
      );
    } catch (e) {
      debugPrint('NotificationService.show failed: $e');
    }
  }
}
