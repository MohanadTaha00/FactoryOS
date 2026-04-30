import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../data/models/enums.dart';
import '../../state/providers.dart';
import '../shared/widgets/app_scaffold.dart';
import '../shared/widgets/dashboard_hero.dart';
import '../shared/widgets/empty_state.dart';
import '../shared/widgets/stat_card.dart';
import '../shared/widgets/work_order_tile.dart';

class WorkerDashboard extends ConsumerWidget {
  const WorkerDashboard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mine = ref.watch(myWorkOrdersProvider);
    return AppScaffold(
      title: 'Worker',
      role: UserRole.worker,
      child: mine.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (orders) {
          final active = orders
              .where(
                (o) =>
                    o.status == WorkOrderStatus.assigned ||
                    o.status == WorkOrderStatus.inProgress ||
                    o.status == WorkOrderStatus.rejected,
              )
              .length;
          final qa = orders
              .where((o) => o.status == WorkOrderStatus.readyForQa)
              .length;
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              DashboardHero(
                title: 'Worker Dashboard',
                subtitle: 'Focus on assigned tasks and fast QA handoff.',
                icon: Icons.engineering_outlined,
                trailing: FilledButton.tonalIcon(
                  onPressed: () => context.push('/worker/history'),
                  icon: const Icon(Icons.history),
                  label: const Text('History'),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: StatCard(
                      label: 'Active tasks',
                      value: '$active',
                      icon: Icons.engineering_outlined,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: StatCard(
                      label: 'Waiting QA',
                      value: '$qa',
                      icon: Icons.fact_check_outlined,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              if (orders
                  .where(
                    (o) =>
                        o.status != WorkOrderStatus.completed &&
                        o.status != WorkOrderStatus.approved &&
                        o.status != WorkOrderStatus.cancelled,
                  )
                  .isEmpty)
                const EmptyState(
                  icon: Icons.assignment_outlined,
                  title: 'No tasks assigned yet',
                )
              else
                ...orders
                    .where(
                      (o) =>
                          o.status != WorkOrderStatus.completed &&
                          o.status != WorkOrderStatus.approved &&
                          o.status != WorkOrderStatus.cancelled,
                    )
                    .map(
                      (o) => Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Column(
                          children: [
                            if (o.status == WorkOrderStatus.rejected)
                              Container(
                                width: double.infinity,
                                margin: const EdgeInsets.only(bottom: 6),
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.errorContainer,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Text(
                                  'Order Revision: ${o.latestRevisionNotes ?? 'QA requested revisions.'}',
                                  style: TextStyle(
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.onErrorContainer,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            WorkOrderTile(
                              order: o,
                              compact: true,
                              onTap: () =>
                                  context.push('/worker/tasks/${o.id}'),
                            ),
                          ],
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
