import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../state/providers.dart';
import '../shared/widgets/empty_state.dart';
import '../shared/widgets/loading_skeleton.dart';
import '../shared/widgets/work_order_tile.dart';

class WorkerHistoryScreen extends ConsumerWidget {
  const WorkerHistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final history = ref.watch(workerHistoryProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('My Project History')),
      body: history.when(
        loading: () => const LoadingSkeletonList(itemCount: 6),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (orders) {
          if (orders.isEmpty) {
            return const EmptyState(
              icon: Icons.history,
              title: 'No project history yet',
              message: 'Completed or reviewed work will appear here.',
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.all(12),
            itemCount: orders.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (_, i) => WorkOrderTile(
              order: orders[i],
              onTap: () => context.push('/worker/tasks/${orders[i].id}'),
            ),
          );
        },
      ),
    );
  }
}
