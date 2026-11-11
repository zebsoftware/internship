import 'package:flutter_test/flutter_test.dart';
import 'package:pharmacare/pharmacy_settings.dart';

void main() {
  test('Defaults are safe for a new pharmacy', () {
    final s = PharmacySettings.fromMap(null);
    expect(s.currency, 'PKR');
    expect(s.lowStockThreshold, 20);
    expect(s.expiryWarningDays, 60);
  });

  test('Saved settings preserve configured values', () {
    final original = PharmacySettings(
      name: 'Northside Pharmacy',
      currency: 'AED',
      taxPercent: 5,
      lowStockThreshold: 15,
      expiryWarningDays: 90,
    );
    final restored = PharmacySettings.fromMap(original.toMap());
    expect(restored.name, 'Northside Pharmacy');
    expect(restored.currency, 'AED');
    expect(restored.taxPercent, 5);
    expect(restored.lowStockThreshold, 15);
  });

  test('Unsupported currencies fall back to PKR', () {
    expect(PharmacySettings.fromMap({'currency': 'XYZ'}).currency, 'PKR');
  });

  test('Money formatting uses selected currency', () {
    expect(formatMoney(1234.5, 'PKR'), 'Rs 1,234.50');
    expect(formatMoney(25, 'USD'), '\$25.00');
  });
}
