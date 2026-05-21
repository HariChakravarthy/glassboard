import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user_model.dart';
import '../../../core/constants/app_constants.dart';
import '../../core/utils/firestore_retry.dart';


class AdminRepository {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  Stream<List<UserModel>> watchAllUsers(String orgId) {
    if (orgId.isEmpty) return Stream.value([]);
    return retryOnPermissionDenied(() {
      return _db.collection(AppConstants.usersCollection)
          .where('orgId', isEqualTo: orgId)
          .snapshots()
          .map((s) {
            final list = s.docs.map(UserModel.fromFirestore).toList();
            list.sort((a, b) => a.createdAt.compareTo(b.createdAt));
            return list;
          });
    });
  }

  Future<void> updateUserRole(String uid, String role) async {
    await _db.collection(AppConstants.usersCollection).doc(uid).update({'role': role});
  }

  Future<void> assignUserToModule(String uid, String? moduleId) async {
    await _db.collection(AppConstants.usersCollection).doc(uid)
        .update({'moduleId': moduleId});
  }
}
