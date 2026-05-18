import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:io';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/providers/app_providers.dart';
import '../../../../core/providers/auth_provider.dart';
import '../../../../shared/widgets/shared_widgets.dart';
import '../../../../data/models/file_model.dart';

class FilesScreen extends ConsumerStatefulWidget {
  const FilesScreen({super.key});

  @override
  ConsumerState<FilesScreen> createState() => _FilesScreenState();
}

class _FilesScreenState extends ConsumerState<FilesScreen> {
  bool _uploading = false;

  @override
  Widget build(BuildContext context) {
    final userAsync = ref.watch(currentUserProvider);
    final user = userAsync.valueOrNull;

    if (user == null) return const SizedBox();

    final moduleIdKey = user.moduleId ?? '';
    // Admins see all files; members see only their module's files
    final filesAsync = user.isOrgAdmin
        ? ref.watch(allFilesProvider)
        : ref.watch(moduleFilesProvider(moduleIdKey));

    return Scaffold(
      backgroundColor: AppTheme.bg,
      appBar: const GlassAppBar(
        title: 'SHARED FILES',
        subtitle: 'MODULE WORKSPACE',
        accentColor: AppTheme.purple,
      ),
      floatingActionButton: (user.isLead || user.isOrgAdmin)
          ? FloatingActionButton(
              onPressed: _uploading ? null : () => _pickAndUpload(user),
              child: _uploading
                  ? const SizedBox(width: 20, height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.bg))
                  : const Icon(Icons.upload_file_rounded, color: AppTheme.bg),
            )
          : null,
      body: filesAsync.when(
        data: (files) {
          if (files.isEmpty) {
            return EmptyState(
              icon: Icons.folder_open_outlined,
              title: 'No Files Yet',
              subtitle: (user.isLead || user.isOrgAdmin)
                  ? 'Tap + to upload shared files'
                  : 'No files have been shared with your module.',
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: files.length,
            itemBuilder: (_, i) => _FileCard(file: files[i], user: user)
                .animate().fadeIn(delay: (i * 60).ms),
          );
        },
        loading: () => const Padding(
          padding: EdgeInsets.all(24), child: LoadingCardSkeleton()),
        error: (e, _) => Center(
          child: Text('$e', style: const TextStyle(color: AppTheme.danger))),
      ),
    );
  }

  Future<void> _pickAndUpload(user) async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.any,
      allowMultiple: false,
    );
    if (result == null || result.files.isEmpty) return;

    final file = result.files.first;
    if (file.path == null) return;

    setState(() => _uploading = true);
    try {
      await ref.read(fileRepositoryProvider).uploadFile(
        file:        File(file.path!),
        fileName:    file.name,
        moduleScope: user.moduleId != null ? [user.moduleId!] : [],
        uploadedBy:  user.uid,
        mimeType:    file.extension != null
            ? _mimeFromExtension(file.extension!)
            : null,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('✓ File uploaded successfully')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Upload failed: $e'),
            backgroundColor: AppTheme.danger));
      }
    } finally {
      setState(() => _uploading = false);
    }
  }

  String _mimeFromExtension(String ext) => switch (ext.toLowerCase()) {
    'jpg' || 'jpeg' => 'image/jpeg',
    'png'           => 'image/png',
    'pdf'           => 'application/pdf',
    'doc'           => 'application/msword',
    'docx'          => 'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
    'xls'           => 'application/vnd.ms-excel',
    'xlsx'          => 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
    _               => 'application/octet-stream',
  };
}

class _FileCard extends ConsumerWidget {
  final FileModel file;
  final dynamic user;
  const _FileCard({required this.file, required this.user});

  IconData get _icon => file.isImage
      ? Icons.image_outlined
      : file.isPdf
          ? Icons.picture_as_pdf_outlined
          : Icons.insert_drive_file_outlined;

