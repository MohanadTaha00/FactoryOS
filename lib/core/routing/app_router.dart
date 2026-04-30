import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../data/models/enums.dart';
import '../../features/auth/login_screen.dart';
import '../../features/auth/signup_screen.dart';
import '../../features/manager/create_order_screen.dart';
import '../../features/manager/inventory_screen.dart';
import '../../features/manager/manager_dashboard.dart';
import '../../features/manager/order_details_screen.dart';
import '../../features/manager/orders_list_screen.dart';
import '../../features/manager/reports_screen.dart';
import '../../features/qa/qa_dashboard.dart';
import '../../features/qa/qa_history_screen.dart';
import '../../features/qa/qa_review_screen.dart';
import '../../features/shared/notifications_screen.dart';
import '../../features/shared/setup_screen.dart';
import '../../features/worker/task_details_screen.dart';
import '../../features/worker/worker_dashboard.dart';
import '../../features/worker/worker_history_screen.dart';
import '../../state/providers.dart';
import '../config/env.dart';

class AppRouter {
  AppRouter(this.ref);
  final Ref ref;

  late final GoRouter router = GoRouter(
    initialLocation: '/login',
    debugLogDiagnostics: false,
    refreshListenable: _RouterRefresh(ref),
    redirect: _redirect,
    routes: [
      GoRoute(
        path: '/setup',
        pageBuilder: (context, state) =>
            _page(state, const SetupScreen(), fadeOnly: true),
      ),
      GoRoute(
        path: '/login',
        pageBuilder: (context, state) =>
            _page(state, const LoginScreen(), fadeOnly: true),
      ),
      GoRoute(
        path: '/signup',
        pageBuilder: (context, state) =>
            _page(state, const SignupScreen(), fadeOnly: true),
      ),
      GoRoute(
        path: '/notifications',
        pageBuilder: (context, state) =>
            _page(state, const NotificationsScreen()),
      ),
      // Manager
      GoRoute(
        path: '/manager',
        pageBuilder: (context, state) => _page(state, const ManagerDashboard()),
        routes: [
          GoRoute(
            path: 'orders',
            pageBuilder: (context, state) =>
                _page(state, const OrdersListScreen()),
          ),
          GoRoute(
            path: 'orders/new',
            pageBuilder: (context, state) =>
                _page(state, const CreateOrderScreen()),
          ),
          GoRoute(
            path: 'orders/:id',
            pageBuilder: (context, state) => _page(
              state,
              OrderDetailsScreen(orderId: state.pathParameters['id']!),
            ),
          ),
          GoRoute(
            path: 'inventory',
            pageBuilder: (context, state) =>
                _page(state, const InventoryScreen()),
          ),
          GoRoute(
            path: 'reports',
            pageBuilder: (context, state) => _page(state, const ReportsScreen()),
          ),
        ],
      ),
      // Worker
      GoRoute(
        path: '/worker',
        pageBuilder: (context, state) => _page(state, const WorkerDashboard()),
        routes: [
          GoRoute(
            path: 'tasks/:id',
            pageBuilder: (context, state) => _page(
              state,
              TaskDetailsScreen(orderId: state.pathParameters['id']!),
            ),
          ),
          GoRoute(
            path: 'history',
            pageBuilder: (context, state) =>
                _page(state, const WorkerHistoryScreen()),
          ),
        ],
      ),
      // QA
      GoRoute(
        path: '/qa',
        pageBuilder: (context, state) => _page(state, const QaDashboard()),
        routes: [
          GoRoute(
            path: 'review/:id',
            pageBuilder: (context, state) => _page(
              state,
              QaReviewScreen(orderId: state.pathParameters['id']!),
            ),
          ),
          GoRoute(
            path: 'history',
            pageBuilder: (context, state) =>
                _page(state, const QaHistoryScreen()),
          ),
        ],
      ),
    ],
    errorBuilder: (context, state) => Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Text('Route not found: ${state.uri}'),
        ),
      ),
    ),
  );

  String? _redirect(BuildContext context, GoRouterState state) {
    if (!Env.isConfigured) {
      return state.matchedLocation == '/setup' ? null : '/setup';
    }
    final session = ref.read(currentSessionProvider);
    final loc = state.matchedLocation;
    final atAuth = loc == '/login' || loc == '/signup';
    if (session == null) return atAuth ? null : '/login';

    final profileAsync = ref.read(currentProfileProvider);
    final profile = profileAsync.value;
    if (profile == null) {
      // first profile load -- let the screen render and show a spinner
      return atAuth ? '/manager' : null;
    }

    // role-based root redirect when landing on /
    if (atAuth) return profile.getDashboardView();

    final allowed = switch (profile.role) {
      UserRole.manager => loc.startsWith('/manager') ||
          loc.startsWith('/notifications'),
      UserRole.worker => loc.startsWith('/worker') ||
          loc.startsWith('/notifications'),
      UserRole.qa => loc.startsWith('/qa') ||
          loc.startsWith('/notifications') ||
          loc.startsWith('/manager/orders/'),
      UserRole.admin => true,
    };
    if (!allowed) return profile.getDashboardView();
    return null;
  }

  CustomTransitionPage<void> _page(
    GoRouterState state,
    Widget child, {
    bool fadeOnly = false,
  }) {
    return CustomTransitionPage<void>(
      key: state.pageKey,
      child: child,
      transitionDuration: const Duration(milliseconds: 260),
      reverseTransitionDuration: const Duration(milliseconds: 220),
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        final fade = CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutCubic,
        );
        if (fadeOnly) {
          return FadeTransition(opacity: fade, child: child);
        }
        final slide = Tween<Offset>(
          begin: const Offset(0.03, 0),
          end: Offset.zero,
        ).animate(fade);
        return FadeTransition(
          opacity: fade,
          child: SlideTransition(position: slide, child: child),
        );
      },
    );
  }
}

/// Bridges Riverpod's auth & profile providers into go_router's
/// `refreshListenable`, so route guards re-evaluate on sign-in/out.
class _RouterRefresh extends ChangeNotifier {
  _RouterRefresh(this.ref) {
    ref.listen(currentSessionProvider, (_, __) => notifyListeners());
    ref.listen(currentProfileProvider, (_, __) => notifyListeners());
  }
  final Ref ref;
}

final appRouterProvider = Provider<AppRouter>((ref) => AppRouter(ref));
