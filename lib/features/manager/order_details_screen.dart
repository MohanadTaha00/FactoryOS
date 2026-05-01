import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'dart:typed_data';

import '../../data/models/enums.dart';
import '../../data/models/user_attributes.dart';
import '../../data/models/work_order.dart';
import '../../state/providers.dart';
import '../reports/report_generator.dart';
import '../shared/widgets/status_chip.dart';
import '../shared/widgets/work_order_pdf_attachment.dart';

final _df = DateFormat('MMM d, yyyy HH:mm');

class OrderDetailsScreen extends ConsumerWidget {
  const OrderDetailsScreen({super.key, required this.orderId});

  final String orderId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final orderAsync = ref.watch(workOrderByIdProvider(orderId));
    return Scaffold(
      appBar: AppBar(
        title: const Text('Work order'),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.invalidate(workOrderByIdProvider(orderId)),
          ),
          orderAsync.maybeWhen(
            data: (order) => order == null
                ? const SizedBox.shrink()
                : IconButton(
                    tooltip: 'Generate PDF report',
                    icon: const Icon(Icons.picture_as_pdf_outlined),
                    onPressed: () =>
                        ReportGenerator.shareWorkOrderReport(order),
                  ),
            orElse: () => const SizedBox.shrink(),
          ),
        ],
      ),
      body: orderAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (order) {
          if (order == null) {
            return const Center(child: Text('Order not found'));
          }
          return _OrderBody(order: order, isManagerView: true);
        },
      ),
    );
  }
}

class _OrderBody extends ConsumerWidget {
  const _OrderBody({required this.order, required this.isManagerView});
  final WorkOrder order;
  final bool isManagerView;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: cs.primaryContainer.withValues(alpha: 0.45),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          order.title,
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      StatusChip(status: order.status),
                    ],
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  order.code,
                  style: TextStyle(
                    color: cs.onSurfaceVariant,
                    fontFamily: 'monospace',
                    fontSize: 13,
                  ),
                ),
                if (order.description != null) ...[
                  const SizedBox(height: 12),
                  Text(order.description!),
                ],
                if (order.attachmentUrl != null &&
                    order.attachmentUrl!.trim().isNotEmpty) ...[
                  const SizedBox(height: 12),
                  WorkOrderPdfAttachment(url: order.attachmentUrl!),
                ],
                const Divider(height: 32),
                _kv('Created by', order.createdByName ?? '—'),
                _kv('Assigned to', order.assignedToName ?? 'Unassigned'),
                _kv('QA inspector', order.qaAssignedToName ?? '—'),
                _kv('Priority', 'P${order.priority}'),
                _kv(
                  'Quantity',
                  '${order.quantityProduced} / ${order.quantityTarget}',
                ),
                _kv('Created at', _df.format(order.createdAt)),
                if (order.dueAt != null)
                  _kv('Due at', _df.format(order.dueAt!)),
                if (order.startedAt != null)
                  _kv('Started at', _df.format(order.startedAt!)),
                if (order.submittedForQaAt != null)
                  _kv('Submitted for QA', _df.format(order.submittedForQaAt!)),
                if (order.approvedAt != null)
                  _kv('Approved at', _df.format(order.approvedAt!)),
                if (order.completedAt != null)
                  _kv('Completed at', _df.format(order.completedAt!)),
                _kv(
                  'Estimated completion',
                  order.calculateCompletionDate() == null
                      ? '—'
                      : _df.format(order.calculateCompletionDate()!),
                ),
                if (order.productionDuration() != null)
                  _kv(
                    'Production duration',
                    _formatDuration(order.productionDuration()!),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Materials',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 8),
                if (order.materials.isEmpty)
                  Text(
                    'No materials linked to this order',
                    style: TextStyle(color: cs.onSurfaceVariant),
                  )
                else
                  ...order.materials.map(
                    (m) => Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      child: Row(
                        children: [
                          Icon(
                            m.deducted
                                ? Icons.check_box_outlined
                                : Icons.inventory_2_outlined,
                            color: m.deducted ? Colors.green : cs.primary,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(m.inventoryName ?? m.inventoryId),
                                if (m.inventorySku != null)
                                  Text(
                                    m.inventorySku!,
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: cs.onSurfaceVariant,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          Text(
                            '${m.quantityPlanned} ${m.inventoryUnit ?? ''}',
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Quality logs',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 8),
                if (order.qualityLogs.isEmpty)
                  Text(
                    'No QA inspections recorded',
                    style: TextStyle(color: cs.onSurfaceVariant),
                  )
                else
                  ...order.qualityLogs.map(
                    (log) => Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Row(
                        children: [
                          Icon(
                            log.result == QaResult.pass
                                ? Icons.check_circle_outlined
                                : Icons.cancel_outlined,
                            color: log.result == QaResult.pass
                                ? Colors.green
                                : Colors.red,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '${log.result.label} • ${log.inspectorName ?? log.inspectorId}',
                                ),
                                Text(
                                  _df.format(log.inspectedAt),
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: cs.onSurfaceVariant,
                                  ),
                                ),
                                if (log.notes != null) Text(log.notes!),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        if (isManagerView) _ManagerActions(order: order),
      ],
    );
  }

  Widget _kv(String k, String v) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 3),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 160,
          child: Text(k, style: const TextStyle(fontWeight: FontWeight.w500)),
        ),
        Expanded(child: Text(v)),
      ],
    ),
  );

  static String _formatDuration(Duration d) {
    if (d.inDays > 0) return '${d.inDays}d ${d.inHours % 24}h';
    if (d.inHours > 0) return '${d.inHours}h ${d.inMinutes % 60}m';
    return '${d.inMinutes}m';
  }
}

