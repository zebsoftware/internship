import 'package:cloud_firestore/cloud_firestore.dart' hide Order;
import 'package:flutter/material.dart';

import 'AddOrderDialog.dart';
import 'OrderDetailsDialog.dart';
import 'order_model.dart';
import 'pharma_theme.dart';
import 'pharmacy_data.dart';
import 'pharmacy_settings.dart';

/// Private, real-time orders with bounded reads and atomic stock restoration.
class OrdersScreen extends StatefulWidget {
  const OrdersScreen({super.key});

  @override
  State<OrdersScreen> createState() => _OrdersScreenState();
}

class _OrdersScreenState extends State<OrdersScreen> {
  static const _pageSize = 30;
  static const _filters = ['All', 'Pending', 'Processing', 'Completed', 'Cancelled'];
  final _search = TextEditingController();
  late Stream<QuerySnapshot<Map<String, dynamic>>> _ordersStream;
  int _limit = _pageSize;
  String _filter = 'All';
  String _query = '';
  String? _workingOrder;

  @override
  void initState() {
    super.initState();
    _subscribe();
    _search.addListener(_onSearchChanged);
  }

  void _subscribe() {
    _ordersStream = PharmacyData.collection('orders')
        .orderBy('createdAt', descending: true)
        .limit(_limit)
        .snapshots();
  }

  void _onSearchChanged() {
    if (mounted) setState(() => _query = _search.text.trim().toLowerCase());
  }

  @override
  void dispose() {
    _search.removeListener(_onSearchChanged);
    _search.dispose();
    super.dispose();
  }

