import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart' as firestore; // Add prefix
import 'package:pharmacare/medicine_model.dart';
import 'order_model.dart';

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

  // For adding new item
  Medicine? _selectedMedicine;
  final _quantityController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadMedicines();
  }

  Future<void> _loadMedicines() async {
    try {
      final snapshot = await _firestore
          .collection('medicines')
          .where('quantity', isGreaterThan: 0)
          .orderBy('quantity')
          .get();

      setState(() {
        _availableMedicines = snapshot.docs
            .map((doc) => Medicine.fromFirestore(doc))
            .toList();
      });
    } catch (e) {
      print('Error loading medicines: $e');
    }
  }

  void _addItem() {
    if (_selectedMedicine == null || _quantityController.text.isEmpty) return;

    final quantity = int.tryParse(_quantityController.text) ?? 0;
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

  void _removeItem(int index) {
    setState(() {
      _selectedItems.removeAt(index);
    });
  }

  double get _subtotal {
    return _selectedItems.fold(0, (sum, item) => sum + item.total);
  }

  double get _tax {
    return _subtotal * 0.13; // 13% tax
  }

  double get _total {
    return _subtotal + _tax;
  }

  Future<void> _createOrder() async {
    if (_formKey.currentState!.validate() && _selectedItems.isNotEmpty) {
      try {
        // Create order
        final order = Order(  // This is your custom Order from order_model.dart
          customerName: _customerNameController.text.trim(),
          customerPhone: _customerPhoneController.text.trim(),
          customerEmail: _customerEmailController.text.trim(),
          items: _selectedItems,
          subtotal: _subtotal,
          tax: _tax,
          totalAmount: _total,
          status: _status,
          paymentMethod: _paymentMethod,
          notes: _notesController.text.trim(),
        );

        // Add to Firestore
        final orderDoc = await _firestore.collection('orders').add(order.toMap());

        // Update medicine quantities
        for (final item in _selectedItems) {
          final medicineDoc = await _firestore
              .collection('medicines')
              .doc(item.medicineId)
              .get();

          if (medicineDoc.exists) {
            final currentQuantity = medicineDoc.data()!['quantity'] ?? 0;
            final newQuantity = currentQuantity - item.quantity;

            await _firestore
                .collection('medicines')
                .doc(item.medicineId)
                .update({
                  'quantity': newQuantity,
                });
          }
        }

        widget.onSaved();
        Navigator.pop(context);

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            backgroundColor: Color(0xFF10B981),
            content: Text('Order created successfully'),
          ),
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: const Color(0xFFEF4444),
            content: Text('Error: $e'),
          ),
        );
      }
    } else if (_selectedItems.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: Color(0xFFEF4444),
          content: Text('Please add at least one item'),
        ),
      );
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
                'Full Name',
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

              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Phone Number',
                          style: TextStyle(
                            color: Color(0xFF94A3B8),
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 8),
                        TextFormField(
                          controller: _customerPhoneController,
                          style: const TextStyle(color: Colors.white),
                          keyboardType: TextInputType.phone,
                          decoration: InputDecoration(
                            hintText: 'Enter phone',
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
                      ],
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Email (Optional)',
                          style: TextStyle(
                            color: Color(0xFF94A3B8),
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 8),
                        TextFormField(
                          controller: _customerEmailController,
                          style: const TextStyle(color: Colors.white),
                          keyboardType: TextInputType.emailAddress,
                          decoration: InputDecoration(
                            hintText: 'Enter email',
                            hintStyle: const TextStyle(color: Color(0xFF64748B)),
                            filled: true,
                            fillColor: const Color(0xFF1E293B),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide.none,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

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
                    // Medicine Selection
                    Row(
                      children: [
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            decoration: BoxDecoration(
                              color: const Color(0xFF0F172A),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: DropdownButtonHideUnderline(
                              child: DropdownButton<Medicine?>(
                                value: _selectedMedicine,
                                hint: const Text(
                                  'Select Medicine',
                                  style: TextStyle(color: Color(0xFF64748B)),
                                ),
                                isExpanded: true,
                                dropdownColor: const Color(0xFF1E293B),
                                style: const TextStyle(color: Colors.white),
                                items: [
                                  const DropdownMenuItem(
                                    value: null,
                                    child: Text('Select Medicine'),
                                  ),
                                  ..._availableMedicines.map((medicine) {
                                    return DropdownMenuItem(
                                      value: medicine,
                                      child: Text(
                                        '${medicine.name} (${medicine.quantity} left)',
                                        style: TextStyle(
                                          color: medicine.isLowStock
                                              ? const Color(0xFFF59E0B)
                                              : medicine.isOutOfStock
                                                  ? const Color(0xFFEF4444)
                                                  : Colors.white,
                                        ),
                                      ),
                                    );
                                  }),
                                ],
                                onChanged: (Medicine? value) {
                                  setState(() => _selectedMedicine = value);
                                },
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        SizedBox(
                          width: 100,
                          child: TextFormField(
                            controller: _quantityController,
                            style: const TextStyle(color: Colors.white),
                            keyboardType: TextInputType.number,
                            decoration: InputDecoration(
                              hintText: 'Qty',
                              hintStyle: const TextStyle(color: Color(0xFF64748B)),
                              filled: true,
                              fillColor: const Color(0xFF0F172A),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide.none,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        ElevatedButton(
                          onPressed: _addItem,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF2B7AFE),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: const Icon(Icons.add, size: 20),
                        ),
                      ],
                    ),
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
                                      '\$${item.price.toStringAsFixed(2)} × ${item.quantity}',
                                      style: const TextStyle(
                                        color: Color(0xFF94A3B8),
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Text(
                                '\$${item.total.toStringAsFixed(2)}',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
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
                      value: '\$${_subtotal.toStringAsFixed(2)}',
                    ),
                    const SizedBox(height: 8),
                    _SummaryRow(
                      label: 'Tax (13%)',
                      value: '\$${_tax.toStringAsFixed(2)}',
                    ),
                    const Divider(color: Color(0xFF334155), height: 24),
                    _SummaryRow(
                      label: 'Total',
                      value: '\$${_total.toStringAsFixed(2)}',
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
                  onPressed: _createOrder,
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