import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'pharma_theme.dart';
import 'pharmacy_data.dart';
import 'pharmacy_settings.dart';

/// Responsive live dashboard for the authenticated pharmacy account.
class PharmaHome extends StatefulWidget {
  const PharmaHome({super.key});

  @override
  State<PharmaHome> createState() => _PharmaHomeState();
}

class _PharmaHomeState extends State<PharmaHome> {
  late final String? _uid;
  Stream<DocumentSnapshot<Map<String, dynamic>>>? _profile;
  Stream<QuerySnapshot<Map<String, dynamic>>>? _orders;
  Stream<QuerySnapshot<Map<String, dynamic>>>? _medicines;

  @override
  void initState() {
    super.initState();
    _uid = FirebaseAuth.instance.currentUser?.uid;
    if (_uid != null) {
      _profile = FirebaseFirestore.instance.collection('users').doc(_uid).snapshots();
      _orders = PharmacyData.collection('orders')
          .orderBy('createdAt', descending: true).limit(200).snapshots();
      _medicines = PharmacyData.collection('medicines')
          .orderBy('name').limit(200).snapshots();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_uid == null) {
      return const Scaffold(
        body: Center(child: Text('Sign in to view your pharmacy dashboard.')),
      );
    }

    return Scaffold(
      body: SafeArea(
        child: ValueListenableBuilder<PharmacySettings>(
          valueListenable: PharmacySettingsService.instance.current,
          builder: (context, settings, _) => StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
            stream: _profile,
            builder: (context, profile) {
              final name = profile.data?.data()?['fullName'] as String?
                  ?? FirebaseAuth.instance.currentUser?.displayName
                  ?? 'Pharmacy Owner';
              return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream: _orders,
                builder: (context, orders) => StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                  stream: _medicines,
                  builder: (context, medicines) {
                    final failure = profile.hasError || orders.hasError || medicines.hasError;
                    final loading = !orders.hasData || !medicines.hasData;
                    final orderDocs = orders.data?.docs
                        .where((doc) => doc.data()['archived'] != true)
                        .toList() ?? [];
                    final medicineDocs = medicines.data?.docs ?? [];
                    final sales = orderDocs
                        .where((doc) => doc.data()['status'] == 'completed')
                        .fold<double>(
                          0,
                          (total, doc) => total +
                              ((doc.data()['totalAmount'] as num?)?.toDouble() ?? 0),
                        );
                    final lowStock = medicineDocs.where((doc) {
                      final quantity = doc.data()['quantity'];
                      return quantity is num && quantity <= settings.lowStockThreshold;
                    }).length;
                    final expiresBy = DateTime.now().add(
                      Duration(days: settings.expiryWarningDays),
                    );
                    final expiring = medicineDocs.where((doc) {
                      final expiry = doc.data()['expiryDate'];
                      return expiry is Timestamp && !expiry.toDate().isAfter(expiresBy);
                    }).length;

                    orderDocs.sort((first, second) {
                      final a = first.data()['createdAt'];
                      final b = second.data()['createdAt'];
                      if (a is Timestamp && b is Timestamp) return b.compareTo(a);
                      return 0;
                    });

                    return LayoutBuilder(
                      builder: (context, layout) {
                        final wide = layout.maxWidth > 850;
                        return ListView(
                          padding: EdgeInsets.symmetric(
                            horizontal: wide ? 32 : 18,
                            vertical: wide ? 26 : 18,
                          ),
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    gradient: const LinearGradient(
                                      colors: [PharmaTheme.blue, PharmaTheme.teal],
                                    ),
                                    borderRadius: BorderRadius.circular(15),
                                  ),
                                  child: const Icon(
                                    Icons.medical_services_rounded,
                                    color: Colors.white,
                                    size: 26,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                const Text.rich(
                                  TextSpan(children: [
                                    TextSpan(text: 'Pharma'),
                                    TextSpan(
                                      text: 'Care',
                                      style: TextStyle(color: PharmaTheme.teal),
                                    ),
                                  ]),
                                  style: TextStyle(
                                    fontSize: 24,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: -.6,
                                  ),
                                ),
                                const Spacer(),
                                const Tooltip(
                                  message: 'Your account data stays in its own workspace',
                                  child: Icon(Icons.verified_user_outlined, color: PharmaTheme.teal),
                                ),
                              ],
                            ),
                            const SizedBox(height: 28),
                            Text(
                              'WELCOME BACK',
                              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                                color: PharmaTheme.teal,
                                letterSpacing: 1.6,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 7),
                            Text(
                              name,
                              style: TextStyle(
                                fontSize: wide ? 34 : 28,
                                fontWeight: FontWeight.w800,
                                letterSpacing: -.8,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              settings.name,
                              style: const TextStyle(color: PharmaTheme.muted),
                            ),
                            const SizedBox(height: 22),
                            if (failure) ...[
                              const Card(
                                child: Padding(
                                  padding: EdgeInsets.all(18),
                                  child: Row(children: [
                                    Icon(Icons.cloud_off_outlined, color: Color(0xFFFFB183)),
                                    SizedBox(width: 12),
                                    Expanded(
                                      child: Text(
                                        'Some data could not be loaded. Check your connection and account permissions.',
                                      ),
                                    ),
                                  ]),
                                ),
                              ),
                              const SizedBox(height: 12),
                            ],
                            if (loading) ...[
                              const LinearProgressIndicator(minHeight: 3),
                              const SizedBox(height: 18),
                            ],
                            GridView.count(
                              crossAxisCount: layout.maxWidth > 900 ? 4 : 2,
                              crossAxisSpacing: 12,
                              mainAxisSpacing: 12,
                              childAspectRatio: layout.maxWidth > 900
                                  ? 1.2
                                  : layout.maxWidth > 460 ? 1.5 : 1.05,
                              physics: const NeverScrollableScrollPhysics(),
                              shrinkWrap: true,
                              children: [
                                _metric('Orders (loaded)', loading ? '—' : '${orderDocs.length}',
                                  Icons.receipt_long_rounded, PharmaTheme.blue),
                                _metric('Low stock (loaded)', loading ? '—' : '$lowStock',
                                  Icons.inventory_2_outlined, const Color(0xFFFFB45D)),
                                _metric('Expiring soon', loading ? '—' : '$expiring',
                                  Icons.event_busy_outlined, const Color(0xFFFF8993)),
                                _metric('Sales (loaded)',
                                  loading ? '—' : formatMoney(sales, settings.currency),
                                  Icons.payments_outlined, PharmaTheme.teal),
                              ],
                            ),
                            const SizedBox(height: 8),
                            const Text('Dashboard summaries cover up to 200 recent orders and 200 medicines.',
                              style: TextStyle(color: PharmaTheme.muted, fontSize: 11)),
                            const SizedBox(height: 24),
                            Row(
                              children: [
                                const Icon(Icons.history_rounded, color: PharmaTheme.teal),
                                const SizedBox(width: 9),
                                Text(
                                  'Recent orders',
                                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 9),
                            if (!loading && orderDocs.isEmpty)
                              const Card(
                                child: Padding(
                                  padding: EdgeInsets.all(24),
                                  child: Column(children: [
                                    Icon(Icons.receipt_long_outlined,
                                      size: 36, color: PharmaTheme.muted),
                                    SizedBox(height: 12),
                                    Text('No orders yet',
                                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                                    SizedBox(height: 6),
                                    Text('Your most recent orders will appear here.',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(color: PharmaTheme.muted)),
                                  ]),
                                ),
                              ),
                            for (final doc in orderDocs.take(5))
                              Card(
                                child: ListTile(
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 16, vertical: 5,
                                  ),
                                  leading: CircleAvatar(
                                    backgroundColor: PharmaTheme.blue.withValues(alpha: .2),
                                    child: const Icon(Icons.shopping_bag_outlined,
                                      color: PharmaTheme.blue),
                                  ),
                                  title: Text(
                                    doc.data()['customerName'] as String? ?? 'Customer',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  subtitle: Text(
                                    (doc.data()['status'] as String? ?? 'pending').toUpperCase(),
                                    style: const TextStyle(color: PharmaTheme.muted, fontSize: 12),
                                  ),
                                  trailing: Text(
                                    formatMoney(
                                      (doc.data()['totalAmount'] as num?) ?? 0,
                                      doc.data()['currency'] as String? ?? settings.currency,
                                    ),
                                    style: const TextStyle(fontWeight: FontWeight.w700),
                                  ),
                                ),
                              ),
                          ],
                        );
                      },
                    );
                  },
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _metric(String label, String value, IconData icon, Color accent) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: PharmaTheme.card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFF304461)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Container(
            padding: const EdgeInsets.all(9),
            decoration: BoxDecoration(
              color: accent.withValues(alpha: .15),
              borderRadius: BorderRadius.circular(11),
            ),
            child: Icon(icon, color: accent, size: 22),
          ),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
          ),
          Text(
            label,
            maxLines: 2,
            style: const TextStyle(fontSize: 12, color: PharmaTheme.muted),
          ),
        ],
      ),
    );
  }
}