class _ManagerActions extends ConsumerStatefulWidget {
  const _ManagerActions({required this.order});
  final WorkOrder order;

  @override
  ConsumerState<_ManagerActions> createState() => _ManagerActionsState();
}

class _ManagerActionsState extends ConsumerState<_ManagerActions> {
  bool _busy = false;

  Future<void> _transition(WorkOrderStatus to) async {
    setState(() => _busy = true);
    try {
      await ref
          .read(workOrderRepositoryProvider)
          .transition(
            workOrderId: widget.order.id,
            to: to,
            message: 'manager action',
          );
      ref.invalidate(workOrderByIdProvider(widget.order.id));
      ref.invalidate(allWorkOrdersProvider);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final allowed = widget.order.status.allowedNext;
    if (allowed.isEmpty) return const SizedBox.shrink();
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Actions',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                OutlinedButton.icon(
                  onPressed: _busy ? null : _editOrder,
                  icon: const Icon(Icons.edit_outlined),
                  label: const Text('Edit order'),
                ),
                for (final next in allowed)
                  if (_managerCanDo(widget.order.status, next))
                    FilledButton(
                      onPressed: _busy ? null : () => _transition(next),
                      child: Text(
                        next == WorkOrderStatus.cancelled
                            ? 'Cancel Order'
                            : 'Move to ${next.label}',
                      ),
                    ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  bool _managerCanDo(WorkOrderStatus from, WorkOrderStatus to) {
    return switch ((from, to)) {
      (WorkOrderStatus.pending, WorkOrderStatus.assigned) => true,
      (WorkOrderStatus.pending, WorkOrderStatus.cancelled) => true,
      (WorkOrderStatus.assigned, WorkOrderStatus.cancelled) => true,
      (WorkOrderStatus.inProgress, WorkOrderStatus.cancelled) => true,
      (WorkOrderStatus.approved, WorkOrderStatus.completed) => true,
      _ => false,
    };
  }

  Future<void> _editOrder() async {
    final workers = await ref.read(usersByRoleProvider(UserRole.worker).future);
    final qas = await ref.read(usersByRoleProvider(UserRole.qa).future);
    if (!mounted) return;

    final form = await showDialog<_EditOrderFormResult>(
      context: context,
      builder: (_) =>
          _EditOrderDialog(order: widget.order, workers: workers, qas: qas),
    );
    if (form == null) return;

    setState(() => _busy = true);
    try {
      await ref
          .read(workOrderRepositoryProvider)
          .updateOrder(
            workOrderId: widget.order.id,
            title: form.title,
            description: form.description,
            quantityTarget: form.quantityTarget,
            priority: form.priority,
            assignedTo: form.workerId,
            qaAssignedTo: form.qaId,
            dueAt: form.dueAt,
            attachmentFileName: form.attachmentName,
            attachmentBytes: form.attachmentBytes,
            clearAttachment: form.clearAttachment,
          );
      ref.invalidate(workOrderByIdProvider(widget.order.id));
      ref.invalidate(allWorkOrdersProvider);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Order updated')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Update failed: $e')));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }
}

class _EditOrderFormResult {
  const _EditOrderFormResult({
    required this.title,
    required this.description,
    required this.quantityTarget,
    required this.priority,
    required this.workerId,
    required this.qaId,
    required this.dueAt,
    required this.attachmentName,
    required this.attachmentBytes,
    required this.clearAttachment,
  });

  final String title;
  final String? description;
  final int quantityTarget;
  final int priority;
  final String? workerId;
  final String? qaId;
  final DateTime? dueAt;
  final String? attachmentName;
  final Uint8List? attachmentBytes;
  final bool clearAttachment;
}

class _EditOrderDialog extends StatefulWidget {
  const _EditOrderDialog({
    required this.order,
    required this.workers,
    required this.qas,
  });

  final WorkOrder order;
  final List<UserAttributes> workers;
  final List<UserAttributes> qas;

  @override
  State<_EditOrderDialog> createState() => _EditOrderDialogState();
}

class _EditOrderDialogState extends State<_EditOrderDialog> {
  late final TextEditingController _title;
  late final TextEditingController _description;
  late final TextEditingController _quantity;
  late int _priority;
  DateTime? _dueAt;
  String? _workerId;
  String? _qaId;
  String? _attachmentName;
  Uint8List? _attachmentBytes;
  bool _clearAttachment = false;

