import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'core/config/env.dart';
import 'data/supabase/supabase_service.dart';
import 'features/shared/notifications/notification_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Env.loadPlatformRuntime();
  await SupabaseService.initialize();

  String? notificationLaunchRoute;
  if (!kIsWeb) {
    notificationLaunchRoute = await NotificationService.instance
        .initializeAndConsumeLaunchPayload();
  }

  runApp(
    ProviderScope(
      child: FactoryOSApp(notificationLaunchRoute: notificationLaunchRoute),
    ),
  );
}
