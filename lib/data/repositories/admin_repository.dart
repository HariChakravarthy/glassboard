import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user_model.dart';
import '../../../core/constants/app_constants.dart';


class AdminRepository {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  Stream<List<UserModel>> watchAllUsers() {
    return _db.collection(AppConstants.usersCollection)
        .orderBy('createdAt', descending: false)
        .snapshots()
        .map((s) => s.docs.map(UserModel.fromFirestore).toList());
  }

  Future<void> updateUserRole(String uid, String role) async {
    await _db.collection(AppConstants.usersCollection).doc(uid).update({'role': role});
  }

  Future<void> assignUserToModule(String uid, String? moduleId) async {
    await _db.collection(AppConstants.usersCollection).doc(uid)
        .update({'moduleId': moduleId});
  }
}
