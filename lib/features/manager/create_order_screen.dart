import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../data/models/enums.dart';
import '../../data/models/inventory_item.dart';
import '../../data/models/user_attributes.dart';
import '../../state/providers.dart';

class CreateOrderScreen extends ConsumerStatefulWidget {
  const CreateOrderScreen({super.key});

  @override
  ConsumerState<CreateOrderScreen> createState() => _CreateOrderScreenState();
}

class _CreateOrderScreenState extends ConsumerState<CreateOrderScreen> {
  final _form = GlobalKey<FormState>();
  final _title = TextEditingController();
  final _description = TextEditingController();
  final _quantity = TextEditingController(text: '1');
  int _priority = 3;
  UserAttributes? _worker;
  UserAttributes? _qa;
  DateTime? _due;
  final List<_MaterialLine> _materials = [];
  String? _attachmentName;
  Uint8List? _attachmentBytes;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _title.dispose();
    _description.dispose();
    _quantity.dispose();
    super.dispose();
  }

  Future<void> _pickDue() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _due ?? now.add(const Duration(days: 3)),
      firstDate: now,
      lastDate: now.add(const Duration(days: 365)),
    );
    if (picked != null) setState(() => _due = picked);
  }

  Future<void> _addMaterialDialog() async {
    final inv = await ref.read(inventoryRepositoryProvider).fetchAll();
    if (!mounted) return;
    final result = await showDialog<_MaterialLine>(
      context: context,
      builder: (_) => _PickMaterialDialog(inventory: inv),
    );
    if (result != null) setState(() => _materials.add(result));
  }

  Future<void> _pickPdfAttachment() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['pdf'],
      withData: true,
    );
    if (!mounted || result == null || result.files.isEmpty) return;
    final file = result.files.single;
    if (file.bytes == null) {
      setState(() => _error = 'Unable to read selected PDF file.');
      return;
    }
    setState(() {
      _attachmentName = file.name;
      _attachmentBytes = file.bytes;
    });
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final repo = ref.read(workOrderRepositoryProvider);
      final order = await repo.create(
        title: _title.text.trim(),
        description: _description.text.trim().isEmpty
            ? null
            : _description.text.trim(),
        quantityTarget: int.parse(_quantity.text),
        priority: _priority,
        assignedTo: _worker?.id,
        qaAssignedTo: _qa?.id,
        dueAt: _due,
        materials: [
          for (final m in _materials)
            (inventoryId: m.item.id, planned: m.quantity),
        ],
        attachmentFileName: _attachmentName,
        attachmentBytes: _attachmentBytes,
      );
      ref.invalidate(allWorkOrdersProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Work order created successfully')),
        );
        context.go('/manager/orders/${order.id}');
      }
    } catch (e) {
      setState(() => _error = e.toString().replaceAll('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final workersAsync = ref.watch(usersByRoleProvider(UserRole.worker));
    final qaAsync = ref.watch(usersByRoleProvider(UserRole.qa));
    final df = DateFormat('MMM d, yyyy');
    return Scaffold(
      appBar: AppBar(title: const Text('New work order')),
      body: Form(
        key: _form,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Create Production Order',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onPrimaryContainer,
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Define assignment, schedule, and materials in one flow.',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onPrimaryContainer,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Order Information',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 10),
            TextFormField(
              controller: _title,
              decoration: const InputDecoration(labelText: 'Title'),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Required' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _description,
              maxLines: 3,
              decoration: const InputDecoration(labelText: 'Description'),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _quantity,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Quantity target',
                    ),
                    validator: (v) {
                      final n = int.tryParse(v ?? '');
                      return (n == null || n <= 0) ? 'Invalid' : null;
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: DropdownButtonFormField<int>(
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
                ),
              ],
            ),
            const SizedBox(height: 12),
            ListTile(
              tileColor: Theme.of(context).colorScheme.surfaceContainerHighest,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              leading: const Icon(Icons.picture_as_pdf_outlined),
              title: Text(_attachmentName ?? 'Attach PDF (optional)'),
              subtitle: _attachmentName == null
                  ? const Text('Add work instructions or technical sheet')
                  : const Text('PDF selected'),
              trailing: _attachmentName == null
                  ? null
                  : IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () => setState(() {
                        _attachmentName = null;
                        _attachmentBytes = null;
                      }),
                    ),
              onTap: _pickPdfAttachment,
            ),
            const SizedBox(height: 12),
            const Text(
              'Assignments',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 10),
            workersAsync.when(
              loading: () => const LinearProgressIndicator(),
              error: (e, _) => Text('Workers error: $e'),
              data: (workers) => DropdownButtonFormField<UserAttributes?>(
                initialValue: _worker,
                decoration: const InputDecoration(labelText: 'Assigned worker'),
                items: [
                  const DropdownMenuItem(
                    value: null,
                    child: Text('Unassigned'),
                  ),
                  for (final w in workers)
                    DropdownMenuItem(value: w, child: Text(w.fullName)),
                ],
                onChanged: (v) => setState(() => _worker = v),
              ),
            ),
            const SizedBox(height: 12),
            qaAsync.when(
              loading: () => const LinearProgressIndicator(),
              error: (e, _) => Text('QA error: $e'),
              data: (qas) => DropdownButtonFormField<UserAttributes?>(
                initialValue: _qa,
                decoration: const InputDecoration(labelText: 'QA inspector'),
                items: [
                  const DropdownMenuItem(value: null, child: Text('None')),
                  for (final q in qas)
                    DropdownMenuItem(value: q, child: Text(q.fullName)),
                ],
                onChanged: (v) => setState(() => _qa = v),
              ),
            ),
            const SizedBox(height: 12),
            ListTile(
              tileColor: Theme.of(context).colorScheme.surfaceContainerHighest,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              leading: const Icon(Icons.event),
              title: Text(_due == null ? 'Pick due date' : df.format(_due!)),
              trailing: _due == null
                  ? null
                  : IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () => setState(() => _due = null),
                    ),
              onTap: _pickDue,
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                const Text(
                  'Materials',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                ),
                const Spacer(),
                FilledButton.tonalIcon(
                  onPressed: _addMaterialDialog,
                  icon: const Icon(Icons.add),
                  label: const Text('Add material'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (_materials.isEmpty)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    'No materials defined yet. Add at least one to enable inventory deduction on QA submission.',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              )
            else
              ..._materials.map(
                (m) => Card(
                  child: ListTile(
                    leading: const Icon(Icons.inventory_2_outlined),
                    title: Text(m.item.name),
                    subtitle: Text(m.item.sku),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('${m.quantity} ${m.item.unit}'),
                        IconButton(
                          icon: const Icon(Icons.delete_outline),
                          onPressed: () => setState(() => _materials.remove(m)),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.errorContainer,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.error_outline,
                      size: 18,
                      color: Theme.of(context).colorScheme.onErrorContainer,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _error!,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onErrorContainer,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: _busy ? null : _save,
              icon: _busy
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.save_outlined),
              label: Text(_busy ? 'Creating...' : 'Create work order'),
            ),
          ],
        ),
      ),
    );
  }
}

