import 'package:equatable/equatable.dart';

class InventoryItem extends Equatable {
  const InventoryItem({
    required this.id,
    required this.sku,
    required this.name,
    required this.unit,
    required this.quantity,
    required this.threshold,
    required this.unitCost,
    this.description,
    this.location,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String sku;
  final String name;
  final String? description;
  final String unit;
  final double quantity;
  final double threshold;
  final double unitCost;
  final String? location;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  /// As described in section 4.3 of the report -- inventory state predicate.
  bool isBelowThreshold() => quantity <= threshold;

  factory InventoryItem.fromMap(Map<String, dynamic> map) => InventoryItem(
        id: map['id'] as String,
        sku: map['sku'] as String,
        name: map['name'] as String,
        description: map['description'] as String?,
        unit: (map['unit'] ?? 'pcs') as String,
        quantity: _num(map['quantity']),
        threshold: _num(map['threshold']),
        unitCost: _num(map['unit_cost']),
        location: map['location'] as String?,
        createdAt: _date(map['created_at']),
        updatedAt: _date(map['updated_at']),
      );

  Map<String, dynamic> toMap() => {
        'id': id,
        'sku': sku,
        'name': name,
        'description': description,
        'unit': unit,
        'quantity': quantity,
        'threshold': threshold,
        'unit_cost': unitCost,
        'location': location,
      };

  InventoryItem copyWith({
    String? sku,
    String? name,
    String? description,
    String? unit,
    double? quantity,
    double? threshold,
    double? unitCost,
    String? location,
  }) =>
      InventoryItem(
        id: id,
        sku: sku ?? this.sku,
        name: name ?? this.name,
        description: description ?? this.description,
        unit: unit ?? this.unit,
        quantity: quantity ?? this.quantity,
        threshold: threshold ?? this.threshold,
        unitCost: unitCost ?? this.unitCost,
        location: location ?? this.location,
        createdAt: createdAt,
        updatedAt: updatedAt,
      );

  @override
  List<Object?> get props =>
      [id, sku, name, unit, quantity, threshold, unitCost, location];
}

double _num(Object? v) {
  if (v == null) return 0;
  if (v is num) return v.toDouble();
  return double.tryParse(v.toString()) ?? 0;
}

DateTime? _date(Object? v) {
  if (v == null) return null;
  if (v is DateTime) return v;
  return DateTime.tryParse(v.toString());
}
