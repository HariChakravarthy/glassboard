import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:timeago/timeago.dart' as timeago;
import '../../../../core/theme/app_theme.dart';
import '../../../../core/providers/app_providers.dart';
import '../../../../core/providers/auth_provider.dart';
import '../../../../shared/widgets/shared_widgets.dart';
import '../../../../data/models/audit_model.dart';

class NotificationsScreen extends ConsumerWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userAsync = ref.watch(currentUserProvider);
    return userAsync.when(
      data: (user) {
        if (user == null) return const SizedBox();
        final notifAsync = ref.watch(notificationsProvider(user.uid));

        return Scaffold(
          backgroundColor: AppTheme.bg,
          appBar: GlassAppBar(
            title: 'NOTIFICATIONS',
            subtitle: 'ACTIVITY FEED',
            accentColor: AppTheme.primary,
            actions: [
              TextButton(
                onPressed: () => ref.read(auditRepositoryProvider).markAllRead(user.uid),
                child: const Text('MARK ALL READ',
                  style: TextStyle(fontSize: 10, letterSpacing: 1.5)),
              ),
            ],
          ),
          body: notifAsync.when(
            data: (notifs) {
              if (notifs.isEmpty) {
                return const EmptyState(
                  icon: Icons.notifications_none_rounded,
                  title: 'No Notifications',
                  subtitle: 'You\'re all caught up!',
                );
              }
              return ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: notifs.length,
                itemBuilder: (_, i) => _NotifCard(notif: notifs[i])
                    .animate().fadeIn(delay: (i * 50).ms),
              );
            },
            loading: () => const Padding(
              padding: EdgeInsets.all(24), child: LoadingCardSkeleton()),
            error: (e, _) => Center(
              child: Text('$e', style: const TextStyle(color: AppTheme.danger))),
          ),
        );
      },
      loading: () => const Scaffold(
        backgroundColor: AppTheme.bg,
        body: Center(child: CircularProgressIndicator(color: AppTheme.primary)),
      ),
      error: (_, __) => const SizedBox(),
    );
  }
}

class _NotifCard extends ConsumerWidget {
  final NotificationModel notif;
  const _NotifCard({required this.notif});

  IconData get _icon => switch (notif.type) {
    'HANDSHAKE_RECEIVED' => Icons.handshake_outlined,
    'HANDSHAKE_ACCEPTED' => Icons.check_circle_outline_rounded,
    'HANDSHAKE_REJECTED' => Icons.cancel_outlined,
    'TASK_ASSIGNED'      => Icons.checklist_rounded,
    'FILE_MODIFIED'      => Icons.folder_open_outlined,
    _                    => Icons.notifications_outlined,
  };

  Color get _color => switch (notif.type) {
    'HANDSHAKE_RECEIVED' => AppTheme.warning,
    'HANDSHAKE_ACCEPTED' => AppTheme.success,
    'HANDSHAKE_REJECTED' => AppTheme.danger,
    'TASK_ASSIGNED'      => AppTheme.primary,
    'FILE_MODIFIED'      => AppTheme.purple,
    _                    => AppTheme.textMuted,
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return GestureDetector(
      onTap: () => ref.read(auditRepositoryProvider).markRead(notif.id),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(
          color: notif.read ? AppTheme.surface : AppTheme.surface2,
          border: Border(
            left: BorderSide(color: _color, width: notif.read ? 1 : 3),
            top:    const BorderSide(color: AppTheme.border),
            right:  const BorderSide(color: AppTheme.border),
            bottom: const BorderSide(color: AppTheme.border),
          ),
        ),
        child: ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          leading: Container(
            width: 38, height: 38,
            decoration: BoxDecoration(
              color: _color.withAlpha(26),
              border: Border.all(color: _color.withAlpha(77)),
            ),
            child: Icon(_icon, color: _color, size: 18),
          ),
          title: Text(notif.message,
            style: TextStyle(
              color: notif.read ? AppTheme.textSecondary : AppTheme.textPrimary,
              fontSize: 13,
              fontWeight: notif.read ? FontWeight.w400 : FontWeight.w500,
            )),
          subtitle: Text(timeago.format(notif.createdAt),
            style: const TextStyle(color: AppTheme.textDim, fontSize: 11)),
          trailing: notif.read
              ? null
              : Container(
                  width: 8, height: 8,
                  decoration: BoxDecoration(color: _color, shape: BoxShape.circle),
                ),
        ),
      ),
    );
  }
}
