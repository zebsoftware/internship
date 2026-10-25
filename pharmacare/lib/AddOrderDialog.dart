import 'pharmacy_data.dart';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart' as firestore; // Add prefix
import 'package:pharmacare/medicine_model.dart';
import 'order_model.dart';
import 'pharmacy_settings.dart';

class AddOrderDialog extends StatefulWidget {
  final VoidCallback onSaved;

  const AddOrderDialog({Key? key, required this.onSaved}) : super(key: key);

  @override
  State<AddOrderDialog> createState() => _AddOrderDialogState();
}

class _AddOrderDialogState extends State<AddOrderDialog> {
  final _formKey = GlobalKey<FormState>();
  final firestore.FirebaseFirestore _firestore = firestore.FirebaseFirestore.instance; // Use prefix

  // Customer details
  final _customerNameController = TextEditingController();
  final _customerPhoneController = TextEditingController();
  final _customerEmailController = TextEditingController();
  final _notesController = TextEditingController();
  String _paymentMethod = 'cash';
  String _status = 'pending';

  // Order items
  final List<OrderItem> _selectedItems = [];
  List<Medicine> _availableMedicines = [];
  StreamSubscription<firestore.QuerySnapshot<Map<String, dynamic>>>? _inventorySubscription;

  // For adding new item
  Medicine? _selectedMedicine;
  final _quantityController = TextEditingController();

  @override
  void initState() {
    super.initState();
    PharmacySettingsService.instance.listen();
    _loadMedicines();
  }

  void _loadMedicines() {
    try {
      _inventorySubscription = PharmacyData.collection('medicines').snapshots().listen((snapshot) {
        if (!mounted) return;
        setState(() {
          _availableMedicines = snapshot.docs.map((doc) => Medicine.fromFirestore(doc))
            .where((medicine) => medicine.quantity > 0 && !medicine.expiryDate.isBefore(DateTime.now()))
            .toList();
        });
      });
    } catch (e) {
      print('Error loading medicines: $e');
    }
  }

  @override
  void dispose() {
    _inventorySubscription?.cancel();
    _customerNameController.dispose();
    _customerPhoneController.dispose();
    _customerEmailController.dispose();
    _notesController.dispose();
    _quantityController.dispose();
    super.dispose();
  }

