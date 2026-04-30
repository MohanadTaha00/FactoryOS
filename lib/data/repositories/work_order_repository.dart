import 'dart:convert';
import 'dart:typed_data';

import 'package:drift/drift.dart' show Value;
import 'package:supabase_flutter/supabase_flutter.dart';

import '../local/app_database.dart';
import '../models/enums.dart';
import '../models/work_order.dart';
import '../supabase/supabase_service.dart';

/// Repository for work orders.  Reads from Supabase first, falls back to the
/// Drift cache when offline; writes go through Supabase RPCs and are queued
/// locally if the device is offline.
class WorkOrderRepository {
  WorkOrderRepository(this._db);

  final AppDatabase _db;

  SupabaseClient get _c => SupabaseService.client;

  static const _selectColumns = '''
    *,
    creator:created_by(id, full_name, role),
    assigned_user:assigned_to(id, full_name, role),
    qa_user:qa_assigned_to(id, full_name, role),
    material_consumption(*, inventory_items(id, sku, name, unit)),
    quality_logs(*, user_profiles!quality_logs_inspector_id_fkey(id, full_name))
  ''';

  // --------------------------------------------------------------- READ ---

  Future<List<WorkOrder>> fetchAll() async {
    try {
      final rows = await _c
          .from('work_orders')
          .select(_selectColumns)
          .order('created_at', ascending: false);
      final list = (rows as List).cast<Map<String, dynamic>>();
      final orders = list.map(WorkOrder.fromMap).toList();
      await _cacheOrders(orders);
      return orders;
    } catch (_) {
      return _readFromCache();
    }
  }

  Future<List<WorkOrder>> fetchAssignedTo(String userId) async {
    try {
      final rows = await _c
          .from('work_orders')
          .select(_selectColumns)
          .eq('assigned_to', userId)
          .order('created_at', ascending: false);
      final list = (rows as List).cast<Map<String, dynamic>>();
      return list.map(WorkOrder.fromMap).toList();
    } catch (_) {
      final cached = await _readFromCache();
      return cached.where((w) => w.assignedTo == userId).toList();
    }
  }

  Future<List<WorkOrder>> fetchWorkerHistory(String userId) async {
    try {
      final rows = await _c
          .from('work_orders')
          .select(_selectColumns)
          .eq('assigned_to', userId)
          .inFilter('status', [
            'approved',
            'completed',
            'rejected',
            'cancelled',
          ])
          .order('updated_at', ascending: false);
      final list = (rows as List).cast<Map<String, dynamic>>();
      return list.map(WorkOrder.fromMap).toList();
    } catch (_) {
      final cached = await _readFromCache();
      return cached
          .where(
            (w) =>
                w.assignedTo == userId &&
                (w.status == WorkOrderStatus.approved ||
                    w.status == WorkOrderStatus.completed ||
                    w.status == WorkOrderStatus.rejected ||
                    w.status == WorkOrderStatus.cancelled),
          )
          .toList();
    }
  }

  Future<List<WorkOrder>> fetchForQa(String userId) async {
    try {
      final rows = await _c
          .from('work_orders')
          .select(_selectColumns)
          .or('qa_assigned_to.eq.$userId,status.eq.ready_for_qa')
          .order('submitted_for_qa_at', ascending: true);
      final list = (rows as List).cast<Map<String, dynamic>>();
      return list.map(WorkOrder.fromMap).toList();
    } catch (_) {
      final cached = await _readFromCache();
      return cached
          .where(
            (w) =>
                w.qaAssignedTo == userId ||
                w.status == WorkOrderStatus.readyForQa,
          )
          .toList();
    }
  }

  Future<List<WorkOrder>> fetchQaHistory(String userId) async {
    try {
      final rows = await _c
          .from('work_orders')
          .select(_selectColumns)
          .eq('qa_assigned_to', userId)
          .inFilter('status', [
            'approved',
            'completed',
            'rejected',
            'cancelled',
          ])
          .order('updated_at', ascending: false);
      final list = (rows as List).cast<Map<String, dynamic>>();
      return list.map(WorkOrder.fromMap).toList();
    } catch (_) {
      final cached = await _readFromCache();
      return cached
          .where(
            (w) =>
                w.qaAssignedTo == userId &&
                (w.status == WorkOrderStatus.approved ||
                    w.status == WorkOrderStatus.completed ||
                    w.status == WorkOrderStatus.rejected ||
                    w.status == WorkOrderStatus.cancelled),
          )
          .toList();
    }
  }

