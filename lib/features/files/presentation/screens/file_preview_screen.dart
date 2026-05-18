import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../data/models/file_model.dart';

class FilePreviewScreen extends StatelessWidget {
  final FileModel file;
  const FilePreviewScreen({super.key, required this.file});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bg,
      appBar: AppBar(
        backgroundColor: AppTheme.surface,
        title: Text(file.name,
          style: const TextStyle(color: AppTheme.textPrimary, fontSize: 14),
          overflow: TextOverflow.ellipsis),
        iconTheme: const IconThemeData(color: AppTheme.textSecondary),
        actions: [
          IconButton(
            icon: const Icon(Icons.open_in_browser_rounded),
            tooltip: 'Open in browser',
            onPressed: () => launchUrl(Uri.parse(file.url),
                mode: LaunchMode.externalApplication),
          ),
        ],
      ),
      body: _buildPreview(context),
    );
  }

  Widget _buildPreview(BuildContext context) {
    if (file.isImage) {
      return InteractiveViewer(
        minScale: 0.5,
        maxScale: 4.0,
        child: Center(
          child: CachedNetworkImage(
            imageUrl: file.url,
            fit: BoxFit.contain,
            placeholder: (_, __) => const Center(
              child: CircularProgressIndicator(color: AppTheme.primary)),
            errorWidget: (_, __, ___) => const Icon(
              Icons.broken_image_outlined, color: AppTheme.textMuted, size: 64),
          ),
        ),
      );
    }

    // Non-image: show info card + open externally button
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80, height: 80,
              decoration: BoxDecoration(
                color: AppTheme.purple.withAlpha(26),
                border: Border.all(color: AppTheme.purple.withAlpha(80)),
                shape: BoxShape.circle,
              ),
              child: Icon(
                file.isPdf
                    ? Icons.picture_as_pdf_outlined
                    : Icons.insert_drive_file_outlined,
                color: AppTheme.purple, size: 36),
            ),
            const SizedBox(height: 24),
            Text(file.name,
              style: const TextStyle(
                color: AppTheme.textPrimary,
                fontSize: 16, fontWeight: FontWeight.w600),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text('${file.currentVersion} · ${_sizeLabel(file.sizeBytes)}',
              style: const TextStyle(color: AppTheme.textDim, fontSize: 12)),
            const SizedBox(height: 32),
            ElevatedButton.icon(
              onPressed: () => launchUrl(Uri.parse(file.url),
                  mode: LaunchMode.externalApplication),
              icon: const Icon(Icons.open_in_new_rounded, size: 16),
              label: const Text('OPEN FILE'),
            ),
            const SizedBox(height: 12),
            const Text(
              'PDF and document preview requires an external app.',
              style: TextStyle(color: AppTheme.textDim, fontSize: 11),
              textAlign: TextAlign.center,
            ),
          ],
        ),
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
