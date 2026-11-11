import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import 'AddMedicineDialog.dart';
import 'adjust_stock_dialog.dart';
import 'medicine_model.dart';
import 'pharma_theme.dart';
import 'pharmacy_data.dart';
import 'pharmacy_settings.dart';

/// Optional alert filters are independently queried in Firestore rather than
/// filtering only the first page of alphabetically sorted medicines.
enum InventoryAlertFilter { all, lowStock, expiringSoon }

/// Account-scoped, bounded live inventory with non-destructive archiving.
class InventoryScreen extends StatefulWidget {
  const InventoryScreen({super.key, this.initialFilter = InventoryAlertFilter.all});

  final InventoryAlertFilter initialFilter;
  @override
  State<InventoryScreen> createState() => _InventoryScreenState();
}

class _InventoryScreenState extends State<InventoryScreen> {
  static const pageSize = 40;
  static const categories = ['All', 'Tablet', 'Capsule', 'Syrup', 'Injection'];
  final search = TextEditingController();
  late Stream<QuerySnapshot<Map<String, dynamic>>> medicinesStream;
  int limit = pageSize;
  String selected = 'All';
  String query = '';
  late InventoryAlertFilter alertFilter;

  @override
  void initState() {
    super.initState();
    alertFilter = widget.initialFilter;
    _subscribe();
    search.addListener(_searchChanged);
  }

  void _subscribe() {
    final collection = PharmacyData.collection('medicines');
    switch (alertFilter) {
      case InventoryAlertFilter.lowStock:
        final threshold = PharmacySettingsService.instance.current.value.lowStockThreshold;
        medicinesStream = collection.where('quantity', isLessThanOrEqualTo: threshold)
            .orderBy('quantity').limit(limit).snapshots();
      case InventoryAlertFilter.expiringSoon:
        final days = PharmacySettingsService.instance.current.value.expiryWarningDays;
        final cutoff = DateTime.now().add(Duration(days: days));
        medicinesStream = collection.where('expiryDate',
            isLessThanOrEqualTo: Timestamp.fromDate(cutoff))
            .orderBy('expiryDate').limit(limit).snapshots();
      case InventoryAlertFilter.all:
        medicinesStream = collection.orderBy('name').limit(limit).snapshots();
    }
  }

  void _searchChanged() {
    if (mounted) setState(() => query = search.text.toLowerCase().trim());
  }

  @override
  void dispose() {
    search.removeListener(_searchChanged);
    search.dispose();
    super.dispose();
  }