  Future<WorkOrder?> fetchById(String id) async {
    final rows = await _c
        .from('work_orders')
        .select(_selectColumns)
        .eq('id', id)
        .maybeSingle();
    if (rows == null) return null;
    return WorkOrder.fromMap(rows);
  }

  Stream<List<WorkOrder>> watchAll() {
    return _c
        .from('work_orders')
        .stream(primaryKey: ['id'])
        .order('created_at')
        .map((rows) => rows.map(WorkOrder.fromMap).toList());
  }

  // -------------------------------------------------------------- WRITE ---

  Future<WorkOrder> create({
    required String title,
    String? description,
    required int quantityTarget,
    int priority = 3,
    String? assignedTo,
    String? qaAssignedTo,
    DateTime? dueAt,
    String? attachmentFileName,
    Uint8List? attachmentBytes,
    required List<({String inventoryId, double planned})> materials,
  }) async {
    final code = await _c.rpc<String>('generate_work_order_code');
    final attachmentUrl = await _uploadPdfAttachment(
      fileName: attachmentFileName,
      bytes: attachmentBytes,
      orderCode: code,
    );
    final inserted = await _c
        .from('work_orders')
        .insert({
          'code': code,
          'title': title,
          'description': description,
          'priority': priority,
          'assigned_to': assignedTo,
          'qa_assigned_to': qaAssignedTo,
          'quantity_target': quantityTarget,
          'due_at': dueAt?.toIso8601String(),
          'attachment_url': attachmentUrl,
          // Always create in pending, then transition through the state machine
          // so events/notifications are generated consistently.
          'status': 'pending',
          'created_by': _c.auth.currentUser!.id,
        })
        .select()
        .single();

    final orderId = inserted['id'] as String;
    if (materials.isNotEmpty) {
      await _c.from('material_consumption').insert([
        for (final m in materials)
          {
            'work_order_id': orderId,
            'inventory_id': m.inventoryId,
            'quantity_planned': m.planned,
          },
      ]);
    }

    if (assignedTo != null) {
      await _c.rpc(
        'transition_work_order',
        params: {
          'p_id': orderId,
          'p_to': 'assigned',
          'p_message': 'created with assignment',
        },
      );
    }
    return (await fetchById(orderId))!;
  }

  Future<WorkOrder> updateOrder({
    required String workOrderId,
    required String title,
    String? description,
    required int quantityTarget,
    required int priority,
    String? assignedTo,
    String? qaAssignedTo,
    DateTime? dueAt,
    String? attachmentFileName,
    Uint8List? attachmentBytes,
    bool clearAttachment = false,
  }) async {
    final existing = await fetchById(workOrderId);
    if (existing == null) throw Exception('Order not found');

    String? attachmentUrl = existing.attachmentUrl;
    if (clearAttachment) {
      attachmentUrl = null;
    }
    if (attachmentBytes != null && attachmentFileName != null) {
      attachmentUrl = await _uploadPdfAttachment(
        fileName: attachmentFileName,
        bytes: attachmentBytes,
        orderCode: existing.code,
      );
    }

    await _c
        .from('work_orders')
        .update({
          'title': title,
          'description': description,
          'quantity_target': quantityTarget,
          'priority': priority,
          'assigned_to': assignedTo,
          'qa_assigned_to': qaAssignedTo,
          'due_at': dueAt?.toIso8601String(),
          'attachment_url': attachmentUrl,
        })
        .eq('id', workOrderId);

    return (await fetchById(workOrderId))!;
  }

  /// Attempt a state-machine transition online; if offline, enqueue and
  /// return null so the caller can show "queued for sync".
  Future<WorkOrder?> transition({
    required String workOrderId,
    required WorkOrderStatus to,
    String? message,
  }) async {
    try {
      final row = await _c.rpc<Map<String, dynamic>>(
        'transition_work_order',
        params: {'p_id': workOrderId, 'p_to': to.wire, 'p_message': message},
      );
      return WorkOrder.fromMap(row);
    } on Exception catch (e) {
      await _db.enqueueMutation(
        PendingMutationsCompanion.insert(
          kind: 'transition_work_order',
          payload: jsonEncode({
            'p_id': workOrderId,
            'p_to': to.wire,
            'p_message': message,
          }),
          createdAt: DateTime.now(),
          lastError: Value(e.toString()),
        ),
      );
      return null;
    }
  }

