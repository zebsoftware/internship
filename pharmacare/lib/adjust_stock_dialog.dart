import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'medicine_model.dart';

/// Adds inventory without overwriting stock sold by another checkout.
class AdjustStockDialog extends StatefulWidget {
  final Medicine medicine;
  const AdjustStockDialog({super.key, required this.medicine});
  @override
  State<AdjustStockDialog> createState() => _AdjustStockDialogState();
}

class _AdjustStockDialogState extends State<AdjustStockDialog> {
  final quantity = TextEditingController();
  final note = TextEditingController();
  String reason = 'restock';
  bool busy = false;

  @override
  void dispose() { quantity.dispose(); note.dispose(); super.dispose(); }

  Future<void> submit() async {
    final count = int.tryParse(quantity.text.trim());
    if (count == null || count <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter a positive whole number of units')));
      return;
    }
    setState(() => busy = true);
    try {
      final db = FirebaseFirestore.instance;
      final medicineRef = db.collection('medicines').doc(widget.medicine.id);
      final adjustmentRef = db.collection('stockAdjustments').doc();
      await db.runTransaction((transaction) async {
        final medicine = await transaction.get(medicineRef);
        if (!medicine.exists) throw StateError('Medicine no longer exists');
        final stock = medicine.data()?['quantity'];
        if (stock is! num || stock < 0) throw StateError('Invalid stock value');
        transaction.update(medicineRef, {
          'quantity': stock.toInt() + count,
          'updatedAt': FieldValue.serverTimestamp(),
        });
        transaction.set(adjustmentRef, {
          'medicineId': widget.medicine.id,
          'medicineName': widget.medicine.name,
          'quantityDelta': count,
          'reason': reason,
          'note': note.text.trim(),
          'createdAt': FieldValue.serverTimestamp(),
        });
      });
      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Added $count units to inventory')));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Stock update failed: $e')));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text('Update stock · ${widget.medicine.name}'),
    content: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
      Text('Current stock: ${widget.medicine.quantity} units'),
      const SizedBox(height: 12),
      DropdownButtonFormField<String>(
        value: reason,
        decoration: const InputDecoration(labelText: 'Reason'),
        items: const [
          DropdownMenuItem(value: 'restock', child: Text('New stock received')),
          DropdownMenuItem(value: 'customer_return', child: Text('Customer returned product')),
          DropdownMenuItem(value: 'correction', child: Text('Stock count correction (+)')),
        ],
        onChanged: busy ? null : (value) => setState(() => reason = value ?? reason),
      ),
      TextField(controller: quantity, keyboardType: TextInputType.number,
        decoration: const InputDecoration(labelText: 'Units to add')),
      TextField(controller: note, decoration: const InputDecoration(labelText: 'Notes (optional)')),
      if (reason == 'customer_return') const Padding(
        padding: EdgeInsets.only(top: 8),
        child: Text('Only return unopened, saleable items. This manual adjustment does not refund or modify an order.')),
    ])),
    actions: [
      TextButton(onPressed: busy ? null : () => Navigator.pop(context), child: const Text('Cancel')),
      FilledButton(onPressed: busy ? null : submit,
        child: Text(busy ? 'Saving...' : 'Add stock')),
    ],
  );
}
