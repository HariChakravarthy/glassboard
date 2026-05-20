import 'package:cloud_firestore/cloud_firestore.dart';

class OrganizationModel {
  final String id;
  final String name;
  final String inviteCode;
  final DateTime createdAt;
  final String createdBy;

  const OrganizationModel({
    required this.id,
    required this.name,
    required this.inviteCode,
    required this.createdAt,
    required this.createdBy,
  });

  factory OrganizationModel.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return OrganizationModel(
      id:         doc.id,
      name:       d['name'] ?? '',
      inviteCode: d['inviteCode'] ?? '',
      createdAt:  (d['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      createdBy:  d['createdBy'] ?? '',
    );
  }

  Map<String, dynamic> toMap() => {
    'name':       name,
    'inviteCode': inviteCode,
    'createdAt':  Timestamp.fromDate(createdAt),
    'createdBy':  createdBy,
  };
}
