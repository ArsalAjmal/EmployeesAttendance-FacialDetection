import 'package:firebase_auth/firebase_auth.dart';
import '../utils/constants.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;

  User? get currentUser => _auth.currentUser;
  bool get isLoggedIn => currentUser != null;

  Stream<User?> get authStateChanges => _auth.authStateChanges();

  Future<bool> signInAdmin(String email, String password) async {
    try {
      print('🔐 AuthService: Login attempt started');
      print('🔐 AuthService: Input email="$email", password="$password"');
      print(
        '🔐 AuthService: Expected email="${AppConstants.adminEmail}", password="${AppConstants.adminPassword}"',
      );

      // For demo purposes, check against hardcoded credentials
      final emailMatch =
          email.trim().toLowerCase() == AppConstants.adminEmail.toLowerCase();
      final passwordMatch = password == AppConstants.adminPassword;

      print('🔐 AuthService: Email match: $emailMatch');
      print('🔐 AuthService: Password match: $passwordMatch');
      print(
        '🔐 AuthService: Email comparison: "${email.trim().toLowerCase()}" == "${AppConstants.adminEmail.toLowerCase()}"',
      );
      print(
        '🔐 AuthService: Password comparison: "$password" == "${AppConstants.adminPassword}"',
      );

      if (emailMatch && passwordMatch) {
        print('✅ AuthService: Credentials valid, returning true');
        // Skip Firebase auth temporarily to isolate the issue
        // await _auth.signInAnonymously();
        return true;
      }
      print('❌ AuthService: Credentials invalid, returning false');
      return false;
    } catch (e) {
      print('❌ AuthService: Sign in error: $e');
      return false;
    }
  }

  Future<void> signOut() async {
    try {
      await _auth.signOut();
    } catch (e) {
      print('Sign out error: $e');
    }
  }

  // Initialize admin user for demo (call this once during app setup)
  Future<void> initializeAdminUser() async {
    try {
      // In production, you would create proper admin users through Firebase Console
      // or use Firebase Admin SDK
      print('Admin system initialized');
    } catch (e) {
      print('Admin initialization error: $e');
    }
  }
}
