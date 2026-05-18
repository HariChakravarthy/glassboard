import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/providers/auth_provider.dart';
import '../../../../core/providers/app_providers.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../data/models/module_model.dart';
import '../../../../shared/widgets/shared_widgets.dart';

class CreateModuleScreen extends ConsumerStatefulWidget {
  const CreateModuleScreen({super.key});

  @override
  ConsumerState<CreateModuleScreen> createState() => _CreateModuleScreenState();
}

class _CreateModuleScreenState extends ConsumerState<CreateModuleScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  String _status = AppConstants.statusNotStarted;
  final List<String> _selectedDeps = [];
  bool _loading = false;

  static const _statuses = [
    AppConstants.statusNotStarted,
    AppConstants.statusInProgress,
    AppConstants.statusReview,
    AppConstants.statusComplete,
  ];

  @override
  void dispose() {
    _nameCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final user = ref.read(currentUserProvider).valueOrNull;
    if (user == null) return;

    setState(() => _loading = true);
    try {
      final id = const Uuid().v4().replaceAll('-', '').substring(0, 12);
      final module = ModuleModel(
        id: id,
        name: _nameCtrl.text.trim(),
        description: _descCtrl.text.trim(),
        ownerId: user.uid,
        status: _status,
        progress: 0,
        dependsOn: _selectedDeps,
        createdAt: DateTime.now(),
      );
      await ref.read(moduleRepositoryProvider).createModule(module);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('✓ Module created successfully')));
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: AppTheme.danger));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final modulesAsync = ref.watch(allModulesProvider);
    final allModules = modulesAsync.valueOrNull ?? [];

    return Scaffold(
      backgroundColor: AppTheme.bg,
      appBar: GlassAppBar(
        title: 'CREATE MODULE',
        subtitle: 'ADMIN ONLY',
        accentColor: AppTheme.success,
        actions: [
          TextButton(
            onPressed: _loading ? null : _submit,
            child: _loading
                ? const SizedBox(width: 16, height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.primary))
                : const Text('SAVE', style: TextStyle(color: AppTheme.primary,
                    fontSize: 12, letterSpacing: 2, fontFamily: 'Space Mono')),
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            // Module Name
            const _Label('MODULE NAME'),
            const SizedBox(height: 8),
            TextFormField(
              controller: _nameCtrl,
              style: const TextStyle(color: AppTheme.textPrimary),
              decoration: const InputDecoration(
                hintText: 'e.g. Authentication Module',
                prefixIcon: Icon(Icons.grid_view_rounded, size: 18),
              ),
              validator: (v) => v == null || v.trim().isEmpty ? 'Name is required' : null,
            ),
            const SizedBox(height: 20),

            // Description
            const _Label('DESCRIPTION'),
            const SizedBox(height: 8),
            TextFormField(
              controller: _descCtrl,
              maxLines: 3,
              style: const TextStyle(color: AppTheme.textPrimary),
              decoration: const InputDecoration(
                hintText: 'What does this module own?',
              ),
            ),
            const SizedBox(height: 24),

            // Initial Status
            const _Label('INITIAL STATUS'),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _statuses.map((s) {
                final selected = _status == s;
                final color = _statusColor(s);
                return GestureDetector(
                  onTap: () => setState(() => _status = s),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: selected ? color.withAlpha(30) : AppTheme.surface,
                      border: Border.all(
                        color: selected ? color : AppTheme.border,
                        width: selected ? 1.5 : 1,
                      ),
                    ),
                    child: Text(s.toUpperCase(),
                      style: TextStyle(
                        color: selected ? color : AppTheme.textMuted,
                        fontSize: 10, letterSpacing: 2, fontFamily: 'Space Mono',
                        fontWeight: selected ? FontWeight.w700 : FontWeight.w400,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 24),

            // Dependencies
            const _Label('DEPENDS ON (OPTIONAL)'),
            const SizedBox(height: 4),
            Text('Select modules that must complete before this one starts',
              style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: 12),
            if (allModules.isEmpty)
              Text('No other modules yet — add more later.',
                style: Theme.of(context).textTheme.bodySmall)
            else
              ...allModules.map((m) {
                final checked = _selectedDeps.contains(m.id);
                return CheckboxListTile(
                  value: checked,
                  title: Text(m.name,
                    style: const TextStyle(color: AppTheme.textPrimary, fontSize: 13)),
                  subtitle: Text(m.status.toUpperCase(),
                    style: const TextStyle(color: AppTheme.textDim, fontSize: 10, letterSpacing: 1.5)),
                  activeColor: AppTheme.primary,
                  side: const BorderSide(color: AppTheme.border),
                  contentPadding: EdgeInsets.zero,
                  onChanged: (v) {
                    setState(() {
                      if (v == true) {
                        _selectedDeps.add(m.id);
                      } else {
                        _selectedDeps.remove(m.id);
                      }
                    });
                  },
                );
              }),

            const SizedBox(height: 40),
            ElevatedButton(
              onPressed: _loading ? null : _submit,
              child: _loading
                  ? const SizedBox(height: 16, width: 16,
                      child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.bg))
                  : const Text('CREATE MODULE'),
            ),
          ],
        ),
      ),
    );
  }

  Color _statusColor(String s) => switch (s) {
    AppConstants.statusComplete   => AppTheme.success,
    AppConstants.statusInProgress => AppTheme.primary,
    AppConstants.statusReview     => AppTheme.warning,
    _                             => AppTheme.textMuted,
  };
}

class _Label extends StatelessWidget {
  final String text;
  const _Label(this.text);

  @override
  Widget build(BuildContext context) => Text(text,
    style: const TextStyle(
      color: AppTheme.primary, fontSize: 10,
      letterSpacing: 3, fontFamily: 'Space Mono',
    ),
  );
}
