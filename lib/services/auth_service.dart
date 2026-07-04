import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

class AuthService {
  static final FirebaseAuth _auth = FirebaseAuth.instance;
  static String? lastError;

  static User? get currentUser => _auth.currentUser;

  static String _friendlyFirebaseAuthMessage(FirebaseAuthException e) {
    switch (e.code) {
      case 'network-request-failed':
        return 'Network error. Check your internet connection and try again.';
      case 'user-not-found':
        return 'No account exists for that email address.';
      case 'wrong-password':
        return 'Incorrect password. Please try again.';
      case 'invalid-email':
        return 'The email address is invalid.';
      case 'weak-password':
        return 'Password is too weak. Use at least 6 characters.';
      case 'email-already-in-use':
        return 'An account with this email already exists.';
      case 'user-disabled':
        return 'This account has been disabled.';
      case 'too-many-requests':
        return 'Too many attempts. Please wait and try again later.';
      default:
        return '${e.code.replaceAll('_', ' ')}: ${e.message ?? 'An authentication error occurred.'}';
    }
  }

  static String _authErrorMessage(Object e) {
    if (e is FirebaseAuthException) {
      return _friendlyFirebaseAuthMessage(e);
    }
    return e.toString();
  }

  static Future<User?> ensureSignedIn() async {
    if (_auth.currentUser != null) {
      return _auth.currentUser;
    }

    try {
      final credential = await _auth.signInAnonymously();
      debugPrint('✓ Firebase anonymous auth enabled (AuthService)');
      return credential.user;
    } catch (e) {
      debugPrint('⚠️ AuthService signInAnonymously failed: $e');
      return null;
    }
  }

  static Future<UserCredential?> signInWithEmail(String email, String password) async {
    try {
      final credential = await _auth.signInWithEmailAndPassword(email: email, password: password);
      lastError = null;
      return credential;
    } catch (e) {
      lastError = _authErrorMessage(e);
      debugPrint('⚠️ AuthService signInWithEmail failed: $lastError');
      return null;
    }
  }

  static Future<UserCredential?> createUserWithEmail(String email, String password) async {
    try {
      final credential = await _auth.createUserWithEmailAndPassword(email: email, password: password);
      lastError = null;
      return credential;
    } catch (e) {
      lastError = _authErrorMessage(e);
      debugPrint('⚠️ AuthService createUserWithEmail failed: $lastError');
      return null;
    }
  }

  static Future<bool> sendPasswordResetEmail(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email);
      lastError = null;
      debugPrint('✓ AuthService password reset email sent to $email');
      return true;
    } catch (e) {
      lastError = _authErrorMessage(e);
      debugPrint('⚠️ AuthService sendPasswordResetEmail failed: $lastError');
      return false;
    }
  }

  static Future<void> signOut() async {
    try {
      await _auth.signOut();
      debugPrint('✓ AuthService user signed out');
    } catch (e) {
      debugPrint('⚠️ AuthService signOut failed: $e');
    }
  }
}
