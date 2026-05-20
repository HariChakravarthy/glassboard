import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/providers/auth_provider.dart';
import '../../../../core/providers/app_providers.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../shared/widgets/shared_widgets.dart';
import '../../../../data/models/module_model.dart';
import '../widgets/dependency_graph.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userAsync    = ref.watch(currentUserProvider);
    final modulesAsync = ref.watch(allModulesProvider);

    return userAsync.when(
      data: (user) {
        if (user == null) return const SizedBox();
        final unreadAsync = ref.watch(unreadCountProvider(user.uid));
        final unread = unreadAsync.valueOrNull ?? 0;

        return Scaffold(
          backgroundColor: AppTheme.bg,
          appBar: PreferredSize(
            preferredSize: const Size.fromHeight(64),
            child: GlassAppBar(
              title: 'GLASSBOARD',
              subtitle: user.role.toUpperCase().replaceAll('_', ' '),
              leading: const SizedBox(width: 16),
              accentColor: AppTheme.primary,
              actions: [
                // Notification bell
                Stack(
                  alignment: Alignment.topRight,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.notifications_outlined, size: 22),
                      onPressed: () => context.push('/notifications'),
                      color: AppTheme.textSecondary,
                    ),
                    if (unread > 0)
                      Positioned(
                        top: 8, right: 8,
                        child: Container(
                          width: 8, height: 8,
                          decoration: const BoxDecoration(
                            color: AppTheme.danger,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                  ],
                ),
                IconButton(
                  icon: const Icon(Icons.person_outline_rounded, size: 22),
                  onPressed: () => context.push('/profile'),
                  color: AppTheme.textSecondary,
                ),
              ],
            ),
          ),
          floatingActionButton: user.isOrgAdmin
              ? FloatingActionButton(
                  onPressed: () => context.push('/modules/create'),
                  tooltip: 'Create Module',
                  child: const Icon(Icons.add_rounded, color: AppTheme.bg),
                )
              : null,
          body: RefreshIndicator(
            color: AppTheme.primary,
            backgroundColor: AppTheme.surface,
            onRefresh: () async => ref.invalidate(allModulesProvider),
            child: modulesAsync.when(
              data: (modules) => _buildBody(context, ref, user, modules),
              loading: () => const Padding(
                padding: EdgeInsets.all(24),
                child: LoadingCardSkeleton(),
              ),
              error: (e, _) => Center(
                child: Text('Error: $e',
                  style: const TextStyle(color: AppTheme.danger)),
              ),
            ),
          ),
        );
      },
      loading: () => const Scaffold(
        backgroundColor: AppTheme.bg,
        body: Center(child: CircularProgressIndicator(color: AppTheme.primary)),
      ),
      error: (e, _) => Scaffold(
        backgroundColor: AppTheme.bg,
        body: Center(child: Text('$e', style: const TextStyle(color: AppTheme.danger))),
      ),
    );
  }

  Widget _buildBody(BuildContext context, WidgetRef ref, user, List<ModuleModel> modules) {
    // Filter: non-admins only see their module
    final visibleModules = user.isOrgAdmin
        ? modules
        : modules.where((m) => m.id == user.moduleId).toList();

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        // ── Stats Row ───────────────────────────────────────────────
        if (user.isOrgAdmin) ...[
          _StatsRow(modules: modules).animate().fadeIn(duration: 400.ms),
          const SizedBox(height: 16),
          // ── Dependency Graph ────────────────────────────────────────
          const SectionHeader(
            label: 'Pipeline',
            title: 'Dependency Graph',
            accentColor: AppTheme.primary,
          ),
          const SizedBox(height: 12),
          GlassCard(
            padding: EdgeInsets.zero,
            child: DependencyGraph(
              modules: modules,
              onModuleTap: (id) => context.push('/modules/$id'),
            ),
          ),
          const SizedBox(height: 24),
        ],

        // ── Quick Actions ────────────────────────────────────────────
        _QuickActions(user: user).animate().fadeIn(delay: 100.ms),
        const SizedBox(height: 24),

        // ── Modules Grid / List ──────────────────────────────────────
        SectionHeader(
          label: user.isOrgAdmin ? 'Org Overview' : 'My Module',
          title: 'Modules',
          accentColor: AppTheme.primary,
          trailing: user.isOrgAdmin
              ? TextButton(
                  onPressed: () => context.push('/audit'),
                  child: const Text('AUDIT LOG',
                    style: TextStyle(fontSize: 10, letterSpacing: 2)),
                )
              : null,
        ),
        const SizedBox(height: 16),

        if (visibleModules.isEmpty)
          const EmptyState(
            icon: Icons.view_module_outlined,
            title: 'No Modules Yet',
            subtitle: 'An org admin can create modules for the team.',
          )
        else
          ...visibleModules.asMap().entries.map((e) =>
            _ModuleCard(module: e.value)
                .animate()
                .fadeIn(delay: (100 + e.key * 60).ms)
                .slideY(begin: 0.1, end: 0)),
      ],
    );
  }


}

