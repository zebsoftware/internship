import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// A private namespace for every account. Legacy shared collections remain
/// untouched and are not included in the new UI.
class PharmacyData {
  static String get uid {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw StateError('Sign in to access pharmacy data');
    return user.uid;
  }
  static CollectionReference<Map<String, dynamic>> collection(String name) {
    if (!const ['medicines', 'orders', 'stockAdjustments'].contains(name)) {
      throw ArgumentError.value(name, 'name', 'Unsupported pharmacy collection');
    }
    return FirebaseFirestore.instance.collection('users').doc(uid).collection(name);
  }
}
