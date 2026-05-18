import 'package:cloud_firestore/cloud_firestore.dart';
import '../../core/constants/app_constants.dart';

class ModuleModel {
  final String id;
  final String name;
  final String ownerId;
  final String status;
  final double progress;      // 0–100
  final List<String> dependsOn;
  final String? description;
  final DateTime createdAt;

  const ModuleModel({
    required this.id,
    required this.name,
    required this.ownerId,
    required this.status,
    required this.progress,
    required this.dependsOn,
    this.description,
    required this.createdAt,
  });

  bool get isComplete     => status == AppConstants.statusComplete;
  bool get isInProgress   => status == AppConstants.statusInProgress;
  bool get isNotStarted   => status == AppConstants.statusNotStarted;

  /// Delay color: green / amber / red based on progress
  String get delayColor {
    if (progress >= 75) return 'green';
    if (progress >= 40) return 'yellow';
    return 'red';
  }

  factory ModuleModel.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return ModuleModel(
      id:          doc.id,
      name:        d['name'] ?? '',
      ownerId:     d['ownerId'] ?? '',
      status:      d['status'] ?? AppConstants.statusNotStarted,
      progress:    (d['progress'] ?? 0).toDouble(),
      dependsOn:   List<String>.from(d['dependsOn'] ?? []),
      description: d['description'],
      createdAt:   (d['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() => {
    'name':        name,
    'ownerId':     ownerId,
    'status':      status,
    'progress':    progress,
    'dependsOn':   dependsOn,
    'description': description,
    'createdAt':   Timestamp.fromDate(createdAt),
  };

  ModuleModel copyWith({
    String? name, String? status, double? progress,
    List<String>? dependsOn, String? description,
  }) =>
    ModuleModel(
      id:          id,
      name:        name ?? this.name,
      ownerId:     ownerId,
      status:      status ?? this.status,
      progress:    progress ?? this.progress,
      dependsOn:   dependsOn ?? this.dependsOn,
      description: description ?? this.description,
      createdAt:   createdAt,
    );
}