// ── Stats Row ──────────────────────────────────────────────────────
class _StatsRow extends StatelessWidget {
  final List<ModuleModel> modules;
  const _StatsRow({required this.modules});

  @override
  Widget build(BuildContext context) {
    final complete   = modules.where((m) => m.isComplete).length;
    final inProgress = modules.where((m) => m.isInProgress).length;
    final notStarted = modules.where((m) => m.isNotStarted).length;

    return Row(
      children: [
        _Stat(value: '${modules.length}', label: 'TOTAL', color: AppTheme.primary),
        const SizedBox(width: 12),
        _Stat(value: '$complete', label: 'COMPLETE', color: AppTheme.success),
        const SizedBox(width: 12),
        _Stat(value: '$inProgress', label: 'IN PROGRESS', color: AppTheme.warning),
        const SizedBox(width: 12),
        _Stat(value: '$notStarted', label: 'NOT STARTED', color: AppTheme.textMuted),
      ],
    );
  }
}

class _Stat extends StatelessWidget {
  final String value;
  final String label;
  final Color color;
  const _Stat({required this.value, required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GlassCard(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
        borderLeftColor: color,
        borderLeftWidth: 3,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(value,
              style: TextStyle(
                color: color, fontSize: 22, fontWeight: FontWeight.w800,
                fontFamily: 'Syne',
              )),
            Text(label,
              style: const TextStyle(
                color: AppTheme.textDim, fontSize: 9, letterSpacing: 1.5,
              )),
          ],
        ),
      ),
    );
  }
}

// ── Quick Actions ──────────────────────────────────────────────────
class _QuickActions extends StatelessWidget {
  final dynamic user;
  const _QuickActions({required this.user});

  @override
  Widget build(BuildContext context) {
    final actions = [
      if (user.isLead || user.isOrgAdmin)
        _Action(icon: Icons.handshake_outlined, label: 'INBOX',
            color: AppTheme.warning, onTap: () => context.push('/handshake/inbox')),
      _Action(icon: Icons.folder_shared_outlined, label: 'FILES',
          color: AppTheme.purple, onTap: () => context.push('/files')),
      if (user.isOrgAdmin)
        _Action(icon: Icons.people_outline_rounded, label: 'USERS',
            color: AppTheme.orange, onTap: () => context.push('/admin/users')),
      if (user.isOrgAdmin)
        _Action(icon: Icons.receipt_long_outlined, label: 'AUDIT',
            color: AppTheme.success, onTap: () => context.push('/audit')),
    ];

    if (actions.isEmpty) return const SizedBox();
    // Show max 4 in a row, wrap if more
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: actions.map((a) => SizedBox(width: (MediaQuery.of(context).size.width - 60) / 4, child: a)).toList(),
    );
  }
}

class _Action extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  const _Action({required this.icon, required this.label, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      onTap: onTap,
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 8),
          Text(label,
            style: TextStyle(color: color, fontSize: 9, letterSpacing: 2, fontFamily: 'Space Mono')),
        ],
      ),
    );
  }
}

// ── Module Card ────────────────────────────────────────────────────
class _ModuleCard extends ConsumerWidget {
  final ModuleModel module;
  const _ModuleCard({required this.module});

  Color get _statusColor => switch (module.status) {
    AppConstants.statusComplete   => AppTheme.success,
    AppConstants.statusInProgress => AppTheme.warning,
    AppConstants.statusReview     => AppTheme.purple,
    _                              => AppTheme.textMuted,
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final liveProgress = module.progress;

    return GestureDetector(
      onTap: () => context.push('/modules/${module.id}'),
      child: GlassCard(
        padding: const EdgeInsets.all(20),
        borderLeftColor: _statusColor,
        borderLeftWidth: 3,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(module.name,
                    style: Theme.of(context).textTheme.titleMedium),
                ),
                StatusBadge(label: module.status.replaceAll('_', ' '), color: _statusColor),
              ],
            ),
            if (module.description != null && module.description!.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(module.description!,
                style: Theme.of(context).textTheme.bodySmall,
                maxLines: 2, overflow: TextOverflow.ellipsis),
            ],
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: GlassProgressBar(
                    value: liveProgress, color: _statusColor),
                ),
                const SizedBox(width: 12),
                Text('${liveProgress.toInt()}%',
                  style: TextStyle(
                    color: _statusColor, fontSize: 12,
                    fontWeight: FontWeight.w700, fontFamily: 'Space Mono',
                  )),
              ],
            ),
            if (module.dependsOn.isNotEmpty) ...[
              const SizedBox(height: 10),
              Text('DEPENDS ON: ${module.dependsOn.join(", ")}',
                style: const TextStyle(
                  color: AppTheme.textDim, fontSize: 9, letterSpacing: 1.5)),
            ],
          ],
        ),
      ).animate().shimmer(duration: 1200.ms, delay: 500.ms,
          color: AppTheme.primary.withAlpha(10)),
    );
  }
}
