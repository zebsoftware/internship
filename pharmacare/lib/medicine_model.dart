import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:ui'; 
class Medicine {
  String? id;
  final String name;
  final String batchNo;
  final String type;
  final int quantity;
  final double costPrice;
  final double sellingPrice;
  final DateTime expiryDate;
  final DateTime createdAt;

  Medicine({
    this.id,
    required this.name,
    required this.batchNo,
    required this.type,
    required this.quantity,
    required this.costPrice,
    required this.sellingPrice,
    required this.expiryDate,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  // Convert to Map for Firestore
  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'batchNo': batchNo,
      'type': type,
      'quantity': quantity,
      'costPrice': costPrice,
      'sellingPrice': sellingPrice,
      'expiryDate': Timestamp.fromDate(expiryDate),
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }

  // Create Medicine from Firestore Document
  factory Medicine.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Medicine(
      id: doc.id,
      name: data['name'] ?? '',
      batchNo: data['batchNo'] ?? '',
      type: data['type'] ?? 'Tablet',
      quantity: data['quantity'] ?? 0,
      costPrice: (data['costPrice'] ?? 0).toDouble(),
      sellingPrice: (data['sellingPrice'] ?? 0).toDouble(),
      expiryDate: (data['expiryDate'] as Timestamp).toDate(),
      createdAt: (data['createdAt'] as Timestamp).toDate(),
    );
  }

  // Check if medicine is low stock (less than 20 units)
  bool get isLowStock => quantity < 20;

  // Check if medicine is out of stock
  bool get isOutOfStock => quantity == 0;

  // Get status color
  Color get statusColor {
    if (isOutOfStock) return const Color(0xFFEF4444);
    if (isLowStock) return const Color(0xFFF59E0B);
    return const Color(0xFF10B981);
  }

  // Get status text
  String get statusText {
    if (isOutOfStock) return 'Out of Stock';
    if (isLowStock) return 'Low Stock';
    return 'In Stock';
  }
}