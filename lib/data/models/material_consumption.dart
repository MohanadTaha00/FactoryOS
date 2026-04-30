import 'package:equatable/equatable.dart';

class MaterialConsumption extends Equatable {
  const MaterialConsumption({
    required this.id,
    required this.workOrderId,
    required this.inventoryId,
    required this.quantityPlanned,
    required this.quantityActual,
    required this.deducted,
    this.inventoryName,
    this.inventoryUnit,
    this.inventorySku,
  });

  final String id;
  final String workOrderId;
  final String inventoryId;
  final double quantityPlanned;
  final double quantityActual;
  final bool deducted;

  // Optional joined columns for display.
  final String? inventoryName;
  final String? inventoryUnit;
  final String? inventorySku;

  factory MaterialConsumption.fromMap(Map<String, dynamic> map) {
    final inv = map['inventory_items'] as Map<String, dynamic>?;
    return MaterialConsumption(
      id: map['id'] as String,
      workOrderId: map['work_order_id'] as String,
      inventoryId: map['inventory_id'] as String,
      quantityPlanned: _num(map['quantity_planned']),
      quantityActual: _num(map['quantity_actual']),
      deducted: (map['deducted'] ?? false) as bool,
      inventoryName: inv?['name'] as String?,
      inventoryUnit: inv?['unit'] as String?,
      inventorySku: inv?['sku'] as String?,
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'work_order_id': workOrderId,
        'inventory_id': inventoryId,
        'quantity_planned': quantityPlanned,
        'quantity_actual': quantityActual,
        'deducted': deducted,
      };

  @override
  List<Object?> get props =>
      [id, workOrderId, inventoryId, quantityPlanned, quantityActual, deducted];
}

double _num(Object? v) {
  if (v == null) return 0;
  if (v is num) return v.toDouble();
  return double.tryParse(v.toString()) ?? 0;
}
