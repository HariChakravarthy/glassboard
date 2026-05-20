import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'dart:io';
import '../models/file_model.dart';

import '../../core/constants/app_constants.dart';

class FileRepository {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;

  /// Lightweight upload for handshake proof — returns just the download URL
  Future<String> uploadProofFile(File file, String fileName) async {
    final ref = _storage
        .ref('handshake_proofs/${DateTime.now().millisecondsSinceEpoch}_$fileName');
    await ref.putFile(file);
    return ref.getDownloadURL();
  }

  Future<FileModel> uploadFile({
    required File file,
    required String fileName,
    required List<String> moduleScope,
    required String orgId,
    required String uploadedBy,
    String? mimeType,
  }) async {
    final storageRef = _storage
        .ref(AppConstants.storageSharedFiles)
        .child('${DateTime.now().millisecondsSinceEpoch}_$fileName');

    final uploadTask = await storageRef.putFile(file,
        SettableMetadata(contentType: mimeType));
    final url = await uploadTask.ref.getDownloadURL();

    final fileModel = FileModel(
      id:             '',
      name:           fileName,
      url:            url,
      moduleScope:    moduleScope,
      orgId:          orgId,
      uploadedBy:     uploadedBy,
      uploadedAt:     DateTime.now(),
      currentVersion: 'v1',
      mimeType:       mimeType,
      sizeBytes:      await file.length(),
    );

    final ref2 = await _db.collection(AppConstants.filesCollection).add(fileModel.toMap());
    return FileModel(
      id:             ref2.id,
      name:           fileModel.name,
      url:            fileModel.url,
      moduleScope:    fileModel.moduleScope,
      orgId:          fileModel.orgId,
      uploadedBy:     fileModel.uploadedBy,
      uploadedAt:     fileModel.uploadedAt,
      currentVersion: fileModel.currentVersion,
      mimeType:       fileModel.mimeType,
      sizeBytes:      fileModel.sizeBytes,
    );
  }

  Future<void> uploadNewVersion({
    required String fileId,
    required File file,
    required String orgId,
    required String modifiedBy,
    required String changeSummary,
    required String currentVersion,
  }) async {
    final storageRef = _storage
        .ref(AppConstants.storageSharedFiles)
        .child('${DateTime.now().millisecondsSinceEpoch}_v');

    final uploadTask = await storageRef.putFile(file);
    final url = await uploadTask.ref.getDownloadURL();

    final batch = _db.batch();
    final fileRef = _db.collection(AppConstants.filesCollection).doc(fileId);

    // Save old version
    final versionRef = fileRef.collection(AppConstants.versionsSubcollection).doc();
    batch.set(versionRef, {
      'url':           currentVersion,
      'modifiedBy':    modifiedBy,
      'modifiedAt':    Timestamp.now(),
      'changeSummary': changeSummary,
    });

    // Bump version + new URL
    final vNum = _nextVersion(currentVersion);
    batch.update(fileRef, {'url': url, 'currentVersion': vNum});

    // Audit
    final aRef = _db.collection(AppConstants.auditLogCollection).doc();
    batch.set(aRef, {
      'actorId':      modifiedBy,
      'actorName':    '',
      'action':       'FILE_UPDATED',
      'targetModule': '',
      'orgId':        orgId,
      'metadata':     {'fileId': fileId, 'version': vNum},
      'timestamp':    Timestamp.now(),
    });

    await batch.commit();
  }

  String _nextVersion(String v) {
    final num = int.tryParse(v.replaceAll('v', '')) ?? 1;
    return 'v${num + 1}';
  }

  Stream<List<FileModel>> watchModuleFiles(String orgId, List<String> moduleIds) {
    if (moduleIds.isEmpty || orgId.isEmpty) return Stream.value([]);
    return _db.collection(AppConstants.filesCollection)
        .where('orgId', isEqualTo: orgId)
        .snapshots()
        .map((s) {
          final list = s.docs
              .map(FileModel.fromFirestore)
              .where((f) => f.moduleScope.any((m) => moduleIds.contains(m)))
              .toList();
          list.sort((a, b) => b.uploadedAt.compareTo(a.uploadedAt));
          return list;
        });
  }

  /// Admin-only — returns all files within organization
  Stream<List<FileModel>> watchAllFiles(String orgId) {
    if (orgId.isEmpty) return Stream.value([]);
    return _db.collection(AppConstants.filesCollection)
        .where('orgId', isEqualTo: orgId)
        .snapshots()
        .map((s) {
          final list = s.docs.map(FileModel.fromFirestore).toList();
          list.sort((a, b) => b.uploadedAt.compareTo(a.uploadedAt));
          return list;
        });
  }

  Stream<List<FileVersionModel>> watchVersions(String fileId) {
    return _db.collection(AppConstants.filesCollection)
        .doc(fileId)
        .collection(AppConstants.versionsSubcollection)
        .orderBy('modifiedAt', descending: true)
        .snapshots()
        .map((s) => s.docs.map(FileVersionModel.fromFirestore).toList());
  }

  Future<void> restoreVersion(
      String fileId, FileVersionModel version, String restoredBy) async {
    final fileSnap = await _db.collection(AppConstants.filesCollection).doc(fileId).get();
    final orgId = fileSnap.exists ? (fileSnap.data()?['orgId'] as String? ?? '') : '';

    await _db.collection(AppConstants.filesCollection).doc(fileId).update({
      'url':            version.url,
      'currentVersion': '${version.id}_restored',
    });
    // Log the restore
    await _db.collection(AppConstants.auditLogCollection).add({
      'actorId':      restoredBy,
      'actorName':    '',
      'action':       'FILE_RESTORED',
      'targetModule': '',
      'orgId':        orgId,
      'metadata':     {'fileId': fileId, 'restoredVersionId': version.id},
      'timestamp':    Timestamp.now(),
    });
  }
}
