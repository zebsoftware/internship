import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'pharmacy_settings.dart';

/// Firebase Auth owns credentials; profile details are stored under the user's UID.
/// Do not log passwords, user identifiers, or customer profile data.
class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  User? get currentUser => _auth.currentUser;
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  Future<User?> registerUser({
    required String fullName,
    required String email,
    required String phoneNumber,
    required String licenseNumber,
    required String password,
    String currency = 'PKR',
  }) async {
    if (!supportedCurrencies.contains(currency)) {
      throw ArgumentError('Select a supported currency.');
    }
    final normalizedEmail = email.trim().toLowerCase();
    if (fullName.trim().isEmpty || normalizedEmail.isEmpty || password.length < 8) {
      throw ArgumentError('Enter your name, a valid email, and at least 8 password characters.');
    }

    try {
      final credential = await _auth.createUserWithEmailAndPassword(
        email: normalizedEmail,
        password: password,
      );
      final user = credential.user;
      if (user == null) throw StateError('Unable to finish account registration.');

      // A license number supplied by a user is not evidence of license verification.
      // Verification must happen in a trusted administrative workflow.
      final profile = _firestore.collection('users').doc(user.uid);
      final batch = _firestore.batch();
      batch.set(profile, {
        'uid': user.uid,
        'fullName': fullName.trim(),
        'email': user.email ?? normalizedEmail,
        'phoneNumber': phoneNumber.trim(),
        'licenseNumber': licenseNumber.trim(),
        'createdAt': FieldValue.serverTimestamp(),
        'accountType': 'pharmacy',
        'isActive': true,
        'pharmacyName': 'PharmaCare Pharmacy',
      });
      batch.set(
        profile.collection('settings').doc('pharmacy'),
        PharmacySettings(currency: currency).toMap(),
      );
      await batch.commit();
      await user.updateDisplayName(fullName.trim());
      return user;
    } on FirebaseAuthException catch (error) {
      throw _authMessage(error.code);
    } on FirebaseException {
      throw 'Account created, but pharmacy setup could not finish. Please sign in again or contact support.';
    }
  }

  Future<User?> loginUser({
    required String email,
    required String password,
  }) async {
    try {
      final credential = await _auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      final user = credential.user;
      if (user == null) throw StateError('Unable to sign in.');

      // Do not automatically create an incomplete, privileged-looking profile.
      // Missing profiles should be repaired through an explicit recovery flow.
      final profile = await _firestore.collection('users').doc(user.uid).get();
      if (!profile.exists) {
        await _auth.signOut();
        throw StateError('Your pharmacy profile is missing. Please contact support.');
      }
      return user;
    } on FirebaseAuthException catch (error) {
      throw _authMessage(error.code);
    }
  }

  /// Firebase sends a reset link if the email belongs to an account.
  /// The UI should display the same neutral confirmation for any valid email.
  Future<void> sendPasswordResetEmail(String email) async {
    final normalizedEmail = email.trim();
    if (normalizedEmail.isEmpty || !normalizedEmail.contains('@')) {
      throw ArgumentError('Enter a valid email address.');
    }
    try {
      await _auth.sendPasswordResetEmail(email: normalizedEmail);
    } on FirebaseAuthException catch (error) {
      if (error.code == 'invalid-email') {
        throw ArgumentError('Enter a valid email address.');
      }
      // Account existence must not be disclosed by password recovery.
      if (error.code == 'user-not-found') return;
      throw 'Unable to send a recovery email right now. Please try again later.';
    }
  }

  Future<void> logout() => _auth.signOut();

  Future<Map<String, dynamic>?> getUserData(String userId) async {
    if (_auth.currentUser?.uid != userId) {
      throw StateError('You can only access your own pharmacy profile.');
    }
    final document = await _firestore.collection('users').doc(userId).get();
    return document.data();
  }

  /// Do not query all user profiles to determine if an email is registered.
  /// Account uniqueness is enforced by Firebase Authentication registration.
  @Deprecated('Use Firebase Authentication registration; do not enumerate user emails.')
  Future<bool> checkEmailExists(String email) {
    throw UnsupportedError('Email availability checks are not supported.');
  }

  String _authMessage(String code) {
    switch (code) {
      case 'email-already-in-use':
        return 'This email is already registered. Sign in or reset your password.';
      case 'invalid-email':
        return 'Enter a valid email address.';
      case 'weak-password':
        return 'Use a stronger password with at least 8 characters.';
      case 'too-many-requests':
        return 'Too many attempts. Please try again later.';
      case 'network-request-failed':
        return 'Network error. Check your connection and try again.';
      case 'user-not-found':
      case 'wrong-password':
      case 'invalid-credential':
      case 'invalid-login-credentials':
        return 'Invalid email or password.';
      default:
        return 'Authentication failed. Please try again.';
    }
  }
}
