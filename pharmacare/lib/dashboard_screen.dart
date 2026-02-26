import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'orders_screen.dart';
import 'inventory_screen.dart';
import 'analytics_screen.dart';
import 'profile_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({Key? key}) : super(key: key);

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  int _currentIndex = 0;
  final User? currentUser = FirebaseAuth.instance.currentUser;

  final List<Widget> _screens = [
    const DashboardContent(),
    const OrdersScreen(),
    const InventoryScreen(),
    const AnalyticsScreen(),
    const ProfileScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A1628),
      body: _screens[_currentIndex],
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          color: Color(0xFF1E293B),
          border: Border(
            top: BorderSide(color: Color(0xFF334155), width: 0.5),
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildNavItem(Icons.home_rounded, 'Home', 0),
                _buildNavItem(Icons.shopping_cart_rounded, 'Orders', 1),
                _buildNavItem(Icons.inventory_2_rounded, 'Inventory', 2),
                _buildNavItem(Icons.analytics_rounded, 'Analytics', 3),
                _buildNavItem(Icons.person_rounded, 'Profile', 4),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem(IconData icon, String label, int index) {
    final isSelected = _currentIndex == index;
    return GestureDetector(
      onTap: () => setState(() => _currentIndex = index),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF2B7AFE) : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              color: isSelected ? Colors.white : const Color(0xFF64748B),
              size: 24,
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                color: isSelected ? Colors.white : const Color(0xFF64748B),
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class DashboardContent extends StatefulWidget {
  const DashboardContent({Key? key}) : super(key: key);

  @override
  State<DashboardContent> createState() => _DashboardContentState();
}

class _DashboardContentState extends State<DashboardContent> {
  final User? currentUser = FirebaseAuth.instance.currentUser;
  String fullName = 'User';
  String pharmacyName = '';
  bool _isLoading = true;
  
  @override
  void initState() {
    super.initState();
    _fetchUserData();
  }

  Future<void> _fetchUserData() async {
    if (currentUser != null) {
      try {
        print('Current User UID: ${currentUser!.uid}');
        
        // Get user data from Firestore using the UID
        DocumentSnapshot userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(currentUser!.uid)
            .get();

        if (userDoc.exists) {
          print('User document exists');
          Map<String, dynamic> userData = userDoc.data() as Map<String, dynamic>;
          print('User data: $userData');
          
          setState(() {
            // Using your exact field names from the image
            fullName = userData['fullName'] ?? 'User';
            pharmacyName = userData['pharmacyName'] ?? '';
            _isLoading = false;
          });
        } else {
          print('User document does not exist in Firestore');
          setState(() {
            if (currentUser?.displayName != null && currentUser!.displayName!.isNotEmpty) {
              fullName = currentUser!.displayName!;
            } else if (currentUser?.email != null) {
              fullName = currentUser!.email!.split('@')[0];
            }
            _isLoading = false;
          });
        }
      } catch (e) {
        print('Error fetching user data: $e');
        setState(() {
          _isLoading = false;
        });
      }
    } else {
      print('No user is currently signed in');
      setState(() {
        _isLoading = false;
      });
    }
  }

  // Stream for low stock items (quantity < 10)
  Stream<int> getLowStockCount() {
    return FirebaseFirestore.instance
        .collection('medicines')
        .where('quantity', isLessThan: 10)
        .snapshots()
        .map((snapshot) => snapshot.docs.length);
  }

  // Stream for expiring items (expiry within 2 months)
  Stream<int> getExpiringCount() {
    DateTime twoMonthsFromNow = DateTime.now().add(const Duration(days: 60));
    
    return FirebaseFirestore.instance
        .collection('medicines')
        .where('expiryDate', isLessThanOrEqualTo: twoMonthsFromNow)
        .snapshots()
        .map((snapshot) => snapshot.docs.length);
  }

  // Stream for total revenue (completed orders)
  Stream<double> getTotalRevenue() {
    return FirebaseFirestore.instance
        .collection('orders')
        .where('status', isEqualTo: 'completed')
        .snapshots()
        .map((snapshot) {
          double total = 0;
          for (var doc in snapshot.docs) {
            var data = doc.data();
            if (data.containsKey('totalAmount')) {
              total += (data['totalAmount'] ?? 0).toDouble();
            } else if (data.containsKey('total')) {
              total += (data['total'] ?? 0).toDouble();
            } else if (data.containsKey('amount')) {
              total += (data['amount'] ?? 0).toDouble();
            }
          }
          return total;
        });
  }

  // Stream for total orders count
  Stream<int> getTotalOrders() {
    return FirebaseFirestore.instance
        .collection('orders')
        .snapshots()
        .map((snapshot) => snapshot.docs.length);
  }

  // Stream for recent orders
  Stream<QuerySnapshot> getRecentOrders() {
    return FirebaseFirestore.instance
        .collection('orders')
        .orderBy('createdAt', descending: true)
        .limit(5)
        .snapshots();
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmallScreen = screenWidth < 400;
    final paddingValue = isSmallScreen ? 16.0 : 20.0;

    if (_isLoading) {
      return const SafeArea(
        child: Center(
          child: CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF2B7AFE)),
          ),
        ),
      );
    }

    return SafeArea(
      child: SingleChildScrollView(
        padding: EdgeInsets.all(paddingValue),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header with real user data from Firebase - Showing Dr. + fullName
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Welcome back,',
                      style: TextStyle(
                        fontSize: 14,
                        color: Color(0xFF94A3B8),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Dr. $fullName',
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    // if (pharmacyName.isNotEmpty)
                    //   Text(
                    //     pharmacyName,
                    //     style: const TextStyle(
                    //       fontSize: 14,
                    //       color: Color(0xFF94A3B8),
                    //     ),
                    //   ),
                  ],
                ),
                Stack(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1E293B),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.notifications_rounded,
                        color: Colors.white,
                        size: 24,
                      ),
                    ),
                    // Notification badge for low stock and expiring items
                    StreamBuilder<int>(
                      stream: getLowStockCount(),
                      builder: (context, lowStockSnapshot) {
                        return StreamBuilder<int>(
                          stream: getExpiringCount(),
                          builder: (context, expiringSnapshot) {
                            int totalAlerts = 0;
                            if (lowStockSnapshot.hasData) totalAlerts += lowStockSnapshot.data!;
                            if (expiringSnapshot.hasData) totalAlerts += expiringSnapshot.data!;
                            
                            if (totalAlerts > 0) {
                              return Positioned(
                                top: 8,
                                right: 8,
                                child: Container(
                                  padding: const EdgeInsets.all(4),
                                  decoration: const BoxDecoration(
                                    color: Color(0xFFEF4444),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Text(
                                    totalAlerts > 9 ? '9+' : totalAlerts.toString(),
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 8,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              );
                            }
                            return const SizedBox.shrink();
                          },
                        );
                      },
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Search Bar
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: const Color(0xFF1E293B),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: const Color(0xFF334155),
                  width: 1,
                ),
              ),
              child: Row(
                children: const [
                  Icon(Icons.search, color: Color(0xFF64748B), size: 20),
                  SizedBox(width: 12),
                  Text(
                    'Search medicines, orders...',
                    style: TextStyle(
                      color: Color(0xFF64748B),
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Stats Grid with real data
            LayoutBuilder(
              builder: (context, constraints) {
                final containerWidth = constraints.maxWidth;
                final crossAxisCount = containerWidth < 400 ? 2 : 4;
                final childAspectRatio = containerWidth < 400 ? 1.2 : 1.0;
                
                return GridView.count(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisCount: crossAxisCount,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  childAspectRatio: childAspectRatio,
                  children: [
                    // Revenue Card
                    StreamBuilder<double>(
                      stream: getTotalRevenue(),
                      builder: (context, snapshot) {
                        double revenue = snapshot.data ?? 0;
                        String revenueText = revenue >= 1000 
                            ? '\$${(revenue/1000).toStringAsFixed(1)}K'
                            : '\$${revenue.toStringAsFixed(0)}';
                        
                        return _StatCard(
                          icon: Icons.attach_money_rounded,
                          iconColor: const Color(0xFF10B981),
                          title: 'Revenue',
                          value: revenueText,
                          trend: '+12.5%',
                          trendColor: const Color(0xFF10B981),
                          iconBackground: const Color(0xFF10B981).withOpacity(0.1),
                        );
                      },
                    ),
                    
                    // Orders Card
                    StreamBuilder<int>(
                      stream: getTotalOrders(),
                      builder: (context, snapshot) {
                        int orders = snapshot.data ?? 0;
                        return _StatCard(
                          icon: Icons.shopping_cart_rounded,
                          iconColor: const Color(0xFF2B7AFE),
                          title: 'Orders',
                          value: orders.toString(),
                          trend: '+8.2%',
                          trendColor: const Color(0xFF10B981),
                          iconBackground: const Color(0xFF2B7AFE).withOpacity(0.1),
                        );
                      },
                    ),
                    
                    if (containerWidth >= 400) ...[
                      // Low Stock Card (shows medicines with quantity < 10)
                      StreamBuilder<int>(
                        stream: getLowStockCount(),
                        builder: (context, snapshot) {
                          int lowStock = snapshot.data ?? 0;
                          return _StatCard(
                            icon: Icons.inventory_2_rounded,
                            iconColor: const Color(0xFFF59E0B),
                            title: 'Low Stock',
                            value: lowStock.toString(),
                            trend: lowStock > 5 ? 'Alert!' : 'Normal',
                            trendColor: lowStock > 5 ? const Color(0xFFEF4444) : const Color(0xFF10B981),
                            iconBackground: const Color(0xFFF59E0B).withOpacity(0.1),
                          );
                        },
                      ),
                      
                      // Expiring Items Card (within 2 months)
                      StreamBuilder<int>(
                        stream: getExpiringCount(),
                        builder: (context, snapshot) {
                          int expiring = snapshot.data ?? 0;
                          return _StatCard(
                            icon: Icons.timer_rounded,
                            iconColor: const Color(0xFF8B5CF6),
                            title: 'Expiring Soon',
                            value: expiring.toString(),
                            trend: expiring > 3 ? 'Check!' : 'Normal',
                            trendColor: expiring > 3 ? const Color(0xFFEF4444) : const Color(0xFF10B981),
                            iconBackground: const Color(0xFF8B5CF6).withOpacity(0.1),
                          );
                        },
                      ),
                    ],
                  ],
                );
              },
            ),

            // For small screens: Show Low Stock and Expiring items in second row
            LayoutBuilder(
              builder: (context, constraints) {
                if (constraints.maxWidth >= 400) {
                  return const SizedBox.shrink();
                }
                return Column(
                  children: [
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: StreamBuilder<int>(
                            stream: getLowStockCount(),
                            builder: (context, snapshot) {
                              int lowStock = snapshot.data ?? 0;
                              return _StatCard(
                                icon: Icons.inventory_2_rounded,
                                iconColor: const Color(0xFFF59E0B),
                                title: 'Low Stock',
                                value: lowStock.toString(),
                                trend: lowStock > 5 ? 'Alert!' : 'Normal',
                                trendColor: lowStock > 5 ? const Color(0xFFEF4444) : const Color(0xFF10B981),
                                iconBackground: const Color(0xFFF59E0B).withOpacity(0.1),
                              );
                            },
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: StreamBuilder<int>(
                            stream: getExpiringCount(),
                            builder: (context, snapshot) {
                              int expiring = snapshot.data ?? 0;
                              return _StatCard(
                                icon: Icons.timer_rounded,
                                iconColor: const Color(0xFF8B5CF6),
                                title: 'Expiring Soon',
                                value: expiring.toString(),
                                trend: expiring > 3 ? 'Check!' : 'Normal',
                                trendColor: expiring > 3 ? const Color(0xFFEF4444) : const Color(0xFF10B981),
                                iconBackground: const Color(0xFF8B5CF6).withOpacity(0.1),
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  ],
                );
              },
            ),

            const SizedBox(height: 32),

            // Recent Orders Header with Live Updates
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Recent Orders',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E293B),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFF334155)),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.refresh_rounded, color: Color(0xFF2B7AFE), size: 16),
                      SizedBox(width: 4),
                      Text(
                        'Live',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Recent Orders from Firestore
            StreamBuilder<QuerySnapshot>(
              stream: getRecentOrders(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  print('Error loading orders: ${snapshot.error}');
                  return Center(
                    child: Text(
                      'Error loading orders',
                      style: TextStyle(color: Colors.white.withOpacity(0.7)),
                    ),
                  );
                }

                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF2B7AFE)),
                    ),
                  );
                }

                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E293B),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Center(
                      child: Column(
                        children: [
                          Icon(
                            Icons.shopping_cart_rounded,
                            size: 48,
                            color: Colors.white.withOpacity(0.3),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'No orders yet',
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.5),
                              fontSize: 16,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }

                return Column(
                  children: snapshot.data!.docs.map((doc) {
                    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
                    
                    // Get customer name - you'll need to adjust these field names based on your orders collection structure
                    String customerName = data['customerName'] ?? 
                                         data['customer_name'] ?? 
                                         data['customer'] ?? 
                                         data['userId'] ?? 
                                         'Customer';
                    
                    // Get order ID
                    String orderId = data['orderId'] ?? 
                                    data['order_id'] ?? 
                                    data['id'] ?? 
                                    doc.id;
                    
                    // Get status
                    String status = data['status'] ?? 'pending';
                    if (status is String) {
                      status = status.toLowerCase();
                    }
                    
                    Color statusColor;
                    switch (status) {
                      case 'completed':
                      case 'delivered':
                        statusColor = const Color(0xFF10B981);
                        break;
                      case 'pending':
                        statusColor = const Color(0xFFF59E0B);
                        break;
                      case 'cancelled':
                        statusColor = const Color(0xFFEF4444);
                        break;
                      default:
                        statusColor = const Color(0xFF64748B);
                    }

                    return Column(
                      children: [
                        _OrderCard(
                          customerName: customerName,
                          orderId: orderId,
                          status: status,
                          statusColor: statusColor,
                        ),
                        const SizedBox(height: 12),
                      ],
                    );
                  }).toList(),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String value;
  final String trend;
  final Color trendColor;
  final Color iconBackground;

  const _StatCard({
    Key? key,
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.value,
    required this.trend,
    required this.trendColor,
    required this.iconBackground,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: iconBackground,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: iconColor, size: 20),
              ),
              Text(
                trend,
                style: TextStyle(
                  fontSize: 12,
                  color: trendColor,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            title,
            style: const TextStyle(
              fontSize: 13,
              color: Color(0xFF94A3B8),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}

class _OrderCard extends StatelessWidget {
  final String customerName;
  final String orderId;
  final String status;
  final Color statusColor;

  const _OrderCard({
    Key? key,
    required this.customerName,
    required this.orderId,
    required this.status,
    required this.statusColor,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
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
            child: Row(
              children: [
                Container(
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: statusColor,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  status[0].toUpperCase() + status.substring(1),
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: statusColor,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}