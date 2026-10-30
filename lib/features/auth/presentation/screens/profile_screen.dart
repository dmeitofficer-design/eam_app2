// lib/features/auth/presentation/screens/profile_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/error_formatter.dart';
import '../../data/repositories/auth_repository.dart';
import '../bloc/auth_bloc.dart';

/// The signed-in user's own account. Users without a name are sent here
/// first: the name is shown as the author of every change they make.
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _nameCtrl = TextEditingController();
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final state = context.read<AuthBloc>().state;
    if (state is AuthAuthenticated) _nameCtrl.text = state.profile.fullName ?? '';
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  Future<void> _saveName() async {
    final name = _nameCtrl.text.trim();
    final messenger = ScaffoldMessenger.of(context);
    if (name.isEmpty) {
      messenger.showSnackBar(const SnackBar(
        content: Text('Please enter your name.'),
        behavior: SnackBarBehavior.floating,
      ));
      return;
    }
    setState(() => _saving = true);
    try {
      final profile = await context.read<AuthRepository>().updateFullName(name);
      if (!mounted) return;
      context.read<AuthBloc>().add(AuthProfileUpdated(profile));
      messenger.showSnackBar(const SnackBar(
        content: Text('Name saved.'),
        backgroundColor: AppColors.success,
        behavior: SnackBarBehavior.floating,
      ));
    } catch (e) {
      messenger.showSnackBar(SnackBar(
        content: Text(ErrorFormatter.format(e)),
        backgroundColor: AppColors.error,
        behavior: SnackBarBehavior.floating,
      ));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final authState = context.watch<AuthBloc>().state;
    if (authState is! AuthAuthenticated) return const SizedBox.shrink();
    final profile = authState.profile;
    final muted = theme.colorScheme.onSurface.withOpacity(0.55);

    return Scaffold(
      appBar: AppBar(title: const Text('My Profile')),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.md),
        children: [
          if (!profile.hasName)
            Container(
              margin: const EdgeInsets.only(bottom: AppSpacing.md),
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                color: AppColors.warning.withOpacity(0.12),
                borderRadius: BorderRadius.circular(AppRadius.sm),
                border: Border.all(color: AppColors.warning.withOpacity(0.5)),
              ),
              child: const Text(
                'Please add your name to continue. It is shown next to the '
                'data you add or change.',
              ),
            ),
          Card(
            margin: EdgeInsets.zero,
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextField(
                    controller: _nameCtrl,
                    enabled: !_saving,
                    textCapitalization: TextCapitalization.words,
                    textInputAction: TextInputAction.done,
                    onSubmitted: (_) => _saving ? null : _saveName(),
                    decoration: const InputDecoration(labelText: 'Full name'),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Align(
                    alignment: Alignment.centerRight,
                    child: ElevatedButton(
                      onPressed: _saving ? null : _saveName,
                      child: _saving
                          ? const SizedBox(
                              height: 18,
                              width: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('Save Name'),
                    ),
                  ),
                  const Divider(height: AppSpacing.xl),
                  _InfoRow(label: 'Email', value: profile.email ?? '—', muted: muted),
                  const SizedBox(height: AppSpacing.xs),
                  _InfoRow(label: 'Role', value: profile.role.label, muted: muted),
                ],
              ),
            ),
          ),
          if (profile.hasName) ...[
            const SizedBox(height: AppSpacing.md),
            Card(
              margin: EdgeInsets.zero,
              child: Column(
                children: [
                  ListTile(
                    leading: const Icon(Icons.lock_reset_rounded),
                    title: const Text('Change Password'),
                    onTap: () => context.go('/change-password'),
                  ),
                  ListTile(
                    leading: const Icon(Icons.gpp_good_rounded),
                    title: const Text('Device Security'),
                    onTap: () => context.go('/device-management'),
                  ),
                  if (profile.isAdmin)
                    ListTile(
                      leading: const Icon(Icons.manage_accounts_rounded),
                      title: const Text('Manage Users'),
                      onTap: () => context.go('/users'),
                    ),
                ],
              ),
            ),
          ],
          const SizedBox(height: AppSpacing.md),
          Card(
            margin: EdgeInsets.zero,
            child: ListTile(
              leading: const Icon(Icons.logout_rounded, color: AppColors.error),
              title: const Text('Sign Out', style: TextStyle(color: AppColors.error)),
              onTap: () => context.read<AuthBloc>().add(AuthLogoutRequested()),
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value, required this.muted});
  final String label;
  final String value;
  final Color muted;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(width: 64, child: Text(label, style: TextStyle(color: muted))),
        Expanded(child: Text(value)),
      ],
    );
  }
}