  void _edit([Medicine? medicine]) {
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => AddMedicineDialog(medicine: medicine, onSaved: () {}),
    );
  }

  Future<void> _archive(Medicine medicine) async {
    if (medicine.id == null) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Archive medicine?'),
        content: Text(medicine.name +
            ' will be hidden from active inventory. Historical orders remain intact.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Keep'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Archive'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await PharmacyData.collection('medicines').doc(medicine.id).update({
        'archived': true,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Medicine archived; stock history preserved.')),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not archive medicine. Please retry.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: medicinesStream,
        builder: (context, snapshot) {
          final documents = snapshot.data?.docs ?? [];
          final all = <Medicine>[];
          for (final doc in documents) {
            if (doc.data()['archived'] == true) continue;
            try {
              all.add(Medicine.fromFirestore(doc));
            } catch (_) {
              // Damaged legacy records must not crash the entire screen.
            }
          }
          final matching = all.where((medicine) =>
            (selected == 'All' || medicine.type.toLowerCase() == selected.toLowerCase()) &&
            (query.isEmpty || medicine.name.toLowerCase().contains(query) ||
                medicine.batchNo.toLowerCase().contains(query))).toList();
          final threshold = PharmacySettingsService.instance.current.value.lowStockThreshold;
          final low = all.where((m) => m.quantity > 0 && m.quantity <= threshold).length;
          final out = all.where((m) => m.quantity == 0).length;

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
                    const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('Inventory',
                        style: TextStyle(fontSize: 29, fontWeight: FontWeight.w800)),
                      SizedBox(height: 4),
                      Text('Keep stock organized and up to date',
                        style: TextStyle(color: PharmaTheme.muted)),
                    ]),
                    FilledButton.icon(
                      onPressed: () => _edit(),
                      icon: const Icon(Icons.add_rounded),
                      label: const Text('Add medicine'),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Wrap(spacing: 8, runSpacing: 8, children: [
                  ChoiceChip(label: const Text('All medicines'),
                    selected: alertFilter == InventoryAlertFilter.all,
                    onSelected: (_) => _changeAlertFilter(InventoryAlertFilter.all)),
                  ChoiceChip(label: const Text('Low stock'),
                    selected: alertFilter == InventoryAlertFilter.lowStock,
                    onSelected: (_) => _changeAlertFilter(InventoryAlertFilter.lowStock)),
                  ChoiceChip(label: const Text('Expiring soon'),
                    selected: alertFilter == InventoryAlertFilter.expiringSoon,
                    onSelected: (_) => _changeAlertFilter(InventoryAlertFilter.expiringSoon)),
                ]),
                const SizedBox(height: 14),
                Wrap(spacing: 10, runSpacing: 10, children: [
                  _stat('Active medicines', all.length.toString(),
                      Icons.medication_outlined, PharmaTheme.blue),
                  _stat('Low stock', low.toString(),
                      Icons.warning_amber_rounded, const Color(0xFFFFB45D)),
                  _stat('Out of stock', out.toString(),
                      Icons.inventory_2_outlined, const Color(0xFFF38E99)),
                ]),
                const SizedBox(height: 22),
                TextField(
                  controller: search,
                  decoration: InputDecoration(
                    hintText: 'Search medicine or batch',
                    prefixIcon: const Icon(Icons.search_rounded),
                    suffixIcon: query.isEmpty ? null : IconButton(
                      tooltip: 'Clear search',
                      icon: const Icon(Icons.close_rounded),
                      onPressed: search.clear,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(children: [
                    for (final category in categories)
                      Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ChoiceChip(
                          label: Text(category),
                          selected: selected == category,
                          onSelected: (_) => setState(() => selected = category),
                        ),
                      ),
                  ]),
                ),
                const SizedBox(height: 16),
                if (snapshot.hasError)
                  _message(Icons.cloud_off_outlined, 'Inventory unavailable',
                      'Check your connection and access permissions.')
                else if (!snapshot.hasData)
                  const Padding(
                    padding: EdgeInsets.all(40),
                    child: Center(child: CircularProgressIndicator()),
                  )
                else if (matching.isEmpty)
                  _message(Icons.inventory_2_outlined,
                      all.isEmpty ? 'Start your inventory' : 'No matches found',
                      all.isEmpty ? 'Add your first medicine to begin.' : 'Try another search or filter.')
                else
                  LayoutBuilder(builder: (context, size) {
                    final columns = size.maxWidth >= 1050 ? 3 :
                        size.maxWidth >= 660 ? 2 : 1;
                    final cardWidth = (size.maxWidth - 12 * (columns - 1)) / columns;
                    return Wrap(spacing: 12, runSpacing: 12, children: [
                      for (final medicine in matching)
                        SizedBox(width: cardWidth, child: _card(medicine)),
                    ]);
                  }),
                const SizedBox(height: 20),
                if (documents.length >= limit)
                  Center(child: OutlinedButton.icon(
                    onPressed: () => setState(() {
                      limit += pageSize;
                      _subscribe();
                    }),
                    icon: const Icon(Icons.expand_more),
                    label: const Text('Load more medicines'),
                  )),
                const SizedBox(height: 12),
                Text('Showing up to ' + limit.toString() +
                    ' records in this filter. Search applies to loaded medicines.',
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 11, color: PharmaTheme.muted)),
              ],
            );
          });
        },
      ),
    ),
  );

  Widget _stat(String label, String value, IconData icon, Color accent) =>
      Container(
        width: 160,
        padding: const EdgeInsets.all(15),
        decoration: BoxDecoration(
          color: PharmaTheme.card,
          border: Border.all(color: const Color(0xFF344761)),
          borderRadius: BorderRadius.circular(18),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(icon, color: accent),
          const SizedBox(height: 9),
          Text(value, style: const TextStyle(fontSize: 23, fontWeight: FontWeight.w800)),
          Text(label, style: const TextStyle(fontSize: 12, color: PharmaTheme.muted)),
        ]),
      );

  Widget _card(Medicine medicine) {
    final threshold = PharmacySettingsService.instance.current.value.lowStockThreshold;
    final accent = medicine.quantity == 0 ? const Color(0xFFF38E99) :
        medicine.quantity <= threshold ? const Color(0xFFFFB45D) : PharmaTheme.teal;
    final date = medicine.expiryDate;
    final expiry = date.day.toString().padLeft(2, '0') + '/' +
        date.month.toString().padLeft(2, '0') + '/' + date.year.toString();
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(17),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            CircleAvatar(
              backgroundColor: PharmaTheme.blue.withValues(alpha: .2),
              child: const Icon(Icons.medication_rounded, color: PharmaTheme.blue),
            ),
            const SizedBox(width: 11),
            Expanded(child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(medicine.name, maxLines: 1, overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                Text(medicine.type + ' · Batch ' + medicine.batchNo,
                  maxLines: 1, overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: PharmaTheme.muted, fontSize: 12)),
              ],
            )),
          ]),
          const SizedBox(height: 15),
          Wrap(spacing: 8, runSpacing: 8, children: [
            Chip(
              avatar: Icon(Icons.inventory_2_outlined, color: accent, size: 16),
              label: Text(medicine.quantity.toString() + ' units'),
              visualDensity: VisualDensity.compact,
            ),
            Chip(
              avatar: const Icon(Icons.event_outlined, size: 16),
              label: Text('Exp ' + expiry),
              visualDensity: VisualDensity.compact,
            ),
          ]),
          const SizedBox(height: 12),
          const Text('Selling price',
              style: TextStyle(color: PharmaTheme.muted, fontSize: 12)),
          Text(formatMoney(medicine.sellingPrice,
                  PharmacySettingsService.instance.current.value.currency),
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
          const Divider(height: 22),
          Wrap(spacing: 5, children: [
            TextButton.icon(
              onPressed: () => _edit(medicine),
              icon: const Icon(Icons.edit_outlined, size: 18),
              label: const Text('Edit'),
            ),
            TextButton.icon(
              onPressed: () => showDialog<void>(
                context: context,
                builder: (_) => AdjustStockDialog(medicine: medicine),
              ),
              icon: const Icon(Icons.add_box_outlined, size: 18),
              label: const Text('Stock'),
            ),
            IconButton(
              tooltip: 'Archive medicine',
              onPressed: () => _archive(medicine),
              icon: const Icon(Icons.archive_outlined, size: 20),
            ),
          ]),
        ]),
      ),
    );
  }

  Widget _message(IconData icon, String title, String detail) =>
      Card(child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 36),
        child: Column(children: [
          Icon(icon, color: PharmaTheme.muted, size: 42),
          const SizedBox(height: 12),
          Text(title, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
          const SizedBox(height: 6),
          Text(detail, textAlign: TextAlign.center,
            style: const TextStyle(color: PharmaTheme.muted)),
        ]),
      ));
}
