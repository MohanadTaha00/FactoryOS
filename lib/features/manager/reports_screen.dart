import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/enums.dart';
import '../../state/providers.dart';
import '../reports/report_generator.dart';
import '../shared/widgets/empty_state.dart';
import '../shared/widgets/refresh_data_button.dart';
import '../shared/widgets/status_chip.dart';

class ReportsScreen extends ConsumerWidget {
  const ReportsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ordersAsync = ref.watch(allWorkOrdersProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Reports'),
        actions: [
          const RefreshDataButton(),
          ordersAsync.maybeWhen(
            data: (orders) => IconButton(
              tooltip: 'Summary report',
              icon: const Icon(Icons.summarize_outlined),
              onPressed: () => ReportGenerator.shareSummaryReport(orders),
            ),
            orElse: () => const SizedBox.shrink(),
          ),
        ],
      ),
      body: ordersAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (orders) {
          if (orders.isEmpty) {
            return const EmptyState(
              icon: Icons.bar_chart_outlined,
              title: 'No data to report on yet',
            );
          }
          final approved = orders
              .where((o) =>
                  o.status == WorkOrderStatus.approved ||
                  o.status == WorkOrderStatus.completed)
              .toList();
          final avgLatencyMs = approved
              .map((o) => o.assignmentLatency()?.inMilliseconds)
              .whereType<int>()
              .fold<List<int>>([], (l, ms) => l..add(ms));
          final avg = avgLatencyMs.isEmpty
              ? 0
              : avgLatencyMs.reduce((a, b) => a + b) ~/ avgLatencyMs.length;

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Throughput',
                          style: TextStyle(
                              fontSize: 16, fontWeight: FontWeight.w700)),
                      const SizedBox(height: 12),
                      _row('Total work orders', orders.length.toString()),
                      _row('Approved / completed', approved.length.toString()),
                      _row(
                          'Avg. assignment-to-start latency',
                          avg == 0
                              ? '—'
                              : '${(avg / 1000).toStringAsFixed(1)} s'),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              const Text('Per-order PDFs',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),
              for (final o in orders.take(40))
                Card(
                  child: ListTile(
                    leading: const Icon(Icons.picture_as_pdf_outlined),
                    title: Text(o.title),
                    subtitle:
                        Text('${o.code} • created ${o.createdAt.toLocal()}'),
                    trailing: StatusChip(status: o.status, dense: true),
                    onTap: () => ReportGenerator.shareWorkOrderReport(o),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  Widget _row(String k, String v) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [
            Expanded(child: Text(k)),
            Text(v, style: const TextStyle(fontWeight: FontWeight.w700)),
          ],
        ),
      );
}
