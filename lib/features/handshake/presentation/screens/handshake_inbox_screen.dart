import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:timeago/timeago.dart' as timeago;
import '../../../../core/theme/app_theme.dart';
import '../../../../core/providers/app_providers.dart';
import '../../../../core/providers/auth_provider.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../shared/widgets/shared_widgets.dart';
import '../../../../data/models/handshake_model.dart';

class HandshakeInboxScreen extends ConsumerWidget {
  const HandshakeInboxScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userAsync = ref.watch(currentUserProvider);
    return userAsync.when(
      data: (user) {
        if (user == null) return const SizedBox();
        final isOrgAdmin = user.role == AppConstants.roleOrgAdmin;
        final targetModuleId = isOrgAdmin ? 'admin' : user.moduleId;

        if (targetModuleId == null) {
          return const Scaffold(
            backgroundColor: AppTheme.bg,
            appBar: GlassAppBar(title: 'HANDSHAKE INBOX'),
            body: EmptyState(
              icon: Icons.inbox_rounded,
              title: 'No Module Assigned',
              subtitle: 'Ask your admin to assign you to a module.',
            ),
          );
        }

        final incomingAsync = ref.watch(incomingHandshakesProvider(targetModuleId));

        return Scaffold(
          backgroundColor: AppTheme.bg,
          appBar: const GlassAppBar(
            title: 'HANDSHAKE INBOX',
            subtitle: 'PENDING HANDSHAKES',
          ),
          body: incomingAsync.when(
            data: (handshakes) {
              if (handshakes.isEmpty) {
                return const EmptyState(
                  icon: Icons.mark_email_read_outlined,
                  title: 'All Clear',
                  subtitle: 'No pending handshakes at this time.',
                );
              }
              return ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: handshakes.length,
                itemBuilder: (_, i) => _HandshakeInboxCard(
                  handshake: handshakes[i],
                  currentUser: user,
                ).animate().fadeIn(delay: (i * 80).ms).slideX(begin: 0.05, end: 0),
              );
            },
            loading: () => const Padding(
              padding: EdgeInsets.all(24),
              child: LoadingCardSkeleton(),
            ),
            error: (e, _) => Center(
              child: Text('$e', style: const TextStyle(color: AppTheme.danger))),
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

class _HandshakeInboxCard extends ConsumerWidget {
  final HandshakeModel handshake;
  final dynamic currentUser;
  const _HandshakeInboxCard({required this.handshake, required this.currentUser});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return GlassCard(
      borderLeftColor: AppTheme.warning,
      borderLeftWidth: 3,
      padding: const EdgeInsets.all(0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  width: 40, height: 40,
                  decoration: BoxDecoration(
                    color: AppTheme.warning.withAlpha(26),
                    border: Border.all(color: AppTheme.warning.withAlpha(77)),
                  ),
                  child: const Icon(Icons.handshake_outlined,
                    color: AppTheme.warning, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('FROM: ${handshake.fromModuleName}',
                        style: const TextStyle(
                          color: AppTheme.warning, fontSize: 11, letterSpacing: 2,
                          fontFamily: 'Space Mono',
                        )),
                      const SizedBox(height: 2),
                      Text(timeago.format(handshake.timestamp),
                        style: const TextStyle(color: AppTheme.textDim, fontSize: 11)),
                    ],
                  ),
                ),
                StatusBadge(label: handshake.status, color: AppTheme.warning),
              ],
            ),
          ),

          // Proof attachment
          if (handshake.proofNote != null && handshake.proofNote!.isNotEmpty)
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.bg,
                border: Border.all(color: AppTheme.border),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.attach_file_rounded,
                    size: 14, color: AppTheme.textMuted),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(handshake.proofNote!,
                      style: const TextStyle(
                        color: AppTheme.textSecondary, fontSize: 12, height: 1.5)),
                  ),
                ],
              ),
            ),

          if (handshake.proofUrl != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: TextButton.icon(
                onPressed: () {},
                icon: const Icon(Icons.open_in_new_rounded, size: 14),
                label: const Text('VIEW ATTACHMENT'),
              ),
            ),

          // Actions
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _reject(context, ref),
                    icon: const Icon(Icons.close_rounded, size: 16, color: AppTheme.danger),
                    label: const Text('REJECT',
                      style: TextStyle(color: AppTheme.danger)),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: AppTheme.danger),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _accept(context, ref),
                    icon: const Icon(Icons.check_rounded, size: 16),
                    label: const Text('ACCEPT'),
                    style: ElevatedButton.styleFrom(backgroundColor: AppTheme.success),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _accept(BuildContext context, WidgetRef ref) async {
    await ref.read(handshakeRepositoryProvider).acceptHandshake(
      handshake.id,
      currentUser.uid,
      currentUser.name,
    );
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('✓ Handshake accepted')));
    }
  }

  Future<void> _reject(BuildContext context, WidgetRef ref) async {
    final reasonCtrl = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('REJECT HANDSHAKE'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Provide a reason for rejection:',
              style: TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
            const SizedBox(height: 12),
            TextField(
              controller: reasonCtrl,
              style: const TextStyle(color: AppTheme.textPrimary),
              decoration: const InputDecoration(
                hintText: 'e.g. Missing test coverage',
                hintStyle: TextStyle(color: AppTheme.textDim),
              ),
              maxLines: 3,
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('CANCEL')),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.danger),
            child: const Text('REJECT'),
          ),
        ],
      ),
    );
    if (confirmed == true && context.mounted) {
      await ref.read(handshakeRepositoryProvider).rejectHandshake(
        handshake.id,
        currentUser.uid,
        currentUser.name,
        reasonCtrl.text.trim(),
      );
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Handshake rejected')));
      }
    }
  }
}
