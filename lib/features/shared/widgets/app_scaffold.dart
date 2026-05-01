import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../data/models/enums.dart';
import '../../../state/providers.dart';
import 'connection_indicator.dart';
import 'refresh_data_button.dart';
import 'role_badge.dart';

/// Common app shell: side rail on wide screens, drawer on narrow,
/// notification + offline indicators in the bar, sign-out menu.
class AppScaffold extends ConsumerWidget {
  const AppScaffold({
    super.key,
    required this.title,
    required this.child,
    required this.role,
    this.actions,
    this.floatingActionButton,
    this.destinations = const <NavDestination>[],
    this.selectedIndex,
    this.onDestinationSelected,
  });

  final String title;
  final Widget child;
  final UserRole role;
  final List<Widget>? actions;
  final Widget? floatingActionButton;
  final List<NavDestination> destinations;
  final int? selectedIndex;
  final ValueChanged<int>? onDestinationSelected;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifications = ref.watch(notificationsProvider).value ?? const [];
    final unread = notifications.where((n) => n.isUnread).length;

    return LayoutBuilder(
      builder: (context, c) {
        final wide = c.maxWidth >= 900 && destinations.isNotEmpty;
        final compactTopBar = c.maxWidth < 460;
        final body = Column(
          children: [
            const ConnectionIndicator(),
            Expanded(child: child),
          ],
        );

        return Scaffold(
          appBar: AppBar(
            title: Row(
              children: [
                const Icon(Icons.factory_outlined, size: 20),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (!compactTopBar) ...[
                  const SizedBox(width: 12),
                  RoleBadge(role: role),
                ],
              ],
            ),
            actions: [
              const RefreshDataButton(),
              IconButton(
                icon: Badge(
                  isLabelVisible: unread > 0,
                  label: Text(unread.toString()),
                  child: const Icon(Icons.notifications_none),
                ),
                onPressed: () => context.push('/notifications'),
              ),
              ...?actions,
              PopupMenuButton<String>(
                icon: const Icon(Icons.account_circle_outlined),
                onSelected: (v) async {
                  if (v == 'logout') {
                    await ref.read(authRepositoryProvider).signOut();
                    if (context.mounted) context.go('/login');
                  }
                },
                itemBuilder: (_) => const [
                  PopupMenuItem(value: 'logout', child: Text('Sign out')),
                ],
              ),
              const SizedBox(width: 8),
            ],
          ),
          drawer: wide || destinations.isEmpty ? null : _Drawer(
            destinations: destinations,
            selectedIndex: selectedIndex,
            onDestinationSelected: onDestinationSelected,
          ),
          body: wide
              ? Row(
                  children: [
                    NavigationRail(
                      extended: c.maxWidth >= 1200,
                      selectedIndex: selectedIndex,
                      onDestinationSelected: onDestinationSelected,
                      destinations: [
                        for (final d in destinations)
                          NavigationRailDestination(
                            icon: Icon(d.icon),
                            selectedIcon: Icon(d.selectedIcon ?? d.icon),
                            label: Text(d.label),
                          ),
                      ],
                    ),
                    const VerticalDivider(width: 1),
                    Expanded(child: body),
                  ],
                )
              : body,
          floatingActionButton: floatingActionButton,
        );
      },
    );
  }
}

class NavDestination {
  const NavDestination({
    required this.icon,
    required this.label,
    this.selectedIcon,
  });
  final IconData icon;
  final IconData? selectedIcon;
  final String label;
}

class _Drawer extends StatelessWidget {
  const _Drawer({
    required this.destinations,
    required this.selectedIndex,
    required this.onDestinationSelected,
  });
  final List<NavDestination> destinations;
  final int? selectedIndex;
  final ValueChanged<int>? onDestinationSelected;

  @override
  Widget build(BuildContext context) {
    return NavigationDrawer(
      selectedIndex: selectedIndex,
      onDestinationSelected: (i) {
        Navigator.of(context).pop();
        onDestinationSelected?.call(i);
      },
      children: [
        const Padding(
          padding: EdgeInsets.fromLTRB(28, 16, 16, 10),
          child: Text(
            'FactoryOS',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
          ),
        ),
        for (final d in destinations)
          NavigationDrawerDestination(
            icon: Icon(d.icon),
            selectedIcon: Icon(d.selectedIcon ?? d.icon),
            label: Text(d.label),
          ),
      ],
    );
  }
}