  @override
  void initState() {
    super.initState();
    _title = TextEditingController(text: widget.order.title);
    _description = TextEditingController(text: widget.order.description ?? '');
    _quantity = TextEditingController(
      text: widget.order.quantityTarget.toString(),
    );
    _priority = widget.order.priority;
    _dueAt = widget.order.dueAt;
    _workerId = widget.order.assignedTo;
    _qaId = widget.order.qaAssignedTo;
  }

  @override
  void dispose() {
    _title.dispose();
    _description.dispose();
    _quantity.dispose();
    super.dispose();
  }

  Future<void> _pickPdf() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['pdf'],
      withData: true,
    );
    if (!mounted || result == null || result.files.isEmpty) return;
    final file = result.files.single;
    if (file.bytes == null) return;
    setState(() {
      _attachmentName = file.name;
      _attachmentBytes = file.bytes;
      _clearAttachment = false;
    });
  }

  Future<void> _pickDue() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _dueAt ?? now,
      firstDate: now.subtract(const Duration(days: 30)),
      lastDate: now.add(const Duration(days: 365)),
    );
    if (picked != null) setState(() => _dueAt = picked);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Edit order'),
      content: SizedBox(
        width: 520,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: _title,
                decoration: const InputDecoration(labelText: 'Title'),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _description,
                maxLines: 3,
                decoration: const InputDecoration(labelText: 'Description'),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _quantity,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Quantity target'),
              ),
              const SizedBox(height: 10),
              DropdownButtonFormField<int>(
                initialValue: _priority,
                decoration: const InputDecoration(labelText: 'Priority'),
                items: const [
                  DropdownMenuItem(value: 1, child: Text('P1 - Urgent')),
                  DropdownMenuItem(value: 2, child: Text('P2 - High')),
                  DropdownMenuItem(value: 3, child: Text('P3 - Normal')),
                  DropdownMenuItem(value: 4, child: Text('P4 - Low')),
                  DropdownMenuItem(value: 5, child: Text('P5 - Backlog')),
                ],
                onChanged: (v) => setState(() => _priority = v ?? 3),
              ),
              const SizedBox(height: 10),
              DropdownButtonFormField<String?>(
                initialValue: _workerId,
                decoration: const InputDecoration(labelText: 'Assigned worker'),
                items: [
                  const DropdownMenuItem(
                    value: null,
                    child: Text('Unassigned'),
                  ),
                  for (final w in widget.workers)
                    DropdownMenuItem(value: w.id, child: Text(w.fullName)),
                ],
                onChanged: (v) => setState(() => _workerId = v),
              ),
              const SizedBox(height: 10),
              DropdownButtonFormField<String?>(
                initialValue: _qaId,
                decoration: const InputDecoration(labelText: 'QA inspector'),
                items: [
                  const DropdownMenuItem(value: null, child: Text('None')),
                  for (final q in widget.qas)
                    DropdownMenuItem(value: q.id, child: Text(q.fullName)),
                ],
                onChanged: (v) => setState(() => _qaId = v),
              ),
              const SizedBox(height: 10),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.event_outlined),
                title: Text(
                  _dueAt == null
                      ? 'No due date'
                      : DateFormat('MMM d, yyyy').format(_dueAt!),
                ),
                onTap: _pickDue,
                trailing: IconButton(
                  icon: const Icon(Icons.clear),
                  onPressed: () => setState(() => _dueAt = null),
                ),
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.picture_as_pdf_outlined),
                title: Text(_attachmentName ?? 'Replace attachment (optional)'),
                subtitle: Text(
                  widget.order.attachmentUrl == null
                      ? 'No current PDF attached'
                      : 'Current attachment exists',
                ),
                onTap: _pickPdf,
                trailing: widget.order.attachmentUrl == null
                    ? null
                    : Checkbox(
                        value: _clearAttachment,
                        onChanged: (v) =>
                            setState(() => _clearAttachment = v ?? false),
                      ),
              ),
              if (widget.order.attachmentUrl != null)
                const Align(
                  alignment: Alignment.centerLeft,
                  child: Text('Check the box to remove existing attachment'),
                ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () {
            final quantity = int.tryParse(_quantity.text.trim());
            if (_title.text.trim().isEmpty ||
                quantity == null ||
                quantity <= 0) {
              return;
            }
            Navigator.of(context).pop(
              _EditOrderFormResult(
                title: _title.text.trim(),
                description: _description.text.trim().isEmpty
                    ? null
                    : _description.text.trim(),
                quantityTarget: quantity,
                priority: _priority,
                workerId: _workerId,
                qaId: _qaId,
                dueAt: _dueAt,
                attachmentName: _attachmentName,
                attachmentBytes: _attachmentBytes,
                clearAttachment: _clearAttachment,
              ),
            );
          },
          child: const Text('Save changes'),
        ),
      ],
    );
  }
}
