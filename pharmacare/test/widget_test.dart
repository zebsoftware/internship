import 'package:flutter_test/flutter_test.dart';
import 'package:pharmacare/medicine_model.dart';
import 'package:pharmacare/order_model.dart';

void main() {
  group('Medicine stock classification', () {
    Medicine medicine(int quantity) => Medicine(
      name: 'Test medicine',
      batchNo: 'B-01',
      type: 'Tablet',
      quantity: quantity,
      costPrice: 10,
      sellingPrice: 15,
      expiryDate: DateTime(2030, 1, 1),
    );

    test('zero quantity is out of stock', () {
      expect(medicine(0).isOutOfStock, isTrue);
      expect(medicine(0).statusText, 'Out of Stock');
    });

    test('quantities below 20 are low stock', () {
      expect(medicine(19).isLowStock, isTrue);
      expect(medicine(19).statusText, 'Low Stock');
    });

    test('20 and above are in stock', () {
      expect(medicine(20).isLowStock, isFalse);
      expect(medicine(20).statusText, 'In Stock');
    });
  });

  test('Order item count sums quantities', () {
    final order = Order(
      customerName: 'Sample',
      customerPhone: '',
      customerEmail: '',
      items: [
        OrderItem(medicineId: 'a', medicineName: 'A', price: 10, quantity: 2, total: 20),
        OrderItem(medicineId: 'b', medicineName: 'B', price: 5, quantity: 3, total: 15),
      ],
      subtotal: 35,
      tax: 0,
      totalAmount: 35,
    );
    expect(order.totalItems, 5);
  });
}
