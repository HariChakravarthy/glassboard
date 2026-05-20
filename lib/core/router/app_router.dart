import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../features/auth/presentation/screens/login_screen.dart';
import '../../features/auth/presentation/screens/register_screen.dart';
import '../../features/auth/presentation/screens/onboarding_screen.dart';
import '../../features/auth/presentation/screens/profile_screen.dart';
import '../../features/dashboard/presentation/screens/dashboard_screen.dart';
import '../../features/modules/presentation/screens/module_detail_screen.dart';
import '../../features/modules/presentation/screens/create_module_screen.dart';
import '../../features/tasks/presentation/screens/task_screen.dart';
import '../../features/handshake/presentation/screens/handshake_inbox_screen.dart';
import '../../features/handshake/presentation/screens/initiate_handshake_screen.dart';
import '../../features/handshake/presentation/screens/handshake_detail_screen.dart';
import '../../features/files/presentation/screens/files_screen.dart';
import '../../features/files/presentation/screens/file_preview_screen.dart';
import '../../features/notifications/presentation/screens/notifications_screen.dart';
import '../../features/audit/presentation/screens/audit_log_screen.dart';
import '../../features/admin/presentation/screens/admin_users_screen.dart';
import '../../shared/widgets/main_shell.dart';
import '../providers/auth_provider.dart';

final routerProvider = Provider<GoRouter>((ref) {
  final authState = ref.watch(authStateProvider);

  return GoRouter(
    initialLocation: '/onboarding',
    redirect: (context, state) {
      final isLoggedIn = authState.valueOrNull != null;
      final loc = state.matchedLocation;
      final isAuthRoute = loc == '/login' || loc == '/register' || loc == '/onboarding';

      if (!isLoggedIn && !isAuthRoute) return '/login';
      if (isLoggedIn && isAuthRoute) return '/dashboard';
      return null;
    },
    routes: [
      // ── Auth routes (no shell) ─────────────────────────────────
      GoRoute(path: '/onboarding', builder: (_, __) => const OnboardingScreen()),
      GoRoute(path: '/login', builder: (_, __) => const LoginScreen()),
      GoRoute(path: '/register', builder: (_, __) => const RegisterScreen()),

      // ── Main shell (bottom nav) ────────────────────────────────
      ShellRoute(
        builder: (_, __, child) => MainShell(child: child),
        routes: [
          GoRoute(path: '/dashboard', builder: (_, __) => const DashboardScreen()),
          GoRoute(path: '/handshake/inbox', builder: (_, __) => const HandshakeInboxScreen()),
          GoRoute(path: '/files', builder: (_, __) => const FilesScreen()),
          GoRoute(path: '/notifications', builder: (_, __) => const NotificationsScreen()),
        ],
      ),

      // ── Full-screen routes (no bottom nav) ─────────────────────
      GoRoute(path: '/modules/create', builder: (_, __) => const CreateModuleScreen()),
      GoRoute(
        path: '/modules/:id',
        builder: (_, state) => ModuleDetailScreen(moduleId: state.pathParameters['id']!),
      ),
      GoRoute(
        path: '/modules/:id/tasks',
        builder: (_, state) => TaskScreen(moduleId: state.pathParameters['id']!),
      ),
      GoRoute(
        path: '/modules/:id/handshake/initiate',
        builder: (_, state) => InitiateHandshakeScreen(fromModuleId: state.pathParameters['id']!),
      ),
      GoRoute(
        path: '/handshake/:id',
        builder: (_, state) => HandshakeDetailScreen(handshakeId: state.pathParameters['id']!),
      ),
      GoRoute(path: '/profile', builder: (_, __) => const ProfileScreen()),
      GoRoute(path: '/audit', builder: (_, __) => const AuditLogScreen()),
      GoRoute(path: '/admin/users', builder: (_, __) => const AdminUsersScreen()),
      GoRoute(
        path: '/files/:id/preview',
        builder: (_, state) {
          // File object is passed as extra
          final file = state.extra;
          if (file == null) return const SizedBox();
          return FilePreviewScreen(file: file as dynamic);
        },
      ),
    ],
    errorBuilder: (context, state) => const Scaffold(
      backgroundColor: Color(0xFF080B10),
      body: Center(
        child: Text('404 — Page not found',
            style: TextStyle(color: Colors.white70)),
      ),
    ),
  );
});
