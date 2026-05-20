import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../models/user_model.dart';
import '../../core/constants/app_constants.dart';

class AuthRepository {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn();

  Stream<User?> get authStateChanges => _auth.authStateChanges();

  User? get currentUser => _auth.currentUser;

  /// Email / password sign in
  Future<UserModel> signInWithEmail(String email, String password) async {
    final cred = await _auth.signInWithEmailAndPassword(
      email: email, password: password);
    return _fetchUser(cred.user!.uid);
  }

  String _generateInviteCode() {
    final rand = Random();
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    return List.generate(6, (i) => chars[rand.nextInt(chars.length)]).join();
  }

  Future<String> _getUniqueInviteCode() async {
    while (true) {
      final code = _generateInviteCode();
      final snap = await _db.collection('organizations')
          .where('inviteCode', isEqualTo: code)
          .limit(1)
          .get();
      if (snap.docs.isEmpty) return code;
    }
  }

  /// Register with email / password, creates Firestore profile & organization
  Future<UserModel> registerWithEmail({
    required String name,
    required String email,
    required String password,
    required String role,
    String? orgName,
    String? inviteCode,
  }) async {
    String finalOrgId = '';
    String? orgCode;

    if (role == AppConstants.roleOrgAdmin) {
      if (orgName == null || orgName.trim().isEmpty) {
        throw Exception('Organization name is required for admins');
      }
      orgCode = await _getUniqueInviteCode();
      final orgRef = _db.collection('organizations').doc();
      finalOrgId = orgRef.id;
    } else {
      if (inviteCode == null || inviteCode.trim().isEmpty) {
        throw Exception('Invite code is required to join an organization');
      }
      final codeUpper = inviteCode.trim().toUpperCase();
      final orgSnap = await _db.collection('organizations')
          .where('inviteCode', isEqualTo: codeUpper)
          .limit(1)
          .get();
      if (orgSnap.docs.isEmpty) {
        throw Exception('Invalid invite code. Please verify with your admin.');
      }
      finalOrgId = orgSnap.docs.first.id;
    }

    // 1. Create Auth credential (this automatically signs the user in)
    final cred = await _auth.createUserWithEmailAndPassword(
      email: email, password: password);
    await cred.user!.updateDisplayName(name);

    final uid = cred.user!.uid;

    // 2. Create user document first so that rules calling getUserData() can retrieve this profile
    final user = UserModel(
      uid:       uid,
      name:      name,
      email:     email,
      role:      role,
      orgId:     finalOrgId,
      createdAt: DateTime.now(),
    );
    await _db.collection(AppConstants.usersCollection)
        .doc(uid)
        .set(user.toMap());

    // 3. Create organization document (only for admins)
    if (role == AppConstants.roleOrgAdmin) {
      await _db.collection('organizations').doc(finalOrgId).set({
        'name':       orgName!.trim(),
        'inviteCode': orgCode,
        'createdAt':  FieldValue.serverTimestamp(),
        'createdBy':  uid,
      });
    }

    return user;
  }

  /// Google Sign-In (with fallback empty orgId)
  Future<UserModel> signInWithGoogle() async {
    final googleUser = await _googleSignIn.signIn();
    if (googleUser == null) throw Exception('Google sign-in cancelled');
    final googleAuth = await googleUser.authentication;
    final credential = GoogleAuthProvider.credential(
      accessToken: googleAuth.accessToken,
      idToken:     googleAuth.idToken,
    );
    final cred = await _auth.signInWithCredential(credential);
    final uid = cred.user!.uid;
    final docRef = _db.collection(AppConstants.usersCollection).doc(uid);
    final snap = await docRef.get();
    if (!snap.exists) {
      final user = UserModel(
        uid:       uid,
        name:      cred.user!.displayName ?? googleUser.displayName ?? '',
        email:     cred.user!.email ?? '',
        role:      AppConstants.roleMember,
        orgId:     '', // Google Sign-in sandbox
        photoUrl:  cred.user!.photoURL,
        createdAt: DateTime.now(),
      );
      await docRef.set(user.toMap());
      return user;
    }
    return UserModel.fromFirestore(snap);
  }

  Future<void> signOut() async {
    await Future.wait([_auth.signOut(), _googleSignIn.signOut()]);
  }

  Future<UserModel> fetchCurrentUser() async {
    return _fetchUser(_auth.currentUser!.uid);
  }

  Future<UserModel> _fetchUser(String uid) async {
    final snap = await _db.collection(AppConstants.usersCollection).doc(uid).get();
    if (!snap.exists) throw Exception('User profile not found');
    return UserModel.fromFirestore(snap);
  }

  Stream<UserModel?> watchUser(String uid) {
    return _db.collection(AppConstants.usersCollection)
        .doc(uid)
        .snapshots()
        .map((s) => s.exists ? UserModel.fromFirestore(s) : null);
  }

  Future<void> updateFcmToken(String uid, String token) async {
    await _db.collection(AppConstants.usersCollection)
        .doc(uid)
        .update({'fcmToken': token});
  }

  Future<Map<String, dynamic>?> getOrganization(String orgId) async {
    if (orgId.isEmpty) return null;
    final snap = await _db.collection('organizations').doc(orgId).get();
    return snap.data();
  }
}
