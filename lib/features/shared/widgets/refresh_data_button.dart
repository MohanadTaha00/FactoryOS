import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../state/providers.dart';

/// Refetches remote data (same session). Use on dashboards and list screens.
class RefreshDataButton extends ConsumerWidget {
  const RefreshDataButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return IconButton(
      tooltip: 'Refresh data',
      icon: const Icon(Icons.refresh),
      onPressed: () async {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Refreshing data…'),
              duration: Duration(seconds: 2),
            ),
          );
        }
        await refreshAppData(ref);
      },
    );
  }
}
