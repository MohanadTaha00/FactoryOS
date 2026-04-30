import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';
import 'package:flutter/foundation.dart';

part 'app_database.g.dart';

/// Local cache (Drift / SQLite).  Mirrors the Supabase tables we need to
/// keep available offline so that the worker app keeps working in the
/// "Wi-Fi dead zones" described in section 3.8 of the report.
///
/// We use a wide TEXT column for status / role to avoid coupling the
/// generated Drift code to the Dart enum -- the repository layer parses
/// the values back into the strongly-typed enums in `models/enums.dart`.

@DataClassName('CachedWorkOrder')
class CachedWorkOrders extends Table {
  TextColumn get id => text()();
  TextColumn get code => text()();
  TextColumn get title => text()();
  TextColumn get description => text().nullable()();
  TextColumn get status => text()();
  IntColumn get priority => integer().withDefault(const Constant(3))();
  TextColumn get createdBy => text()();
  TextColumn get assignedTo => text().nullable()();
  TextColumn get qaAssignedTo => text().nullable()();
  IntColumn get quantityTarget => integer().withDefault(const Constant(1))();
  IntColumn get quantityProduced => integer().withDefault(const Constant(0))();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get dueAt => dateTime().nullable()();
  DateTimeColumn get startedAt => dateTime().nullable()();
  DateTimeColumn get submittedForQaAt => dateTime().nullable()();
  DateTimeColumn get approvedAt => dateTime().nullable()();
  DateTimeColumn get completedAt => dateTime().nullable()();
  DateTimeColumn get updatedAt => dateTime().nullable()();
  TextColumn get assignedToName => text().nullable()();
  TextColumn get qaAssignedToName => text().nullable()();
  TextColumn get createdByName => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

@DataClassName('CachedInventoryItem')
class CachedInventoryItems extends Table {
  TextColumn get id => text()();
  TextColumn get sku => text()();
  TextColumn get name => text()();
  TextColumn get description => text().nullable()();
  TextColumn get unit => text().withDefault(const Constant('pcs'))();
  RealColumn get quantity => real().withDefault(const Constant(0))();
  RealColumn get threshold => real().withDefault(const Constant(0))();
  RealColumn get unitCost => real().withDefault(const Constant(0))();
  TextColumn get location => text().nullable()();
  DateTimeColumn get updatedAt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

@DataClassName('CachedNotification')
class CachedNotifications extends Table {
  TextColumn get id => text()();
  TextColumn get recipientId => text()();
  TextColumn get workOrderId => text().nullable()();
  TextColumn get title => text()();
  TextColumn get body => text().nullable()();
  TextColumn get kind => text()();
  DateTimeColumn get readAt => dateTime().nullable()();
  DateTimeColumn get createdAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Pending mutations that the device wasn't able to send because it was
/// offline.  The sync layer drains this queue when connectivity returns.
@DataClassName('PendingMutationRow')
class PendingMutations extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get kind => text()();             // e.g. 'transition_work_order'
  TextColumn get payload => text()();          // JSON-encoded args
  DateTimeColumn get createdAt => dateTime()();
  IntColumn get attempts => integer().withDefault(const Constant(0))();
  TextColumn get lastError => text().nullable()();
}

@DriftDatabase(
  tables: [
    CachedWorkOrders,
    CachedInventoryItems,
    CachedNotifications,
    PendingMutations,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_open());
  AppDatabase.forTesting(super.executor);

  @override
  int get schemaVersion => 1;

  static QueryExecutor _open() {
    if (kIsWeb) {
      return driftDatabase(
        name: 'factoryos_cache',
        web: DriftWebOptions(
          sqlite3Wasm: Uri.parse('sqlite3.wasm'),
          driftWorker: Uri.parse('drift_worker.js'),
        ),
      );
    }
    return driftDatabase(name: 'factoryos_cache');
  }

  // --- Work orders -----------------------------------------------------
  Future<List<CachedWorkOrder>> allWorkOrders() =>
      (select(cachedWorkOrders)..orderBy([(t) => OrderingTerm.desc(t.createdAt)]))
          .get();

  Future<CachedWorkOrder?> workOrderById(String id) =>
      (select(cachedWorkOrders)..where((t) => t.id.equals(id)))
          .getSingleOrNull();

  Future<void> upsertWorkOrders(Iterable<CachedWorkOrdersCompanion> rows) =>
      batch((b) => b.insertAllOnConflictUpdate(cachedWorkOrders, rows.toList()));

  Future<int> deleteWorkOrder(String id) =>
      (delete(cachedWorkOrders)..where((t) => t.id.equals(id))).go();

  // --- Inventory -------------------------------------------------------
  Future<List<CachedInventoryItem>> allInventory() =>
      (select(cachedInventoryItems)..orderBy([(t) => OrderingTerm.asc(t.name)]))
          .get();

  Future<void> upsertInventory(Iterable<CachedInventoryItemsCompanion> rows) =>
      batch(
          (b) => b.insertAllOnConflictUpdate(cachedInventoryItems, rows.toList()));

  // --- Notifications ---------------------------------------------------
  Future<List<CachedNotification>> notificationsFor(String userId) =>
      (select(cachedNotifications)
            ..where((t) => t.recipientId.equals(userId))
            ..orderBy([(t) => OrderingTerm.desc(t.createdAt)]))
          .get();

  Future<void> upsertNotifications(Iterable<CachedNotificationsCompanion> rows) =>
      batch(
          (b) => b.insertAllOnConflictUpdate(cachedNotifications, rows.toList()));

  // --- Pending mutations ----------------------------------------------
  Future<int> enqueueMutation(PendingMutationsCompanion row) =>
      into(pendingMutations).insert(row);

  Future<List<PendingMutationRow>> pendingMutationsList() =>
      (select(pendingMutations)..orderBy([(t) => OrderingTerm.asc(t.createdAt)]))
          .get();

  Future<int> markMutationDone(int id) =>
      (delete(pendingMutations)..where((t) => t.id.equals(id))).go();

  Future<int> bumpMutationFailure(int id, String error) =>
      (update(pendingMutations)..where((t) => t.id.equals(id))).write(
        PendingMutationsCompanion(
          attempts: const Value.absent(),
          lastError: Value(error),
        ),
      );

  Future<void> clear() async {
    await batch((b) {
      b.deleteAll(cachedWorkOrders);
      b.deleteAll(cachedInventoryItems);
      b.deleteAll(cachedNotifications);
      b.deleteAll(pendingMutations);
    });
  }
}
