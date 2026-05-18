import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/providers/app_providers.dart';
import '../../../../core/providers/auth_provider.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../shared/widgets/shared_widgets.dart';
import '../../../../data/models/task_model.dart';

class TaskScreen extends ConsumerStatefulWidget {
  final String moduleId;
  const TaskScreen({super.key, required this.moduleId});

  @override
  ConsumerState<TaskScreen> createState() => _TaskScreenState();
}

class _TaskScreenState extends ConsumerState<TaskScreen> {
  String _filterPriority = 'ALL';

  @override
  Widget build(BuildContext context) {
    final tasksAsync = ref.watch(tasksProvider(widget.moduleId));
    final userAsync  = ref.watch(currentUserProvider);
    final user       = userAsync.valueOrNull;
    final canEdit    = user?.isLead == true || user?.isOrgAdmin == true;

    return Scaffold(
      backgroundColor: AppTheme.bg,
      appBar: const GlassAppBar(title: 'TASKS', subtitle: 'MODULE CHECKLIST'),
      floatingActionButton: canEdit
          ? FloatingActionButton(
              onPressed: () => _showAddTaskDialog(context, user!),
              child: const Icon(Icons.add, color: AppTheme.bg),
            )
          : null,
      body: Column(
        children: [
          // Priority filter chips
          _PriorityFilter(
            selected: _filterPriority,
            onSelect: (p) => setState(() => _filterPriority = p),
          ),

          Expanded(
            child: tasksAsync.when(
              data: (tasks) {
                final filtered = _filterPriority == 'ALL'
                    ? tasks
                    : tasks.where((t) => t.priority == _filterPriority).toList();

                if (filtered.isEmpty) {
                  return EmptyState(
                    icon: Icons.checklist_rounded,
                    title: 'No Tasks',
                    subtitle: canEdit ? 'Tap + to add tasks' : null,
                  );
                }

                final completed = tasks.where((t) => t.completed).length;
                final total = tasks.length;

                return ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    // Progress summary
                    GlassCard(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text('$completed / $total TASKS COMPLETE',
                                style: Theme.of(context).textTheme.labelMedium),
                              Text('${total > 0 ? (completed / total * 100).toInt() : 0}%',
                                style: const TextStyle(
                                  color: AppTheme.primary, fontSize: 18,
                                  fontWeight: FontWeight.w800, fontFamily: 'Syne',
                                )),
                            ],
                          ),
                          const SizedBox(height: 8),
                          GlassProgressBar(
                            value: total > 0 ? completed / total * 100 : 0,
                            color: AppTheme.primary,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    ...filtered.asMap().entries.map((e) =>
                      _TaskCard(
                        task: e.value,
                        canEdit: canEdit,
                        onToggle: () => ref.read(moduleRepositoryProvider)
                            .toggleTaskCompletion(e.value),
                        onDelete: canEdit
                            ? () => ref.read(moduleRepositoryProvider)
                                .deleteTask(widget.moduleId, e.value.id)
                            : null,
                      ).animate().fadeIn(delay: (e.key * 40).ms),
                    ),
                  ],
                );
              },
              loading: () => const Padding(
                padding: EdgeInsets.all(24),
                child: LoadingCardSkeleton(),
              ),
              error: (e, _) => Center(
                child: Text('$e', style: const TextStyle(color: AppTheme.danger))),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showAddTaskDialog(BuildContext context, user) async {
    final titleCtrl = TextEditingController();
    final descCtrl  = TextEditingController();
    String priority = AppConstants.priorityMedium;
    DateTime? dueDate;

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDState) => AlertDialog(
          title: const Text('NEW TASK'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: titleCtrl,
                  style: const TextStyle(color: AppTheme.textPrimary),
                  decoration: const InputDecoration(labelText: 'Task Title'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: descCtrl,
                  style: const TextStyle(color: AppTheme.textPrimary),
                  decoration: const InputDecoration(labelText: 'Description (optional)'),
                  maxLines: 2,
                ),
                const SizedBox(height: 16),
                Text('PRIORITY', style: Theme.of(context).textTheme.labelSmall),
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
                    );
                    if (picked != null) setDState(() => dueDate = picked);
                  },
                  icon: const Icon(Icons.calendar_today_outlined, size: 16),
                  label: Text(dueDate != null
                    ? 'Due: ${DateFormat('dd MMM yyyy').format(dueDate!)}'
                    : 'SET DUE DATE'),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('CANCEL')),
            ElevatedButton(
              onPressed: () async {
                if (titleCtrl.text.trim().isEmpty) return;
                await ref.read(moduleRepositoryProvider).createTask(TaskModel(
                  id:          '',
                  moduleId:    widget.moduleId,
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

// ── Priority Filter ────────────────────────────────────────────────
class _PriorityFilter extends StatelessWidget {
  final String selected;
  final ValueChanged<String> onSelect;
  const _PriorityFilter({required this.selected, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    final options = ['ALL', AppConstants.priorityBlocker, AppConstants.priorityHigh,
      AppConstants.priorityMedium, AppConstants.priorityLow];
    return Container(
      height: 48,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      color: AppTheme.surface,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: options.map((p) {
          final color = switch (p) {
            'BLOCKER' => AppTheme.danger,
            'HIGH'    => AppTheme.orange,
            'MEDIUM'  => AppTheme.warning,
            'LOW'     => AppTheme.textMuted,
            _          => AppTheme.primary,
          };
          return Padding(
            padding: const EdgeInsets.only(right: 8, top: 8, bottom: 8),
            child: GestureDetector(
              onTap: () => onSelect(p),
              child: AnimatedContainer(
                duration: 150.ms,
                padding: const EdgeInsets.symmetric(horizontal: 14),
                decoration: BoxDecoration(
                  color: selected == p ? color.withAlpha(38) : Colors.transparent,
                  border: Border.all(
                    color: selected == p ? color : AppTheme.border),
                ),
                alignment: Alignment.center,
                child: Text(p,
                  style: TextStyle(
                    color: selected == p ? color : AppTheme.textMuted,
                    fontSize: 10, letterSpacing: 1.5, fontFamily: 'Space Mono',
                  )),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

// ── Task Card ──────────────────────────────────────────────────────
class _TaskCard extends StatelessWidget {
  final TaskModel task;
  final bool canEdit;
  final VoidCallback onToggle;
  final VoidCallback? onDelete;
  const _TaskCard({required this.task, required this.canEdit,
      required this.onToggle, this.onDelete});

  @override
  Widget build(BuildContext context) {
    final isOverdue = task.dueDate != null &&
        !task.completed &&
        task.dueDate!.isBefore(DateTime.now());

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        border: Border(
          left: BorderSide(
            color: task.isBlocker
                ? AppTheme.danger
                : task.isHigh
                    ? AppTheme.orange
                    : AppTheme.border,
            width: 3,
          ),
          top:    const BorderSide(color: AppTheme.border),
          right:  const BorderSide(color: AppTheme.border),
          bottom: const BorderSide(color: AppTheme.border),
        ),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: GestureDetector(
          onTap: onToggle,
          child: AnimatedContainer(
            duration: 200.ms,
            width: 22, height: 22,
            decoration: BoxDecoration(
              color: task.completed ? AppTheme.primary : Colors.transparent,
              border: Border.all(
                color: task.completed ? AppTheme.primary : AppTheme.border2),
            ),
            child: task.completed
                ? const Icon(Icons.check, size: 14, color: AppTheme.bg)
                : null,
          ),
        ),
        title: Text(task.title,
          style: TextStyle(
            color: task.completed ? AppTheme.textMuted : AppTheme.textPrimary,
            fontSize: 13,
            decoration: task.completed ? TextDecoration.lineThrough : null,
          )),
        subtitle: task.dueDate != null
            ? Text(
                'Due: ${DateFormat('dd MMM').format(task.dueDate!)}',
                style: TextStyle(
                  color: isOverdue ? AppTheme.danger : AppTheme.textDim,
                  fontSize: 11,
                ),
              )
            : null,
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            PriorityBadge(priority: task.priority),
            if (onDelete != null) ...[
              const SizedBox(width: 8),
              IconButton(
                icon: const Icon(Icons.delete_outline_rounded, size: 16),
                onPressed: onDelete,
                color: AppTheme.textDim,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
