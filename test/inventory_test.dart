import 'package:factoryos/data/models/inventory_item.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('inventory low-stock predicate', () {
    const item = InventoryItem(
      id: '1',
      sku: 'STL-001',
      name: 'Steel',
      unit: 'pcs',
      quantity: 5,
      threshold: 10,
      unitCost: 1,
    );
    expect(item.isBelowThreshold(), isTrue);
  });
}