  void _addItem() {
    if (_selectedMedicine == null) return;

    final quantity = int.tryParse(_quantityController.text.trim().isEmpty ? '1' : _quantityController.text.trim()) ?? 0;
    if (quantity <= 0 || quantity > _selectedMedicine!.quantity) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: Color(0xFFEF4444),
          content: Text('Invalid quantity or insufficient stock'),
        ),
      );
      return;
    }

    final existingIndex = _selectedItems.indexWhere(
      (item) => item.medicineId == _selectedMedicine!.id,
    );

    if (existingIndex != -1) {
      // Update existing item
      final existingItem = _selectedItems[existingIndex];
      final newQuantity = existingItem.quantity + quantity;
      
      if (newQuantity > _selectedMedicine!.quantity) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            backgroundColor: Color(0xFFEF4444),
            content: Text('Not enough stock available'),
          ),
        );
        return;
      }

      setState(() {
        _selectedItems[existingIndex] = OrderItem(
          medicineId: _selectedMedicine!.id!,
          medicineName: _selectedMedicine!.name,
          price: _selectedMedicine!.sellingPrice,
          quantity: newQuantity,
          total: _selectedMedicine!.sellingPrice * newQuantity,
        );
      });
    } else {
      // Add new item
      setState(() {
        _selectedItems.add(OrderItem(
          medicineId: _selectedMedicine!.id!,
          medicineName: _selectedMedicine!.name,
          price: _selectedMedicine!.sellingPrice,
          quantity: quantity,
          total: _selectedMedicine!.sellingPrice * quantity,
        ));
      });
    }

    // Clear selection
    _selectedMedicine = null;
    _quantityController.clear();
  }

  void _changeItemQuantity(int index, int quantity) {
    if (index < 0 || index >= _selectedItems.length) return;
    final original = _selectedItems[index];
    final available = _availableMedicines.where((m) => m.id == original.medicineId);
    if (available.isEmpty || quantity < 1 || quantity > available.first.quantity) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Insufficient available stock')),
      );
      return;
    }
    setState(() {
      _selectedItems[index] = OrderItem(
        medicineId: original.medicineId,
        medicineName: original.medicineName,
        price: original.price,
        quantity: quantity,
        total: original.price * quantity,
      );
    });
  }

  void _removeItem(int index) {
    setState(() {
      _selectedItems.removeAt(index);
    });
  }

  double get _subtotal {
    return _selectedItems.fold(0, (sum, item) => sum + item.total);
  }

  double get _tax {
    return _subtotal * PharmacySettingsService.instance.current.value.taxPercent / 100;
  }

  double get _total {
    return _subtotal + _tax;
  }

  bool _isSavingOrder = false;

  Future<void> _createOrder() async {
    if (_isSavingOrder) return;
    if (!_formKey.currentState!.validate()) return;

    if (_selectedItems.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please add at least one medicine')),
      );
      return;
    }

    setState(() => _isSavingOrder = true);
    try {
      final items = List<OrderItem>.of(_selectedItems);
      final order = Order(
        customerName: _customerNameController.text.trim(),
        customerPhone: _customerPhoneController.text.trim(),
        customerEmail: _customerEmailController.text.trim(),
        items: items,
        subtotal: _subtotal,
        tax: _tax,
        totalAmount: _total,
        status: _status,
        paymentMethod: _paymentMethod,
        notes: _notesController.text.trim(),
      );
      final orderRef = PharmacyData.collection('orders').doc();

      await _firestore.runTransaction((transaction) async {
        final quantities = <String, int>{};
        final refs = <String, firestore.DocumentReference<Map<String, dynamic>>>{};

        // Read all stock documents before scheduling any writes.
        for (final item in items) {
          if (item.quantity <= 0 || item.medicineId.isEmpty) {
            throw StateError('Invalid quantity or medicine selection.');
          }
          if (refs.containsKey(item.medicineId)) continue;
          final ref = PharmacyData.collection('medicines').doc(item.medicineId);
          final snapshot = await transaction.get(ref);
          if (!snapshot.exists) {
            throw StateError('${item.medicineName} is no longer available.');
          }
          final stock = snapshot.data()?['quantity'];
          if (stock is! num || stock < 0) {
            throw StateError('Invalid stock record for ${item.medicineName}.');
          }
          refs[item.medicineId] = ref;
          quantities[item.medicineId] = stock.toInt();
        }

        final requested = <String, int>{};
        for (final item in items) {
          requested.update(
            item.medicineId,
            (value) => value + item.quantity,
            ifAbsent: () => item.quantity,
          );
        }

        for (final entry in requested.entries) {
          final remaining = quantities[entry.key]! - entry.value;
          if (remaining < 0) {
            throw StateError('Insufficient stock for one or more medicines.');
          }
          transaction.update(refs[entry.key]!, {'quantity': remaining});
        }
        transaction.set(orderRef, {...order.toMap(), 'currency': PharmacySettingsService.instance.current.value.currency, 'taxPercent': PharmacySettingsService.instance.current.value.taxPercent});
      });

      if (!mounted) return;
      widget.onSaved();
      Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Unable to create order: $e')),
      );
    } finally {
      if (mounted) setState(() => _isSavingOrder = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: const Color(0xFF0A1628),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    '➕ Create New Order',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(
                      Icons.close,
                      color: Color(0xFF64748B),
                    ),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Customer Information
              const Text(
                'Customer Information',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),

              // Customer Name
              const Text(
                'Customer Name',
                style: TextStyle(
                  color: Color(0xFF94A3B8),
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _customerNameController,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText: 'Enter customer name',
                  hintStyle: const TextStyle(color: Color(0xFF64748B)),
                  filled: true,
                  fillColor: const Color(0xFF1E293B),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Required';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Add Medicines Section
              const Text(
                'Add Medicines',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),

              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E293B),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  children: [
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size.fromHeight(55),
                        alignment: Alignment.centerLeft,
                        foregroundColor: Colors.white,
                        side: const BorderSide(color: Color(0xFF52729A)),
                      ),
                      onPressed: () async {
                        final selected = await showSearch<Medicine?>(
                          context: context,
                          delegate: _MedicineSearchDelegate(_availableMedicines),
                        );
                        if (selected != null && mounted) {
                          setState(() => _selectedMedicine = selected);
                        }
                      },
                      icon: const Icon(Icons.search),
                      label: Text(
                        _selectedMedicine == null
                          ? 'Search and select medicine'
                          : '${_selectedMedicine!.name} (${_selectedMedicine!.quantity} left)',
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (_availableMedicines.isEmpty)
                      const Padding(
                        padding: EdgeInsets.only(top: 8),
                        child: Text('No medicines in your inventory. Add medicines in Inventory first.',
                          style: TextStyle(color: Colors.amber)),
                      ),
                    const SizedBox(height: 12),
                    Row(children: [
                      Expanded(child: TextFormField(
                        controller: _quantityController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(labelText: 'Quantity', hintText: '1'),
                      )),
                      const SizedBox(width: 12),
                      Expanded(child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF2B7AFE),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 18),
                        ),
                        onPressed: _selectedMedicine == null ? null : _addItem,
                        icon: const Icon(Icons.add_shopping_cart),
                        label: const Text('Add Item'),
                      )),
                    ]),
                    const SizedBox(height: 16),

                    // Selected Items List
                    if (_selectedItems.isNotEmpty)
                      ..._selectedItems.asMap().entries.map((entry) {
                        final index = entry.key;
                        final item = entry.value;
                        return Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: const Color(0xFF0F172A),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      item.medicineName,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    Text(
                                      '${formatMoney(item.price, PharmacySettingsService.instance.current.value.currency)} × ${item.quantity}',
                                      style: const TextStyle(
                                        color: Color(0xFF94A3B8),
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Text(
                                formatMoney(item.total, PharmacySettingsService.instance.current.value.currency),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              IconButton(
                                tooltip: 'Decrease quantity',
                                icon: const Icon(Icons.remove_circle_outline),
                                onPressed: item.quantity > 1
                                    ? () => _changeItemQuantity(index, item.quantity - 1)
                                    : null,
                              ),
                              Text('${item.quantity}'),
                              IconButton(
                                tooltip: 'Increase quantity',
                                icon: const Icon(Icons.add_circle_outline),
                                onPressed: () => _changeItemQuantity(index, item.quantity + 1),
                              ),
                              IconButton(
                                icon: const Icon(
                                  Icons.delete,
                                  color: Color(0xFFEF4444),
                                  size: 18,
                                ),
                                onPressed: () => _removeItem(index),
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Order Summary
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E293B),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  children: [
                    _SummaryRow(
                      label: 'Subtotal',
                      value: formatMoney(_subtotal, PharmacySettingsService.instance.current.value.currency),
                    ),
                    const SizedBox(height: 8),
                    _SummaryRow(
                      label: 'Tax (13%)',
                      value: formatMoney(_tax, PharmacySettingsService.instance.current.value.currency),
                    ),
                    const Divider(color: Color(0xFF334155), height: 24),
                    _SummaryRow(
                      label: 'Total',
                      value: formatMoney(_total, PharmacySettingsService.instance.current.value.currency),
                      isTotal: true,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Payment and Status
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Payment Method',
                          style: TextStyle(
                            color: Color(0xFF94A3B8),
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          decoration: BoxDecoration(
                            color: const Color(0xFF1E293B),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<String>(
                              value: _paymentMethod,
                              isExpanded: true,
                              dropdownColor: const Color(0xFF1E293B),
                              style: const TextStyle(color: Colors.white),
                              items: const [
                                DropdownMenuItem(
                                  value: 'cash',
                                  child: Text('Cash'),
                                ),
                                DropdownMenuItem(
                                  value: 'card',
                                  child: Text('Card'),
                                ),
                                DropdownMenuItem(
                                  value: 'online',
                                  child: Text('Online'),
                                ),
                              ],
                              onChanged: (String? value) {
                                setState(() => _paymentMethod = value!);
                              },
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Status',
                          style: TextStyle(
                            color: Color(0xFF94A3B8),
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          decoration: BoxDecoration(
                            color: const Color(0xFF1E293B),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<String>(
                              value: _status,
                              isExpanded: true,
                              dropdownColor: const Color(0xFF1E293B),
                              style: const TextStyle(color: Colors.white),
                              items: const [
                                DropdownMenuItem(
                                  value: 'pending',
                                  child: Text('Pending'),
                                ),
                                DropdownMenuItem(
                                  value: 'processing',
                                  child: Text('Processing'),
                                ),
                                DropdownMenuItem(
                                  value: 'completed',
                                  child: Text('Completed'),
                                ),
                              ],
                              onChanged: (String? value) {
                                setState(() => _status = value!);
                              },
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Notes
              const Text(
                'Notes (Optional)',
                style: TextStyle(
                  color: Color(0xFF94A3B8),
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _notesController,
                style: const TextStyle(color: Colors.white),
                maxLines: 3,
                decoration: InputDecoration(
                  hintText: 'Add any special instructions...',
                  hintStyle: const TextStyle(color: Color(0xFF64748B)),
                  filled: true,
                  fillColor: const Color(0xFF1E293B),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              const SizedBox(height: 32),

              // Create Order Button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isSavingOrder ? null : _createOrder,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2B7AFE),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    'Create Order',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  final String label;
  final String value;
  final bool isTotal;

  const _SummaryRow({
    Key? key,
    required this.label,
    required this.value,
    this.isTotal = false,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            color: const Color(0xFF94A3B8),
            fontSize: isTotal ? 16 : 14,
            fontWeight: isTotal ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            color: Colors.white,
            fontSize: isTotal ? 18 : 14,
            fontWeight: isTotal ? FontWeight.bold : FontWeight.w600,
          ),
        ),
      ],
    );
  }
}
class _MedicineSearchDelegate extends SearchDelegate<Medicine?> {
  final List<Medicine> medicines;
  _MedicineSearchDelegate(this.medicines);
  @override
  String get searchFieldLabel => 'Search medicine name or batch';
  @override
  List<Widget> buildActions(BuildContext context) => [
    IconButton(icon: const Icon(Icons.clear), onPressed: () { query = ''; }),
  ];
  @override
  Widget buildLeading(BuildContext context) => IconButton(
    icon: const Icon(Icons.arrow_back), onPressed: () => close(context, null));
  @override
  Widget buildResults(BuildContext context) => buildSuggestions(context);
  @override
  Widget buildSuggestions(BuildContext context) {
    final q = query.trim().toLowerCase();
    final results = medicines.where((m) => m.name.toLowerCase().contains(q)
        || m.batchNo.toLowerCase().contains(q)).toList();
    if (results.isEmpty) return const Center(child: Text('No matching medicines'));
    return ListView.builder(itemCount: results.length, itemBuilder: (context, i) {
      final medicine = results[i];
      return ListTile(
        title: Text(medicine.name),
        subtitle: Text('${medicine.quantity} available · Batch ${medicine.batchNo}'),
        onTap: () => close(context, medicine),
      );
    });
  }
}
