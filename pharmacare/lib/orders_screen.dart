import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart' hide Order; // HIDE Order
import 'order_model.dart';
import 'AddOrderDialog.dart';
import 'OrderDetailsDialog.dart';


class OrdersScreen extends StatefulWidget {
  const OrdersScreen({Key? key}) : super(key: key);

  @override
  State<OrdersScreen> createState() => _OrdersScreenState();
}

class _OrdersScreenState extends State<OrdersScreen> {
  String _selectedFilter = 'All';
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  final List<String> _statusFilters = [
    'All',
    'Pending',
    'Processing',
    'Completed',
    'Cancelled',
  ];

  Stream<QuerySnapshot> _getOrdersStream() {
    Query query = _firestore.collection('orders');

    if (_selectedFilter != 'All') {
      query = query.where('status', isEqualTo: _selectedFilter.toLowerCase());
    }

    return query.orderBy('createdAt', descending: true).snapshots();
  }

  void _showAddOrderDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AddOrderDialog(
        onSaved: () => setState(() {}),
      ),
    );
  }

  void _showOrderDetails(Order order) {
    showDialog(
      context: context,
      builder: (context) => OrderDetailsDialog(order: order),
    );
  }

  Future<void> _updateOrderStatus(String orderId, String newStatus) async {
    await _firestore.collection('orders').doc(orderId).update({
      'status': newStatus.toLowerCase(),
      'updatedAt': Timestamp.now(),
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A1628),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header with Add Button
            Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Orders',
                    style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  ElevatedButton.icon(
                    onPressed: _showAddOrderDialog,
                    icon: const Icon(Icons.add, size: 20),
                    label: const Text('Add Order'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF2B7AFE),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 12,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 0,
                    ),
                  ),
                ],
              ),
            ),

            // Filter Buttons
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: _statusFilters.map((filter) {
                  return Padding(
                    padding: const EdgeInsets.only(right: 12),
                    child: _FilterButton(
                      label: filter,
                      isSelected: _selectedFilter == filter,
                      onTap: () => setState(() => _selectedFilter = filter),
                    ),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 24),

            // Orders List with StreamBuilder
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: _getOrdersStream(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(
                      child: CircularProgressIndicator(
                        color: Color(0xFF2B7AFE),
                      ),
                    );
                  }

                  if (snapshot.hasError) {
                    return const Center(
                      child: Text(
                        'Error loading orders',
                        style: TextStyle(color: Colors.white),
                      ),
                    );
                  }

                  if (snapshot.data!.docs.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            width: 100,
                            height: 100,
                            decoration: BoxDecoration(
                              color: const Color(0xFF1E293B),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.shopping_bag_outlined,
                              color: Color(0xFF64748B),
                              size: 48,
                            ),
                          ),
                          const SizedBox(height: 20),
                          const Text(
                            'No orders found',
                            style: TextStyle(
                              color: Color(0xFF94A3B8),
                              fontSize: 16,
                            ),
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'Create your first order to get started',
                            style: TextStyle(
                              color: Color(0xFF64748B),
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(height: 24),
                          ElevatedButton(
                            onPressed: _showAddOrderDialog,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF2B7AFE),
                            ),
                            child: const Text('Create Order'),
                          ),
                        ],
                      ),
                    );
                  }

                  final orders = snapshot.data!.docs
                      .map((doc) => Order.fromFirestore(doc))
                      .toList();

                  return ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    itemCount: orders.length,
                    itemBuilder: (context, index) {
                      final order = orders[index];
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 16),
                        child: _OrderCard(
                          order: order,
                          onViewDetails: () => _showOrderDetails(order),
                          onStatusUpdate: (newStatus) =>
                              _updateOrderStatus(order.id!, newStatus),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FilterButton extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _FilterButton({
    Key? key,
    required this.label,
    required this.isSelected,
    required this.onTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF2B7AFE) : const Color(0xFF1E293B),
          borderRadius: BorderRadius.circular(24),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: isSelected ? Colors.white : const Color(0xFF94A3B8),
          ),
        ),
      ),
    );
  }
}

class _OrderCard extends StatelessWidget {
  final Order order;
  final VoidCallback onViewDetails;
  final Function(String) onStatusUpdate;

  const _OrderCard({
    Key? key,
    required this.order,
    required this.onViewDetails,
    required this.onStatusUpdate,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    order.customerName,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Order #${order.id!.substring(0, 8)}',
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF64748B),
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: order.statusColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  order.status.toUpperCase(),
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: order.statusColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              _InfoItem(
                icon: Icons.shopping_bag_outlined,
                text: '${order.totalItems} items',
              ),
              const SizedBox(width: 24),
              _InfoItem(
                icon: Icons.access_time,
                text: order.formattedTime,
              ),
              const SizedBox(width: 24),
              _InfoItem(
                icon: Icons.calendar_today,
                text: order.formattedDate,
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '\$${order.totalAmount.toStringAsFixed(2)}',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              Row(
                children: [
                  if (order.status != 'completed' && order.status != 'cancelled')
                    PopupMenuButton<String>(
                      icon: Icon(
                        Icons.more_vert,
                        color: order.statusColor,
                      ),
                      itemBuilder: (context) => [
                        if (order.status == 'pending')
                          const PopupMenuItem(
                            value: 'processing',
                            child: Text('Mark as Processing'),
                          ),
                        if (order.status == 'processing')
                          const PopupMenuItem(
                            value: 'completed',
                            child: Text('Mark as Completed'),
                          ),
                        const PopupMenuItem(
                          value: 'cancelled',
                          child: Text('Cancel Order'),
                        ),
                      ],
                      onSelected: onStatusUpdate,
                    ),
                  const SizedBox(width: 8),
                  TextButton(
                    onPressed: onViewDetails,
                    child: Row(
                      children: const [
                        Text(
                          'View Details',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF2B7AFE),
                          ),
                        ),
                        SizedBox(width: 4),
                        Icon(
                          Icons.arrow_forward,
                          size: 16,
                          color: Color(0xFF2B7AFE),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _InfoItem extends StatelessWidget {
  final IconData icon;
  final String text;

  const _InfoItem({
    Key? key,
    required this.icon,
    required this.text,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(
          icon,
          size: 16,
          color: const Color(0xFF64748B),
        ),
        const SizedBox(width: 6),
        Text(
          text,
          style: const TextStyle(
            fontSize: 12,
            color: Color(0xFF94A3B8),
          ),
        ),
      ],
    );
  }
}