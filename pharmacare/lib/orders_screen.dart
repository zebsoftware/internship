import 'package:flutter/material.dart';

class OrdersScreen extends StatefulWidget {
  const OrdersScreen({Key? key}) : super(key: key);

  @override
  State<OrdersScreen> createState() => _OrdersScreenState();
}

class _OrdersScreenState extends State<OrdersScreen> {
  String _selectedFilter = 'All';

  final List<Map<String, dynamic>> _orders = [
    {
      'customerName': 'John Smith',
      'orderId': '#ORD-1234',
      'items': 5,
      'time': '10:30 AM',
      'date': 'Jan 25, 2026',
      'amount': '\$145.00',
      'status': 'completed',
      'statusColor': Color(0xFF10B981),
    },
    {
      'customerName': 'Emma Davis',
      'orderId': '#ORD-1235',
      'items': 3,
      'time': '11:15 AM',
      'date': 'Jan 25, 2026',
      'amount': '\$89.50',
      'status': 'pending',
      'statusColor': Color(0xFFF59E0B),
    },
    {
      'customerName': 'Mike Wilson',
      'orderId': '#ORD-1236',
      'items': 8,
      'time': '09:45 AM',
      'date': 'Jan 26, 2026',
      'amount': '\$234.00',
      'status': 'processing',
      'statusColor': Color(0xFF2B7AFE),
    },
  ];

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.all(20),
            child: const Text(
              'Orders',
              style: TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ),

          // Filter Buttons
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                _FilterButton(
                  label: 'All',
                  isSelected: _selectedFilter == 'All',
                  onTap: () => setState(() => _selectedFilter = 'All'),
                ),
                const SizedBox(width: 12),
                _FilterButton(
                  label: 'Pending',
                  isSelected: _selectedFilter == 'Pending',
                  onTap: () => setState(() => _selectedFilter = 'Pending'),
                ),
                const SizedBox(width: 12),
                _FilterButton(
                  label: 'Completed',
                  isSelected: _selectedFilter == 'Completed',
                  onTap: () => setState(() => _selectedFilter = 'Completed'),
                ),
                const SizedBox(width: 12),
                _FilterButton(
                  label: 'Cancelled',
                  isSelected: _selectedFilter == 'Cancelled',
                  onTap: () => setState(() => _selectedFilter = 'Cancelled'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Orders List
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              itemCount: _orders.length,
              itemBuilder: (context, index) {
                final order = _orders[index];
                return Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: _OrderCard(
                    customerName: order['customerName'],
                    orderId: order['orderId'],
                    items: order['items'],
                    time: order['time'],
                    date: order['date'],
                    amount: order['amount'],
                    status: order['status'],
                    statusColor: order['statusColor'],
                  ),
                );
              },
            ),
          ),
        ],
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
  final String customerName;
  final String orderId;
  final int items;
  final String time;
  final String date;
  final String amount;
  final String status;
  final Color statusColor;

  const _OrderCard({
    Key? key,
    required this.customerName,
    required this.orderId,
    required this.items,
    required this.time,
    required this.date,
    required this.amount,
    required this.status,
    required this.statusColor,
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
                    customerName,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    orderId,
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
                  color: statusColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  status,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: statusColor,
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
                text: '$items items',
              ),
              const SizedBox(width: 24),
              _InfoItem(
                icon: Icons.access_time,
                text: time,
              ),
              const SizedBox(width: 24),
              _InfoItem(
                icon: Icons.calendar_today,
                text: date,
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                amount,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              TextButton(
                onPressed: () {},
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
