import 'package:flutter/material.dart';

class InventoryScreen extends StatefulWidget {
  const InventoryScreen({Key? key}) : super(key: key);

  @override
  State<InventoryScreen> createState() => _InventoryScreenState();
}

class _InventoryScreenState extends State<InventoryScreen> {
  String _selectedCategory = 'All Items';

  final List<Map<String, dynamic>> _inventory = [
    {
      'name': 'Aspirin 500mg',
      'type': 'Tablet',
      'price': '\$12.99',
      'units': 450,
      'isLowStock': false,
    },
    {
      'name': 'Amoxicillin 250mg',
      'type': 'Capsule',
      'price': '\$18.50',
      'units': 23,
      'isLowStock': true,
    },
    {
      'name': 'Ibuprofen 400mg',
      'type': 'Tablet',
      'price': '\$9.99',
      'units': 0,
      'isLowStock': true,
    },
    {
      'name': 'Paracetamol Syrup',
      'type': 'Syrup',
      'price': '\$7.50',
      'units': 180,
      'isLowStock': false,
    },
    {
      'name': 'Vitamin D3',
      'type': 'Capsule',
      'price': '\$15.99',
      'units': 320,
      'isLowStock': false,
    },
  ];

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Inventory',
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: () {},
                  icon: const Icon(Icons.add, size: 20),
                  label: const Text('Add'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2B7AFE),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 0,
                  ),
                ),
              ],
            ),
          ),

          // Search and Filter
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E293B),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: const [
                        Icon(Icons.search, color: Color(0xFF64748B)),
                        SizedBox(width: 12),
                        Text(
                          'Search inventory...',
                          style: TextStyle(
                            color: Color(0xFF64748B),
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E293B),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.filter_list,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Category Filters
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                _CategoryButton(
                  label: 'All Items',
                  isSelected: _selectedCategory == 'All Items',
                  onTap: () => setState(() => _selectedCategory = 'All Items'),
                ),
                const SizedBox(width: 12),
                _CategoryButton(
                  label: 'Tablets',
                  isSelected: _selectedCategory == 'Tablets',
                  onTap: () => setState(() => _selectedCategory = 'Tablets'),
                ),
                const SizedBox(width: 12),
                _CategoryButton(
                  label: 'Capsules',
                  isSelected: _selectedCategory == 'Capsules',
                  onTap: () => setState(() => _selectedCategory = 'Capsules'),
                ),
                const SizedBox(width: 12),
                _CategoryButton(
                  label: 'Syrups',
                  isSelected: _selectedCategory == 'Syrups',
                  onTap: () => setState(() => _selectedCategory = 'Syrups'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Inventory List
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              itemCount: _inventory.length,
              itemBuilder: (context, index) {
                final item = _inventory[index];
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _InventoryCard(
                    name: item['name'],
                    type: item['type'],
                    price: item['price'],
                    units: item['units'],
                    isLowStock: item['isLowStock'],
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

class _CategoryButton extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _CategoryButton({
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

class _InventoryCard extends StatelessWidget {
  final String name;
  final String type;
  final String price;
  final int units;
  final bool isLowStock;

  const _InventoryCard({
    Key? key,
    required this.name,
    required this.type,
    required this.price,
    required this.units,
    required this.isLowStock,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    Color unitColor;
    if (units == 0) {
      unitColor = const Color(0xFFEF4444);
    } else if (isLowStock) {
      unitColor = const Color(0xFFF59E0B);
    } else {
      unitColor = const Color(0xFF10B981);
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          // Medicine Icon
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: const Color(0xFF2B7AFE).withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.medication,
              color: Color(0xFF2B7AFE),
              size: 24,
            ),
          ),
          const SizedBox(width: 16),

          // Medicine Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  type,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF64748B),
                  ),
                ),
              ],
            ),
          ),

          // Price and Units
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                price,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '$units units',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: unitColor,
                ),
              ),
            ],
          ),

          const SizedBox(width: 12),

          // Menu Button
          IconButton(
            onPressed: () {},
            icon: const Icon(
              Icons.more_vert,
              color: Color(0xFF64748B),
            ),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
        ],
      ),
    );
  }
}
