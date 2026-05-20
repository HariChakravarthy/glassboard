import 'package:cloud_firestore/cloud_firestore.dart';

class AuditLogModel {
  final String id;
  final String actorId;
  final String actorName;
  final String action;
  final String targetModule;
  final String orgId;
  final Map<String, dynamic> metadata;
  final DateTime timestamp;

  const AuditLogModel({
    required this.id,
    required this.actorId,
    required this.actorName,
    required this.action,
    required this.targetModule,
    required this.orgId,
    required this.metadata,
    required this.timestamp,
  });

  factory AuditLogModel.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return AuditLogModel(
      id:           doc.id,
      actorId:      d['actorId'] ?? '',
      actorName:    d['actorName'] ?? '',
      action:       d['action'] ?? '',
      targetModule: d['targetModule'] ?? '',
      orgId:        d['orgId'] ?? '',
      metadata:     Map<String, dynamic>.from(d['metadata'] ?? {}),
      timestamp:    (d['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() => {
    'actorId':      actorId,
    'actorName':    actorName,
    'action':       action,
    'targetModule': targetModule,
    'orgId':        orgId,
    'metadata':     metadata,
    'timestamp':    Timestamp.fromDate(timestamp),
  };
}

class NotificationModel {
  final String id;
  final String recipientId;
  final String type;
  final String message;
  final String orgId;
  final bool read;
  final DateTime createdAt;
  final String? relatedId;

  const NotificationModel({
    required this.id,
    required this.recipientId,
    required this.type,
    required this.message,
    required this.orgId,
    required this.read,
    required this.createdAt,
    this.relatedId,
  });

  factory NotificationModel.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return NotificationModel(
      id:          doc.id,
      recipientId: d['recipientId'] ?? '',
      type:        d['type'] ?? '',
      message:     d['message'] ?? '',
      orgId:       d['orgId'] ?? '',
      read:        d['read'] ?? false,
      createdAt:   (d['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      relatedId:   d['relatedId'],
    );
  }

  Map<String, dynamic> toMap() => {
    'recipientId': recipientId,
    'type':        type,
    'message':     message,
    'orgId':       orgId,
    'read':        read,
    'createdAt':   Timestamp.fromDate(createdAt),
    'relatedId':   relatedId,
  };
}
