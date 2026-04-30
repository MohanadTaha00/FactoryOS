import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../data/models/inventory_item.dart';
import '../../state/providers.dart';
import '../shared/widgets/empty_state.dart';
import '../shared/widgets/loading_skeleton.dart';

class InventoryScreen extends ConsumerStatefulWidget {
  const InventoryScreen({super.key});

  @override
  ConsumerState<InventoryScreen> createState() => _InventoryScreenState();
}

class _InventoryScreenState extends ConsumerState<InventoryScreen> {
  String _search = '';

  @override
  Widget build(BuildContext context) {
    final invAsync = ref.watch(inventoryProvider);
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Inventory'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.invalidate(inventoryProvider),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _editItem(null),
        icon: const Icon(Icons.add),
        label: const Text('New item'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: TextField(
              decoration: const InputDecoration(
                hintText: 'Search SKU or name',
                prefixIcon: Icon(Icons.search),
              ),
              onChanged: (v) => setState(() => _search = v.toLowerCase()),
            ),
          ),
          Expanded(
            child: invAsync.when(
              loading: () => const LoadingSkeletonList(itemCount: 8),
              error: (e, _) => Center(child: Text('Error: $e')),
              data: (items) {
                final filtered = items.where((i) {
                  if (_search.isEmpty) return true;
                  return i.sku.toLowerCase().contains(_search) ||
                      i.name.toLowerCase().contains(_search);
                }).toList();
                if (filtered.isEmpty) {
                  return const EmptyState(
                    icon: Icons.inventory_2_outlined,
                    title: 'No inventory items',
                  );
                }
                return ListView.separated(
                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 80),
                  itemCount: filtered.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 6),
                  itemBuilder: (_, i) {
                    final item = filtered[i];
                    final low = item.isBelowThreshold();
                    return Card(
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: low
                              ? Colors.orange.withValues(alpha: 0.15)
                              : cs.primaryContainer,
                          child: Icon(
                            low ? Icons.warning_amber : Icons.inventory_2_outlined,
                            color: low ? Colors.orange : cs.onPrimaryContainer,
                            size: 18,
                          ),
                        ),
                        title: Text(item.name,
                            style: const TextStyle(fontWeight: FontWeight.w600)),
                        subtitle: Text(
                            '${item.sku} • ${item.location ?? "no location"}'),
                        trailing: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              '${item.quantity} ${item.unit}',
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                color: low ? Colors.orange.shade700 : null,
                              ),
                            ),
                            Text('threshold ${item.threshold}',
                                style: TextStyle(
                                    fontSize: 11, color: cs.onSurfaceVariant)),
                          ],
                        ),
                        onTap: () => _editItem(item),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _editItem(InventoryItem? existing) async {
    final result = await showDialog<InventoryItem>(
      context: context,
      builder: (_) => _ItemDialog(existing: existing),
    );
    if (result == null) return;
    try {
      await ref
          .read(inventoryRepositoryProvider)
          .upsert(result, isNew: existing == null);
      ref.invalidate(inventoryProvider);
      ref.invalidate(lowStockProvider);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: $e')));
      }
    }
  }
}

class _ItemDialog extends StatefulWidget {
  const _ItemDialog({this.existing});
  final InventoryItem? existing;

  @override
  State<_ItemDialog> createState() => _ItemDialogState();
}

class _ItemDialogState extends State<_ItemDialog> {
  static const _uuid = Uuid();
  late final _sku = TextEditingController(text: widget.existing?.sku ?? '');
  late final _name = TextEditingController(text: widget.existing?.name ?? '');
  late final _unit =
      TextEditingController(text: widget.existing?.unit ?? 'pcs');
  late final _qty = TextEditingController(
      text: widget.existing?.quantity.toString() ?? '0');
  late final _thr = TextEditingController(
      text: widget.existing?.threshold.toString() ?? '0');
  late final _cost = TextEditingController(
      text: widget.existing?.unitCost.toString() ?? '0');
  late final _loc =
      TextEditingController(text: widget.existing?.location ?? '');

  @override
  void dispose() {
    _sku.dispose();
    _name.dispose();
    _unit.dispose();
    _qty.dispose();
    _thr.dispose();
    _cost.dispose();
    _loc.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.existing == null ? 'New item' : 'Edit item'),
      content: SizedBox(
        width: 420,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: _sku,
                decoration: const InputDecoration(labelText: 'SKU'),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _name,
                decoration: const InputDecoration(labelText: 'Name'),
              ),
              const SizedBox(height: 8),
              Row(children: [
                Expanded(
                  child: TextField(
                    controller: _unit,
                    decoration: const InputDecoration(labelText: 'Unit'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: _loc,
                    decoration:
                        const InputDecoration(labelText: 'Location'),
                  ),
                ),
              ]),
              const SizedBox(height: 8),
              Row(children: [
                Expanded(
                  child: TextField(
                    controller: _qty,
                    keyboardType: TextInputType.number,
                    decoration:
                        const InputDecoration(labelText: 'Quantity'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: _thr,
                    keyboardType: TextInputType.number,
                    decoration:
                        const InputDecoration(labelText: 'Threshold'),
                  ),
                ),
              ]),
              const SizedBox(height: 8),
              TextField(
                controller: _cost,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Unit cost'),
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
            final base = widget.existing;
            final result = (base ??
                    InventoryItem(
                      id: _uuid.v4(),
                      sku: '',
                      name: '',
                      unit: 'pcs',
                      quantity: 0,
                      threshold: 0,
                      unitCost: 0,
                    ))
                .copyWith(
              sku: _sku.text.trim(),
              name: _name.text.trim(),
              unit: _unit.text.trim().isEmpty ? 'pcs' : _unit.text.trim(),
              quantity: double.tryParse(_qty.text) ?? 0,
              threshold: double.tryParse(_thr.text) ?? 0,
              unitCost: double.tryParse(_cost.text) ?? 0,
              location: _loc.text.trim().isEmpty ? null : _loc.text.trim(),
            );
            Navigator.of(context).pop(result);
          },
          child: const Text('Save'),
        ),
      ],
    );
  }
}
