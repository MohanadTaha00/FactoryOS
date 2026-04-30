import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../../data/models/work_order.dart';

class ReportGenerator {
  static final _df = DateFormat('yyyy-MM-dd HH:mm');

  static Future<void> shareWorkOrderReport(WorkOrder order) async {
    final doc = pw.Document();
    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        build: (_) => [
          pw.Text(
            'FactoryOS - Work Order Report',
            style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 8),
          pw.Text('Code: ${order.code}'),
          pw.Text('Title: ${order.title}'),
          pw.Text('Status: ${order.status.label}'),
          pw.Text('Priority: P${order.priority}'),
          pw.Text('Created: ${_df.format(order.createdAt)}'),
          if (order.dueAt != null) pw.Text('Due: ${_df.format(order.dueAt!)}'),
          pw.SizedBox(height: 12),
          pw.Text(
            'Materials',
            style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
          ),
          pw.Table.fromTextArray(
            headers: const ['Item', 'SKU', 'Planned', 'Actual', 'Deducted'],
            data: [
              for (final m in order.materials)
                [
                  m.inventoryName ?? '-',
                  m.inventorySku ?? '-',
                  m.quantityPlanned.toString(),
                  m.quantityActual.toString(),
                  m.deducted ? 'Yes' : 'No',
                ],
            ],
          ),
          pw.SizedBox(height: 12),
          pw.Text(
            'Quality Logs',
            style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
          ),
          pw.Table.fromTextArray(
            headers: const ['Inspector', 'Result', 'Date', 'Notes'],
            data: [
              for (final q in order.qualityLogs)
                [
                  q.inspectorName ?? q.inspectorId,
                  q.result.label,
                  _df.format(q.inspectedAt),
                  q.notes ?? '-',
                ],
            ],
          ),
        ],
      ),
    );

    await Printing.sharePdf(
      bytes: await doc.save(),
      filename: '${order.code}_report.pdf',
    );
  }

  static Future<void> shareSummaryReport(List<WorkOrder> orders) async {
    final doc = pw.Document();
    final approved = orders
        .where(
          (o) =>
              o.status.name == 'approved' || o.status.name == 'completed',
        )
        .length;
    doc.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (_) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(
              'FactoryOS - Summary Report',
              style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold),
            ),
            pw.SizedBox(height: 12),
            pw.Text('Generated: ${_df.format(DateTime.now())}'),
            pw.Text('Total work orders: ${orders.length}'),
            pw.Text('Approved/Completed: $approved'),
            pw.SizedBox(height: 10),
            pw.Table.fromTextArray(
              headers: const ['Code', 'Title', 'Status', 'Priority'],
              data: [
                for (final o in orders.take(100))
                  [o.code, o.title, o.status.label, 'P${o.priority}'],
              ],
            ),
          ],
        ),
      ),
    );
    await Printing.sharePdf(
      bytes: await doc.save(),
      filename: 'factoryos_summary.pdf',
    );
  }
}
