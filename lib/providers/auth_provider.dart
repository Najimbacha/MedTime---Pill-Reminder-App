import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/user_profile.dart';
import '../services/auth_service.dart';
import '../services/caregiver_notification_service.dart';

/// State management for authentication
class AuthProvider extends ChangeNotifier {
  final AuthService _authService = AuthService();

  User? _firebaseUser;
  UserProfile? _userProfile;
  bool _isLoading = false;
  String? _error;

  // Getters
  User? get firebaseUser => _firebaseUser;
  UserProfile? get userProfile => _userProfile;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get isSignedIn => _firebaseUser != null;
  bool get isPatient => _userProfile?.isPatient ?? true;
  bool get isCaregiver => _userProfile?.isCaregiver ?? false;
  bool get shareEnabled => _userProfile?.shareEnabled ?? false;

  AuthProvider() {
    // Listen to auth state changes
    _authService.authStateChanges.listen(_onAuthStateChanged);
  }

  void _onAuthStateChanged(User? user) async {
    _firebaseUser = user;

    if (user != null) {
      await _loadUserProfile();
      
      // Initialize notifications and update token
      try {
        final notificationService = CaregiverNotificationService();
        await notificationService.initialize();
        await notificationService.updateToken(user.uid);
      } catch (e) {
        debugPrint('Error initializing notifications: $e');
      }
    } else {
      _userProfile = null;
    }

    notifyListeners();
  }

  Future<void> _loadUserProfile() async {
    try {
      _userProfile = await _authService.getCurrentUserProfile();
    } catch (e) {
      debugPrint('Error loading user profile: $e');
    }
  }

  /// Reload user profile from Firestore
  Future<void> refreshProfile() async {
    await _loadUserProfile();
    notifyListeners();
  }

  /// Sign in with email
  Future<bool> signInWithEmail(String email, String password) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _userProfile = await _authService.signInWithEmail(email, password);
      _isLoading = false;
      notifyListeners();
      return true;
    } on AuthException catch (e) {
      _error = e.message;
      _isLoading = false;
      notifyListeners();
      return false;
    } catch (e) {
      _error = 'An unexpected error occurred';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  /// Create account with email
  Future<bool> createAccount(
    String email,
    String password, {
    String? displayName,
    String role = 'patient',
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _userProfile = await _authService.createAccountWithEmail(
        email,
        password,
        displayName: displayName,
        role: role,
      );
      _isLoading = false;
      notifyListeners();
      return true;
    } on AuthException catch (e) {
      _error = e.message;
      _isLoading = false;
      notifyListeners();
      return false;
    } catch (e) {
      _error = 'An unexpected error occurred';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  /// Sign in anonymously
  Future<bool> signInAnonymously() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _userProfile = await _authService.signInAnonymously();
      _isLoading = false;
      notifyListeners();
      return true;
    } on AuthException catch (e) {
      _error = e.message;
      _isLoading = false;
      notifyListeners();
      return false;
    } catch (e) {
      _error = 'An unexpected error occurred';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  /// Sign in with Google
  Future<bool> signInWithGoogle() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _userProfile = await _authService.signInWithGoogle();
      _isLoading = false;
      notifyListeners();
      return _userProfile != null; // Returns false if user cancelled
    } on AuthException catch (e) {
      _error = e.message;
      _isLoading = false;
      notifyListeners();
      return false;
    } catch (e) {
      _error = 'Google Sign-In failed: $e';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  /// Sign out
  Future<void> signOut() async {
    await _authService.signOut();
    _userProfile = null;
    notifyListeners();
  }

  /// Toggle sharing
  Future<void> setShareEnabled(bool enabled) async {
    if (_userProfile == null) return;

    try {
      await _authService.setShareEnabled(enabled);
      _userProfile = _userProfile!.copyWith(shareEnabled: enabled);
      notifyListeners();
    } catch (e) {
      debugPrint('Error updating share enabled: $e');
    }
  }

  /// Update FCM token
  Future<void> updateFcmToken(String token) async {
    if (!isSignedIn) return;

    try {
      await _authService.updateFcmToken(token);
      if (_userProfile != null) {
        _userProfile = _userProfile!.copyWith(fcmToken: token);
      }
    } catch (e) {
      debugPrint('Error updating FCM token: $e');
    }
  }

  /// Get linked caregivers
  Future<List<UserProfile>> getLinkedCaregivers() async {
    return await _authService.getLinkedCaregivers();
  }

  /// Get linked patients (for caregiver mode)
  Future<List<UserProfile>> getLinkedPatients() async {
    return await _authService.getLinkedPatients();
  }

  /// Delete account permanently
  Future<bool> deleteAccount() async {
    if (_firebaseUser == null) return false;

    _isLoading = true;
    notifyListeners();

    try {
      // 1. Delete from AuthService (Firebase Auth + Firestore)
      await _authService.deleteAccount();
      
      // 2. Clear local state
      _firebaseUser = null;
      _userProfile = null;
      
      _isLoading = false;
      notifyListeners();
      return true;
    } on AuthException catch (e) {
      _error = e.message;
      _isLoading = false;
      notifyListeners();
      return false; 
    } catch (e) {
      _error = 'Failed to delete account. Please log in again and try.';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  /// Clear error
  void clearError() {
    _error = null;
    notifyListeners();
  }
}
