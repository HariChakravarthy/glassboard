import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:timeago/timeago.dart' as timeago;
import '../../../../core/theme/app_theme.dart';
import '../../../../core/providers/app_providers.dart';
import '../../../../shared/widgets/shared_widgets.dart';

class HandshakeDetailScreen extends ConsumerWidget {
  final String handshakeId;
  const HandshakeDetailScreen({super.key, required this.handshakeId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // We'll fetch handshake details from the allHandshakes stream
    final allAsync = ref.watch(allHandshakesProvider);
    return allAsync.when(
      data: (all) {
        final handshake = all.where((h) => h.id == handshakeId).firstOrNull;
        if (handshake == null) {
          return const Scaffold(
            backgroundColor: AppTheme.bg,
            appBar: GlassAppBar(title: 'HANDSHAKE DETAIL'),
            body: EmptyState(icon: Icons.search_off_rounded, title: 'Not Found'),
          );
        }

        final color = handshake.isAccepted
            ? AppTheme.success
            : handshake.isRejected
                ? AppTheme.danger
                : AppTheme.warning;

        return Scaffold(
          backgroundColor: AppTheme.bg,
          appBar: GlassAppBar(
            title: 'HANDSHAKE',
            subtitle: handshake.status,
            accentColor: color,
          ),
          body: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              // Status card
              GlassCard(
                borderLeftColor: color,
                borderLeftWidth: 4,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          handshake.isAccepted
                              ? Icons.check_circle_rounded
                              : handshake.isRejected
                                  ? Icons.cancel_rounded
                                  : Icons.pending_rounded,
                          color: color, size: 24,
                        ),
                        const SizedBox(width: 10),
                        StatusBadge(label: handshake.status, color: color),
                      ],
                    ),
                    const SizedBox(height: 16),
                    _InfoRow('FROM', handshake.fromModuleName, AppTheme.primary),
                    const SizedBox(height: 8),
                    _InfoRow('TO', handshake.toModuleName, AppTheme.purple),
                    const SizedBox(height: 8),
                    _InfoRow('SENT', timeago.format(handshake.timestamp), AppTheme.textMuted),
                    if (handshake.respondedAt != null) ...[
                      const SizedBox(height: 8),
                      _InfoRow('RESPONDED',
                        timeago.format(handshake.respondedAt!), color),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Proof
              if (handshake.proofNote != null && handshake.proofNote!.isNotEmpty)
                GlassCard(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('DELIVERY NOTE',
                        style: Theme.of(context).textTheme.labelSmall),
                      const SizedBox(height: 10),
                      Text(handshake.proofNote!,
                        style: Theme.of(context).textTheme.bodyMedium!.copyWith(
                          height: 1.6, color: AppTheme.textSecondary)),
                    ],
                  ),
                ),

              // Rejection reason
              if (handshake.isRejected && handshake.rejectionReason != null) ...[
                const SizedBox(height: 16),
                GlassCard(
                  borderLeftColor: AppTheme.danger,
                  borderLeftWidth: 3,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('REJECTION REASON',
                        style: Theme.of(context).textTheme.labelSmall!.copyWith(
                          color: AppTheme.danger)),
                      const SizedBox(height: 8),
                      Text(handshake.rejectionReason!,
                        style: Theme.of(context).textTheme.bodyMedium),
                    ],
                  ),
                ),
              ],
            ],
          ),
        );
      },
      loading: () => const Scaffold(
        backgroundColor: AppTheme.bg,
        body: Center(child: CircularProgressIndicator(color: AppTheme.primary)),
      ),
      error: (e, _) => const Scaffold(backgroundColor: AppTheme.bg),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  const _InfoRow(this.label, this.value, this.color);

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(
          width: 90,
          child: Text(label,
            style: const TextStyle(
              color: AppTheme.textDim, fontSize: 10, letterSpacing: 2,
              fontFamily: 'Space Mono',
            )),
        ),
        Expanded(
          child: Text(value,
            style: TextStyle(color: color, fontSize: 13, fontWeight: FontWeight.w500)),
        ),
      ],
    );
  }
}
