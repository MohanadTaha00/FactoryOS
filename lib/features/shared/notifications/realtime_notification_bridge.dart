import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/routing/app_navigator.dart';
import '../../../core/routing/notification_route.dart';
import '../../../data/models/app_notification.dart';
import '../../../data/models/user_attributes.dart';
import '../../../state/providers.dart';
import 'notification_service.dart';

List<AppNotification>? _notifList(AsyncValue<List<AppNotification>> a) =>
    a.when(data: (v) => v, loading: () => null, error: (_, _) => null);

UserAttributes? _profile(AsyncValue<UserAttributes?> a) =>
    a.when(data: (v) => v, loading: () => null, error: (_, _) => null);

/// Mirrors Supabase realtime notifications into OS notifications with navigation
/// payloads, and handles taps (foreground / background / terminated).
class RealtimeNotificationBridge extends ConsumerStatefulWidget {
  const RealtimeNotificationBridge({
    super.key,
    required this.child,
    this.notificationLaunchRoute,
  });

  final Widget child;
  final String? notificationLaunchRoute;

  @override
  ConsumerState<RealtimeNotificationBridge> createState() =>
      _RealtimeNotificationBridgeState();
}

class _RealtimeNotificationBridgeState
    extends ConsumerState<RealtimeNotificationBridge> {
  bool _primed = false;
  final Set<String> _knownIds = {};
  String? _pendingLaunch;

  @override
  void initState() {
    super.initState();
    _pendingLaunch = widget.notificationLaunchRoute;
  }

  void _navigate(String route) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final ctx = appRootNavigatorKey.currentContext;
      if (ctx != null && ctx.mounted) GoRouter.of(ctx).go(route);
    });
  }

  void _tryPendingLaunch() {
    final route = _pendingLaunch;
    if (route == null) return;
    final session = ref.read(currentSessionProvider);
    final profile = _profile(ref.read(currentProfileProvider));
    if (session == null || profile == null) return;
    _pendingLaunch = null;
    _navigate(route);
  }

  void _primeFromCurrentNotificationsIfNeeded() {
    final profile = _profile(ref.read(currentProfileProvider));
    if (profile == null || _primed) return;
    final list = _notifList(ref.read(notificationsProvider));
    if (list == null) return;
    _primed = true;
    _knownIds
      ..clear()
      ..addAll(list.map((e) => e.id));
  }

  void _maybeBroadcastNewNotifications() {
    if (kIsWeb) return;
    final profile = _profile(ref.read(currentProfileProvider));
    if (profile == null || !_primed) return;
    final list = _notifList(ref.read(notificationsProvider));
    if (list == null) return;

    for (final n in list) {
      if (_knownIds.contains(n.id)) continue;
      _knownIds.add(n.id);
      if (!n.isUnread) continue;

      final route = notificationTargetRoute(
        notification: n,
        role: profile.role,
      );

      NotificationService.instance.show(
        id: n.id.hashCode & 0x7FFFFFFF,
        title: n.title,
        body: n.body,
        payload: route,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    NotificationService.onNavigateToRoute = _navigate;

    ref.listen(currentSessionProvider, (_, session) {
      if (session == null) {
        _primed = false;
        _knownIds.clear();
      }
    });

    ref.listen(currentProfileProvider, (_, next) {
      next.whenData((_) {
        _tryPendingLaunch();
        _primeFromCurrentNotificationsIfNeeded();
      });
    });

    ref.listen(notificationsProvider, (_, next) {
      next.whenData((_) {
        _primeFromCurrentNotificationsIfNeeded();
        _maybeBroadcastNewNotifications();
      });
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _tryPendingLaunch();
      _primeFromCurrentNotificationsIfNeeded();
      _maybeBroadcastNewNotifications();
    });

    return widget.child;
  }
}
