import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/providers/app_providers.dart';
import '../../../../core/providers/auth_provider.dart';
import '../../../../shared/widgets/shared_widgets.dart';
import '../../../../data/models/task_model.dart';

// ── Providers ────────────────────────────────────────────────────────
final _commentsProvider =
    StreamProvider.autoDispose.family<List<Map<String, dynamic>>, ({String moduleId, String taskId})>(
  (ref, args) {
    ref.watch(authStateProvider);
    return ref
        .watch(moduleRepositoryProvider)
        .watchTaskComments(args.moduleId, args.taskId);
  },
);

final _attachmentsProvider =
    StreamProvider.autoDispose.family<List<Map<String, dynamic>>, ({String moduleId, String taskId})>(
  (ref, args) {
    ref.watch(authStateProvider);
    return ref
        .watch(moduleRepositoryProvider)
        .watchTaskAttachments(args.moduleId, args.taskId);
  },
);

// ── Screen ───────────────────────────────────────────────────────────
class TaskDetailScreen extends ConsumerStatefulWidget {
  final TaskModel task;
  const TaskDetailScreen({super.key, required this.task});

  @override
  ConsumerState<TaskDetailScreen> createState() => _TaskDetailScreenState();
}

class _TaskDetailScreenState extends ConsumerState<TaskDetailScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;
  final _commentCtrl = TextEditingController();
  bool _uploading = false;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabs.dispose();
    _commentCtrl.dispose();
    super.dispose();
  }

  Future<void> _postComment() async {
    final text = _commentCtrl.text.trim();
    if (text.isEmpty) return;
    final user = ref.read(currentUserProvider).valueOrNull;
    if (user == null) return;
    _commentCtrl.clear();
    await ref.read(moduleRepositoryProvider).addTaskComment(
          moduleId:   widget.task.moduleId,
          taskId:     widget.task.id,
          authorId:   user.uid,
          authorName: user.name,
          text:       text,
        );
  }

  Future<void> _pickAndUploadFile() async {
    final user = ref.read(currentUserProvider).valueOrNull;
    if (user == null) return;

    final result = await FilePicker.platform.pickFiles(withData: false, withReadStream: false);
    if (result == null || result.files.isEmpty) return;
    final picked = result.files.first;
    if (picked.path == null) return;

    setState(() => _uploading = true);
    try {
      final file     = File(picked.path!);
      final fileName = picked.name;
      final ref      = FirebaseStorage.instance
          .ref('task_attachments/${user.orgId}/${widget.task.id}/$fileName');
      await ref.putFile(file);
      final url = await ref.getDownloadURL();

      await this.ref.read(moduleRepositoryProvider).addTaskAttachment(
            moduleId:       widget.task.moduleId,
            taskId:         widget.task.id,
            uploadedById:   user.uid,
            uploadedByName: user.name,
            fileName:       fileName,
            downloadUrl:    url,
            sizeBytes:      picked.size,
          );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('File uploaded successfully')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Upload failed: $e'),
              backgroundColor: AppTheme.danger));
      }
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final taskAsync    = ref.watch(singleTaskProvider('${widget.task.moduleId}_${widget.task.id}'));
    final task         = taskAsync.valueOrNull ?? widget.task;
    final usersAsync   = ref.watch(orgUsersProvider);
    final currentUser  = ref.watch(currentUserProvider).valueOrNull;
    final canEdit      = currentUser?.isLead == true || currentUser?.isOrgAdmin == true;

    final assignee = usersAsync.when(
      data: (users) {
        final m = users.where((u) => u.uid == task.assignedTo).firstOrNull;
        if (m == null) return 'Unknown';
        return (m.techRole ?? '').isNotEmpty ? '${m.name}  •  ${m.techRole}' : m.name;
      },
      loading: () => 'Loading...',
      error: (_, __) => '—',
    );

    final isOverdue = task.dueDate != null &&
        !task.completed &&
        task.dueDate!.isBefore(DateTime.now());

    final priorityColor = switch (task.priority) {
      'BLOCKER' => AppTheme.danger,
      'HIGH'    => AppTheme.orange,
      'MEDIUM'  => AppTheme.warning,
      _         => AppTheme.textMuted,
    };

    return Scaffold(
      backgroundColor: AppTheme.bg,
      appBar: GlassAppBar(
        title: 'TASK DETAILS',
        subtitle: task.priority,
        accentColor: priorityColor,
      ),
      body: Column(
        children: [
          // ── Header card ─────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: GlassCard(
              borderLeftColor: priorityColor,
              borderLeftWidth: 3,
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Title + checkbox
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      GestureDetector(
                        onTap: () => ref.read(moduleRepositoryProvider)
                            .toggleTaskCompletion(task),
                        child: AnimatedContainer(
                          duration: 200.ms,
                          width: 22, height: 22,
                          margin: const EdgeInsets.only(top: 2, right: 12),
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
                      Expanded(
                        child: Text(task.title,
                          style: TextStyle(
                            color: task.completed ? AppTheme.textMuted : AppTheme.textPrimary,
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            fontFamily: 'Syne',
                            decoration: task.completed ? TextDecoration.lineThrough : null,
                          )),
                      ),
                      PriorityBadge(priority: task.priority),
                    ],
                  ),
                  if ((task.description ?? '').isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Text(task.description!,
                      style: const TextStyle(
                        color: AppTheme.textDim, fontSize: 13, height: 1.5)),
                  ],
                  const SizedBox(height: 16),
                  const Divider(color: AppTheme.border, height: 1),
                  const SizedBox(height: 12),
                  // Meta row
                  Wrap(
                    spacing: 20, runSpacing: 8,
                    children: [
                      _MetaChip(
                        icon: Icons.person_outline_rounded,
                        label: assignee,
                      ),
                      if (task.dueDate != null)
                        _MetaChip(
                          icon: Icons.calendar_today_outlined,
                          label: DateFormat('dd MMM yyyy').format(task.dueDate!),
                          color: isOverdue ? AppTheme.danger : AppTheme.textMuted,
                        ),
                      _MetaChip(
                        icon: task.completed
                            ? Icons.check_circle_outline_rounded
                            : Icons.radio_button_unchecked_rounded,
                        label: task.completed ? 'Completed' : 'Pending',
                        color: task.completed ? AppTheme.primary : AppTheme.textMuted,
                      ),
                    ],
                  ),
                ],
              ),
            ).animate().fadeIn(delay: 50.ms),
          ),

          const SizedBox(height: 12),

          // ── Tab bar ─────────────────────────────────────────────
          Container(
            color: AppTheme.surface,
            child: TabBar(
              controller: _tabs,
              labelColor: AppTheme.primary,
              unselectedLabelColor: AppTheme.textMuted,
              indicatorColor: AppTheme.primary,
              indicatorSize: TabBarIndicatorSize.tab,
              labelStyle: const TextStyle(fontSize: 11, letterSpacing: 1.5, fontFamily: 'Space Mono'),
              tabs: const [
                Tab(text: 'COMMENTS'),
                Tab(text: 'FILES'),
              ],
            ),
          ),

          // ── Tab content ─────────────────────────────────────────
          Expanded(
            child: TabBarView(
              controller: _tabs,
              children: [
                _CommentsTab(task: task, canEdit: canEdit),
                _FilesTab(task: task, onUpload: _pickAndUploadFile, uploading: _uploading),
              ],
            ),
          ),

          // ── Comment input ────────────────────────────────────────
          SafeArea(
            top: false,
            child: AnimatedBuilder(
              animation: _tabs,
              builder: (_, __) => _tabs.index == 0
                  ? Container(
                      color: AppTheme.surface,
                      padding: EdgeInsets.only(
                        left: 16, right: 8, top: 8,
                        bottom: MediaQuery.of(context).viewInsets.bottom > 0 ? 8 : 16,
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _commentCtrl,
                              style: const TextStyle(color: AppTheme.textPrimary, fontSize: 13),
                              decoration: const InputDecoration(
                                hintText: 'Write a comment...',
                                hintStyle: TextStyle(color: AppTheme.textDim),
                                border: InputBorder.none,
                                isDense: true,
                              ),
                              textInputAction: TextInputAction.send,
                              onSubmitted: (_) => _postComment(),
                            ),
                          ),
                          IconButton(
                            onPressed: _postComment,
                            icon: const Icon(Icons.send_rounded, color: AppTheme.primary, size: 20),
                          ),
                        ],
                      ),
                    )
                  : const SizedBox.shrink(),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Comments Tab ─────────────────────────────────────────────────────
