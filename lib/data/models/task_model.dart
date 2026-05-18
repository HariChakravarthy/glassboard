import 'package:cloud_firestore/cloud_firestore.dart';
import '../../core/constants/app_constants.dart';

class TaskModel {
  final String id;
  final String moduleId;
  final String title;
  final String assignedTo;
  final String priority;
  final bool completed;
  final DateTime? dueDate;
  final String? description;
  final DateTime createdAt;

  const TaskModel({
    required this.id,
    required this.moduleId,
    required this.title,
    required this.assignedTo,
    required this.priority,
    required this.completed,
    this.dueDate,
    this.description,
    required this.createdAt,
  });

  bool get isBlocker => priority == AppConstants.priorityBlocker;
  bool get isHigh    => priority == AppConstants.priorityHigh;

  factory TaskModel.fromFirestore(DocumentSnapshot doc, String moduleId) {
    final d = doc.data() as Map<String, dynamic>;
    return TaskModel(
      id:          doc.id,
      moduleId:    moduleId,
      title:       d['title'] ?? '',
      assignedTo:  d['assignedTo'] ?? '',
      priority:    d['priority'] ?? AppConstants.priorityMedium,
      completed:   d['completed'] ?? false,
      dueDate:     (d['dueDate'] as Timestamp?)?.toDate(),
      description: d['description'],
      createdAt:   (d['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() => {
    'title':       title,
    'assignedTo':  assignedTo,
    'priority':    priority,
    'completed':   completed,
    'dueDate':     dueDate != null ? Timestamp.fromDate(dueDate!) : null,
    'description': description,
    'createdAt':   Timestamp.fromDate(createdAt),
  };

  TaskModel copyWith({
    String? title, String? assignedTo, String? priority,
    bool? completed, DateTime? dueDate, String? description,
  }) =>
    TaskModel(
      id:          id,
      moduleId:    moduleId,
      title:       title ?? this.title,
      assignedTo:  assignedTo ?? this.assignedTo,
      priority:    priority ?? this.priority,
      completed:   completed ?? this.completed,
      dueDate:     dueDate ?? this.dueDate,
      description: description ?? this.description,
      createdAt:   createdAt,
    );
}
