import 'env_platform_stub.dart'
    if (dart.library.io) 'env_platform_io.dart'
    if (dart.library.js_interop) 'env_platform_web.dart';

/// Environment configuration.
///
/// **Compile-time** (any platform): `--dart-define` / `--dart-define-from-file`.
///
/// **Desktop / mobile (IO)** at runtime: `.env` next to the executable, cwd,
/// app support/documents (Android/iOS), or `FACTORYOS_ENV_FILE`.
///
/// **Web runtime**: `web/supabase-runtime-config.local.js` / `window.factoryosSupabase`.
class Env {
  Env._();

  static String _runtimeUrl = '';
  static String _runtimeAnonKey = '';

  /// Applies platform-specific overrides (web globals, IO `.env` files).
  static Future<void> loadPlatformRuntime() async {
    await loadPlatformEnv((url, anon) {
      _runtimeUrl = url;
      _runtimeAnonKey = anon;
    });
  }

  static String get supabaseUrl {
    const fromDefine = String.fromEnvironment(
      'SUPABASE_URL',
      defaultValue: '',
    );
    if (fromDefine.isNotEmpty) return fromDefine;
    return _runtimeUrl;
  }

  static String get supabaseAnonKey {
    const fromDefine = String.fromEnvironment(
      'SUPABASE_ANON_KEY',
      defaultValue: '',
    );
    if (fromDefine.isNotEmpty) return fromDefine;
    return _runtimeAnonKey;
  }

  static const String appName = 'FactoryOS';
  static const String appVersion = '1.0.0';

  static bool get isConfigured =>
      supabaseUrl.isNotEmpty && supabaseAnonKey.isNotEmpty;
}
