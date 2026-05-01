import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/routing/notification_route.dart';
import '../../state/providers.dart';
import 'widgets/empty_state.dart';
import 'widgets/loading_skeleton.dart';

class NotificationsScreen extends ConsumerWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifs = ref.watch(notificationsProvider);
    final session = ref.watch(currentSessionProvider);
    final cs = Theme.of(context).colorScheme;
    final df = DateFormat('MMM d, HH:mm');

    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
        actions: [
          if (session != null)
            TextButton.icon(
              onPressed: () async {
                await ref
                    .read(notificationsRepositoryProvider)
                    .markAllRead(session.user.id);
              },
              icon: const Icon(Icons.done_all),
              label: const Text('Mark all read'),
            ),
        ],
      ),
      body: notifs.when(
        loading: () => const LoadingSkeletonList(itemCount: 7),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (list) {
          final profile = ref
              .watch(currentProfileProvider)
              .when(data: (v) => v, loading: () => null, error: (_, _) => null);
          if (list.isEmpty) {
            return const EmptyState(
              icon: Icons.notifications_none,
              title: 'No notifications yet',
              message:
                  'You will see updates from work orders and inventory here.',
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: list.length,
            separatorBuilder: (_, _) => const SizedBox(height: 8),
            itemBuilder: (_, i) {
              final n = list[i];
              return Card(
                child: ListTile(
                  leading: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: cs.primaryContainer,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Icon(n.kind.icon, color: cs.onPrimaryContainer),
                  ),
                  title: Text(
                    n.title,
                    style: TextStyle(
                      fontWeight: n.isUnread
                          ? FontWeight.w700
                          : FontWeight.w500,
                    ),
                  ),
                  subtitle: n.body == null
                      ? null
                      : Text(
                          n.body!,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                  trailing: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        df.format(n.createdAt),
                        style: TextStyle(
                          fontSize: 11,
                          color: cs.onSurfaceVariant,
                        ),
                      ),
                      if (n.isUnread) ...[
                        const SizedBox(height: 4),
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: cs.primary,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ],
                    ],
                  ),
                  onTap: () async {
                    await ref
                        .read(notificationsRepositoryProvider)
                        .markRead(n.id);
                    if (!context.mounted || profile == null) return;
                    final route = notificationTargetRoute(
                      notification: n,
                      role: profile.role,
                    );
                    context.push(route);
                  },
                ),
              );
            },
          );
        },
      ),
    );
  }
}
