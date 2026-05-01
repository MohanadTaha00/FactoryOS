import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/routing/app_router.dart';
import 'core/theme/app_theme.dart';
import 'features/shared/notifications/realtime_notification_bridge.dart';

class FactoryOSApp extends ConsumerWidget {
  const FactoryOSApp({super.key, this.notificationLaunchRoute});

  /// Deep link when Android/iOS opened the app from a killed state via notification.
  final String? notificationLaunchRoute;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(appRouterProvider).router;
    return RealtimeNotificationBridge(
      notificationLaunchRoute: notificationLaunchRoute,
      child: MaterialApp.router(
        title: 'FactoryOS',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light(),
        darkTheme: AppTheme.dark(),
        themeMode: ThemeMode.light,
        routerConfig: router,
      ),
    );
  }
}
