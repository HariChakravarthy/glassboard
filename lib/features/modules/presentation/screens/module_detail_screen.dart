import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/providers/app_providers.dart';
import '../../../../core/providers/auth_provider.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../shared/widgets/shared_widgets.dart';
import '../../../../data/models/module_model.dart';
import '../../../../data/models/task_model.dart';
import 'package:intl/intl.dart';

class ModuleDetailScreen extends ConsumerWidget {
  final String moduleId;
  const ModuleDetailScreen({super.key, required this.moduleId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final moduleAsync = ref.watch(moduleDetailProvider(moduleId));
    final tasksAsync  = ref.watch(tasksProvider(moduleId));
    final userAsync   = ref.watch(currentUserProvider);
    final liveProgress = ref.watch(moduleLiveProgressProvider(moduleId)).valueOrNull;

    debugPrint('=== ModuleDetailScreen: moduleId=$moduleId ===');
    debugPrint('  moduleAsync: hasValue=${moduleAsync.hasValue}, hasError=${moduleAsync.hasError}, error=${moduleAsync.error}, value=${moduleAsync.valueOrNull}');
    debugPrint('  tasksAsync: hasValue=${tasksAsync.hasValue}, hasError=${tasksAsync.hasError}, error=${tasksAsync.error}');
    debugPrint('  userAsync: hasValue=${userAsync.hasValue}, hasError=${userAsync.hasError}, error=${userAsync.error}');
    debugPrint('  liveProgress: $liveProgress');

    return Scaffold(
      backgroundColor: AppTheme.bg,
      appBar: GlassAppBar(
        title: 'MODULE',
        subtitle: moduleAsync.valueOrNull?.name ?? '',
        actions: [
          if (userAsync.valueOrNull?.isOrgAdmin == true)
            PopupMenuButton<String>(
              color: AppTheme.surface,
              onSelected: (v) async {
                if (v == 'status') {
                  _showStatusDialog(context, ref, moduleAsync.valueOrNull);
                }
              },
              itemBuilder: (_) => [
                const PopupMenuItem(value: 'status', child: Text('Change Status')),
              ],
              icon: const Icon(Icons.more_vert_rounded, color: AppTheme.textSecondary),
            ),
        ],
      ),
      floatingActionButton: _buildFab(context, ref, userAsync.valueOrNull, moduleAsync.valueOrNull),
      body: moduleAsync.when(
        data: (module) {
          try {
            if (module == null) {
              return const Center(child: Text('Module not found', style: TextStyle(color: AppTheme.textMuted)));
            }

            final progress = module.progress;
            final statusColor = _statusColor(module.status);

            return ListView(
              padding: const EdgeInsets.all(20),
              children: [
              // ── Progress Card ──────────────────────────────────────
              GlassCard(
                borderLeftColor: statusColor,
                borderLeftWidth: 4,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(module.name,
                            style: Theme.of(context).textTheme.headlineMedium),
                        ),
                        StatusBadge(
                          label: module.status.replaceAll('_', ' '),
                          color: statusColor,
                        ),
                      ],
                    ),
                    if (module.description != null && module.description!.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text(module.description!,
                        style: Theme.of(context).textTheme.bodyMedium),
                    ],
                    const SizedBox(height: 20),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('COMPLETION',
                          style: Theme.of(context).textTheme.labelSmall),
                        Text('${progress.toInt()}%',
                          style: TextStyle(
                            color: statusColor,
                            fontSize: 20, fontWeight: FontWeight.w800,
                            fontFamily: 'Syne',
                          )),
                      ],
                    ),
                    const SizedBox(height: 8),
                    GlassProgressBar(value: progress, color: statusColor, height: 8),
                  ],
                ),
              ).animate().fadeIn(duration: 400.ms),
              const SizedBox(height: 20),

              // ── Checklist ──────────────────────────────────────────
              Row(
                children: [
                  const Expanded(
                    child: SectionHeader(
                      label: 'Checklist',
                      title: 'Tasks',
                      accentColor: AppTheme.primary,
                    ),
                  ),
                  if (userAsync.valueOrNull?.isLead == true || userAsync.valueOrNull?.isOrgAdmin == true) ...[
                    OutlinedButton.icon(
                      onPressed: () => _showAddTaskDialog(context, ref, userAsync.valueOrNull!),
                      icon: const Icon(Icons.add_rounded, size: 14),
                      label: const Text('ADD TASK'),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        textStyle: const TextStyle(fontSize: 10, letterSpacing: 1.5),
                      ),
                    ),
                    const SizedBox(width: 8),
                  ],
                  OutlinedButton.icon(
                    onPressed: () => context.push('/modules/$moduleId/tasks'),
                    icon: const Icon(Icons.open_in_new_rounded, size: 14),
                    label: const Text('MANAGE'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      textStyle: const TextStyle(fontSize: 10, letterSpacing: 1.5),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              tasksAsync.when(
                data: (tasks) {
                  if (tasks.isEmpty) {
                    return const EmptyState(
                      icon: Icons.checklist_rounded,
                      title: 'No tasks yet',
                      subtitle: 'Tap Manage to add checklist items',
                    );
                  }
                  return Column(
                    children: tasks.asMap().entries.map((e) {
                      final task = e.value;
                      return Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        decoration: BoxDecoration(
                          color: AppTheme.surface,
                          border: Border.all(color: AppTheme.border),
                        ),
                        child: ListTile(
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 4),
                          leading: GestureDetector(
                            onTap: () => ref.read(moduleRepositoryProvider)
                                .toggleTaskCompletion(task),
                            child: AnimatedContainer(
                              duration: 200.ms,
                              width: 22, height: 22,
                              decoration: BoxDecoration(
                                color: task.completed
                                    ? AppTheme.primary
                                    : Colors.transparent,
                                border: Border.all(
                                  color: task.completed
                                      ? AppTheme.primary
                                      : AppTheme.border2,
                                ),
                              ),
                              child: task.completed
                                  ? const Icon(Icons.check, size: 14, color: AppTheme.bg)
                                  : null,
                            ),
                          ),
                          title: Text(task.title,
                            style: TextStyle(
                              color: task.completed
                                  ? AppTheme.textMuted
                                  : AppTheme.textPrimary,
                              fontSize: 13,
                              decoration: task.completed
                                  ? TextDecoration.lineThrough
                                  : null,
                            )),
                          trailing: PriorityBadge(priority: task.priority),
                        ),
                      ).animate().fadeIn(delay: (e.key * 50).ms);
                    }).toList(),
                  );
                },
                loading: () => const LoadingCardSkeleton(),
                error: (e, _) => Text('$e', style: const TextStyle(color: AppTheme.danger)),
              ),

              const SizedBox(height: 24),

              // ── Handshake History ──────────────────────────────────
              const SectionHeader(
                label: 'Digital Handshakes',
                title: 'History',
                accentColor: AppTheme.warning,
              ),
              const SizedBox(height: 12),
              _HandshakeHistoryWidget(moduleId: moduleId),
            ],
          );
          } catch (e, stack) {
            debugPrint('ERROR building module detail screen: $e');
            debugPrint(stack.toString());
            return Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Text('Error rendering UI: $e\n\n$stack',
                  style: const TextStyle(color: AppTheme.danger, fontSize: 12)),
              ),
            );
          }
        },
        loading: () {
          try {
            return const Padding(
              padding: EdgeInsets.all(24),
              child: LoadingCardSkeleton(),
            );
          } catch (e, stack) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text('Error in loading skeleton: $e\n\n$stack',
                  style: const TextStyle(color: AppTheme.danger, fontSize: 12)),
              ),
            );
          }
        },
        error: (e, stack) {
          try {
            return Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Text('Stream Error: $e\n\n$stack',
                  style: const TextStyle(color: AppTheme.danger, fontSize: 12)),
              ),
            );
          } catch (err) {
            return Center(
              child: Text('Critical Error: $err',
                style: const TextStyle(color: AppTheme.danger)),
            );
          }
        },
      ),
    );
  }

  Widget? _buildFab(BuildContext context, WidgetRef ref, user, ModuleModel? module) {
    if (user == null || module == null) return null;
    if (!user.isLead && !user.isOrgAdmin) return null;

    return FloatingActionButton.extended(
      onPressed: () => context.push('/modules/$moduleId/handshake/initiate'),
      icon: const Icon(Icons.send_rounded, size: 18, color: AppTheme.bg),
      label: const Text('SEND HANDSHAKE',
        style: TextStyle(color: AppTheme.bg, fontSize: 11, letterSpacing: 2)),
    );
  }

  Color _statusColor(String status) => switch (status) {
    AppConstants.statusComplete   => AppTheme.success,
    AppConstants.statusInProgress => AppTheme.warning,
    AppConstants.statusReview     => AppTheme.purple,
    _                              => AppTheme.textMuted,
  };

  void _showStatusDialog(BuildContext context, WidgetRef ref, ModuleModel? module) {
    if (module == null) return;
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('UPDATE STATUS'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AppConstants.statusNotStarted,
            AppConstants.statusInProgress,
            AppConstants.statusReview,
            AppConstants.statusComplete,
          ].map((s) => ListTile(
            title: Text(s.replaceAll('_', ' '),
              style: const TextStyle(color: AppTheme.textPrimary, fontSize: 13)),
            selected: module.status == s,
            selectedColor: AppTheme.primary,
            onTap: () async {
              await ref.read(moduleRepositoryProvider)
                  .updateModuleStatus(module.id, s);
              if (context.mounted) Navigator.pop(context);
            },
          )).toList(),
        ),
      ),
    );
  }

  Future<void> _showAddTaskDialog(BuildContext context, WidgetRef ref, dynamic user) async {
    final titleCtrl = TextEditingController();
    final descCtrl  = TextEditingController();
    String priority = AppConstants.priorityMedium;
    DateTime? dueDate;

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDState) => AlertDialog(
          backgroundColor: AppTheme.surface,
          title: const Text('NEW TASK', style: TextStyle(color: AppTheme.textPrimary, fontFamily: 'Syne')),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: titleCtrl,
                  style: const TextStyle(color: AppTheme.textPrimary),
                  decoration: const InputDecoration(
                    labelText: 'Task Title',
                    labelStyle: TextStyle(color: AppTheme.textMuted),
                    enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: AppTheme.border)),
                    focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: AppTheme.primary)),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: descCtrl,
                  style: const TextStyle(color: AppTheme.textPrimary),
                  decoration: const InputDecoration(
                    labelText: 'Description (optional)',
                    labelStyle: TextStyle(color: AppTheme.textMuted),
                    enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: AppTheme.border)),
                    focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: AppTheme.primary)),
                  ),
                  maxLines: 2,
                ),
                const SizedBox(height: 16),
                Text('PRIORITY', style: Theme.of(context).textTheme.labelSmall?.copyWith(color: AppTheme.textMuted)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  children: [
                    AppConstants.priorityLow,
                    AppConstants.priorityMedium,
                    AppConstants.priorityHigh,
                    AppConstants.priorityBlocker,
                  ].map((p) {
                    final color = switch (p) {
                      'BLOCKER' => AppTheme.danger,
                      'HIGH'    => AppTheme.orange,
                      'MEDIUM'  => AppTheme.warning,
                      _         => AppTheme.textMuted,
                    };
                    return ChoiceChip(
                      label: Text(p,
                        style: TextStyle(
                          color: priority == p ? color : AppTheme.textMuted,
                          fontSize: 10, letterSpacing: 1,
                        )),
                      selected: priority == p,
                      onSelected: (_) => setDState(() => priority = p),
                      selectedColor: color.withAlpha(31),
                      side: BorderSide(color: priority == p ? color : AppTheme.border),
                      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 12),
                TextButton.icon(
                  onPressed: () async {
                    final picked = await showDatePicker(
                      context: ctx,
                      initialDate: DateTime.now().add(const Duration(days: 3)),
                      firstDate: DateTime.now(),
                      lastDate: DateTime.now().add(const Duration(days: 365)),
                      builder: (context, child) {
                        return Theme(
                          data: Theme.of(context).copyWith(
                            colorScheme: const ColorScheme.dark(
                              primary: AppTheme.primary,
                              onPrimary: AppTheme.bg,
                              surface: AppTheme.surface,
                              onSurface: AppTheme.textPrimary,
                            ),
                            dialogTheme: const DialogThemeData(backgroundColor: AppTheme.surface),
                          ),
                          child: child!,
                        );
                      },
                    );
                    if (picked != null) setDState(() => dueDate = picked);
                  },
                  icon: const Icon(Icons.calendar_today_outlined, size: 16, color: AppTheme.primary),
                  label: Text(dueDate != null
                    ? 'Due: ${DateFormat('dd MMM yyyy').format(dueDate!)}'
                    : 'SET DUE DATE',
                    style: const TextStyle(color: AppTheme.primary),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('CANCEL', style: TextStyle(color: AppTheme.textMuted)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primary,
                foregroundColor: AppTheme.bg,
              ),
              onPressed: () async {
                if (titleCtrl.text.trim().isEmpty) return;
                await ref.read(moduleRepositoryProvider).createTask(TaskModel(
                  id:          '',
                  moduleId:    moduleId,
                  title:       titleCtrl.text.trim(),
                  assignedTo:  user.uid,
                  priority:    priority,
                  completed:   false,
                  dueDate:     dueDate,
                  description: descCtrl.text.trim(),
                  createdAt:   DateTime.now(),
                ));
                if (ctx.mounted) Navigator.pop(ctx);
              },
              child: const Text('ADD TASK'),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Handshake History Widget ────────────────────────────────────────
class _HandshakeHistoryWidget extends ConsumerWidget {
  final String moduleId;
  const _HandshakeHistoryWidget({required this.moduleId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final handshakesAsync = ref.watch(moduleHandshakesProvider(moduleId));
    return handshakesAsync.when(
      data: (handshakes) {
        if (handshakes.isEmpty) {
          return const EmptyState(
            icon: Icons.handshake_outlined,
            title: 'No Handshakes Yet',
            subtitle: 'Initiate one when your checklist is complete.',
          );
        }
        return Column(
          children: handshakes.take(5).map((h) {
            final color = h.isAccepted
                ? AppTheme.success
                : h.isRejected
                    ? AppTheme.danger
                    : AppTheme.warning;
            return GlassCard(
              padding: const EdgeInsets.all(14),
              borderLeftColor: color,
              borderLeftWidth: 3,
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('${h.fromModuleName} → ${h.toModuleName}',
                          style: const TextStyle(
                            color: AppTheme.textPrimary, fontSize: 12, fontWeight: FontWeight.w600)),
                        const SizedBox(height: 4),
                        Text(h.timestamp.toString().substring(0, 16),
                          style: const TextStyle(color: AppTheme.textDim, fontSize: 10)),
                      ],
                    ),
                  ),
                  StatusBadge(label: h.status, color: color),
                ],
              ),
            );
          }).toList(),
        );
      },
      loading: () => const LoadingCardSkeleton(),
      error: (e, _) => const SizedBox(),
    );
  }
}
