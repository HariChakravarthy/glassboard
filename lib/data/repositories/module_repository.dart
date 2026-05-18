import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_database/firebase_database.dart';
import '../models/module_model.dart';
import '../models/task_model.dart';
import '../../core/constants/app_constants.dart';

class ModuleRepository {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseDatabase _rtdb = FirebaseDatabase.instance;

  // ── Modules ────────────────────────────────────────────────────────

  Stream<List<ModuleModel>> watchAllModules() {
    return _db.collection(AppConstants.modulesCollection)
        .orderBy('createdAt', descending: false)
        .snapshots()
        .map((s) => s.docs.map(ModuleModel.fromFirestore).toList());
  }

  Stream<ModuleModel?> watchModule(String moduleId) {
    return _db.collection(AppConstants.modulesCollection)
        .doc(moduleId)
        .snapshots()
        .map((s) => s.exists ? ModuleModel.fromFirestore(s) : null);
  }

  Future<ModuleModel> getModule(String moduleId) async {
    final snap = await _db.collection(AppConstants.modulesCollection).doc(moduleId).get();
    if (!snap.exists) throw Exception('Module not found');
    return ModuleModel.fromFirestore(snap);
  }

  Future<String> createModule(ModuleModel module) async {
    final ref = await _db.collection(AppConstants.modulesCollection).add(module.toMap());
    return ref.id;
  }

  Future<void> updateModuleStatus(String moduleId, String status) async {
    await _db.collection(AppConstants.modulesCollection)
        .doc(moduleId)
        .update({'status': status});
  }

  Future<void> updateModuleProgress(String moduleId, double progress) async {
    // Update Firestore
    await _db.collection(AppConstants.modulesCollection)
        .doc(moduleId)
        .update({'progress': progress});
    // Broadcast via Realtime DB for live sync
    await _rtdb.ref('${AppConstants.rtdbModuleProgress}/$moduleId')
        .set({'progress': progress, 'updatedAt': ServerValue.timestamp});
  }

  /// Watch live progress from Realtime DB
  Stream<double> watchModuleProgressRtdb(String moduleId) {
    return _rtdb.ref('${AppConstants.rtdbModuleProgress}/$moduleId/progress')
        .onValue
        .map((event) => (event.snapshot.value as num?)?.toDouble() ?? 0.0);
  }

  Future<void> deleteModule(String moduleId) async {
    await _db.collection(AppConstants.modulesCollection).doc(moduleId).delete();
  }

  // ── Tasks ──────────────────────────────────────────────────────────

  Stream<List<TaskModel>> watchTasks(String moduleId) {
    return _db.collection(AppConstants.modulesCollection)
        .doc(moduleId)
        .collection(AppConstants.tasksSubcollection)
        .orderBy('createdAt', descending: false)
        .snapshots()
        .map((s) => s.docs.map((d) => TaskModel.fromFirestore(d, moduleId)).toList());
  }

  Future<String> createTask(TaskModel task) async {
    final ref = await _db
        .collection(AppConstants.modulesCollection)
        .doc(task.moduleId)
        .collection(AppConstants.tasksSubcollection)
        .add(task.toMap());
    await _recalcProgress(task.moduleId);
    return ref.id;
  }

  Future<void> toggleTaskCompletion(TaskModel task) async {
    await _db
        .collection(AppConstants.modulesCollection)
        .doc(task.moduleId)
        .collection(AppConstants.tasksSubcollection)
        .doc(task.id)
        .update({'completed': !task.completed});
    await _recalcProgress(task.moduleId);
  }

  Future<void> updateTask(TaskModel task) async {
    await _db
        .collection(AppConstants.modulesCollection)
        .doc(task.moduleId)
        .collection(AppConstants.tasksSubcollection)
        .doc(task.id)
        .update(task.toMap());
  }

  Future<void> deleteTask(String moduleId, String taskId) async {
    await _db
        .collection(AppConstants.modulesCollection)
        .doc(moduleId)
        .collection(AppConstants.tasksSubcollection)
        .doc(taskId)
        .delete();
    await _recalcProgress(moduleId);
  }

  /// Recalculate + push module progress based on completed tasks
  Future<void> _recalcProgress(String moduleId) async {
    final snap = await _db
        .collection(AppConstants.modulesCollection)
        .doc(moduleId)
        .collection(AppConstants.tasksSubcollection)
        .get();
    if (snap.docs.isEmpty) return;
    final total     = snap.docs.length;
    final completed = snap.docs.where((d) => d['completed'] == true).length;
    final progress  = (completed / total * 100).roundToDouble();
    await updateModuleProgress(moduleId, progress);
  }

  /// Check if all tasks are complete (for handshake gate)
  Future<bool> allTasksComplete(String moduleId) async {
    final snap = await _db
        .collection(AppConstants.modulesCollection)
        .doc(moduleId)
        .collection(AppConstants.tasksSubcollection)
        .get();
    if (snap.docs.isEmpty) return true;
    return snap.docs.every((d) => d['completed'] == true);
  }
}
