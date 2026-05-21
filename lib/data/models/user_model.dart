import 'package:cloud_firestore/cloud_firestore.dart';
import '../../core/constants/app_constants.dart';

class UserModel {
  final String uid;
  final String name;
  final String email;
  final String role;
  final String orgId;
  final String? moduleId;
  final String? fcmToken;
  final String? photoUrl;
  final String? techRole;   // e.g. "Web Frontend", "ML Engineer"
  final DateTime createdAt;

  const UserModel({
    required this.uid,
    required this.name,
    required this.email,
    required this.role,
    required this.orgId,
    this.moduleId,
    this.fcmToken,
    this.photoUrl,
    this.techRole,
    required this.createdAt,
  });

  bool get isMember    => role == AppConstants.roleMember;
  bool get isLead      => role == AppConstants.roleModuleLead;
  bool get isOrgAdmin  => role == AppConstants.roleOrgAdmin;

  factory UserModel.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return UserModel(
      uid:       doc.id,
      name:      d['name'] ?? '',
      email:     d['email'] ?? '',
      role:      d['role'] ?? AppConstants.roleMember,
      orgId:     d['orgId'] ?? '',
      moduleId:  d['moduleId'],
      fcmToken:  d['fcmToken'],
      photoUrl:  d['photoUrl'],
      techRole:  d['techRole'],
      createdAt: (d['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() => {
    'uid':       uid,
    'name':      name,
    'email':     email,
    'role':      role,
    'orgId':     orgId,
    'moduleId':  moduleId,
    'fcmToken':  fcmToken,
    'photoUrl':  photoUrl,
    'techRole':  techRole,
    'createdAt': Timestamp.fromDate(createdAt),
  };

  UserModel copyWith({
    String? name, String? role, String? orgId, String? moduleId,
    String? fcmToken, String? photoUrl, String? techRole,
  }) =>
    UserModel(
      uid:       uid,
      name:      name ?? this.name,
      email:     email,
      role:      role ?? this.role,
      orgId:     orgId ?? this.orgId,
      moduleId:  moduleId ?? this.moduleId,
      fcmToken:  fcmToken ?? this.fcmToken,
      photoUrl:  photoUrl ?? this.photoUrl,
      techRole:  techRole ?? this.techRole,
      createdAt: createdAt,
    );
}
