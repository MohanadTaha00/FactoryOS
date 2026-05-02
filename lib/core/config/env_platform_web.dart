import 'dart:js_interop';

@JS()
extension type _FactoryOSSupabase(JSObject _) implements JSObject {
  external String get url;
  external String get anonKey;
}

@JS('factoryosSupabase')
external _FactoryOSSupabase? get _factoryosSupabase;

void registerPlatformEnv(void Function(String url, String anonKey) apply) {
  try {
    final cfg = _factoryosSupabase;
    if (cfg == null) return;
    final url = cfg.url.trim();
    final anon = cfg.anonKey.trim();
    if (url.isEmpty || anon.isEmpty) return;
    apply(url, anon);
  } catch (_) {}
}
