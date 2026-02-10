import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:ui';
class OrderItem {
  final String medicineId;
  final String medicineName;
  final double price;
  final int quantity;
  final double total;

  OrderItem({
    required this.medicineId,
    required this.medicineName,
    required this.price,
    required this.quantity,
    required this.total,
  });

  Map<String, dynamic> toMap() {
    return {
      'medicineId': medicineId,
      'medicineName': medicineName,
      'price': price,
      'quantity': quantity,
      'total': total,
    };
  }

  factory OrderItem.fromMap(Map<String, dynamic> map) {
    return OrderItem(
      medicineId: map['medicineId'] ?? '',
      medicineName: map['medicineName'] ?? '',
      price: (map['price'] ?? 0).toDouble(),
      quantity: map['quantity'] ?? 0,
      total: (map['total'] ?? 0).toDouble(),
    );
  }
}

class Order {
  String? id;
  final String customerName;
  final String customerPhone;
  final String customerEmail;
  final List<OrderItem> items;
  final double subtotal;
  final double tax;
  final double totalAmount;
  final String status;
  final String paymentMethod;
  final String notes;
  final DateTime createdAt;
  final DateTime? updatedAt;

  Order({
    this.id,
    required this.customerName,
    required this.customerPhone,
    required this.customerEmail,
    required this.items,
    required this.subtotal,
    required this.tax,
    required this.totalAmount,
    this.status = 'pending',
    this.paymentMethod = 'cash',
    this.notes = '',
    DateTime? createdAt,
    this.updatedAt,
  }) : createdAt = createdAt ?? DateTime.now();

  // Convert to Map for Firestore
  Map<String, dynamic> toMap() {
    return {
      'customerName': customerName,
      'customerPhone': customerPhone,
      'customerEmail': customerEmail,
      'items': items.map((item) => item.toMap()).toList(),
      'subtotal': subtotal,
      'tax': tax,
      'totalAmount': totalAmount,
      'status': status,
      'paymentMethod': paymentMethod,
      'notes': notes,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': updatedAt != null ? Timestamp.fromDate(updatedAt!) : null,
    };
  }

  // Create Order from Firestore Document
  factory Order.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    
    // Parse items list
    final List<OrderItem> items = (data['items'] as List<dynamic>?)
        ?.map((item) => OrderItem.fromMap(item as Map<String, dynamic>))
        .toList() ?? [];

    return Order(
      id: doc.id,
      customerName: data['customerName'] ?? '',
      customerPhone: data['customerPhone'] ?? '',
      customerEmail: data['customerEmail'] ?? '',
      items: items,
      subtotal: (data['subtotal'] ?? 0).toDouble(),
      tax: (data['tax'] ?? 0).toDouble(),
      totalAmount: (data['totalAmount'] ?? 0).toDouble(),
      status: data['status'] ?? 'pending',
      paymentMethod: data['paymentMethod'] ?? 'cash',
      notes: data['notes'] ?? '',
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      updatedAt: data['updatedAt'] != null 
          ? (data['updatedAt'] as Timestamp).toDate()
          : null,
    );
  }

  // Get status color
  Color get statusColor {
    switch (status.toLowerCase()) {
      case 'completed':
        return const Color(0xFF10B981);
      case 'processing':
        return const Color(0xFF2B7AFE);
      case 'cancelled':
        return const Color(0xFFEF4444);
      case 'pending':
      default:
        return const Color(0xFFF59E0B);
    }
  }

  // Get formatted date
  String get formattedDate {
    return '${createdAt.day}/${createdAt.month}/${createdAt.year}';
  }

  // Get formatted time
  String get formattedTime {
    return '${createdAt.hour.toString().padLeft(2, '0')}:${createdAt.minute.toString().padLeft(2, '0')}';
  }

  // Get total items count
  int get totalItems {
    return items.fold(0, (sum, item) => sum + item.quantity);
  }
}