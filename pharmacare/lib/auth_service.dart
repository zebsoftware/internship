import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Get current user
  User? get currentUser => _auth.currentUser;

  // Stream of user authentication state
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  // Register new user with Firestore
  Future<User?> registerUser({
    required String fullName,
    required String email,
    required String phoneNumber,
    required String licenseNumber,
    required String password,
  }) async {
    try {
      print('🔄 Step 1: Creating user in Firebase Auth...');
      
      // 1. Create user in Firebase Authentication
      UserCredential userCredential = await _auth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password.trim(),
      );

      final userId = userCredential.user!.uid;
      print('✅ Step 1 Complete: Auth user created: $userId');

      print('🔄 Step 2: Saving user data to Firestore...');
      
      // 2. Save user data to Firestore
      await _firestore.collection('users').doc(userId).set({
        'uid': userId,
        'fullName': fullName.trim(),
        'email': email.trim(),
        'phoneNumber': phoneNumber.trim(),
        'licenseNumber': licenseNumber.trim(),
        'createdAt': FieldValue.serverTimestamp(),
        'accountType': 'pharmacy',
        'isActive': true,
        'pharmacyName': 'PharmaCare Pharmacy',
      });

      print('✅ Step 2 Complete: User data saved to Firestore');
      print('🎉 User registration completed successfully!');

      return userCredential.user;
    } on FirebaseAuthException catch (e) {
      print('❌ Firebase Auth Error: ${e.code} - ${e.message}');
      throw _getErrorMessage(e.code);
    } on FirebaseException catch (e) {
      print('❌ Firebase/Firestore Error: ${e.code} - ${e.message}');
      throw 'Firestore error: ${e.message}';
    } catch (e) {
      print('❌ Unexpected Error: $e');
      throw 'Registration failed. Please try again.';
    }
  }

  // Login user
  Future<User?> loginUser({
    required String email,
    required String password,
  }) async {
    try {
      print('🔄 Attempting login...');
      
      UserCredential userCredential = await _auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password.trim(),
      );

      final userId = userCredential.user!.uid;
      print('✅ Login successful: $userId');
      
      // Verify user exists in Firestore
      final userDoc = await _firestore.collection('users').doc(userId).get();
      
      if (!userDoc.exists) {
        print('⚠️ User exists in Auth but not in Firestore');
        // Create Firestore document if missing
        await _firestore.collection('users').doc(userId).set({
          'uid': userId,
          'email': email.trim(),
          'createdAt': FieldValue.serverTimestamp(),
          'isActive': true,
        });
        print('✅ Created missing Firestore document');
      }

      return userCredential.user;
    } on FirebaseAuthException catch (e) {
      print('❌ Login Error: ${e.code} - ${e.message}');
      throw _getErrorMessage(e.code);
    } catch (e) {
      print('❌ Unexpected Login Error: $e');
      throw 'Login failed. Please try again.';
    }
  }

  // Logout user
  Future<void> logout() async {
    await _auth.signOut();
    print('✅ User logged out');
  }

  // Get user data from Firestore
  Future<Map<String, dynamic>?> getUserData(String userId) async {
    try {
      final doc = await _firestore.collection('users').doc(userId).get();
      if (doc.exists) {
        return doc.data();
      }
      return null;
    } catch (e) {
      print('❌ Error getting user data: $e');
      return null;
    }
  }

  // Check if email exists
  Future<bool> checkEmailExists(String email) async {
    try {
      final query = await _firestore
          .collection('users')
          .where('email', isEqualTo: email.trim())
          .limit(1)
          .get();
      
      return query.docs.isNotEmpty;
    } catch (e) {
      print('❌ Error checking email: $e');
      return false;
    }
  }

  String _getErrorMessage(String errorCode) {
    switch (errorCode) {
      case 'email-already-in-use':
        return 'This email is already registered. Please login instead.';
      case 'invalid-email':
        return 'Please enter a valid email address.';
      case 'weak-password':
        return 'Password is too weak (min. 6 characters).';
      case 'user-not-found':
        return 'No account found with this email.';
      case 'wrong-password':
        return 'Incorrect password.';
      default:
        return 'Authentication failed. Please try again.';
    }
  }
}