  Color get _iconColor => file.isImage
      ? AppTheme.success
      : file.isPdf
          ? AppTheme.danger
          : AppTheme.purple;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return GlassCard(
      padding: const EdgeInsets.all(0),
      borderLeftColor: _iconColor,
      borderLeftWidth: 3,
      onTap: () => context.push('/files/${file.id}/preview', extra: file),
      child: Column(
        children: [
          ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            leading: Container(
              width: 40, height: 40,
              decoration: BoxDecoration(
                color: _iconColor.withAlpha(26),
                border: Border.all(color: _iconColor.withAlpha(77)),
              ),
              child: Icon(_icon, color: _iconColor, size: 20),
            ),
            title: Text(file.name,
              style: const TextStyle(
                color: AppTheme.textPrimary, fontSize: 13, fontWeight: FontWeight.w500)),
            subtitle: Text('${file.currentVersion} · ${_sizeLabel(file.sizeBytes)}',
              style: const TextStyle(color: AppTheme.textDim, fontSize: 11)),
            trailing: PopupMenuButton<String>(
              color: AppTheme.surface,
              onSelected: (v) async {
                if (v == 'open') {
                  await launchUrl(Uri.parse(file.url));
                } else if (v == 'versions') {
                  _showVersionHistory(context, ref);
                }
              },
              itemBuilder: (_) => [
                const PopupMenuItem(value: 'open', child: Text('Open File')),
                if (user.isLead || user.isOrgAdmin)
                  const PopupMenuItem(value: 'versions', child: Text('Version History')),
              ],
              icon: const Icon(Icons.more_vert_rounded, color: AppTheme.textMuted, size: 18),
            ),
          ),
          if (file.moduleScope.isNotEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              decoration: const BoxDecoration(
                color: AppTheme.bg,
                border: Border(top: BorderSide(color: AppTheme.border)),
              ),
              child: Text('SCOPE: ${file.moduleScope.join(", ")}',
                style: const TextStyle(
                  color: AppTheme.textDim, fontSize: 9, letterSpacing: 1.5)),
            ),
        ],
      ),
    );
  }

  void _showVersionHistory(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(4)),
        side: BorderSide(color: AppTheme.border),
      ),
      builder: (_) => Consumer(
        builder: (_, ref, __) {
          final versionsAsync = ref.watch(fileVersionsProvider(file.id));
          return Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('VERSION HISTORY',
                  style: Theme.of(context).textTheme.labelMedium),
                const SizedBox(height: 16),
                versionsAsync.when(
                  data: (versions) => versions.isEmpty
                      ? const EmptyState(
                          icon: Icons.history_rounded,
                          title: 'No previous versions')
                      : Column(
                          children: versions.map((v) => ListTile(
                            leading: const Icon(Icons.history_rounded,
                              color: AppTheme.textMuted, size: 18),
                            title: Text(v.id.substring(0, 8),
                              style: const TextStyle(color: AppTheme.textPrimary, fontSize: 12)),
                            subtitle: Text(v.modifiedAt.toString().substring(0, 16),
                              style: const TextStyle(color: AppTheme.textDim, fontSize: 10)),
                            trailing: TextButton(
                              onPressed: () async {
                                await ref.read(fileRepositoryProvider)
                                    .restoreVersion(file.id, v, user.uid);
                                if (context.mounted) Navigator.pop(context);
                              },
                              child: const Text('RESTORE'),
                            ),
                          )).toList(),
                        ),
                  loading: () => const CircularProgressIndicator(color: AppTheme.primary),
                  error: (e, _) => Text('$e',
                    style: const TextStyle(color: AppTheme.danger)),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  String _sizeLabel(int? bytes) {
    if (bytes == null) return '—';
    if (bytes < 1024) return '${bytes}B';
    if (bytes < 1048576) return '${(bytes / 1024).toStringAsFixed(1)}KB';
    return '${(bytes / 1048576).toStringAsFixed(1)}MB';
  }
}
