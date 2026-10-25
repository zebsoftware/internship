import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'pharmacy_data.dart';
import 'pharmacy_settings.dart';
import 'AddOrderDialog.dart';

/// Clean landing dashboard backed by the same Firestore account collections.
class PharmaHome extends StatelessWidget {
  const PharmaHome({super.key});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final uid = user?.uid;
    if (uid == null) return const Center(child: Text('Please sign in'));
    final orders = PharmacyData.collection('orders').snapshots();
    final medicines = PharmacyData.collection('medicines').snapshots();
    return Scaffold(
      backgroundColor: const Color(0xFF071A31),
      body: SafeArea(child: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance.collection('users').doc(uid).snapshots(),
        builder: (context, person) {
          final name = person.data?.data()?['fullName'] as String? ??
              user?.displayName ?? 'Pharmacy Owner';
          return ListView(padding: const EdgeInsets.all(18), children: [
            Row(children: [
              const CircleAvatar(backgroundColor: Color(0xFF00A789),
                child: Icon(Icons.medical_services_rounded, color: Colors.white)),
              const SizedBox(width: 10),
              const Text.rich(TextSpan(children: [
                TextSpan(text: 'Pharma', style: TextStyle(color: Colors.white)),
                TextSpan(text: 'Care', style: TextStyle(color: Color(0xFF25D8AB))),
              ]), style: TextStyle(fontSize: 23, fontWeight: FontWeight.w800)),
              const Spacer(),
              IconButton(tooltip: 'Inventory alerts',
                onPressed: () => showDialog<void>(context: context, builder: (_) =>
                  AlertDialog(title: const Text('Inventory Alerts'),
                    content: StreamBuilder<QuerySnapshot<Map<String,dynamic>>>(
                      stream: medicines,
                      builder: (context, snap) {
                        if (!snap.hasData) return const Text('Loading...');
                        final config = PharmacySettingsService.instance.current.value;
                        if (!config.alertsEnabled) return const Text('Alerts disabled in Settings.');
                        final now = DateTime.now();
                        final alerts = <String>[];
                        for (final doc in snap.data!.docs) {
                          final m = doc.data(); final count = (m['quantity'] as num?)?.toInt() ?? 0;
                          if (count <= config.lowStockThreshold) alerts.add('${m['name']}: $count left');
                          final exp = m['expiryDate'];
                          if (exp is Timestamp && exp.toDate().isBefore(now.add(Duration(days: config.expiryWarningDays)))) {
                            alerts.add('${m['name']}: nearing expiry');
                          }
                        }
                        return SizedBox(width: 300, height: 260,
                          child: alerts.isEmpty ? const Center(child: Text('No active alerts')) :
                            ListView(children: alerts.map((a) => ListTile(
                              leading: const Icon(Icons.warning_amber_rounded), title: Text(a))).toList()));
                      },
                    ),
                    actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close'))])),
                icon: const Icon(Icons.notifications_outlined)),
            ]),
            const SizedBox(height: 20),
            const Text('Welcome Back', style: TextStyle(fontSize: 14, color: Color(0xFFA2B5D2))),
            Text(name, style: const TextStyle(fontSize: 30, fontWeight: FontWeight.w800)),
            ValueListenableBuilder<PharmacySettings>(
              valueListenable: PharmacySettingsService.instance.current,
              builder: (_, settings, __) => Text(settings.name,
                style: const TextStyle(color: Color(0xFF8EA8CA)))),
            const SizedBox(height: 22),
            StreamBuilder<QuerySnapshot<Map<String,dynamic>>>(
              stream: orders,
              builder: (context, o) => StreamBuilder<QuerySnapshot<Map<String,dynamic>>>(
                stream: medicines,
                builder: (context, m) {
                  final orderData = o.data?.docs.where((d) => d.data()['archived'] != true).toList() ?? [];
                  final medicineData = m.data?.docs ?? [];
                  final completed = orderData.where((d) => d.data()['status'] == 'completed');
                  final total = completed.fold<double>(0, (v,d) => v + ((d.data()['totalAmount'] as num?)?.toDouble() ?? 0));
                  final config = PharmacySettingsService.instance.current.value;
                  final low = medicineData.where((d) => ((d.data()['quantity'] as num?)?.toInt() ?? 0) <= config.lowStockThreshold).length;
                  final expires = medicineData.where((d) {
                    final date = d.data()['expiryDate'];
                    return date is Timestamp && date.toDate().isBefore(DateTime.now().add(Duration(days:config.expiryWarningDays)));
                  }).length;
                  Widget tile(String label, String value, IconData icon, Color accent) =>
                    Container(padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18)),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Icon(icon, color: accent),
                        const SizedBox(height: 8),
                        Text(value, style: const TextStyle(color: Color(0xFF082342), fontSize: 21, fontWeight: FontWeight.bold)),
                        Text(label, style: const TextStyle(color: Color(0xFF53657B), fontSize: 12)),
                      ]));
                  return GridView.count(crossAxisCount: 2, crossAxisSpacing: 12, mainAxisSpacing: 12,
                    shrinkWrap: true, physics: const NeverScrollableScrollPhysics(), childAspectRatio: 1.6,
                    children: [
                      tile('Total orders', '${orderData.length}', Icons.shopping_cart_outlined, Colors.blue),
                      tile('Low stock', '$low', Icons.warning_amber, Colors.red),
                      tile('Expiring soon', '$expires', Icons.hourglass_bottom, Colors.orange),
                      tile('Sales', formatMoney(total, config.currency), Icons.payments_outlined, Colors.green),
                    ]);
                },
              ),
            ),
            const SizedBox(height: 26),
            const Text('Quick Actions', style: TextStyle(fontSize: 19, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            SizedBox(height: 56, child: FilledButton.icon(
              onPressed: () => showDialog(context: context, useSafeArea: false,
                builder: (_) => AddOrderDialog(onSaved: () {})),
              icon: const Icon(Icons.add_shopping_cart_outlined),
              label: const Text('New Order'),
            )),
            const SizedBox(height: 24),
            const Text('Recent Orders', style: TextStyle(fontSize: 19, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            StreamBuilder<QuerySnapshot<Map<String,dynamic>>>(
              stream: orders,
              builder: (context, snapshot) {
                if (snapshot.hasError) return Text('Unable to load orders: ${snapshot.error}');
                if (!snapshot.hasData) return const LinearProgressIndicator();
                final docs = snapshot.data!.docs.where((d) => d.data()['archived'] != true).toList()
                    ..sort((a,b) {
                      final x = a.data()['createdAt'], y = b.data()['createdAt'];
                      if (x is Timestamp && y is Timestamp) return y.compareTo(x);
                      return 0;
                    });
                if (docs.isEmpty) return const Card(child: Padding(padding: EdgeInsets.all(18), child: Text('No orders yet. Create your first order!')));
                return Column(children: docs.take(5).map((d) => Card(child: ListTile(
                  leading: const Icon(Icons.receipt_long, color: Color(0xFF40AEFF)),
                  title: Text(d.data()['customerName'] as String? ?? 'Customer'),
                  subtitle: Text(d.data()['status'] as String? ?? 'Pending'),
                  trailing: Text(formatMoney((d.data()['totalAmount'] as num?) ?? 0,
                    d.data()['currency'] as String? ?? PharmacySettingsService.instance.current.value.currency)),
                ))).toList());
              },
            ),
          ]);
        },
      )),
    );
  }
}
