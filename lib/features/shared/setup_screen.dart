import 'package:flutter/material.dart';

import '../../core/config/env.dart';

class SetupScreen extends StatelessWidget {
  const SetupScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('FactoryOS - Configuration needed')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.cloud_off, size: 48, color: cs.error),
                    const SizedBox(height: 16),
                    const Text(
                      'Supabase credentials are missing',
                      style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'FactoryOS needs SUPABASE_URL and SUPABASE_ANON_KEY — '
                      'via --dart-define, a .env file in supported locations, '
                      'or (web only) supabase-runtime-config.local.js.',
                      style: TextStyle(color: cs.onSurfaceVariant),
                    ),
                    const SizedBox(height: 24),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: cs.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const SelectableText(
                        'Easiest Android (uses repo .env):\n'
                        'scripts/run_android_with_env.ps1\n\n'
                        'Or Device File Explorer → data/data/'
                        'com.altinbas.factoryos.factoryos/files/.env\n'
                        'iOS/Desktop: app support/documents or .exe folder.\n\n'
                        'flutter run \\\n'
                        '  --dart-define=SUPABASE_URL=https://xxx.supabase.co \\\n'
                        '  --dart-define=SUPABASE_ANON_KEY=eyJ...\n\n'
                        'Web: scripts/sync_web_supabase_config.ps1 then flutter build web.',
                        style: TextStyle(fontFamily: 'monospace', fontSize: 12),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text('App version: ${Env.appVersion}',
                        style: TextStyle(color: cs.onSurfaceVariant, fontSize: 12)),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