class _MaterialLine {
  _MaterialLine(this.item, this.quantity);
  final InventoryItem item;
  final double quantity;
}

class _PickMaterialDialog extends StatefulWidget {
  const _PickMaterialDialog({required this.inventory});
  final List<InventoryItem> inventory;

  @override
  State<_PickMaterialDialog> createState() => _PickMaterialDialogState();
}

class _PickMaterialDialogState extends State<_PickMaterialDialog> {
  InventoryItem? _selected;
  final _qty = TextEditingController(text: '1');

  @override
  void dispose() {
    _qty.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Add material'),
      content: SizedBox(
        width: 400,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DropdownButtonFormField<InventoryItem>(
              initialValue: _selected,
              decoration: const InputDecoration(labelText: 'Material'),
              items: [
                for (final i in widget.inventory)
                  DropdownMenuItem(
                    value: i,
                    child: Text('${i.name} (${i.quantity} ${i.unit} on hand)'),
                  ),
              ],
              onChanged: (v) => setState(() => _selected = v),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _qty,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Quantity planned'),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () {
            final q = double.tryParse(_qty.text);
            if (_selected == null || q == null || q <= 0) return;
            Navigator.of(context).pop(_MaterialLine(_selected!, q));
          },
          child: const Text('Add'),
        ),
      ],
    );
  }
}
