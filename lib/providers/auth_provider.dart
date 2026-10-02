import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/account_type.dart';
import '../models/user_model.dart';

class AuthProvider extends ChangeNotifier {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  UserModel? _userModel;
  bool _isLoading = false;
  bool _isInitialized = false;

  AuthProvider() {
    _checkCurrentUser();
  }

  UserModel? get user => _userModel;
  bool get isLoading => _isLoading;
  bool get isLoggedIn => _userModel != null;
  bool get isInitialized => _isInitialized;

  // ─── On App Start ─────────────────────────────────────────────────────────

  Future<void> _checkCurrentUser() async {
    final firebaseUser = _auth.currentUser;
    if (firebaseUser != null) {
      await _loadUserFromFirestore(firebaseUser.uid);
    }
    _isInitialized = true;
    notifyListeners();
  }

  // ─── Load Full User Profile from Firestore ────────────────────────────────

  Future<void> _loadUserFromFirestore(String uid) async {
    try {
      final doc = await _db.collection('users').doc(uid).get();

      if (doc.exists && doc.data() != null) {
        // Full profile exists in Firestore — load it
        _userModel = UserModel.fromFirestore(doc.data()!, doc.id);
        debugPrint('✅ User loaded from Firestore: ${_userModel!.name}');
      } else {
        // No Firestore doc yet — fall back to Firebase Auth data
        final firebaseUser = _auth.currentUser!;
        _userModel = UserModel(
          id: firebaseUser.uid,
          email: firebaseUser.email ?? '',
          name: firebaseUser.displayName ?? 'User',
          role: 'citizen',
          joinedAt: firebaseUser.metadata.creationTime ?? DateTime.now(),
        );

        debugPrint('⚠️ No Firestore user doc — using Auth fallback');
      }
    } catch (e) {
      debugPrint('❌ _loadUserFromFirestore error: $e');
      // Still set a minimal user so the app doesn't get stuck
      final firebaseUser = _auth.currentUser;
      if (firebaseUser != null) {
        _userModel = UserModel(
          id: firebaseUser.uid,
          email: firebaseUser.email ?? '',
          name: firebaseUser.displayName ?? 'User',
          role: 'citizen',
          joinedAt: firebaseUser.metadata.creationTime ?? DateTime.now(),
        );
      }
    }
  }

  // ─── Login ────────────────────────────────────────────────────────────────

  Future<void> login(String email, String password) async {
    _isLoading = true;
    notifyListeners();

    try {
      final credential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      await _loadUserFromFirestore(credential.user!.uid);
      debugPrint('✅ Login successful: ${credential.user!.uid}');
    } catch (e) {
      _userModel = null;
      debugPrint('❌ Login error: $e');
      rethrow;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // ─── Register ─────────────────────────────────────────────────────────────

  Future<void> register(Map<String, dynamic> data) async {
    _isLoading = true;
    notifyListeners();

    try {
      final credential = await _auth.createUserWithEmailAndPassword(
        email: data['email'],
        password: data['password'],
      );

      final uid = credential.user!.uid;

      // Update display name in Firebase Auth
      await credential.user!.updateDisplayName(data['name']);

      // Build the user model
      _userModel = UserModel(
        id: uid,
        email: data['email'],
        name: data['name'] ?? 'New User',
        role: data['role'] ?? data['accountType'] ?? 'citizen',
        accountType: AccountType.fromStoredValue(
          data['accountType'] ?? data['role'],
        ),
        contactPerson: data['contactPerson'],
        phoneNumber: data['phoneNumber'],
        completeAddress: data['completeAddress'],
        joinedAt: DateTime.now(),
      );

      // Save full profile to Firestore
      await _db.collection('users').doc(uid).set(_userModel!.toFirestore());
      debugPrint('✅ User registered and saved to Firestore: $uid');
    } catch (e) {
      _userModel = null;
      debugPrint('❌ Register error: $e');
      rethrow;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // ─── Reload Profile ───────────────────────────────────────────────────────

  Future<void> reloadUser() async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;
    await _loadUserFromFirestore(uid);
    notifyListeners();
  }

  Future<void> updatePrivacySettings({
    bool? isPublic,
    bool? allowNotifs,
  }) async {
    if (user == null) return;

    await FirebaseFirestore.instance.collection('users').doc(user!.id).update({
      if (isPublic != null) 'isProfilePublic': isPublic,
      if (allowNotifs != null) 'allowNotifications': allowNotifs,
    });

    await reloadUser(); // Refresh local state
  }
  // ─── Logout ───────────────────────────────────────────────────────────────

  Future<void> logout() async {
    await _auth.signOut();
    _userModel = null;
    notifyListeners();
  }
}
