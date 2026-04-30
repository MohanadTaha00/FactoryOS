import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../data/models/enums.dart';
import '../../state/providers.dart';
import '../shared/widgets/empty_state.dart';
import '../shared/widgets/loading_skeleton.dart';
import '../shared/widgets/work_order_tile.dart';

class OrdersListScreen extends ConsumerStatefulWidget {
  const OrdersListScreen({super.key});

  @override
  ConsumerState<OrdersListScreen> createState() => _OrdersListScreenState();
}

class _OrdersListScreenState extends ConsumerState<OrdersListScreen> {
  WorkOrderStatus? _filter;
  String _search = '';

  @override
  Widget build(BuildContext context) {
    final ordersAsync = ref.watch(allWorkOrdersProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Work orders'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.invalidate(allWorkOrdersProvider),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/manager/orders/new'),
        icon: const Icon(Icons.add),
        label: const Text('New'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: TextField(
              decoration: const InputDecoration(
                hintText: 'Search by code or title',
                prefixIcon: Icon(Icons.search),
              ),
              onChanged: (v) => setState(() => _search = v.toLowerCase()),
            ),
          ),
          SizedBox(
            height: 44,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              children: [
                FilterChip(
                  label: const Text('All'),
                  selected: _filter == null,
                  onSelected: (_) => setState(() => _filter = null),
                ),
                for (final s in WorkOrderStatus.values) ...[
                  const SizedBox(width: 6),
                  FilterChip(
                    label: Text(s.label),
                    selected: _filter == s,
                    onSelected: (_) => setState(
                        () => _filter = _filter == s ? null : s),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: ordersAsync.when(
              loading: () => const LoadingSkeletonList(itemCount: 7),
              error: (e, _) => Center(child: Text('Error: $e')),
              data: (orders) {
                final filtered = orders.where((o) {
                  if (_filter != null && o.status != _filter) return false;
                  if (_search.isNotEmpty) {
                    return o.title.toLowerCase().contains(_search) ||
                        o.code.toLowerCase().contains(_search);
                  }
                  return true;
                }).toList();
                if (filtered.isEmpty) {
                  return const EmptyState(
                    icon: Icons.search_off,
                    title: 'No matching orders',
                  );
                }
                return ListView.separated(
                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 80),
                  itemCount: filtered.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (_, i) => TweenAnimationBuilder<double>(
                    duration: Duration(milliseconds: 140 + (i * 18)),
                    tween: Tween(begin: 0, end: 1),
                    curve: Curves.easeOutCubic,
                    builder: (context, t, child) => Opacity(
                      opacity: t,
                      child: Transform.translate(
                        offset: Offset(0, (1 - t) * 8),
                        child: child,
                      ),
                    ),
                    child: WorkOrderTile(
                      order: filtered[i],
                      onTap: () =>
                          context.push('/manager/orders/${filtered[i].id}'),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
