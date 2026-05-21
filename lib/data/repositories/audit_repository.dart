import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/audit_model.dart';
import '../../core/constants/app_constants.dart';
import '../../core/utils/firestore_retry.dart';

class AuditRepository {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  Stream<List<AuditLogModel>> watchAuditLog(
    String orgId, {
    String? filterModule,
    String? filterAction,
    DateTime? from,
    DateTime? to,
    int limit = 50,
  }) {
    if (orgId.isEmpty) return Stream.value([]);
    return retryOnPermissionDenied(() {
      return _db.collection(AppConstants.auditLogCollection)
          .where('orgId', isEqualTo: orgId)
          .snapshots()
          .map((s) {
            var list = s.docs.map(AuditLogModel.fromFirestore).toList();

            if (filterModule != null && filterModule.isNotEmpty) {
              list = list.where((l) => l.targetModule == filterModule).toList();
            }
            if (filterAction != null && filterAction.isNotEmpty) {
              list = list.where((l) => l.action == filterAction).toList();
            }
            if (from != null) {
              list = list.where((l) => l.timestamp.isAfter(from) || l.timestamp.isAtSameMomentAs(from)).toList();
            }
            if (to != null) {
              list = list.where((l) => l.timestamp.isBefore(to) || l.timestamp.isAtSameMomentAs(to)).toList();
            }

            list.sort((a, b) => b.timestamp.compareTo(a.timestamp));
            if (list.length > limit) {
              list = list.sublist(0, limit);
            }
            return list;
          });
    });
  }

  Future<void> appendLog(AuditLogModel log) async {
    await _db.collection(AppConstants.auditLogCollection).add(log.toMap());
  }

  // ── Notifications ──────────────────────────────────────────────────

  Stream<List<NotificationModel>> watchNotifications(String userId) {
    return retryOnPermissionDenied(() {
      return _db.collection(AppConstants.notificationsCollection)
          .where('recipientId', isEqualTo: userId)
          .orderBy('createdAt', descending: true)
          .limit(30)
          .snapshots()
          .map((s) => s.docs.map(NotificationModel.fromFirestore).toList());
    });
  }

  Stream<int> watchUnreadCount(String userId) {
    return retryOnPermissionDenied(() {
      return _db.collection(AppConstants.notificationsCollection)
          .where('recipientId', isEqualTo: userId)
          .where('read', isEqualTo: false)
          .snapshots()
          .map((s) => s.size);
    });
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
