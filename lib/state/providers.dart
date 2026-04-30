import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide UserAttributes;

import '../data/local/app_database.dart';
import '../data/models/app_notification.dart';
import '../data/models/enums.dart';
import '../data/models/inventory_item.dart';
import '../data/models/user_attributes.dart';
import '../data/models/work_order.dart';
import '../data/repositories/auth_repository.dart';
import '../data/repositories/inventory_repository.dart';
import '../data/repositories/notifications_repository.dart';
import '../data/repositories/sync_repository.dart';
import '../data/repositories/users_repository.dart';
import '../data/repositories/work_order_repository.dart';

/// Singletons -----------------------------------------------------------------

final appDatabaseProvider = Provider<AppDatabase>((ref) {
  final db = AppDatabase();
  ref.onDispose(db.close);
  return db;
});

final authRepositoryProvider = Provider<AuthRepository>(
  (_) => AuthRepository(),
);
final usersRepositoryProvider = Provider<UsersRepository>(
  (_) => UsersRepository(),
);
final inventoryRepositoryProvider = Provider<InventoryRepository>(
  (ref) => InventoryRepository(ref.watch(appDatabaseProvider)),
);
final workOrderRepositoryProvider = Provider<WorkOrderRepository>(
  (ref) => WorkOrderRepository(ref.watch(appDatabaseProvider)),
);
final notificationsRepositoryProvider = Provider<NotificationsRepository>(
  (_) => NotificationsRepository(),
);
final syncRepositoryProvider = Provider<SyncRepository>((ref) {
  final repo = SyncRepository(ref.watch(appDatabaseProvider));
  ref.onDispose(repo.dispose);
  return repo;
});

/// Auth -----------------------------------------------------------------------

final authStateChangesProvider = StreamProvider<AuthState>((ref) {
  return ref.watch(authRepositoryProvider).authStateChanges();
});

final currentSessionProvider = Provider<Session?>((ref) {
  ref.watch(authStateChangesProvider);
  return ref.watch(authRepositoryProvider).session;
});

final currentProfileProvider = FutureProvider<UserAttributes?>((ref) async {
  final session = ref.watch(currentSessionProvider);
  if (session == null) return null;
  return ref.watch(authRepositoryProvider).fetchProfile(session.user.id);
});

/// Connectivity --------------------------------------------------------------

final isOnlineStreamProvider = StreamProvider<bool>((ref) {
  return ref.watch(syncRepositoryProvider).onlineStream;
});

/// Domain data ---------------------------------------------------------------

final allWorkOrdersProvider = FutureProvider<List<WorkOrder>>((ref) async {
  return ref.watch(workOrderRepositoryProvider).fetchAll();
});

final myWorkOrdersProvider = FutureProvider<List<WorkOrder>>((ref) async {
  final session = ref.watch(currentSessionProvider);
  if (session == null) return const [];
  return ref
      .watch(workOrderRepositoryProvider)
      .fetchAssignedTo(session.user.id);
});

final workerHistoryProvider = FutureProvider<List<WorkOrder>>((ref) async {
  final session = ref.watch(currentSessionProvider);
  if (session == null) return const [];
  return ref
      .watch(workOrderRepositoryProvider)
      .fetchWorkerHistory(session.user.id);
});

final qaQueueProvider = FutureProvider<List<WorkOrder>>((ref) async {
  final session = ref.watch(currentSessionProvider);
  if (session == null) return const [];
  return ref.watch(workOrderRepositoryProvider).fetchForQa(session.user.id);
});

final qaHistoryProvider = FutureProvider<List<WorkOrder>>((ref) async {
  final session = ref.watch(currentSessionProvider);
  if (session == null) return const [];
  return ref.watch(workOrderRepositoryProvider).fetchQaHistory(session.user.id);
});

final workOrderByIdProvider =
    FutureProvider.family<WorkOrder?, String>((ref, id) async {
  return ref.watch(workOrderRepositoryProvider).fetchById(id);
});

final inventoryProvider = FutureProvider<List<InventoryItem>>((ref) async {
  return ref.watch(inventoryRepositoryProvider).fetchAll();
});

final lowStockProvider = FutureProvider<List<InventoryItem>>((ref) async {
  return ref.watch(inventoryRepositoryProvider).lowStock();
});

final usersByRoleProvider =
    FutureProvider.family<List<UserAttributes>, UserRole>((ref, role) async {
  return ref.watch(usersRepositoryProvider).fetchByRole(role);
});

final notificationsProvider =
    StreamProvider<List<AppNotification>>((ref) async* {
  final session = ref.watch(currentSessionProvider);
  if (session == null) {
    yield const [];
    return;
  }
  yield await ref
      .watch(notificationsRepositoryProvider)
      .fetchFor(session.user.id);
  yield* ref
      .watch(notificationsRepositoryProvider)
      .watchFor(session.user.id);
});
