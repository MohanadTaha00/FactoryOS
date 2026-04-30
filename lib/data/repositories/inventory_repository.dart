import 'package:drift/drift.dart' show Value;
import 'package:supabase_flutter/supabase_flutter.dart';

import '../local/app_database.dart';
import '../models/inventory_item.dart';
import '../supabase/supabase_service.dart';

class InventoryRepository {
  InventoryRepository(this._db);

  final AppDatabase _db;

  SupabaseClient get _c => SupabaseService.client;

  Future<List<InventoryItem>> fetchAll() async {
    try {
      final rows =
          await _c.from('inventory_items').select().order('name', ascending: true);
      final items = (rows as List)
          .cast<Map<String, dynamic>>()
          .map(InventoryItem.fromMap)
          .toList();
      await _cache(items);
      return items;
    } catch (_) {
      return _readCache();
    }
  }

  Stream<List<InventoryItem>> watch() {
    return _c
        .from('inventory_items')
        .stream(primaryKey: ['id'])
        .order('name')
        .map((rows) => rows.map(InventoryItem.fromMap).toList());
  }

  Future<InventoryItem> upsert(InventoryItem item, {required bool isNew}) async {
    if (isNew) {
      final payload = Map<String, dynamic>.from(item.toMap())..remove('id');
      final row = await _c.from('inventory_items').insert(payload).select().single();
      return InventoryItem.fromMap(row);
    }

    final payload = Map<String, dynamic>.from(item.toMap())..remove('id');
    final row = await _c
        .from('inventory_items')
        .update(payload)
        .eq('id', item.id)
        .select()
        .single();
    return InventoryItem.fromMap(row);
  }

  Future<List<InventoryItem>> lowStock() async {
    final rows = await _c.from('v_low_stock').select();
    return (rows as List)
        .cast<Map<String, dynamic>>()
        .map(InventoryItem.fromMap)
        .toList();
  }

  // ----- Cache --------------------------------------------------------

  Future<void> _cache(List<InventoryItem> items) async {
    final rows = items.map(
      (i) => CachedInventoryItemsCompanion(
        id: Value(i.id),
        sku: Value(i.sku),
        name: Value(i.name),
        description: Value(i.description),
        unit: Value(i.unit),
        quantity: Value(i.quantity),
        threshold: Value(i.threshold),
        unitCost: Value(i.unitCost),
        location: Value(i.location),
        updatedAt: Value(i.updatedAt),
      ),
    );
    await _db.upsertInventory(rows);
  }

  Future<List<InventoryItem>> _readCache() async {
    final rows = await _db.allInventory();
    return rows
        .map((r) => InventoryItem(
              id: r.id,
              sku: r.sku,
              name: r.name,
              description: r.description,
              unit: r.unit,
              quantity: r.quantity,
              threshold: r.threshold,
              unitCost: r.unitCost,
              location: r.location,
              updatedAt: r.updatedAt,
            ))
        .toList();
  }
}
