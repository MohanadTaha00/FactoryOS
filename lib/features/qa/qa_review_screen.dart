import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/enums.dart';
import '../../state/providers.dart';

class QaReviewScreen extends ConsumerStatefulWidget {
  const QaReviewScreen({super.key, required this.orderId});
  final String orderId;

  @override
  ConsumerState<QaReviewScreen> createState() => _QaReviewScreenState();
}

class _QaReviewScreenState extends ConsumerState<QaReviewScreen> {
  final _notes = TextEditingController();
  bool _busy = false;

  @override
  void dispose() {
    _notes.dispose();
    super.dispose();
  }

  Future<void> _submit(QaResult result) async {
    if (result == QaResult.fail && _notes.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please add revision notes before rejecting.'),
        ),
      );
      return;
    }
    setState(() => _busy = true);
    try {
      await ref
          .read(workOrderRepositoryProvider)
          .recordQa(
            workOrderId: widget.orderId,
            result: result,
            notes: _notes.text.trim().isEmpty ? null : _notes.text.trim(),
          );
      ref.invalidate(workOrderByIdProvider(widget.orderId));
      ref.invalidate(qaQueueProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              result == QaResult.pass
                  ? 'Task approved successfully'
                  : 'Task rejected and returned for revision',
            ),
          ),
        );
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('QA action failed: $e')));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final orderAsync = ref.watch(workOrderByIdProvider(widget.orderId));
    return Scaffold(
      appBar: AppBar(title: const Text('QA review')),
      body: orderAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (o) {
          if (o == null) return const Center(child: Text('Order not found'));
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
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(o.code),
                    const SizedBox(height: 6),
                    Text(
                      'Status: ${o.status.label}',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _notes,
                maxLines: 5,
                decoration: const InputDecoration(
                  labelText: 'QA notes',
                  hintText: 'Inspection notes, defects, revisions...',
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _busy ? null : () => _submit(QaResult.fail),
                      icon: const Icon(Icons.close),
                      label: const Text('Reject'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: _busy ? null : () => _submit(QaResult.pass),
                      icon: const Icon(Icons.check),
                      label: const Text('Approve'),
                    ),
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }
}
