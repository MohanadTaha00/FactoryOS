import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../data/models/enums.dart';
import '../../state/providers.dart';
import '../shared/widgets/app_scaffold.dart';
import '../shared/widgets/dashboard_hero.dart';
import '../shared/widgets/empty_state.dart';
import '../shared/widgets/work_order_tile.dart';

class QaDashboard extends ConsumerWidget {
  const QaDashboard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final queue = ref.watch(qaQueueProvider);
    return AppScaffold(
      title: 'Quality Assurance',
      role: UserRole.qa,
      child: queue.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (orders) {
          final ready = orders
              .where((o) => o.status == WorkOrderStatus.readyForQa)
              .toList();
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              DashboardHero(
                title: 'QA Queue',
                subtitle: 'Inspect, approve, or reject tasks with clear notes.',
                icon: Icons.fact_check_outlined,
                trailing: FilledButton.tonalIcon(
                  onPressed: () => context.push('/qa/history'),
                  icon: const Icon(Icons.history),
                  label: const Text('History'),
                ),
              ),
              const SizedBox(height: 14),
              if (ready.isEmpty)
                const EmptyState(
                  icon: Icons.fact_check_outlined,
                  title: 'No tasks waiting for QA',
                )
              else
                ...ready.map(
                  (o) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: WorkOrderTile(
                      order: o,
                      compact: true,
                      onTap: () => context.push('/qa/review/${o.id}'),
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}
