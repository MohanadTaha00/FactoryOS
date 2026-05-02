import 'env_platform_stub.dart'
    if (dart.library.js_interop) 'env_platform_web.dart';

/// Environment configuration.
///
/// **Compile-time** (any platform): `--dart-define` / `--dart-define-from-file`.
///
/// **Web runtime**: before running Flutter, load `supabase-runtime-config.js`
/// from `web/` (sets `window.factoryosSupabase`). Run
/// `scripts/sync_web_supabase_config.ps1` to generate it from `.env`.
class Env {
  Env._();

  static String _runtimeUrl = '';
  static String _runtimeAnonKey = '';

  /// Applies platform-specific overrides (e.g. web `window.factoryosSupabase`).
  static void loadPlatformRuntime() {
    registerPlatformEnv((url, anon) {
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
