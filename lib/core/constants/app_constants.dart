/// Glassboard — App-wide constants
class AppConstants {
  AppConstants._();

  // Firestore collections
  static const String usersCollection = 'users';
  static const String modulesCollection = 'modules';
  static const String tasksSubcollection = 'tasks';
  static const String handshakesCollection = 'handshakes';
  static const String filesCollection = 'files';
  static const String versionsSubcollection = 'versions';
  static const String auditLogCollection = 'auditLog';
  static const String notificationsCollection = 'notifications';

  // Realtime DB paths
  static const String rtdbModuleProgress = 'moduleProgress';

  // Firebase Storage
  static const String storageHandshakeProofs = 'handshake_proofs';
  static const String storageSharedFiles = 'shared_files';

  // RBAC roles
  static const String roleMember = 'member';
  static const String roleModuleLead = 'module_lead';
  static const String roleOrgAdmin = 'org_admin';

  // Module statuses
  static const String statusNotStarted = 'NOT_STARTED';
  static const String statusInProgress = 'IN_PROGRESS';
  static const String statusReview = 'REVIEW';
  static const String statusComplete = 'COMPLETE';

  // Handshake statuses
  static const String handshakePending = 'PENDING';
  static const String handshakeSent = 'SENT';
  static const String handshakeAccepted = 'ACCEPTED';
  static const String handshakeRejected = 'REJECTED';

  // Task priorities
  static const String priorityLow = 'LOW';
  static const String priorityMedium = 'MEDIUM';
  static const String priorityHigh = 'HIGH';
  static const String priorityBlocker = 'BLOCKER';

  // Escalation hours threshold
  static const int escalationHours = 24;

  // Pagination
  static const int pageSize = 20;
}