class _CommentsTab extends ConsumerWidget {
  final TaskModel task;
  final bool canEdit;
  const _CommentsTab({required this.task, required this.canEdit});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final args = (moduleId: task.moduleId, taskId: task.id);
    final commentsAsync = ref.watch(_commentsProvider(args));

    return commentsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator(color: AppTheme.primary, strokeWidth: 2)),
      error: (e, _) => Center(child: Text('$e', style: const TextStyle(color: AppTheme.danger))),
      data: (comments) {
        if (comments.isEmpty) {
          return const EmptyState(
            icon: Icons.chat_bubble_outline_rounded,
            title: 'No Comments Yet',
            subtitle: 'Be the first to leave a note',
          );
        }
        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: comments.length,
          itemBuilder: (_, i) {
            final c = comments[i];
            final ts = c['createdAt'];
            String timeStr = '';
            if (ts != null) {
              try {
                final dt = (ts as dynamic).toDate() as DateTime;
                timeStr = DateFormat('dd MMM · HH:mm').format(dt);
              } catch (_) {}
            }
            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.surface,
                border: Border.all(color: AppTheme.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 24, height: 24,
                        decoration: BoxDecoration(
                          color: AppTheme.primary.withAlpha(30),
                          border: Border.all(color: AppTheme.primary.withAlpha(80)),
                          shape: BoxShape.circle,
                        ),
                        child: Center(
                          child: Text(
                            (c['authorName'] as String? ?? '?')[0].toUpperCase(),
                            style: const TextStyle(color: AppTheme.primary, fontSize: 11, fontWeight: FontWeight.w700),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(c['authorName'] ?? 'Unknown',
                        style: const TextStyle(color: AppTheme.textPrimary, fontSize: 12, fontWeight: FontWeight.w600)),
                      const Spacer(),
                      Text(timeStr,
                        style: const TextStyle(color: AppTheme.textMuted, fontSize: 10)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(c['text'] ?? '',
                    style: const TextStyle(color: AppTheme.textDim, fontSize: 13, height: 1.5)),
                ],
              ),
            ).animate().fadeIn(delay: (i * 40).ms);
          },
        );
      },
    );
  }
}

