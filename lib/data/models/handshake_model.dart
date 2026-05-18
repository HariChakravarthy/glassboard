import 'package:cloud_firestore/cloud_firestore.dart';
import '../../core/constants/app_constants.dart';

class HandshakeModel {
  final String id;
  final String fromModule;
  final String fromModuleName;
  final String toModule;
  final String toModuleName;
  final String status;
  final String? proofUrl;
  final String? proofNote;
  final String? proofType;   // 'photo' | 'document' | 'text'
  final String initiatedBy;
  final DateTime timestamp;
  final DateTime? respondedAt;
  final String? rejectionReason;
  final String? respondedBy;

  const HandshakeModel({
    required this.id,
    required this.fromModule,
    required this.fromModuleName,
    required this.toModule,
    required this.toModuleName,
    required this.status,
    this.proofUrl,
    this.proofNote,
    this.proofType,
    required this.initiatedBy,
    required this.timestamp,
    this.respondedAt,
    this.rejectionReason,
    this.respondedBy,
  });

  bool get isPending  => status == AppConstants.handshakePending;
  bool get isAccepted => status == AppConstants.handshakeAccepted;
  bool get isRejected => status == AppConstants.handshakeRejected;

  factory HandshakeModel.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return HandshakeModel(
      id:              doc.id,
      fromModule:      d['fromModule'] ?? '',
      fromModuleName:  d['fromModuleName'] ?? '',
      toModule:        d['toModule'] ?? '',
      toModuleName:    d['toModuleName'] ?? '',
      status:          d['status'] ?? AppConstants.handshakePending,
      proofUrl:        d['proofUrl'],
      proofNote:       d['proofNote'],
      proofType:       d['proofType'],
      initiatedBy:     d['initiatedBy'] ?? '',
      timestamp:       (d['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now(),
      respondedAt:     (d['respondedAt'] as Timestamp?)?.toDate(),
      rejectionReason: d['rejectionReason'],
      respondedBy:     d['respondedBy'],
    );
  }

  Map<String, dynamic> toMap() => {
    'fromModule':      fromModule,
    'fromModuleName':  fromModuleName,
    'toModule':        toModule,
    'toModuleName':    toModuleName,
    'status':          status,
    'proofUrl':        proofUrl,
    'proofNote':       proofNote,
    'proofType':       proofType,
    'initiatedBy':     initiatedBy,
    'timestamp':       Timestamp.fromDate(timestamp),
    'respondedAt':     respondedAt != null ? Timestamp.fromDate(respondedAt!) : null,
    'rejectionReason': rejectionReason,
    'respondedBy':     respondedBy,
  };
}
