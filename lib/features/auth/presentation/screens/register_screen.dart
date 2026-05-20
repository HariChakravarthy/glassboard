import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/providers/auth_provider.dart';
import '../../../../core/constants/app_constants.dart';

class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final _formKey    = GlobalKey<FormState>();
  final _nameCtrl   = TextEditingController();
  final _emailCtrl  = TextEditingController();
  final _passCtrl   = TextEditingController();
  final _orgNameCtrl = TextEditingController();
  final _inviteCodeCtrl = TextEditingController();
  String _role = AppConstants.roleMember;
  bool _obscure = true;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _passCtrl.dispose();
    _orgNameCtrl.dispose();
    _inviteCodeCtrl.dispose();
    super.dispose();
  }

  Future<void> _register() async {
    if (!_formKey.currentState!.validate()) return;
    await ref.read(authNotifierProvider.notifier).register(
      name: _nameCtrl.text.trim(),
      email: _emailCtrl.text.trim(),
      password: _passCtrl.text,
      role: _role,
      orgName: _role == AppConstants.roleOrgAdmin ? _orgNameCtrl.text.trim() : null,
      inviteCode: _role != AppConstants.roleOrgAdmin ? _inviteCodeCtrl.text.trim() : null,
    );
    final state = ref.read(authNotifierProvider);
    if (state.hasError && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(state.error.toString().replaceAll('Exception: ', ''))));
    }
  }

  @override
  Widget build(BuildContext context) {
    final isLoading = ref.watch(authNotifierProvider).isLoading;

    return Scaffold(
      backgroundColor: AppTheme.bg,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(32),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 32),
                Text('GLASSBOARD',
                  style: Theme.of(context).textTheme.displaySmall!.copyWith(
                    color: AppTheme.primary, letterSpacing: 4, fontFamily: 'Syne',
                  )),
                const SizedBox(height: 4),
                Text('CREATE YOUR ACCOUNT',
                  style: Theme.of(context).textTheme.labelSmall),
                const SizedBox(height: 40),

                _field(_nameCtrl, 'Full Name', Icons.person_outline_rounded)
                    .animate().fadeIn(delay: 100.ms),
                const SizedBox(height: 14),
                _field(_emailCtrl, 'Email', Icons.alternate_email_rounded,
                    type: TextInputType.emailAddress,
                    validator: (v) => v == null || !v.contains('@')
                        ? 'Valid email required' : null)
                    .animate().fadeIn(delay: 150.ms),
                const SizedBox(height: 14),

                TextFormField(
                  controller: _passCtrl,
                  obscureText: _obscure,
                  style: const TextStyle(color: AppTheme.textPrimary, fontSize: 14),
                  decoration: InputDecoration(
                    labelText: 'Password',
                    prefixIcon: const Icon(Icons.lock_outline_rounded, size: 18),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                        size: 18, color: AppTheme.textMuted,
                      ),
                      onPressed: () => setState(() => _obscure = !_obscure),
                    ),
                  ),
                  validator: (v) => v == null || v.length < 6 ? 'Min 6 chars' : null,
                ).animate().fadeIn(delay: 200.ms),

                const SizedBox(height: 20),

                // Role selector
                Text('ROLE', style: Theme.of(context).textTheme.labelSmall),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  children: [
                    _roleChip(AppConstants.roleMember, 'MEMBER', AppTheme.textMuted),
                    _roleChip(AppConstants.roleModuleLead, 'MODULE LEAD', AppTheme.warning),
                    _roleChip(AppConstants.roleOrgAdmin, 'ORG ADMIN', AppTheme.primary),
                  ],
                ).animate().fadeIn(delay: 250.ms),

                const SizedBox(height: 20),

                if (_role == AppConstants.roleOrgAdmin) ...[
                  _field(_orgNameCtrl, 'Organization Name (e.g. IIT Guwahati)', Icons.business_rounded,
                      validator: (v) => v == null || v.trim().isEmpty ? 'Organization Name is required' : null)
                      .animate().fadeIn(duration: 200.ms),
                ] else ...[
                  _field(_inviteCodeCtrl, 'Organization Invite Code', Icons.vpn_key_outlined,
                      validator: (v) => v == null || v.trim().length != 6
                          ? '6-character Invite Code is required' : null)
                      .animate().fadeIn(duration: 200.ms),
                ],

                const SizedBox(height: 32),

                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: isLoading ? null : _register,
                    child: isLoading
                        ? const SizedBox(width: 18, height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.bg))
                        : const Text('CREATE ACCOUNT'),
                  ),
                ).animate().fadeIn(delay: 300.ms),

                const SizedBox(height: 20),
                Center(
                  child: TextButton(
                    onPressed: () => context.go('/login'),
                    child: RichText(
                      text: const TextSpan(
                        text: 'Already have an account? ',
                        style: TextStyle(color: AppTheme.textMuted, fontSize: 13),
                        children: [TextSpan(
                          text: 'Sign In',
                          style: TextStyle(color: AppTheme.primary, fontWeight: FontWeight.w600),
                        )],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _roleChip(String value, String label, Color color) {
    final selected = _role == value;
    return ChoiceChip(
      label: Text(label,
        style: TextStyle(
          color: selected ? color : AppTheme.textMuted,
          fontSize: 10, letterSpacing: 1.5,
        )),
      selected: selected,
      onSelected: (_) => setState(() => _role = value),
      selectedColor: color.withAlpha(31),
      backgroundColor: AppTheme.surface,
      side: BorderSide(color: selected ? color : AppTheme.border),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
    );
  }

  Widget _field(
    TextEditingController ctrl,
    String label,
    IconData icon, {
    TextInputType? type,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: ctrl,
      keyboardType: type,
      style: const TextStyle(color: AppTheme.textPrimary, fontSize: 14),
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, size: 18),
      ),
      validator: validator ??
          (v) => v == null || v.trim().isEmpty ? '$label is required' : null,
    );
  }
}
