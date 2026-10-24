import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';

class PharmacySettings {
  final String name;
  final String phone;
  final String address;
  final String currency;
  final double taxPercent;
  final int lowStockThreshold;
  final int expiryWarningDays;
  final bool alertsEnabled;

  const PharmacySettings({
    this.name = 'My Pharmacy',
    this.phone = '',
    this.address = '',
    this.currency = 'PKR',
    this.taxPercent = 0,
    this.lowStockThreshold = 20,
    this.expiryWarningDays = 60,
    this.alertsEnabled = true,
  });

  factory PharmacySettings.fromMap(Map<String, dynamic>? map) {
    final m = map ?? {};
    return PharmacySettings(
      name: m['name'] as String? ?? 'My Pharmacy',
      phone: m['phone'] as String? ?? '',
      address: m['address'] as String? ?? '',
      currency: supportedCurrencies.contains(m['currency']) ? m['currency'] as String : 'PKR',
      taxPercent: ((m['taxPercent'] as num?) ?? 0).toDouble(),
      lowStockThreshold: ((m['lowStockThreshold'] as num?) ?? 20).toInt(),
      expiryWarningDays: ((m['expiryWarningDays'] as num?) ?? 60).toInt(),
      alertsEnabled: m['alertsEnabled'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toMap() => {
    'name': name, 'phone': phone, 'address': address,
    'currency': currency, 'taxPercent': taxPercent,
    'lowStockThreshold': lowStockThreshold,
    'expiryWarningDays': expiryWarningDays,
    'alertsEnabled': alertsEnabled,
  };
}

const supportedCurrencies = ['PKR', 'USD', 'EUR', 'GBP', 'AED'];

String formatMoney(num amount, String currency) {
  final symbols = {'PKR': 'Rs ', 'USD': '\$', 'EUR': '€', 'GBP': '£', 'AED': 'AED '};
  return '${symbols[currency] ?? 'Rs '}${NumberFormat('#,##0.00').format(amount)}';
}

/// One currency per pharmacy. Switching currency after priced records exist is
/// deliberately rejected: relabelling existing amounts would corrupt reporting.
class PharmacySettingsService {
  PharmacySettingsService._();
  static final instance = PharmacySettingsService._();
  final current = ValueNotifier<PharmacySettings>(const PharmacySettings());
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _subscription;

  DocumentReference<Map<String, dynamic>> get _doc {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) throw StateError('Sign in to access pharmacy settings');
    return FirebaseFirestore.instance.collection('users').doc(uid)
      .collection('settings').doc('pharmacy');
  }

  void listen() {
    _subscription?.cancel();
    if (FirebaseAuth.instance.currentUser == null) return;
    _subscription = _doc.snapshots().listen((doc) {
      current.value = PharmacySettings.fromMap(doc.data());
    });
  }

  Future<void> save(PharmacySettings settings) async {
    if (!supportedCurrencies.contains(settings.currency) ||
        settings.taxPercent < 0 || settings.taxPercent > 100 ||
        settings.lowStockThreshold < 0 || settings.expiryWarningDays < 0) {
      throw ArgumentError('Invalid pharmacy settings');
    }
    final existing = await _doc.get();
    final previous = PharmacySettings.fromMap(existing.data());
    if (existing.exists && previous.currency != settings.currency) {
      throw StateError('Currency changes require a verified price and order migration. Existing amounts were not changed.');
    }
    if (!existing.exists && settings.currency != 'PKR') {
      final db = FirebaseFirestore.instance;
      final inventory = await db.collection('medicines').limit(1).get();
      final orders = await db.collection('orders').limit(1).get();
      if (inventory.docs.isNotEmpty || orders.docs.isNotEmpty) {
        throw StateError('Existing financial records must be migrated before selecting a different currency.');
      }
    }
    await _doc.set(settings.toMap()..['updatedAt'] = FieldValue.serverTimestamp());
    current.value = settings;
  }
}
