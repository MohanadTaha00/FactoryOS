import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../data/models/work_order.dart';
import 'status_chip.dart';

final _df = DateFormat('MMM d, yyyy');

class WorkOrderTile extends StatelessWidget {
  const WorkOrderTile({
    super.key,
    required this.order,
    this.onTap,
    this.compact = false,
  });

  final WorkOrder order;
  final VoidCallback? onTap;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Card(
      elevation: 0,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: EdgeInsets.all(compact ? 12 : 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      color: order.status.color.withValues(alpha: 0.13),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      Icons.assignment_outlined,
                      size: 18,
                      color: order.status.color,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      order.title,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 15,
                      ),
                    ),
                  ),
                  StatusChip(status: order.status, dense: true),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                order.code,
                style: TextStyle(
                  color: cs.onSurfaceVariant,
                  fontSize: 12,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
              if (!compact && order.description != null) ...[
                const SizedBox(height: 6),
                Text(
                  order.description!,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: cs.onSurface, fontSize: 13),
                ),
              ],
              const SizedBox(height: 10),
              Wrap(
                spacing: 12,
                runSpacing: 6,
                children: [
                  _meta(
                    Icons.person_outline,
                    order.assignedToName ?? 'Unassigned',
                    cs,
                  ),
                  _meta(
                    Icons.calendar_today_outlined,
                    order.dueAt != null
                        ? 'Due ${_df.format(order.dueAt!)}'
                        : 'No due date',
                    cs,
                  ),
                  _meta(
                    Icons.inventory_2_outlined,
                    '${order.quantityProduced}/${order.quantityTarget}',
                    cs,
                  ),
                  if (order.priority <= 2)
                    _meta(Icons.priority_high, 'P${order.priority}', cs,
                        color: Colors.red),
                ],
              ),
              if (!compact) ...[
                const SizedBox(height: 10),
                Row(
                  children: [
                    Text(
                      'Tap for details',
                      style: TextStyle(
                        color: cs.primary,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Icon(
                      Icons.arrow_forward_rounded,
                      size: 14,
                      color: cs.primary,
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _meta(IconData icon, String text, ColorScheme cs, {Color? color}) {
    final c = color ?? cs.onSurfaceVariant;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: c),
        const SizedBox(width: 4),
        Text(text, style: TextStyle(fontSize: 12, color: c)),
      ],
    );
  }
}
