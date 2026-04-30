import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/config/env.dart';

/// Thin wrapper around `Supabase.initialize` so the rest of the codebase
/// can stay platform-agnostic and easily testable.
class SupabaseService {
  SupabaseService._();

  static Future<void> initialize() async {
    if (!Env.isConfigured) {
      // Defer crashing until something actually tries to use the client;
      // this lets the dev launch the app to read the configuration screen.
      return;
    }
    await Supabase.initialize(
      url: Env.supabaseUrl,
      anonKey: Env.supabaseAnonKey,
      debug: false,
      authOptions: const FlutterAuthClientOptions(
        authFlowType: AuthFlowType.pkce,
      ),
      realtimeClientOptions: const RealtimeClientOptions(
        logLevel: RealtimeLogLevel.warn,
      ),
    );
  }

  static SupabaseClient get client {
    if (!Env.isConfigured) {
      throw StateError(
        'Supabase is not configured. Pass --dart-define=SUPABASE_URL and '
        '--dart-define=SUPABASE_ANON_KEY when running the app.',
      );
    }
    return Supabase.instance.client;
  }
}
