import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/providers/app_providers.dart';
import '../../../../core/providers/auth_provider.dart';
import '../../../../shared/widgets/shared_widgets.dart';
import '../../../../data/models/handshake_model.dart';
import '../../../../data/models/module_model.dart';

class InitiateHandshakeScreen extends ConsumerStatefulWidget {
  final String fromModuleId;
  const InitiateHandshakeScreen({super.key, required this.fromModuleId});

  @override
  ConsumerState<InitiateHandshakeScreen> createState() =>
      _InitiateHandshakeScreenState();
}

class _InitiateHandshakeScreenState
    extends ConsumerState<InitiateHandshakeScreen> {
  String? _selectedToModuleId;
  String? _selectedToModuleName;
  final _noteCtrl = TextEditingController();
  bool _sending = false;
  File? _proofFile;
  String? _proofFileName;

  @override
  void dispose() {
    _noteCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final modulesAsync = ref.watch(allModulesProvider);
    final userAsync    = ref.watch(currentUserProvider);
    final user         = userAsync.valueOrNull;

    return Scaffold(
      backgroundColor: AppTheme.bg,
      appBar: const GlassAppBar(
        title: 'SEND HANDSHAKE',
        subtitle: 'INITIATE DIGITAL HANDOFF',
        accentColor: AppTheme.warning,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Checklist gate warning
            _ChecklistGateWidget(moduleId: widget.fromModuleId),
            const SizedBox(height: 20),

            // From module chip
            GlassCard(
              padding: const EdgeInsets.all(16),
              borderLeftColor: AppTheme.primary,
              borderLeftWidth: 3,
              child: Row(
                children: [
                  const Icon(Icons.arrow_forward_rounded, color: AppTheme.primary, size: 18),
                  const SizedBox(width: 10),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('FROM MODULE',
                        style: Theme.of(context).textTheme.labelSmall),
                      const SizedBox(height: 2),
                      Text(widget.fromModuleId,
                        style: Theme.of(context).textTheme.titleMedium),
                    ],
                  ),
                ],
              ),
            ).animate().fadeIn(),
            const SizedBox(height: 20),

            // Select receiving module
            Text('SELECT RECEIVING MODULE',
              style: Theme.of(context).textTheme.labelSmall),
            const SizedBox(height: 10),

            modulesAsync.when(
              data: (modules) {
                final others = modules
                    .where((m) => m.id != widget.fromModuleId)
                    .toList();
                if (others.isEmpty) {
                  return const EmptyState(
                    icon: Icons.device_hub_outlined,
                    title: 'No Other Modules',
                    subtitle: 'Create more modules to send handshakes.',
                  );
                }
                return Column(
                  children: others.map((m) =>
                    _ModulePickCard(
                      module: m,
                      selected: _selectedToModuleId == m.id,
                      onTap: () => setState(() {
                        _selectedToModuleId   = m.id;
                        _selectedToModuleName = m.name;
                      }),
                    ).animate().fadeIn(delay: 80.ms),
                  ).toList(),
                );
              },
              loading: () => const LoadingCardSkeleton(),
              error: (e, _) => Text('$e',
                style: const TextStyle(color: AppTheme.danger)),
            ),

            const SizedBox(height: 20),

            // Proof note
            Text('PROOF / DELIVERY NOTE',
              style: Theme.of(context).textTheme.labelSmall),
            const SizedBox(height: 10),
            TextFormField(
              controller: _noteCtrl,
              style: const TextStyle(color: AppTheme.textPrimary, fontSize: 13),
              maxLines: 4,
              decoration: const InputDecoration(
                hintText:
                    'Describe what is being handed off. Include links, notes, or attach evidence.',
                hintStyle: TextStyle(color: AppTheme.textDim),
              ),
            ),
            const SizedBox(height: 16),

            // Proof file attachment
            Text('ATTACH PROOF FILE (OPTIONAL)',
              style: Theme.of(context).textTheme.labelSmall),
            const SizedBox(height: 10),
            GestureDetector(
              onTap: _pickProofFile,
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppTheme.surface,
                  border: Border.all(
                    color: _proofFile != null ? AppTheme.success : AppTheme.border,
                    style: BorderStyle.solid,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      _proofFile != null
                          ? Icons.check_circle_outline_rounded
                          : Icons.attach_file_rounded,
                      color: _proofFile != null ? AppTheme.success : AppTheme.textMuted,
                      size: 20,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        _proofFileName ?? 'Tap to attach image, PDF, or document',
                        style: TextStyle(
                          color: _proofFile != null
                              ? AppTheme.textPrimary
                              : AppTheme.textDim,
                          fontSize: 12,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (_proofFile != null)
                      GestureDetector(
                        onTap: () => setState(() { _proofFile = null; _proofFileName = null; }),
                        child: const Icon(Icons.close_rounded,
                            color: AppTheme.textMuted, size: 16),
                      ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 32),

            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: (_sending || _selectedToModuleId == null || user == null)
                    ? null
                    : () => _send(user),
                icon: _sending
                    ? const SizedBox(width: 16, height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.bg))
                    : const Icon(Icons.send_rounded, size: 16, color: AppTheme.bg),
                label: Text(_sending ? 'SENDING...' : 'SEND HANDSHAKE'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickProofFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['jpg', 'jpeg', 'png', 'pdf', 'doc', 'docx', 'txt'],
    );
    if (result != null && result.files.isNotEmpty && result.files.first.path != null) {
      setState(() {
        _proofFile     = File(result.files.first.path!);
        _proofFileName = result.files.first.name;
      });
    }
  }

  Future<void> _send(user) async {
    // Verify checklist completion
    final allDone = await ref.read(moduleRepositoryProvider)
        .allTasksComplete(widget.fromModuleId);
    if (!allDone && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('⚠ Complete all checklist tasks before sending'),
          backgroundColor: AppTheme.danger,
        ),
      );
      return;
    }

    setState(() => _sending = true);

    // Fetch from module name
    final fromModule = await ref.read(moduleRepositoryProvider)
        .getModule(widget.fromModuleId);

    // Upload proof file if attached
    String? proofUrl;
    String proofType = 'text';
    if (_proofFile != null) {
      try {
        final ext = _proofFileName?.split('.').last ?? 'bin';
        proofUrl = await ref.read(fileRepositoryProvider)
            .uploadProofFile(_proofFile!, 'handshake_proof_${DateTime.now().millisecondsSinceEpoch}.$ext');
        proofType = ext == 'png' || ext == 'jpg' || ext == 'jpeg' ? 'image' : 'document';
      } catch (_) { /* non-fatal — continue without attachment */ }
    }

    await ref.read(handshakeRepositoryProvider).initiateHandshake(
      HandshakeModel(
        id:             '',
        fromModule:     widget.fromModuleId,
        fromModuleName: fromModule.name,
        toModule:       _selectedToModuleId!,
        toModuleName:   _selectedToModuleName!,
        status:         'PENDING',
        proofNote:      _noteCtrl.text.trim(),
        proofUrl:       proofUrl,
        proofType:      proofType,
        initiatedBy:    user.uid,
        timestamp:      DateTime.now(),
      ),
    );

    setState(() => _sending = false);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('✓ Handshake sent successfully')));
      Navigator.of(context).pop();
    }
  }
}

