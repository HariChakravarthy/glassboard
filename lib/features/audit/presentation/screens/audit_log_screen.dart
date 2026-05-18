import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart' show Share, XFile;
import '../../../../core/theme/app_theme.dart';
import '../../../../core/providers/app_providers.dart';
import '../../../../core/providers/auth_provider.dart';
import '../../../../shared/widgets/shared_widgets.dart';
import '../../../../data/models/audit_model.dart';

class AuditLogScreen extends ConsumerStatefulWidget {
  const AuditLogScreen({super.key});

  @override
  ConsumerState<AuditLogScreen> createState() => _AuditLogScreenState();
}

class _AuditLogScreenState extends ConsumerState<AuditLogScreen> {
  String _filterAction = '';
  String _filterModule = '';
  bool _exporting = false;

  Future<void> _exportCsv(List<AuditLogModel> logs) async {
    setState(() => _exporting = true);
    try {
      final buf = StringBuffer();
      buf.writeln('Timestamp,Action,Actor,Module,Details');
      for (final l in logs) {
        final ts   = DateFormat('yyyy-MM-dd HH:mm:ss').format(l.timestamp);
        final actor = l.actorName.isNotEmpty ? l.actorName : l.actorId.substring(0, 8);
        final meta  = l.metadata.entries.map((e) => '${e.key}=${e.value}').join('; ');
        buf.writeln('"$ts","${l.action}","$actor","${l.targetModule}","$meta"');
      }
      final dir  = await getTemporaryDirectory();
      final file = File('${dir.path}/glassboard_audit_${DateTime.now().millisecondsSinceEpoch}.csv');
      await file.writeAsString(buf.toString());
      await Share.shareXFiles(
        [XFile(file.path)],
        text: 'Glassboard Audit Log Export',
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Export failed: $e'), backgroundColor: AppTheme.danger));
      }
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final userAsync = ref.watch(currentUserProvider);
    final user = userAsync.valueOrNull;

    // Only admins should see full audit
    if (user != null && !user.isOrgAdmin) {
      return const Scaffold(
        backgroundColor: AppTheme.bg,
        appBar: GlassAppBar(title: 'AUDIT LOG'),
        body: EmptyState(
          icon: Icons.lock_outline_rounded,
          title: 'Admin Access Only',
          subtitle: 'Contact your org admin to view the audit log.',
        ),
      );
    }

    final auditAsync = ref.watch(auditLogProvider);
    final logs = auditAsync.valueOrNull ?? [];
    var filtered = logs;
    if (_filterAction.isNotEmpty) {
      filtered = filtered.where((l) =>
        l.action.contains(_filterAction.toUpperCase())).toList();
    }
    if (_filterModule.isNotEmpty) {
      filtered = filtered.where((l) =>
        l.targetModule.toLowerCase().contains(_filterModule.toLowerCase())).toList();
    }

    return Scaffold(
      backgroundColor: AppTheme.bg,
      appBar: GlassAppBar(
        title: 'AUDIT LOG',
        subtitle: 'IMMUTABLE RECORD',
        accentColor: AppTheme.success,
        actions: [
          IconButton(
            icon: _exporting
                ? const SizedBox(width: 18, height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.success))
                : const Icon(Icons.download_rounded, size: 20),
            tooltip: 'Export CSV',
            onPressed: _exporting || filtered.isEmpty ? null : () => _exportCsv(filtered),
            color: AppTheme.success,
          ),
          IconButton(
            icon: const Icon(Icons.filter_list_rounded, size: 20),
            onPressed: () => _showFilterSheet(context),
            color: AppTheme.textSecondary,
          ),
        ],
      ),
      body: auditAsync.when(
        data: (_) {          if (filtered.isEmpty) {
            return const EmptyState(
              icon: Icons.receipt_long_outlined,
              title: 'No Audit Entries',
              subtitle: 'Actions will appear here as they happen.',
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: filtered.length,
            itemBuilder: (_, i) => _AuditCard(log: filtered[i])
                .animate().fadeIn(delay: (i * 30).ms),
          );
        },
        loading: () => const Padding(
          padding: EdgeInsets.all(24), child: LoadingCardSkeleton()),
        error: (e, _) => Center(
          child: Text('$e', style: const TextStyle(color: AppTheme.danger))),
      ),
    );
  }

  void _showFilterSheet(BuildContext context) {
    final actionCtrl = TextEditingController(text: _filterAction);
    final moduleCtrl = TextEditingController(text: _filterModule);
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.surface,
      builder: (_) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('FILTER AUDIT LOG',
              style: Theme.of(context).textTheme.labelMedium),
            const SizedBox(height: 16),
            TextField(
              controller: actionCtrl,
              style: const TextStyle(color: AppTheme.textPrimary),
              decoration: const InputDecoration(labelText: 'Action (e.g. HANDSHAKE)'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: moduleCtrl,
              style: const TextStyle(color: AppTheme.textPrimary),
              decoration: const InputDecoration(labelText: 'Module ID or Name'),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () {
                      setState(() { _filterAction = ''; _filterModule = ''; });
                      Navigator.pop(context);
                    },
                    child: const Text('CLEAR'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      setState(() {
                        _filterAction = actionCtrl.text;
                        _filterModule = moduleCtrl.text;
                      });
                      Navigator.pop(context);
                    },
                    child: const Text('APPLY'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _AuditCard extends StatelessWidget {
  final AuditLogModel log;
  const _AuditCard({required this.log});

  Color get _actionColor => switch (log.action) {
    String a when a.contains('ACCEPTED') => AppTheme.success,
    String a when a.contains('REJECTED') => AppTheme.danger,
    String a when a.contains('HANDSHAKE') => AppTheme.warning,
    String a when a.contains('FILE') => AppTheme.purple,
    _ => AppTheme.textMuted,
  };

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        border: Border(
          left: BorderSide(color: _actionColor, width: 2),
          top:    const BorderSide(color: AppTheme.border),
          right:  const BorderSide(color: AppTheme.border),
          bottom: const BorderSide(color: AppTheme.border),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(log.action,
                    style: TextStyle(
                      color: _actionColor,
                      fontSize: 11, letterSpacing: 2,
                      fontFamily: 'Space Mono', fontWeight: FontWeight.w700,
                    )),
                  const SizedBox(height: 4),
                  Text('Actor: ${log.actorName.isNotEmpty ? log.actorName : log.actorId.substring(0, 8)}',
                    style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
                  if (log.targetModule.isNotEmpty)
                    Text('Module: ${log.targetModule}',
                      style: const TextStyle(color: AppTheme.textDim, fontSize: 11)),
                ],
              ),
            ),
            Text(DateFormat('dd MMM HH:mm').format(log.timestamp),
              style: const TextStyle(color: AppTheme.textDim, fontSize: 10)),
          ],
        ),
      ),
    );
  }
}
