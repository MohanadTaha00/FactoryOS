import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'data/supabase/supabase_service.dart';
import 'features/shared/notifications/notification_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SupabaseService.initialize();
  if (!kIsWeb) {
    await NotificationService.instance.init();
  }
  runApp(const ProviderScope(child: FactoryOSApp()));
}