class _ModulePickCard extends StatelessWidget {
  final ModuleModel module;
  final bool selected;
  final VoidCallback onTap;
  const _ModulePickCard({required this.module, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: 150.ms,
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: selected
              ? AppTheme.warning.withAlpha(20)
              : AppTheme.surface,
          border: Border.all(
            color: selected ? AppTheme.warning : AppTheme.border,
          ),
        ),
        child: Row(
          children: [
            Icon(
              selected ? Icons.radio_button_checked : Icons.radio_button_off,
              color: selected ? AppTheme.warning : AppTheme.textDim,
              size: 18,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(module.name,
                style: TextStyle(
                  color: selected ? AppTheme.textPrimary : AppTheme.textSecondary,
                  fontSize: 13, fontWeight: FontWeight.w500,
                )),
            ),
            StatusBadge(
              label: module.status.replaceAll('_', ' '),
              color: AppTheme.textMuted,
            ),
          ],
        ),
      ),
    );
  }
}

class _ChecklistGateWidget extends ConsumerWidget {
  final String moduleId;
  const _ChecklistGateWidget({required this.moduleId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tasksAsync = ref.watch(tasksProvider(moduleId));
    return tasksAsync.when(
      data: (tasks) {
        if (tasks.isEmpty) return const SizedBox();
        final allDone = tasks.every((t) => t.completed);
        if (allDone) {
          return Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppTheme.success.withAlpha(20),
              border: Border.all(color: AppTheme.success.withAlpha(102)),
            ),
            child: Row(
              children: [
                const Icon(Icons.check_circle_outline_rounded,
                  color: AppTheme.success, size: 18),
                const SizedBox(width: 8),
                Text('All ${tasks.length} checklist tasks complete — ready to handshake.',
                  style: const TextStyle(color: AppTheme.success, fontSize: 12)),
              ],
            ),
          );
        }
        final remaining = tasks.where((t) => !t.completed).length;
        return Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppTheme.danger.withAlpha(20),
            border: Border.all(color: AppTheme.danger.withAlpha(102)),
          ),
          child: Row(
            children: [
              const Icon(Icons.warning_amber_rounded,
                color: AppTheme.danger, size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text('$remaining task(s) still incomplete. Handshake will be blocked on send.',
                  style: const TextStyle(color: AppTheme.danger, fontSize: 12)),
              ),
            ],
          ),
        );
      },
      loading: () => const SizedBox(),
      error: (_, __) => const SizedBox(),
    );
  }
}
