import 'dart:math';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../models/user_profile.dart';
import '../models/caregiver_invite.dart';

/// Service for Firebase Authentication and user management
class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn();

  // Singleton pattern
  static final AuthService _instance = AuthService._internal();
  factory AuthService() => _instance;
  AuthService._internal();

  /// Get current Firebase user
  User? get currentUser => _auth.currentUser;

  /// Check if user is signed in
  bool get isSignedIn => currentUser != null;

  /// Stream of auth state changes
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  /// Get current user profile from Firestore
  Future<UserProfile?> getCurrentUserProfile() async {
    final user = currentUser;
    if (user == null) return null;

    final doc = await _firestore.collection('users').doc(user.uid).get();
    if (!doc.exists) return null;

    return UserProfile.fromFirestore(doc);
  }

  /// Sign in with email and password
  Future<UserProfile?> signInWithEmail(String email, String password) async {
    try {
      final credential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      if (credential.user != null) {
        return await _getOrCreateUserProfile(credential.user!);
      }
    } on FirebaseAuthException catch (e) {
      throw AuthException(_mapFirebaseAuthError(e.code));
    }
    return null;
  }

  /// Create account with email and password
  Future<UserProfile?> createAccountWithEmail(
    String email,
    String password, {
    String? displayName,
    String role = 'patient',
  }) async {
    try {
      final credential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      if (credential.user != null) {
        if (displayName != null) {
          await credential.user!.updateDisplayName(displayName);
        }

        // Create user profile in Firestore
        final profile = UserProfile(
          id: credential.user!.uid,
          email: email,
          displayName: displayName,
          role: role,
          shareEnabled: false,
        );

        await _firestore.collection('users').doc(profile.id).set(profile.toMap());
        return profile;
      }
    } on FirebaseAuthException catch (e) {
      throw AuthException(_mapFirebaseAuthError(e.code));
    }
    return null;
  }

  /// Sign in anonymously (for privacy-focused users)
  Future<UserProfile?> signInAnonymously() async {
    try {
      final credential = await _auth.signInAnonymously();

      if (credential.user != null) {
        return await _getOrCreateUserProfile(credential.user!);
      }
    } on FirebaseAuthException catch (e) {
      throw AuthException(_mapFirebaseAuthError(e.code));
    }
    return null;
  }

  /// Sign in with Google
  Future<UserProfile?> signInWithGoogle() async {
    try {
      // Trigger the Google Sign-In flow
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      
      if (googleUser == null) {
        // User cancelled the sign-in
        return null;
      }

      // Obtain the auth details from the request
      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;

      // Create a new credential
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      // Sign in to Firebase with the Google credential
      final userCredential = await _auth.signInWithCredential(credential);

      if (userCredential.user != null) {
        return await _getOrCreateUserProfile(userCredential.user!);
      }
    } on FirebaseAuthException catch (e) {
      throw AuthException(_mapFirebaseAuthError(e.code));
    } catch (e) {
      throw AuthException('Google Sign-In failed: $e');
    }
    return null;
  }

  /// Sign out
  Future<void> signOut() async {
    await _googleSignIn.signOut();
    await _auth.signOut();
  }

  /// Get or create user profile
  Future<UserProfile> _getOrCreateUserProfile(User user) async {
    final doc = await _firestore.collection('users').doc(user.uid).get();

    if (doc.exists) {
      return UserProfile.fromFirestore(doc);
    }

    // Create new profile
    final profile = UserProfile(
      id: user.uid,
      email: user.email,
      displayName: user.displayName,
      role: 'patient',
      shareEnabled: false,
    );

    await _firestore.collection('users').doc(profile.id).set(profile.toMap());
    return profile;
  }

  /// Update user profile
  Future<void> updateUserProfile(UserProfile profile) async {
    await _firestore.collection('users').doc(profile.id).update({
      ...profile.toMap(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  /// Update FCM token for push notifications
  Future<void> updateFcmToken(String token) async {
    final user = currentUser;
    if (user == null) return;

    await _firestore.collection('users').doc(user.uid).update({
      'fcmToken': token,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  /// Toggle sharing enabled
  Future<void> setShareEnabled(bool enabled) async {
    final user = currentUser;
    if (user == null) return;

    await _firestore.collection('users').doc(user.uid).update({
      'shareEnabled': enabled,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  // ==================== INVITE MANAGEMENT ====================

  /// Generate a unique 6-digit invite code
  Future<CaregiverInvite> generateInviteCode({String? patientName}) async {
    final user = currentUser;
    if (user == null) throw AuthException('Not signed in');

    // Generate random 6-digit code
    final random = Random();
    String code;
    bool exists = true;

    // Ensure unique code
    do {
      code = (100000 + random.nextInt(900000)).toString();
      final doc = await _firestore.collection('invites').doc(code).get();
      exists = doc.exists;
    } while (exists);

    final invite = CaregiverInvite(
      code: code,
      patientId: user.uid,
      patientName: patientName,
      expiresAt: DateTime.now().add(const Duration(hours: 24)),
    );

    await _firestore.collection('invites').doc(code).set(invite.toMap());
    return invite;
  }

  /// Validate and accept an invite code
  Future<CaregiverInvite?> acceptInviteCode(String code) async {
    final user = currentUser;
    if (user == null) throw AuthException('Not signed in');

    final doc = await _firestore.collection('invites').doc(code).get();
    if (!doc.exists) throw AuthException('Invalid invite code');

    final invite = CaregiverInvite.fromFirestore(doc);

    if (invite.isExpired) {
      throw AuthException('Invite code has expired');
    }

    if (invite.isAccepted) {
      throw AuthException('Invite code has already been used');
    }

    if (invite.patientId == user.uid) {
      throw AuthException('You cannot accept your own invite');
    }

    // Update invite status
    await _firestore.collection('invites').doc(code).update({
      'status': 'accepted',
    });

    // Link patient and caregiver
    await _linkPatientAndCaregiver(invite.patientId, user.uid);

    return invite.copyWith(status: 'accepted');
  }

  /// Link a patient and caregiver bidirectionally
  Future<void> _linkPatientAndCaregiver(String patientId, String caregiverId) async {
    final batch = _firestore.batch();

    // Add caregiver to patient's list
    batch.update(_firestore.collection('users').doc(patientId), {
      'linkedCaregiverIds': FieldValue.arrayUnion([caregiverId]),
      'updatedAt': FieldValue.serverTimestamp(),
    });

    // Add patient to caregiver's list and set role to include caregiver
    batch.update(_firestore.collection('users').doc(caregiverId), {
      'linkedPatientIds': FieldValue.arrayUnion([patientId]),
      'role': 'both', // Enable caregiver mode
      'updatedAt': FieldValue.serverTimestamp(),
    });

    await batch.commit();
  }

  /// Unlink a caregiver from patient
  Future<void> unlinkCaregiver(String caregiverId) async {
    final user = currentUser;
    if (user == null) throw AuthException('Not signed in');

    final batch = _firestore.batch();

    // Remove caregiver from patient's list
    batch.update(_firestore.collection('users').doc(user.uid), {
      'linkedCaregiverIds': FieldValue.arrayRemove([caregiverId]),
      'updatedAt': FieldValue.serverTimestamp(),
    });

    // Remove patient from caregiver's list
    batch.update(_firestore.collection('users').doc(caregiverId), {
      'linkedPatientIds': FieldValue.arrayRemove([user.uid]),
      'updatedAt': FieldValue.serverTimestamp(),
    });

    await batch.commit();
  }

  /// Get list of linked caregivers for current patient
  Future<List<UserProfile>> getLinkedCaregivers() async {
    final user = currentUser;
    if (user == null) return [];

    final profile = await getCurrentUserProfile();
    if (profile == null || profile.linkedCaregiverIds.isEmpty) return [];

    final caregivers = <UserProfile>[];
    for (final id in profile.linkedCaregiverIds) {
      final doc = await _firestore.collection('users').doc(id).get();
      if (doc.exists) {
        caregivers.add(UserProfile.fromFirestore(doc));
      }
    }

    return caregivers;
  }

  /// Get list of linked patients for current caregiver
  Future<List<UserProfile>> getLinkedPatients() async {
    final user = currentUser;
    if (user == null) return [];

    final profile = await getCurrentUserProfile();
    if (profile == null || profile.linkedPatientIds.isEmpty) return [];

    final patients = <UserProfile>[];
    for (final id in profile.linkedPatientIds) {
      final doc = await _firestore.collection('users').doc(id).get();
      if (doc.exists) {
        patients.add(UserProfile.fromFirestore(doc));
      }
    }

    return patients;
  }

  /// Map Firebase auth error codes to friendly messages
  String _mapFirebaseAuthError(String code) {
    switch (code) {
      case 'user-not-found':
        return 'No account found with this email';
      case 'wrong-password':
        return 'Incorrect password';
      case 'email-already-in-use':
        return 'An account already exists with this email';
      case 'weak-password':
        return 'Password is too weak';
      case 'invalid-email':
        return 'Invalid email address';
      case 'too-many-requests':
        return 'Too many attempts. Please try again later';
      default:
        return 'Authentication error: $code';
    }
  }
}

/// Custom exception for auth errors
class AuthException implements Exception {
  final String message;
  AuthException(this.message);

  @override
  String toString() => message;
}