  void _addOrder() {
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => AddOrderDialog(onSaved: () {}),
    );
  }

  void _details(Order order) {
    showDialog<void>(
      context: context,
      builder: (_) => OrderDetailsDialog(order: order),
    );
  }

  /// All stock reads happen before any writes in the transaction. A second
  /// attempt to cancel an order cannot restore stock again.
  Future<void> _changeStatus(Order order, String target,
      {bool archive = false}) async {
    if (order.id == null || _workingOrder != null) return;
    setState(() => _workingOrder = order.id);
    try {
      final orderRef = PharmacyData.collection('orders').doc(order.id);
      await FirebaseFirestore.instance.runTransaction((transaction) async {
        final snapshot = await transaction.get(orderRef);
        if (!snapshot.exists) throw StateError('The order no longer exists.');
        final data = snapshot.data()!;
        final previous = (data['status'] as String? ?? 'pending').toLowerCase();
        if (data['archived'] == true) throw StateError('This order is archived.');

        if (archive && target != 'cancelled') {
          throw StateError('Orders must be cancelled before archiving.');
        }
        if (previous == 'cancelled') {
          if (archive) {
            transaction.update(orderRef, {
              'archived': true,
              'updatedAt': FieldValue.serverTimestamp(),
            });
            return;
          }
          throw StateError('Cancelled orders cannot be reopened.');
        }
        if (previous == target) return;
        if (target == 'processing' && previous != 'pending') {
          throw StateError('Only pending orders can start processing.');
        }
        if (target == 'completed' &&
            previous != 'pending' && previous != 'processing') {
          throw StateError('This order cannot be completed.');
        }
        if (!['processing', 'completed', 'cancelled'].contains(target)) {
          throw StateError('Unsupported order status.');
        }

        if (target == 'cancelled') {
          final quantities = <String, int>{};
          for (final raw in (data['items'] as List<dynamic>? ?? [])) {
            if (raw is! Map) throw StateError('Invalid order line.');
            final item = Map<String, dynamic>.from(raw);
            final medicineId = item['medicineId'] as String?;
            final count = item['quantity'];
            if (medicineId == null || medicineId.isEmpty ||
                count is! int || count <= 0) {
              throw StateError('Invalid order stock data.');
            }
            quantities.update(medicineId, (amount) => amount + count,
                ifAbsent: () => count);
          }
          if (quantities.isEmpty) throw StateError('Order has no stock items.');

          final stockRefs = <String, DocumentReference<Map<String, dynamic>>>{};
          final stockLevels = <String, int>{};
          for (final entry in quantities.entries) {
            final ref = PharmacyData.collection('medicines').doc(entry.key);
            final medicine = await transaction.get(ref);
            final value = medicine.data()?['quantity'];
            if (!medicine.exists || value is! int || value < 0) {
              throw StateError('Stock cannot be restored for a missing medicine.');
            }
            stockRefs[entry.key] = ref;
            stockLevels[entry.key] = value;
          }
          for (final entry in quantities.entries) {
            transaction.update(stockRefs[entry.key]!, {
              'quantity': stockLevels[entry.key]! + entry.value,
              'updatedAt': FieldValue.serverTimestamp(),
            });
          }
          transaction.update(orderRef, {
            'status': 'cancelled',
            'stockRestored': true,
            if (archive) 'archived': true,
            'updatedAt': FieldValue.serverTimestamp(),
          });
        } else {
          transaction.update(orderRef, {
            'status': target,
            'updatedAt': FieldValue.serverTimestamp(),
          });
        }
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(archive ? 'Order archived.' : 'Order updated.')),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text(
            'Unable to update the order. Check its status, stock and connection.',
          )),
        );
      }
    } finally {
      if (mounted) setState(() => _workingOrder = null);
    }
  }

  Future<void> _archive(Order order) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Archive order?'),
        content: const Text(
          'The order will be hidden from the active list. If it is not '
          'already cancelled, its items will be returned to inventory once. '
          'The history record will be retained.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Keep order'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Archive'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await _changeStatus(order, 'cancelled', archive: true);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: _ordersStream,
        builder: (context, snapshot) {
          final docs = snapshot.data?.docs ?? [];
          final orders = <Order>[];
          for (final doc in docs) {
            if (doc.data()['archived'] == true) continue;
            try {
              orders.add(Order.fromFirestore(doc));
            } catch (_) {
              // One malformed legacy record should not break the entire list.
            }
          }
          final filtered = orders.where((order) {
            final statusMatches = _filter == 'All' ||
                order.status.toLowerCase() == _filter.toLowerCase();
            final searchMatches = _query.isEmpty ||
                order.customerName.toLowerCase().contains(_query) ||
                (order.id?.toLowerCase().contains(_query) ?? false);
            return statusMatches && searchMatches;
          }).toList();
          return LayoutBuilder(builder: (context, viewport) {
            final inset = viewport.maxWidth >= 800 ? 30.0 : 16.0;
            return ListView(
              padding: EdgeInsets.fromLTRB(inset, 22, inset, 34),
              children: [
                Wrap(
                  alignment: WrapAlignment.spaceBetween,
                  spacing: 12,
                  runSpacing: 12,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    const Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Orders', style: TextStyle(
                          fontSize: 29, fontWeight: FontWeight.w800)),
                        SizedBox(height: 4),
                        Text('Track and manage pharmacy orders',
                          style: TextStyle(color: PharmaTheme.muted)),
                      ],
                    ),
                    FilledButton.icon(
                      onPressed: _addOrder,
                      icon: const Icon(Icons.add_rounded),
                      label: const Text('New order'),
                    ),
                  ],
                ),
                const SizedBox(height: 23),
                TextField(
                  controller: _search,
                  decoration: InputDecoration(
                    hintText: 'Search customer or order ID',
                    prefixIcon: const Icon(Icons.search_rounded),
                    suffixIcon: _query.isEmpty ? null : IconButton(
                      tooltip: 'Clear search',
                      icon: const Icon(Icons.close),
                      onPressed: _search.clear,
                    ),
                  ),
                ),
                const SizedBox(height: 13),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(children: [
                    for (final item in _filters)
                      Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ChoiceChip(
                          label: Text(item),
                          selected: _filter == item,
                          onSelected: (_) => setState(() => _filter = item),
                        ),
                      ),
                  ]),
                ),
                const SizedBox(height: 17),
                if (snapshot.hasError)
                  _empty(Icons.cloud_off_outlined, 'Orders unavailable',
                    'Check your connection and access permissions.')
                else if (!snapshot.hasData)
                  const Padding(
                    padding: EdgeInsets.all(40),
                    child: Center(child: CircularProgressIndicator()),
                  )
                else if (filtered.isEmpty)
                  _empty(Icons.receipt_long_outlined,
                    orders.isEmpty ? 'No orders yet' : 'No matching orders',
                    orders.isEmpty
                      ? 'Create your first order to begin tracking sales.'
                      : 'Try a different search or status.'),
                for (final order in filtered) _orderCard(order),
                const SizedBox(height: 16),
                if (docs.length >= _limit)
                  Center(child: OutlinedButton.icon(
                    onPressed: () => setState(() {
                      _limit += _pageSize;
                      _subscribe();
                    }),
                    icon: const Icon(Icons.expand_more),
                    label: const Text('Load more orders'),
                  )),
                const SizedBox(height: 12),
                Text('Showing up to ' + _limit.toString() +
                    ' records. Filters apply to loaded orders.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 11, color: PharmaTheme.muted)),
              ],
            );
          });
        },
      ),
    ),
  );

  Widget _orderCard(Order order) {
    final busy = _workingOrder == order.id;
    final currency = PharmacySettingsService.instance.current.value.currency;
    final status = order.status.toLowerCase();
    final accent = status == 'completed' ? PharmaTheme.teal :
        status == 'cancelled' ? const Color(0xFFFF8993) :
        status == 'processing' ? PharmaTheme.blue :
        const Color(0xFFFFB45D);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            CircleAvatar(
              backgroundColor: PharmaTheme.blue.withValues(alpha: .2),
              child: const Icon(Icons.receipt_long_rounded,
                  color: PharmaTheme.blue),
            ),
            const SizedBox(width: 12),
            Expanded(child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(order.customerName.isEmpty ? 'Customer' : order.customerName,
                  maxLines: 1, overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                Text(order.formattedDate + ' · ' + order.totalItems.toString() + ' items',
                  style: const TextStyle(fontSize: 12, color: PharmaTheme.muted)),
              ],
            )),
            Flexible(child: Text(formatMoney(order.totalAmount, currency),
              maxLines: 1, overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.w800))),
          ]),
          const SizedBox(height: 14),
          Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 10,
            runSpacing: 8,
            children: [
              Chip(
                avatar: Icon(Icons.circle, size: 12, color: accent),
                label: Text(order.status.toUpperCase()),
                visualDensity: VisualDensity.compact,
              ),
              TextButton.icon(
                onPressed: busy ? null : () => _details(order),
                icon: const Icon(Icons.visibility_outlined, size: 18),
                label: const Text('Details'),
              ),
              if (status == 'pending')
                TextButton(
                  onPressed: busy ? null : () => _changeStatus(order, 'processing'),
                  child: const Text('Process'),
                ),
              if (status == 'pending' || status == 'processing')
                TextButton(
                  onPressed: busy ? null : () => _changeStatus(order, 'completed'),
                  child: const Text('Complete'),
                ),
              if (status != 'cancelled')
                TextButton(
                  onPressed: busy ? null : () => _changeStatus(order, 'cancelled'),
                  child: const Text('Cancel'),
                ),
              IconButton(
                tooltip: 'Archive order',
                onPressed: busy ? null : () => _archive(order),
                icon: const Icon(Icons.archive_outlined),
              ),
            ],
          ),
        ]),
      ),
    );
  }

  Widget _empty(IconData icon, String title, String message) => Card(
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 36),
      child: Column(children: [
        Icon(icon, color: PharmaTheme.muted, size: 42),
        const SizedBox(height: 12),
        Text(title, style: const TextStyle(
          fontSize: 17, fontWeight: FontWeight.w700)),
        const SizedBox(height: 7),
        Text(message, textAlign: TextAlign.center,
          style: const TextStyle(color: PharmaTheme.muted)),
      ]),
    ),
  );
}