  Future<WorkOrder?> submitForQa(String workOrderId) async {
    try {
      final row = await _c.rpc<Map<String, dynamic>>(
        'submit_for_qa',
        params: {'p_work_order_id': workOrderId},
      );
      return WorkOrder.fromMap(row);
    } on Exception catch (e) {
      await _db.enqueueMutation(
        PendingMutationsCompanion.insert(
          kind: 'submit_for_qa',
          payload: jsonEncode({'p_work_order_id': workOrderId}),
          createdAt: DateTime.now(),
          lastError: Value(e.toString()),
        ),
      );
      return null;
    }
  }

  Future<WorkOrder?> recordQa({
    required String workOrderId,
    required QaResult result,
    String? notes,
  }) async {
    try {
      final row = await _c.rpc<Map<String, dynamic>>(
        'record_qa',
        params: {
          'p_work_order_id': workOrderId,
          'p_result': result.wire,
          'p_notes': notes,
        },
      );
      return WorkOrder.fromMap(row);
    } on Exception catch (e) {
      await _db.enqueueMutation(
        PendingMutationsCompanion.insert(
          kind: 'record_qa',
          payload: jsonEncode({
            'p_work_order_id': workOrderId,
            'p_result': result.wire,
            'p_notes': notes,
          }),
          createdAt: DateTime.now(),
          lastError: Value(e.toString()),
        ),
      );
      return null;
    }
  }

  Future<void> updateProgress(String workOrderId, int produced) async {
    await _c
        .from('work_orders')
        .update({'quantity_produced': produced})
        .eq('id', workOrderId);
  }

  Future<String?> _uploadPdfAttachment({
    required String? fileName,
    required Uint8List? bytes,
    required String orderCode,
  }) async {
    if (fileName == null || bytes == null) return null;
    final safeName = fileName.replaceAll(RegExp(r'[^a-zA-Z0-9._-]'), '_');
    final filePath =
        'work_orders/${orderCode}_${DateTime.now().millisecondsSinceEpoch}_$safeName';
    await _c.storage
        .from('order_attachments')
        .uploadBinary(
          filePath,
          bytes,
          fileOptions: const FileOptions(
            cacheControl: '3600',
            contentType: 'application/pdf',
            upsert: true,
          ),
        );
    return _c.storage.from('order_attachments').getPublicUrl(filePath);
  }

  // ------------------------------------------------------------- CACHE ---

  Future<void> _cacheOrders(List<WorkOrder> orders) async {
    final rows = orders.map(
      (o) => CachedWorkOrdersCompanion(
        id: Value(o.id),
        code: Value(o.code),
        title: Value(o.title),
        description: Value(o.description),
        status: Value(o.status.wire),
        priority: Value(o.priority),
        createdBy: Value(o.createdBy),
        assignedTo: Value(o.assignedTo),
        qaAssignedTo: Value(o.qaAssignedTo),
        quantityTarget: Value(o.quantityTarget),
        quantityProduced: Value(o.quantityProduced),
        createdAt: Value(o.createdAt),
        dueAt: Value(o.dueAt),
        startedAt: Value(o.startedAt),
        submittedForQaAt: Value(o.submittedForQaAt),
        approvedAt: Value(o.approvedAt),
        completedAt: Value(o.completedAt),
        updatedAt: Value(o.updatedAt),
        assignedToName: Value(o.assignedToName),
        qaAssignedToName: Value(o.qaAssignedToName),
        createdByName: Value(o.createdByName),
      ),
    );
    await _db.upsertWorkOrders(rows);
  }

  Future<List<WorkOrder>> _readFromCache() async {
    final rows = await _db.allWorkOrders();
    return rows
        .map(
          (r) => WorkOrder(
            id: r.id,
            code: r.code,
            title: r.title,
            description: r.description,
            status: WorkOrderStatus.fromString(r.status),
            priority: r.priority,
            createdBy: r.createdBy,
            assignedTo: r.assignedTo,
            qaAssignedTo: r.qaAssignedTo,
            quantityTarget: r.quantityTarget,
            quantityProduced: r.quantityProduced,
            createdAt: r.createdAt,
            dueAt: r.dueAt,
            startedAt: r.startedAt,
            submittedForQaAt: r.submittedForQaAt,
            approvedAt: r.approvedAt,
            completedAt: r.completedAt,
            updatedAt: r.updatedAt,
            assignedToName: r.assignedToName,
            qaAssignedToName: r.qaAssignedToName,
            createdByName: r.createdByName,
          ),
        )
        .toList();
  }
}
