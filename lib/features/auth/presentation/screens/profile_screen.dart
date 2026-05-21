import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/providers/auth_provider.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../shared/widgets/shared_widgets.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userAsync = ref.watch(currentUserProvider);
    return userAsync.when(
      data: (user) {
        if (user == null) return const SizedBox();
        final roleColor = switch (user.role) {
          AppConstants.roleOrgAdmin   => AppTheme.primary,
          AppConstants.roleModuleLead => AppTheme.warning,
          _                           => AppTheme.textMuted,
        };

        return Scaffold(
          backgroundColor: AppTheme.bg,
          appBar: const GlassAppBar(title: 'PROFILE'),
          body: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              // Avatar + name
              Center(
                child: Column(
                  children: [
                    Container(
                      width: 80, height: 80,
                      decoration: BoxDecoration(
                        color: roleColor.withAlpha(26),
                        border: Border.all(color: roleColor, width: 2),
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: Text(
                          user.name.isNotEmpty ? user.name[0].toUpperCase() : '?',
                          style: TextStyle(
                            color: roleColor, fontSize: 32,
                            fontWeight: FontWeight.w800, fontFamily: 'Syne',
                          ),
                        ),
                      ),
                    ).animate().scale(duration: 400.ms),
                    const SizedBox(height: 14),
                    Text(user.name,
                      style: Theme.of(context).textTheme.headlineMedium),
                    const SizedBox(height: 4),
                    Text(user.email,
                      style: Theme.of(context).textTheme.bodySmall),
                    const SizedBox(height: 10),
                    StatusBadge(
                      label: user.role.toUpperCase().replaceAll('_', ' '),
                      color: roleColor,
                    ),
                    if ((user.techRole ?? '').isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppTheme.primary.withAlpha(20),
                          border: Border.all(color: AppTheme.primary.withAlpha(80)),
                        ),
                        child: Text(
                          user.techRole!,
                          style: const TextStyle(
                            color: AppTheme.primary,
                            fontSize: 10, letterSpacing: 1,
                            fontFamily: 'Space Mono',
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 32),

              // Info cards
              Builder(
                builder: (context) {
                  final orgAsync = ref.watch(organizationProvider(user.orgId));
                  final inviteCode = orgAsync.valueOrNull?['inviteCode'] ?? 'Loading...';
                  final orgName = orgAsync.valueOrNull?['name'] ?? 'Loading...';

                  return GlassCard(
                    padding: const EdgeInsets.all(0),
                    child: Column(
                      children: [
                        _InfoTile('ORGANIZATION NAME', orgName, Icons.business_outlined),
                        const Divider(height: 1),
                        _InfoTile('ORGANIZATION ID', user.orgId.isNotEmpty ? user.orgId : '—', Icons.badge_outlined),
                        const Divider(height: 1),
                        _InfoTile('INVITE CODE', inviteCode, Icons.vpn_key_outlined),
                        if ((user.techRole ?? '').isNotEmpty) ...[
                          const Divider(height: 1),
                          _InfoTile('TECH ROLE', user.techRole!, Icons.code_rounded),
                        ],
                        const Divider(height: 1),
                        _InfoTile('MEMBER SINCE',
                          user.createdAt.toString().substring(0, 10), Icons.calendar_today_outlined),
                      ],
                    ),
                  );
                }
              ).animate().fadeIn(delay: 200.ms),
              const SizedBox(height: 24),

              // Danger zone
              Container(
                decoration: BoxDecoration(
                  border: Border.all(color: AppTheme.danger.withAlpha(77)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
                      child: Text('DANGER ZONE',
                        style: TextStyle(
                          color: AppTheme.danger.withAlpha(179),
                          fontSize: 10, letterSpacing: 3,
                          fontFamily: 'Space Mono',
                        )),
                    ),
                    ListTile(
                      leading: const Icon(Icons.logout_rounded,
                        color: AppTheme.danger, size: 20),
                      title: const Text('Sign Out',
                        style: TextStyle(color: AppTheme.danger, fontSize: 13)),
                      onTap: () async {
                        await ref.read(authNotifierProvider.notifier).signOut();
                        if (context.mounted) context.go('/login');
                      },
                    ),
                  ],
                ),
              ).animate().fadeIn(delay: 300.ms),
            ],
          ),
        );
      },
      loading: () => const Scaffold(
        backgroundColor: AppTheme.bg,
        body: Center(child: CircularProgressIndicator(color: AppTheme.primary)),
      ),
      error: (e, _) => const SizedBox(),
    );
  }
}

class _InfoTile extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  const _InfoTile(this.label, this.value, this.icon);

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      leading: Icon(icon, size: 18, color: AppTheme.textMuted),
      title: Text(label,
        style: const TextStyle(
          color: AppTheme.textDim, fontSize: 10, letterSpacing: 2,
          fontFamily: 'Space Mono',
        )),
      subtitle: Text(value,
        style: const TextStyle(color: AppTheme.textPrimary, fontSize: 13)),
    );
  }
}
