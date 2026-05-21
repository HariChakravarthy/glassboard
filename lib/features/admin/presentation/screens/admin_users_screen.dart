import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/providers/app_providers.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../data/repositories/admin_repository.dart';
import '../../../../data/models/user_model.dart';
import '../../../../shared/widgets/shared_widgets.dart';

class AdminUsersScreen extends ConsumerWidget {
  const AdminUsersScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final usersAsync = ref.watch(orgUsersProvider);
    final modulesAsync = ref.watch(allModulesProvider);
    final modules = modulesAsync.valueOrNull ?? [];

    return Scaffold(
      backgroundColor: AppTheme.bg,
      appBar: const GlassAppBar(
        title: 'USER MANAGEMENT',
        subtitle: 'ORG ADMIN',
        accentColor: AppTheme.orange,
      ),
      body: usersAsync.when(
        loading: () => const Padding(
            padding: EdgeInsets.all(24), child: LoadingCardSkeleton()),
        error: (e, _) => Center(
            child: Text('$e', style: const TextStyle(color: AppTheme.danger))),
        data: (users) {
          if (users.isEmpty) {
            return const EmptyState(
              icon: Icons.people_outline_rounded,
              title: 'No users registered yet',
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: users.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (_, i) => _UserCard(
              user: users[i],
              modules: modules,
              adminRepo: ref.read(adminRepositoryProvider),
            ).animate().fadeIn(delay: (i * 50).ms),
          );
        },
      ),
    );
  }
}

class _UserCard extends StatelessWidget {
  final UserModel user;
  final List modules;
  final AdminRepository adminRepo;

  const _UserCard({
    required this.user,
    required this.modules,
    required this.adminRepo,
  });

  Color _roleColor(String role) => switch (role) {
    AppConstants.roleOrgAdmin    => AppTheme.warning,
    AppConstants.roleModuleLead  => AppTheme.primary,
    _                            => AppTheme.textMuted,
  };

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      borderLeftColor: _roleColor(user.role),
      borderLeftWidth: 3,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header row
          Row(
            children: [
              Container(
                width: 36, height: 36,
                decoration: BoxDecoration(
                  color: _roleColor(user.role).withAlpha(26),
                  border: Border.all(color: _roleColor(user.role).withAlpha(80)),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    user.name.isNotEmpty ? user.name[0].toUpperCase() : '?',
                    style: TextStyle(
                      color: _roleColor(user.role),
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(user.name,
                      style: const TextStyle(
                        color: AppTheme.textPrimary,
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                    Text(user.email,
                      style: const TextStyle(
                        color: AppTheme.textDim, fontSize: 11),
                    ),
                    if ((user.techRole ?? '').isNotEmpty) ...[
                      const SizedBox(height: 3),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppTheme.primary.withAlpha(25),
                          border: Border.all(color: AppTheme.primary.withAlpha(80)),
                        ),
                        child: Text(
                          user.techRole!,
                          style: const TextStyle(
                            color: AppTheme.primary,
                            fontSize: 9, letterSpacing: 0.8,
                            fontFamily: 'Space Mono',
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              StatusBadge(label: user.role.toUpperCase(), color: _roleColor(user.role)),
            ],
          ),
          const SizedBox(height: 14),
          const Divider(color: AppTheme.border, height: 1),
          const SizedBox(height: 14),

          // Controls row
          Row(
            children: [
              // Role selector
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('ROLE', style: TextStyle(
                      color: AppTheme.textDim, fontSize: 9, letterSpacing: 2, fontFamily: 'Space Mono')),
                    const SizedBox(height: 6),
                    _RoleDropdown(user: user, adminRepo: adminRepo),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              // Module selector
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('MODULE', style: TextStyle(
                      color: AppTheme.textDim, fontSize: 9, letterSpacing: 2, fontFamily: 'Space Mono')),
                    const SizedBox(height: 6),
                    _ModuleDropdown(user: user, modules: modules, adminRepo: adminRepo),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _RoleDropdown extends StatefulWidget {
  final UserModel user;
  final AdminRepository adminRepo;
  const _RoleDropdown({required this.user, required this.adminRepo});

  @override
  State<_RoleDropdown> createState() => _RoleDropdownState();
}

class _RoleDropdownState extends State<_RoleDropdown> {
  late String _selected;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _selected = widget.user.role;
  }

  @override
  void didUpdateWidget(covariant _RoleDropdown oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.user.role != oldWidget.user.role) {
      _selected = widget.user.role;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: AppTheme.bg,
        border: Border.all(color: AppTheme.border),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: _selected,
          isDense: true,
          dropdownColor: AppTheme.surface,
          style: const TextStyle(color: AppTheme.textPrimary, fontSize: 11),
          icon: _saving
              ? const SizedBox(width: 14, height: 14,
                  child: CircularProgressIndicator(strokeWidth: 1.5, color: AppTheme.primary))
              : const Icon(Icons.keyboard_arrow_down_rounded,
                  color: AppTheme.textMuted, size: 16),
          items: [
            AppConstants.roleMember,
            AppConstants.roleModuleLead,
            AppConstants.roleOrgAdmin,
          ].map((r) => DropdownMenuItem(
            value: r,
            child: Text(r.toUpperCase(),
              style: const TextStyle(fontSize: 10, letterSpacing: 1, fontFamily: 'Space Mono')),
          )).toList(),
          onChanged: (v) async {
            if (v == null || v == _selected) return;
            setState(() { _selected = v; _saving = true; });
            try {
              await widget.adminRepo.updateUserRole(widget.user.uid, v);
            } finally {
              if (mounted) setState(() => _saving = false);
            }
          },
        ),
      ),
    );
  }
}

class _ModuleDropdown extends StatefulWidget {
  final UserModel user;
  final List modules;
  final AdminRepository adminRepo;
  const _ModuleDropdown({required this.user, required this.modules, required this.adminRepo});

  @override
  State<_ModuleDropdown> createState() => _ModuleDropdownState();
}

class _ModuleDropdownState extends State<_ModuleDropdown> {
  String? _selected;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _selected = widget.user.moduleId;
  }

  @override
  void didUpdateWidget(covariant _ModuleDropdown oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.user.moduleId != oldWidget.user.moduleId) {
      _selected = widget.user.moduleId;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: AppTheme.bg,
        border: Border.all(color: AppTheme.border),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String?>(
          value: _selected,
          isDense: true,
          isExpanded: true,
          dropdownColor: AppTheme.surface,
          style: const TextStyle(color: AppTheme.textPrimary, fontSize: 11),
          icon: _saving
              ? const SizedBox(width: 14, height: 14,
                  child: CircularProgressIndicator(strokeWidth: 1.5, color: AppTheme.primary))
              : const Icon(Icons.keyboard_arrow_down_rounded,
                  color: AppTheme.textMuted, size: 16),
          items: [
            const DropdownMenuItem(value: null, child: Text('— None —',
              style: TextStyle(color: AppTheme.textDim, fontSize: 10))),
            ...widget.modules.map((m) => DropdownMenuItem(
              value: m.id as String?,
              child: Text(m.name as String,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 10, letterSpacing: 0.5)),
            )),
          ],
          onChanged: (v) async {
            if (v == _selected) return;
            setState(() { _selected = v; _saving = true; });
            try {
              await widget.adminRepo.assignUserToModule(widget.user.uid, v);
            } finally {
              if (mounted) setState(() => _saving = false);
            }
          },
        ),
      ),
    );
  }
}
