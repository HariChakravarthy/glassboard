import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/audit_model.dart';
import '../../core/constants/app_constants.dart';

class AuditRepository {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  Stream<List<AuditLogModel>> watchAuditLog({
    String? filterModule,
    String? filterAction,
    DateTime? from,
    DateTime? to,
    int limit = 50,
  }) {
    Query<Map<String, dynamic>> query =
        _db.collection(AppConstants.auditLogCollection)
            .orderBy('timestamp', descending: true)
            .limit(limit);

    if (filterModule != null && filterModule.isNotEmpty) {
      query = query.where('targetModule', isEqualTo: filterModule);
    }
    if (filterAction != null && filterAction.isNotEmpty) {
      query = query.where('action', isEqualTo: filterAction);
    }
    if (from != null) {
      query = query.where('timestamp',
          isGreaterThanOrEqualTo: Timestamp.fromDate(from));
    }
    if (to != null) {
      query = query.where('timestamp',
          isLessThanOrEqualTo: Timestamp.fromDate(to));
    }

    return query.snapshots()
        .map((s) => s.docs.map(AuditLogModel.fromFirestore).toList());
  }

  Future<void> appendLog(AuditLogModel log) async {
    await _db.collection(AppConstants.auditLogCollection).add(log.toMap());
  }

  // ── Notifications ──────────────────────────────────────────────────

  Stream<List<NotificationModel>> watchNotifications(String userId) {
    return _db.collection(AppConstants.notificationsCollection)
        .where('recipientId', isEqualTo: userId)
        .orderBy('createdAt', descending: true)
        .limit(30)
        .snapshots()
        .map((s) => s.docs.map(NotificationModel.fromFirestore).toList());
  }

  Stream<int> watchUnreadCount(String userId) {
    return _db.collection(AppConstants.notificationsCollection)
        .where('recipientId', isEqualTo: userId)
        .where('read', isEqualTo: false)
        .snapshots()
        .map((s) => s.size);
  }

  Future<void> markRead(String notifId) async {
    await _db.collection(AppConstants.notificationsCollection)
        .doc(notifId)
        .update({'read': true});
  }

  Future<void> markAllRead(String userId) async {
    final snap = await _db.collection(AppConstants.notificationsCollection)
        .where('recipientId', isEqualTo: userId)
        .where('read', isEqualTo: false)
        .get();
    final batch = _db.batch();
    for (final doc in snap.docs) {
      batch.update(doc.reference, {'read': true});
    }
    await batch.commit();
  }
}
