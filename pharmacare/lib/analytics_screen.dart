import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class AnalyticsScreen extends StatefulWidget {
  const AnalyticsScreen({Key? key}) : super(key: key);

  @override
  State<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends State<AnalyticsScreen> {
  String _selectedPeriod = 'This Week';
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  // Date ranges based on selected period
  DateTime get _startDate {
    final now = DateTime.now();
    switch (_selectedPeriod) {
      case 'This Month':
        return DateTime(now.year, now.month, 1);
      case 'This Year':
        return DateTime(now.year, 1, 1);
      case 'This Week':
      default:
        return now.subtract(Duration(days: now.weekday - 1));
    }
  }
  
  DateTime get _endDate => DateTime.now();

  Future<Map<String, dynamic>> _fetchAnalyticsData() async {
    try {
      // Get orders from selected period
      final ordersSnapshot = await _firestore
          .collection('orders')
          .where('createdAt', isGreaterThanOrEqualTo: Timestamp.fromDate(_startDate))
          .where('createdAt', isLessThanOrEqualTo: Timestamp.fromDate(_endDate))
          .get();

      // Get all medicines for top products calculation
      final medicinesSnapshot = await _firestore.collection('medicines').get();

      double totalRevenue = 0.0;
      int completedOrders = 0;
      int pendingOrders = 0;
      int cancelledOrders = 0;
      final Map<String, int> productSales = {};
      final Map<String, double> productRevenue = {};

      // Process orders
      for (final doc in ordersSnapshot.docs) {
        final Map<String, dynamic> order = doc.data() as Map<String, dynamic>;
        final String status = order['status']?.toString() ?? 'pending';
        final double totalAmount = (order['totalAmount'] ?? 0).toDouble();
        
        totalRevenue += totalAmount;

        // Count by status
        if (status == 'completed') {
          completedOrders++;
        } else if (status == 'pending') {
          pendingOrders++;
        } else if (status == 'cancelled') {
          cancelledOrders++;
        }

        // Process order items for product sales
        final List<dynamic> items = order['items'] is List ? order['items'] as List<dynamic> : [];
        for (final dynamic item in items) {
          if (item is Map<String, dynamic>) {
            final String medicineName = item['medicineName']?.toString() ?? '';
            final int quantity = (item['quantity'] ?? 0) is int ? (item['quantity'] as int) : 0;
            final double price = (item['price'] ?? 0).toDouble();
            
            if (medicineName.isNotEmpty) {
              // Update product sales - SAFE APPROACH
              final int? existingSales = productSales[medicineName];
              if (existingSales != null) {
                productSales[medicineName] = existingSales + quantity;
              } else {
                productSales[medicineName] = quantity;
              }
              
              // Update product revenue - SAFE APPROACH
              final double? existingRevenue = productRevenue[medicineName];
              final double itemRevenue = price * quantity;
              if (existingRevenue != null) {
                productRevenue[medicineName] = existingRevenue + itemRevenue;
              } else {
                productRevenue[medicineName] = itemRevenue;
              }
            }
          }
        }
      }

      // Calculate trend (compare with previous period)
      final previousPeriodData = await _fetchPreviousPeriodData();
      final double previousRevenue = (previousPeriodData['totalRevenue'] ?? 0).toDouble();
      double revenueGrowth = 0.0;
      
      if (previousRevenue > 0) {
        revenueGrowth = ((totalRevenue - previousRevenue) / previousRevenue) * 100;
      } else if (totalRevenue > 0) {
        revenueGrowth = 100.0; // Infinite growth from 0
      }

      // Get top selling products
      final List<Map<String, dynamic>> topProducts = _getTopProducts(productSales, productRevenue);

      return {
        'totalRevenue': totalRevenue,
        'revenueGrowth': revenueGrowth,
        'completedOrders': completedOrders,
        'pendingOrders': pendingOrders,
        'cancelledOrders': cancelledOrders,
        'totalOrders': completedOrders + pendingOrders + cancelledOrders,
        'topProducts': topProducts,
        'totalMedicines': medicinesSnapshot.docs.length,
      };
    } catch (e) {
      print('Error fetching analytics: $e');
      return {
        'totalRevenue': 0.0,
        'revenueGrowth': 0.0,
        'completedOrders': 0,
        'pendingOrders': 0,
        'cancelledOrders': 0,
        'totalOrders': 0,
        'topProducts': [],
        'totalMedicines': 0,
      };
    }
  }

  Future<Map<String, dynamic>> _fetchPreviousPeriodData() async {
    final DateTime previousStartDate = _startDate.subtract(const Duration(days: 7));
    final DateTime previousEndDate = _endDate.subtract(const Duration(days: 7));

    try {
      final QuerySnapshot ordersSnapshot = await _firestore
          .collection('orders')
          .where('createdAt', isGreaterThanOrEqualTo: Timestamp.fromDate(previousStartDate))
          .where('createdAt', isLessThanOrEqualTo: Timestamp.fromDate(previousEndDate))
          .get();

      double totalRevenue = 0.0;
      for (final doc in ordersSnapshot.docs) {
        final Map<String, dynamic> order = doc.data() as Map<String, dynamic>;
        totalRevenue += (order['totalAmount'] ?? 0).toDouble();
      }

      return {'totalRevenue': totalRevenue};
    } catch (e) {
      return {'totalRevenue': 0.0};
    }
  }

  List<Map<String, dynamic>> _getTopProducts(
    Map<String, int> productSales,
    Map<String, double> productRevenue,
  ) {
    // Convert to list and sort by sales
    final List<MapEntry<String, int>> productList = productSales.entries.toList();
    productList.sort((a, b) => b.value.compareTo(a.value));

    // Take top 5 and format
    return productList.take(5).map((entry) {
      final String name = entry.key;
      final int sales = entry.value;
      final double revenue = productRevenue[name] ?? 0.0;
      // For now, use simple trend logic
      final bool trend = sales > 0;

      return {
        'name': name,
        'sales': sales,
        'revenue': revenue,
        'trend': trend,
      };
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.all(20),
              child: const Text(
                'Analytics',
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),

            // Period Selector
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  _PeriodButton(
                    label: 'This Week',
                    isSelected: _selectedPeriod == 'This Week',
                    onTap: () => setState(() => _selectedPeriod = 'This Week'),
                  ),
                  const SizedBox(width: 12),
                  _PeriodButton(
                    label: 'This Month',
                    isSelected: _selectedPeriod == 'This Month',
                    onTap: () => setState(() => _selectedPeriod = 'This Month'),
                  ),
                  const SizedBox(width: 12),
                  _PeriodButton(
                    label: 'This Year',
                    isSelected: _selectedPeriod == 'This Year',
                    onTap: () => setState(() => _selectedPeriod = 'This Year'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Analytics Data with FutureBuilder
            FutureBuilder<Map<String, dynamic>>(
              future: _fetchAnalyticsData(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: CircularProgressIndicator(
                      color: Color(0xFF2B7AFE),
                    ),
                  );
                }

                if (snapshot.hasError) {
                  return Padding(
                    padding: const EdgeInsets.all(20),
                    child: Center(
                      child: Text(
                        'Error loading analytics',
                        style: const TextStyle(color: Colors.white),
                      ),
                    ),
                  );
                }

                final Map<String, dynamic> data = snapshot.data ?? {};
                final double totalRevenue = (data['totalRevenue'] ?? 0).toDouble();
                final double revenueGrowth = (data['revenueGrowth'] ?? 0).toDouble();
                final int completedOrders = (data['completedOrders'] ?? 0) as int;
                final int pendingOrders = (data['pendingOrders'] ?? 0) as int;
                final int totalOrders = (data['totalOrders'] ?? 0) as int;
                final int totalMedicines = (data['totalMedicines'] ?? 0) as int;
                final List<dynamic> topProductsRaw = data['topProducts'] is List ? data['topProducts'] as List<dynamic> : [];
                final List<Map<String, dynamic>> topProducts = topProductsRaw.map((item) {
                  if (item is Map<String, dynamic>) {
                    return item;
                  }
                  return <String, dynamic>{};
                }).toList();

                return Column(
                  children: [
                    // Revenue Card
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Container(
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFF2B7AFE), Color(0xFF1E5DD6)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'Total Revenue (${_selectedPeriod.toLowerCase()})',
                                  style: const TextStyle(
                                    fontSize: 14,
                                    color: Colors.white70,
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.2),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Icon(
                                    revenueGrowth >= 0
                                        ? Icons.trending_up
                                        : Icons.trending_down,
                                    color: Colors.white,
                                    size: 20,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Text(
                              '\$${NumberFormat('#,###').format(totalRevenue)}',
                              style: const TextStyle(
                                fontSize: 36,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                Icon(
                                  revenueGrowth >= 0
                                      ? Icons.arrow_upward
                                      : Icons.arrow_downward,
                                  color: revenueGrowth >= 0
                                      ? const Color(0xFF10B981)
                                      : const Color(0xFFEF4444),
                                  size: 16,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  '${revenueGrowth >= 0 ? '+' : ''}${revenueGrowth.toStringAsFixed(1)}% vs previous period',
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: revenueGrowth >= 0
                                        ? const Color(0xFF10B981)
                                        : const Color(0xFFEF4444),
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Order Stats
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Row(
                        children: [
                          Expanded(
                            child: _StatCard(
                              icon: Icons.check_circle,
                              iconColor: const Color(0xFF10B981),
                              label: 'Completed',
                              value: completedOrders.toString(),
                              subtitle: 'Orders',
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _StatCard(
                              icon: Icons.access_time,
                              iconColor: const Color(0xFFF59E0B),
                              label: 'Pending',
                              value: pendingOrders.toString(),
                              subtitle: 'Orders',
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Row(
                        children: [
                          Expanded(
                            child: _StatCard(
                              icon: Icons.shopping_bag,
                              iconColor: const Color(0xFF2B7AFE),
                              label: 'Total',
                              value: totalOrders.toString(),
                              subtitle: 'Orders',
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _StatCard(
                              icon: Icons.medication,
                              iconColor: const Color(0xFF8B5CF6),
                              label: 'Products',
                              value: totalMedicines.toString(),
                              subtitle: 'In Stock',
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 32),

                    // Top Selling Products
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Top Selling Products',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          Text(
                            _selectedPeriod,
                            style: const TextStyle(
                              fontSize: 12,
                              color: Color(0xFF64748B),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Product List or Empty State
                    if (topProducts.isEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: Container(
                          padding: const EdgeInsets.all(40),
                          decoration: BoxDecoration(
                            color: const Color(0xFF1E293B),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Column(
                            children: [
                              Container(
                                width: 80,
                                height: 80,
                                decoration: BoxDecoration(
                                  color: const Color(0xFF0F172A),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.analytics_outlined,
                                  color: Color(0xFF64748B),
                                  size: 40,
                                ),
                              ),
                              const SizedBox(height: 20),
                              const Text(
                                'No sales data',
                                style: TextStyle(
                                  color: Color(0xFF94A3B8),
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 8),
                              const Text(
                                'Complete some orders to see analytics',
                                style: TextStyle(
                                  color: Color(0xFF64748B),
                                  fontSize: 14,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        ),
                      )
                    else
                      ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        itemCount: topProducts.length,
                        itemBuilder: (context, index) {
                          final Map<String, dynamic> product = topProducts[index];
                          final String name = product['name']?.toString() ?? 'Unknown Product';
                          final int sales = (product['sales'] ?? 0) as int;
                          final double revenue = (product['revenue'] ?? 0).toDouble();
                          final bool trend = (product['trend'] ?? true) as bool;

                          return Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: _ProductCard(
                              name: name,
                              sales: sales,
                              revenue: revenue,
                              trend: trend,
                            ),
                          );
                        },
                    ),
                    const SizedBox(height: 20),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _PeriodButton extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _PeriodButton({
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
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF2B7AFE) : const Color(0xFF1E293B),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: isSelected ? Colors.white : const Color(0xFF94A3B8),
          ),
        ),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String label;
  final String value;
  final String subtitle;

  const _StatCard({
    Key? key,
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.value,
    required this.subtitle,
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
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: iconColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: iconColor, size: 28),
          ),
          const SizedBox(height: 16),
          Text(
            label,
            style: const TextStyle(
              fontSize: 13,
              color: Color(0xFF94A3B8),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: const TextStyle(
              fontSize: 11,
              color: Color(0xFF64748B),
            ),
          ),
        ],
      ),
    );
  }
}

class _ProductCard extends StatelessWidget {
  final String name;
  final int sales;
  final double revenue;
  final bool trend;

  const _ProductCard({
    Key? key,
    required this.name,
    required this.sales,
    required this.revenue,
    required this.trend,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
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

          // Product Info
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
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  '$sales ${sales == 1 ? 'sale' : 'sales'}',
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF64748B),
                  ),
                ),
              ],
            ),
          ),

          // Revenue and Trend
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '\$${NumberFormat('#,###').format(revenue)}',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 4),
              Icon(
                trend ? Icons.trending_up : Icons.trending_down,
                color: trend ? const Color(0xFF10B981) : const Color(0xFFEF4444),
                size: 20,
              ),
            ],
          ),
        ],
      ),
    );
  }
}