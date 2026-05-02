import 'dart:developer' show log;
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// Loads [SUPABASE_URL] + [SUPABASE_ANON_KEY] from `.env`.
///
/// Order (first hit wins):
/// 1. `FACTORYOS_ENV_FILE`
/// 2. Next to the executable (desktop release)
/// 3. Current working directory (desktop `flutter run` from repo)
/// 4. App support directory (Android/iOS/desktop — reliable on mobile)
/// 5. App documents directory
Future<void> loadPlatformEnv(void Function(String url, String anon) apply) async {
  final paths = <String>[];

  final override = Platform.environment['FACTORYOS_ENV_FILE']?.trim();
  if (override != null && override.isNotEmpty) {
    paths.add(
      p.isAbsolute(override)
          ? override
          : p.join(Directory.current.path, override),
    );
  }

  paths.add(p.join(p.dirname(Platform.resolvedExecutable), '.env'));
  paths.add(p.join(Directory.current.path, '.env'));

  try {
    final support = await getApplicationSupportDirectory();
    paths.add(p.join(support.path, '.env'));
  } catch (_) {}

  try {
    final docs = await getApplicationDocumentsDirectory();
    paths.add(p.join(docs.path, '.env'));
  } catch (_) {}

  final seen = <String>{};
  for (final path in paths) {
    if (!seen.add(path)) continue;
    final file = File(path);
    if (!file.existsSync()) continue;
    String content;
    try {
      content = file.readAsStringSync();
    } catch (_) {
      continue;
    }
    final map = _parseDotEnv(content);
    final url = map['SUPABASE_URL']?.trim() ?? '';
    final anon = map['SUPABASE_ANON_KEY']?.trim() ?? '';
    if (url.isNotEmpty && anon.isNotEmpty) {
      apply(url, anon);
      return;
    }
  }

  if (Platform.isAndroid || Platform.isIOS) {
    log(
      'No SUPABASE_URL/SUPABASE_ANON_KEY loaded from .env; tried: ${paths.join(', ')}',
      name: 'factoryos.env',
    );
  }
}

Map<String, String> _parseDotEnv(String content) {
  final m = <String, String>{};
  for (final rawLine in content.split(RegExp(r'\r?\n'))) {
    final line = rawLine.trim();
    if (line.isEmpty || line.startsWith('#')) continue;
    final eq = line.indexOf('=');
    if (eq <= 0) continue;
    final key = line.substring(0, eq).trim();
    var val = line.substring(eq + 1).trim();
    if ((val.startsWith('"') && val.endsWith('"')) ||
        (val.startsWith("'") && val.endsWith("'"))) {
      val = val.substring(1, val.length - 1);
    }
    m[key] = val;
  }
  return m;
}
