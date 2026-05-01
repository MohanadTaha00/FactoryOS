import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/enums.dart';
import '../../state/providers.dart';
import '../shared/widgets/status_chip.dart';
import '../shared/widgets/work_order_pdf_attachment.dart';

class TaskDetailsScreen extends ConsumerStatefulWidget {
  const TaskDetailsScreen({super.key, required this.orderId});
  final String orderId;

  @override
  ConsumerState<TaskDetailsScreen> createState() => _TaskDetailsScreenState();
}

class _TaskDetailsScreenState extends ConsumerState<TaskDetailsScreen> {
  bool _busy = false;
  final _producedController = TextEditingController();

  @override
  void dispose() {
    _producedController.dispose();
    super.dispose();
  }

  Future<void> _start() async {
    setState(() => _busy = true);
    try {
      await ref
          .read(workOrderRepositoryProvider)
          .transition(
            workOrderId: widget.orderId,
            to: WorkOrderStatus.inProgress,
            message: 'worker started task',
          );
      ref.invalidate(workOrderByIdProvider(widget.orderId));
      ref.invalidate(myWorkOrdersProvider);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Task started')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to start task: $e')));
      }
    }
    if (mounted) setState(() => _busy = false);
  }

  Future<void> _submitQa() async {
    setState(() => _busy = true);
    try {
      await ref.read(workOrderRepositoryProvider).submitForQa(widget.orderId);
      ref.invalidate(workOrderByIdProvider(widget.orderId));
      ref.invalidate(myWorkOrdersProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Submitted to QA successfully')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Submit failed: $e')));
      }
    }
    if (mounted) setState(() => _busy = false);
  }

  Future<void> _saveProduced(WorkOrderStatus status, int target) async {
    final parsed = int.tryParse(_producedController.text.trim());
    if (parsed == null || parsed < 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter a valid produced quantity')),
      );
      return;
    }
    if (parsed > target) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Produced quantity cannot exceed target ($target)'),
        ),
      );
      return;
    }

    setState(() => _busy = true);
    try {
      await ref
          .read(workOrderRepositoryProvider)
          .updateProgress(widget.orderId, parsed);
      ref.invalidate(workOrderByIdProvider(widget.orderId));
      ref.invalidate(myWorkOrdersProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Produced quantity updated')),
        );
      }
      if (parsed == target && status == WorkOrderStatus.inProgress && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Target reached. You can now submit for QA.'),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to update quantity: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final orderAsync = ref.watch(workOrderByIdProvider(widget.orderId));
    return Scaffold(
      appBar: AppBar(title: const Text('Task details')),
      body: orderAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (o) {
          if (o == null) return const Center(child: Text('Task not found'));
          final producedText = o.quantityProduced.toString();
          if (_producedController.text != producedText) {
            _producedController.text = producedText;
          }
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      o.title,
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      o.code,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                        fontFamily: 'monospace',
                      ),
                    ),
                    const SizedBox(height: 10),
                    if (o.status == WorkOrderStatus.rejected)
                      const Chip(
                        avatar: Icon(Icons.build_circle_outlined, size: 18),
                        label: Text('Revision'),
                      )
                    else
                      StatusChip(status: o.status),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              if (o.attachmentUrl != null && o.attachmentUrl!.trim().isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: WorkOrderPdfAttachment(url: o.attachmentUrl!),
                ),
              if (o.status == WorkOrderStatus.rejected) ...[
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.errorContainer,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Revision sent to worker',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onErrorContainer,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        o.latestRevisionNotes ??
                            'QA requested revision. Please review and rework.',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onErrorContainer,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
              ],
              if (o.description != null) Text(o.description!),
              const SizedBox(height: 18),
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: LinearProgressIndicator(
                  value: o.quantityTarget == 0
                      ? 0
                      : (o.quantityProduced / o.quantityTarget).clamp(0, 1),
                  minHeight: 10,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Produced: ${o.quantityProduced}/${o.quantityTarget}',
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 18),
              if (o.status == WorkOrderStatus.inProgress ||
                  o.status == WorkOrderStatus.rejected) ...[
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _producedController,
                        keyboardType: TextInputType.number,
                        enabled: !_busy,
                        decoration: const InputDecoration(
                          labelText: 'Produced quantity',
                          hintText: 'Enter produced count',
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    FilledButton.icon(
                      onPressed: _busy
                          ? null
                          : () => _saveProduced(o.status, o.quantityTarget),
                      icon: const Icon(Icons.save_outlined),
                      label: const Text('Save'),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
              ],
              if (o.status == WorkOrderStatus.assigned ||
                  o.status == WorkOrderStatus.rejected)
                FilledButton(
                  onPressed: _busy ? null : _start,
                  child: Text(
                    o.status == WorkOrderStatus.rejected
                        ? 'Start revision'
                        : 'Start task',
                  ),
                ),
              if (o.status == WorkOrderStatus.inProgress)
                FilledButton.icon(
                  onPressed: _busy ? null : _submitQa,
                  icon: const Icon(Icons.upload_outlined),
                  label: const Text('Submit for QA'),
                ),
            ],
          );
        },
      ),
    );
  }
}
