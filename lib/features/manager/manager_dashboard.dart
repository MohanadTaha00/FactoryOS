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

class ManagerDashboard extends ConsumerWidget {
  const ManagerDashboard({super.key});

  static const _destinations = [
    NavDestination(icon: Icons.dashboard_outlined, label: 'Overview'),
    NavDestination(icon: Icons.assignment_outlined, label: 'Work orders'),
    NavDestination(icon: Icons.inventory_2_outlined, label: 'Inventory'),
    NavDestination(icon: Icons.picture_as_pdf_outlined, label: 'Reports'),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(currentProfileProvider).value;
    final isAdmin = profile?.role == UserRole.admin;
    final title = isAdmin ? 'Administrator' : 'Manager';
    final role = profile?.role ?? UserRole.manager;

    return AppScaffold(
      title: title,
      role: role,
      destinations: _destinations,
      selectedIndex: 0,
      onDestinationSelected: (i) {
        switch (i) {
          case 0:
            break;
          case 1:
            context.push('/manager/orders');
          case 2:
            context.push('/manager/inventory');
          case 3:
            context.push('/manager/reports');
        }
      },
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/manager/orders/new'),
        icon: const Icon(Icons.add),
        label: const Text('New work order'),
      ),
      child: const _ManagerHome(),
    );
  }
}

class _ManagerHome extends ConsumerWidget {
  const _ManagerHome();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ordersAsync = ref.watch(allWorkOrdersProvider);
    final lowStockAsync = ref.watch(lowStockProvider);

    Future<void> reloadOverview() async {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Refreshing data…'),
            duration: Duration(seconds: 2),
          ),
        );
      }
      await refreshAppData(ref);
      await ref.read(allWorkOrdersProvider.future);
      await ref.read(lowStockProvider.future);
    }

    return RefreshIndicator(
      onRefresh: reloadOverview,
      child: ordersAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (orders) {
          final pending = orders
              .where((o) => o.status == WorkOrderStatus.pending)
              .length;
          final inProgress = orders
              .where((o) => o.status == WorkOrderStatus.inProgress)
              .length;
          final readyForQa = orders
              .where((o) => o.status == WorkOrderStatus.readyForQa)
              .length;
          final completed = orders
              .where((o) =>
                  o.status == WorkOrderStatus.completed ||
                  o.status == WorkOrderStatus.approved)
              .length;
          final lowStock = lowStockAsync.value ?? const [];

          return ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(20),
            children: [
              DashboardHero(
                title: 'Manager Overview',
                subtitle:
                    'Track production flow, inventory risk, and QA throughput.',
                icon: Icons.dashboard_customize_outlined,
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      tooltip: 'Refresh data',
                      style: IconButton.styleFrom(
                        foregroundColor: Colors.white,
                      ),
                      onPressed: reloadOverview,
                      icon: const Icon(Icons.refresh),
                    ),
                    const SizedBox(width: 4),
                    FilledButton.tonalIcon(
                      onPressed: () => context.push('/manager/users/new'),
                      icon: const Icon(Icons.person_add_alt_1),
                      label: const Text('Account'),
                    ),
                    const SizedBox(width: 8),
                    FilledButton.tonalIcon(
                      onPressed: () => context.push('/manager/orders/new'),
                      icon: const Icon(Icons.add),
                      label: const Text('New'),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              _StatGrid(children: [
                StatCard(
                  label: 'Pending',
                  value: '$pending',
                  icon: Icons.pending_actions_outlined,
                  color: WorkOrderStatus.pending.color,
                ),
                StatCard(
                  label: 'In progress',
                  value: '$inProgress',
                  icon: Icons.precision_manufacturing_outlined,
                  color: WorkOrderStatus.inProgress.color,
                ),
                StatCard(
                  label: 'Ready for QA',
                  value: '$readyForQa',
                  icon: Icons.fact_check_outlined,
                  color: WorkOrderStatus.readyForQa.color,
                ),
                StatCard(
                  label: 'Completed',
                  value: '$completed',
                  icon: Icons.check_circle_outline,
                  color: WorkOrderStatus.completed.color,
                ),
              ]),
              const SizedBox(height: 24),
              if (lowStock.isNotEmpty) ...[
                Card(
                  color: Colors.orange.shade50,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.warning_amber_outlined, color: Colors.orange),
                            SizedBox(width: 8),
                            Text('Low stock alerts',
                                style: TextStyle(
                                    fontWeight: FontWeight.w700, fontSize: 16)),
                          ],
                        ),
                        const SizedBox(height: 8),
                        for (final item in lowStock.take(5))
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 4),
                            child: Row(
                              children: [
                                Expanded(child: Text(item.name)),
                                Text('${item.quantity} ${item.unit}',
                                    style: const TextStyle(
                                        fontWeight: FontWeight.w600)),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),
              ],
              const Text('Recent Work Orders',
                  style:
                      TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
              const SizedBox(height: 12),
              if (orders.isEmpty)
                EmptyState(
                  icon: Icons.assignment_outlined,
                  title: 'No work orders yet',
                  message: 'Create your first production order to get started.',
                  action: FilledButton.icon(
                    onPressed: () => context.push('/manager/orders/new'),
                    icon: const Icon(Icons.add),
                    label: const Text('New work order'),
                  ),
                )
              else
                ...orders.take(8).map(
                      (o) => Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: WorkOrderTile(
                          order: o,
                          compact: true,
                          onTap: () =>
                              context.push('/manager/orders/${o.id}'),
                        ),
                      ),
                    ),
              if (orders.length > 8)
                Center(
                  child: TextButton.icon(
                    onPressed: () => context.push('/manager/orders'),
                    icon: const Icon(Icons.list),
                    label: Text('View all ${orders.length} orders'),
                  ),
                ),
              const SizedBox(height: 80),
            ],
          );
        },
      ),
    );
  }
}

class _StatGrid extends StatelessWidget {
  const _StatGrid({required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, c) {
      final cols = c.maxWidth >= 900 ? 4 : (c.maxWidth >= 600 ? 2 : 1);
      return GridView.count(
        crossAxisCount: cols,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: c.maxWidth >= 900 ? 1.35 : 1.5,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        children: children,
      );
    });
  }
}
