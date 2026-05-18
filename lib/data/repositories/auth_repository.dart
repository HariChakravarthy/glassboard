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

  /// Register with email / password, creates Firestore profile
  Future<UserModel> registerWithEmail({
    required String name,
    required String email,
    required String password,
    String role = AppConstants.roleMember,
  }) async {
    final cred = await _auth.createUserWithEmailAndPassword(
      email: email, password: password);
    await cred.user!.updateDisplayName(name);

    final user = UserModel(
      uid:       cred.user!.uid,
      name:      name,
      email:     email,
      role:      role,
      createdAt: DateTime.now(),
    );
    await _db.collection(AppConstants.usersCollection)
        .doc(user.uid)
        .set(user.toMap());
    return user;
  }

  /// Google Sign-In
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
}
