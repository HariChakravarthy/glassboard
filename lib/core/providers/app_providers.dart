import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/repositories/module_repository.dart';
import '../../data/repositories/handshake_repository.dart';
import '../../data/repositories/file_repository.dart';
import '../../data/repositories/audit_repository.dart';
import '../../data/models/module_model.dart';
import '../../data/models/task_model.dart';
import '../../data/models/handshake_model.dart';
import '../../data/models/file_model.dart';
import '../../data/models/audit_model.dart';
import 'auth_provider.dart';

// ── Repositories ───────────────────────────────────────────────────
final moduleRepositoryProvider = Provider<ModuleRepository>((_) => ModuleRepository());
final handshakeRepositoryProvider = Provider<HandshakeRepository>((_) => HandshakeRepository());
final fileRepositoryProvider = Provider<FileRepository>((_) => FileRepository());
final auditRepositoryProvider = Provider<AuditRepository>((_) => AuditRepository());

// ── Modules ────────────────────────────────────────────────────────
final allModulesProvider = StreamProvider<List<ModuleModel>>((ref) {
  final auth = ref.watch(authStateProvider).valueOrNull;
  if (auth == null) return Stream.value([]);
  return ref.watch(moduleRepositoryProvider).watchAllModules();
});

final moduleDetailProvider = StreamProvider.family<ModuleModel?, String>((ref, id) {
  final auth = ref.watch(authStateProvider).valueOrNull;
  if (auth == null) return Stream.value(null);
  return ref.watch(moduleRepositoryProvider).watchModule(id);
});

final moduleLiveProgressProvider = StreamProvider.family<double, String>((ref, id) {
  final auth = ref.watch(authStateProvider).valueOrNull;
  if (auth == null) return Stream.value(0.0);
  return ref.watch(moduleRepositoryProvider).watchModuleProgressRtdb(id);
});


// ── Tasks ──────────────────────────────────────────────────────────
final tasksProvider = StreamProvider.family<List<TaskModel>, String>((ref, moduleId) {
  final auth = ref.watch(authStateProvider).valueOrNull;
  if (auth == null) return Stream.value([]);
  return ref.watch(moduleRepositoryProvider).watchTasks(moduleId);
});

// ── Handshakes ─────────────────────────────────────────────────────
final incomingHandshakesProvider = StreamProvider.family<List<HandshakeModel>, String>(
    (ref, moduleId) {
  final auth = ref.watch(authStateProvider).valueOrNull;
  if (auth == null) return Stream.value([]);
  return ref.watch(handshakeRepositoryProvider).watchIncomingHandshakes(moduleId);
});

final moduleHandshakesProvider = StreamProvider.family<List<HandshakeModel>, String>(
    (ref, moduleId) {
  final auth = ref.watch(authStateProvider).valueOrNull;
  if (auth == null) return Stream.value([]);
  return ref.watch(handshakeRepositoryProvider).watchModuleHandshakes(moduleId);
});

final allHandshakesProvider = StreamProvider<List<HandshakeModel>>((ref) {
  final auth = ref.watch(authStateProvider).valueOrNull;
  if (auth == null) return Stream.value([]);
  return ref.watch(handshakeRepositoryProvider).watchAllHandshakes();
});

// ── Files ──────────────────────────────────────────────────────────
/// Key is a comma-joined moduleId string (e.g. "mod1,mod2") for stable caching.
/// Pass empty string to get an empty result immediately.
final moduleFilesProvider = StreamProvider.family<List<FileModel>, String>(
    (ref, moduleIdsKey) {
  final auth = ref.watch(authStateProvider).valueOrNull;
  if (auth == null) return Stream.value([]);
  if (moduleIdsKey.isEmpty) return Stream.value([]);
  final ids = moduleIdsKey.split(',');
  return ref.watch(fileRepositoryProvider).watchModuleFiles(ids);
});

final fileVersionsProvider = StreamProvider.family<List<FileVersionModel>, String>(
    (ref, fileId) {
  final auth = ref.watch(authStateProvider).valueOrNull;
  if (auth == null) return Stream.value([]);
  return ref.watch(fileRepositoryProvider).watchVersions(fileId);
});

// Admin-visible all-files stream (no moduleScope filter)
final allFilesProvider = StreamProvider<List<FileModel>>((ref) {
  final auth = ref.watch(authStateProvider).valueOrNull;
  if (auth == null) return Stream.value([]);
  return ref.watch(fileRepositoryProvider).watchAllFiles();
});

// ── Audit & Notifications ─────────────────────────────────────────
final auditLogProvider = StreamProvider<List<AuditLogModel>>((ref) {
  final auth = ref.watch(authStateProvider).valueOrNull;
  if (auth == null) return Stream.value([]);
  return ref.watch(auditRepositoryProvider).watchAuditLog();
});

final notificationsProvider = StreamProvider.family<List<NotificationModel>, String>(
    (ref, userId) {
  final auth = ref.watch(authStateProvider).valueOrNull;
  if (auth == null) return Stream.value([]);
  return ref.watch(auditRepositoryProvider).watchNotifications(userId);
});

final unreadCountProvider = StreamProvider.family<int, String>((ref, userId) {
  final auth = ref.watch(authStateProvider).valueOrNull;
  if (auth == null) return Stream.value(0);
  return ref.watch(auditRepositoryProvider).watchUnreadCount(userId);
});
