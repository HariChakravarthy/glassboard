import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/handshake_model.dart';
import '../models/audit_model.dart';
import '../../core/constants/app_constants.dart';

class HandshakeRepository {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // ── Initiate ───────────────────────────────────────────────────────

  Future<String> initiateHandshake(HandshakeModel handshake) async {
    final batch = _db.batch();
    final hRef = _db.collection(AppConstants.handshakesCollection).doc();
    batch.set(hRef, handshake.toMap());

    // Append to audit log
    final aRef = _db.collection(AppConstants.auditLogCollection).doc();
    batch.set(aRef, AuditLogModel(
      id:           aRef.id,
      actorId:      handshake.initiatedBy,
      actorName:    '',
      action:       'HANDSHAKE_INITIATED',
      targetModule: handshake.toModule,
      metadata:     {'fromModule': handshake.fromModule, 'handshakeId': hRef.id},
      timestamp:    DateTime.now(),
    ).toMap());

    await batch.commit();
    return hRef.id;
  }

  // ── Respond ────────────────────────────────────────────────────────

  Future<void> acceptHandshake(
      String handshakeId, String responderId, String responderName) async {
    final hSnap = await _db.collection(AppConstants.handshakesCollection).doc(handshakeId).get();
    if (!hSnap.exists) throw Exception('Handshake not found');
    final fromModuleId = hSnap.data()?['fromModule'] as String?;

    final batch = _db.batch();

    final hRef = _db.collection(AppConstants.handshakesCollection).doc(handshakeId);
    batch.update(hRef, {
      'status':      AppConstants.handshakeAccepted,
      'respondedAt': Timestamp.now(),
      'respondedBy': responderId,
    });

    if (fromModuleId != null) {
      batch.update(_db.collection(AppConstants.modulesCollection).doc(fromModuleId), {
        'status': AppConstants.statusComplete,
      });
    }

    final aRef = _db.collection(AppConstants.auditLogCollection).doc();
    batch.set(aRef, {
      'actorId':      responderId,
      'actorName':    responderName,
      'action':       'HANDSHAKE_ACCEPTED',
      'targetModule': '',
      'metadata':     {'handshakeId': handshakeId},
      'timestamp':    Timestamp.now(),
    });

    await batch.commit();
  }

  Future<void> rejectHandshake(
      String handshakeId, String responderId, String responderName,
      String rejectionReason) async {
    final hSnap = await _db.collection(AppConstants.handshakesCollection).doc(handshakeId).get();
    if (!hSnap.exists) throw Exception('Handshake not found');
    final fromModuleId = hSnap.data()?['fromModule'] as String?;

    final batch = _db.batch();

    final hRef = _db.collection(AppConstants.handshakesCollection).doc(handshakeId);
    batch.update(hRef, {
      'status':          AppConstants.handshakeRejected,
      'respondedAt':     Timestamp.now(),
      'respondedBy':     responderId,
      'rejectionReason': rejectionReason,
    });

    if (fromModuleId != null) {
      batch.update(_db.collection(AppConstants.modulesCollection).doc(fromModuleId), {
        'status': AppConstants.statusInProgress,
      });
    }

    final aRef = _db.collection(AppConstants.auditLogCollection).doc();
    batch.set(aRef, {
      'actorId':      responderId,
      'actorName':    responderName,
      'action':       'HANDSHAKE_REJECTED',
      'targetModule': '',
      'metadata':     {'handshakeId': handshakeId, 'reason': rejectionReason},
      'timestamp':    Timestamp.now(),
    });

    await batch.commit();
  }

  // ── Streams ────────────────────────────────────────────────────────

  Stream<List<HandshakeModel>> watchIncomingHandshakes(String moduleId) {
    return _db.collection(AppConstants.handshakesCollection)
        .where('toModule', isEqualTo: moduleId)
        .where('status', isEqualTo: AppConstants.handshakePending)
        .orderBy('timestamp', descending: true)
        .snapshots()
        .map((s) => s.docs.map(HandshakeModel.fromFirestore).toList());
  }

  Stream<List<HandshakeModel>> watchModuleHandshakes(String moduleId) {
    // All handshakes sent OR received by this module
    return _db.collection(AppConstants.handshakesCollection)
        .where(Filter.or(
          Filter('fromModule', isEqualTo: moduleId),
          Filter('toModule', isEqualTo: moduleId),
        ))
        .orderBy('timestamp', descending: true)
        .snapshots()
        .map((s) => s.docs.map(HandshakeModel.fromFirestore).toList());
  }

  Stream<List<HandshakeModel>> watchAllHandshakes() {
    return _db.collection(AppConstants.handshakesCollection)
        .orderBy('timestamp', descending: true)
        .snapshots()
        .map((s) => s.docs.map(HandshakeModel.fromFirestore).toList());
  }

  Future<HandshakeModel> getHandshake(String id) async {
    final snap = await _db.collection(AppConstants.handshakesCollection).doc(id).get();
    if (!snap.exists) throw Exception('Handshake not found');
    return HandshakeModel.fromFirestore(snap);
  }
}