// ── Files Tab ─────────────────────────────────────────────────────────
class _FilesTab extends ConsumerWidget {
  final TaskModel task;
  final VoidCallback onUpload;
  final bool uploading;
  const _FilesTab({required this.task, required this.onUpload, required this.uploading});

  String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final args = (moduleId: task.moduleId, taskId: task.id);
    final attAsync = ref.watch(_attachmentsProvider(args));

    return Stack(
      children: [
        attAsync.when(
          loading: () => const Center(child: CircularProgressIndicator(color: AppTheme.primary, strokeWidth: 2)),
          error: (e, _) => Center(child: Text('$e', style: const TextStyle(color: AppTheme.danger))),
          data: (files) {
            if (files.isEmpty) {
              return const EmptyState(
                icon: Icons.attach_file_rounded,
                title: 'No Files Yet',
                subtitle: 'Tap + to attach a file',
              );
            }
            return ListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
              itemCount: files.length,
              itemBuilder: (_, i) {
                final f = files[i];
                final url = f['downloadUrl'] as String? ?? '';
                final name = f['fileName'] as String? ?? 'file';
                final size = f['sizeBytes'] as int? ?? 0;
                final by   = f['uploadedByName'] as String? ?? '';
                final ext  = name.contains('.') ? name.split('.').last.toUpperCase() : 'FILE';

                return GestureDetector(
                  onTap: () async {
                    if (url.isNotEmpty) {
                      final uri = Uri.parse(url);
                      if (await canLaunchUrl(uri)) await launchUrl(uri);
                    }
                  },
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppTheme.surface,
                      border: Border.all(color: AppTheme.border),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 40, height: 40,
                          color: AppTheme.primary.withAlpha(20),
                          child: Center(
                            child: Text(ext,
                              style: const TextStyle(
                                color: AppTheme.primary, fontSize: 9,
                                fontFamily: 'Space Mono', fontWeight: FontWeight.w700,
                              )),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(name,
                                style: const TextStyle(color: AppTheme.textPrimary, fontSize: 13),
                                maxLines: 1, overflow: TextOverflow.ellipsis),
                              const SizedBox(height: 2),
                              Text('${_formatBytes(size)}  •  $by',
                                style: const TextStyle(color: AppTheme.textMuted, fontSize: 11)),
                            ],
                          ),
                        ),
                        const Icon(Icons.open_in_new_rounded, size: 16, color: AppTheme.textDim),
                      ],
                    ),
                  ).animate().fadeIn(delay: (i * 40).ms),
                );
              },
            );
          },
        ),

        // Upload FAB
        Positioned(
          bottom: 16, right: 16,
          child: uploading
              ? const CircularProgressIndicator(color: AppTheme.primary)
              : FloatingActionButton(
                  onPressed: onUpload,
                  backgroundColor: AppTheme.primary,
                  child: const Icon(Icons.attach_file_rounded, color: AppTheme.bg),
                ),
        ),
      ],
    );
  }
}

// ── Meta Chip ─────────────────────────────────────────────────────────
class _MetaChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  const _MetaChip({required this.icon, required this.label, this.color = AppTheme.textMuted});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 13, color: color),
        const SizedBox(width: 5),
        Text(label, style: TextStyle(color: color, fontSize: 12)),
      ],
    );
  }
}
