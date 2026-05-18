import 'package:cloud_firestore/cloud_firestore.dart';

class FileModel {
  final String id;
  final String name;
  final String url;
  final List<String> moduleScope;
  final String uploadedBy;
  final DateTime uploadedAt;
  final String currentVersion;
  final String? mimeType;
  final int? sizeBytes;

  const FileModel({
    required this.id,
    required this.name,
    required this.url,
    required this.moduleScope,
    required this.uploadedBy,
    required this.uploadedAt,
    required this.currentVersion,
    this.mimeType,
    this.sizeBytes,
  });

  bool get isImage => mimeType?.startsWith('image/') ?? false;
  bool get isPdf   => mimeType == 'application/pdf';

  factory FileModel.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return FileModel(
      id:             doc.id,
      name:           d['name'] ?? '',
      url:            d['url'] ?? '',
      moduleScope:    List<String>.from(d['moduleScope'] ?? []),
      uploadedBy:     d['uploadedBy'] ?? '',
      uploadedAt:     (d['uploadedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      currentVersion: d['currentVersion'] ?? 'v1',
      mimeType:       d['mimeType'],
      sizeBytes:      d['sizeBytes'],
    );
  }

  Map<String, dynamic> toMap() => {
    'name':           name,
    'url':            url,
    'moduleScope':    moduleScope,
    'uploadedBy':     uploadedBy,
    'uploadedAt':     Timestamp.fromDate(uploadedAt),
    'currentVersion': currentVersion,
    'mimeType':       mimeType,
    'sizeBytes':      sizeBytes,
  };
}

class FileVersionModel {
  final String id;
  final String url;
  final String modifiedBy;
  final DateTime modifiedAt;
  final String? changeSummary;

  const FileVersionModel({
    required this.id,
    required this.url,
    required this.modifiedBy,
    required this.modifiedAt,
    this.changeSummary,
  });

  factory FileVersionModel.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return FileVersionModel(
      id:            doc.id,
      url:           d['url'] ?? '',
      modifiedBy:    d['modifiedBy'] ?? '',
      modifiedAt:    (d['modifiedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      changeSummary: d['changeSummary'],
    );
  }
}
