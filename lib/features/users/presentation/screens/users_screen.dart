// lib/features/users/presentation/screens/users_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/error_formatter.dart';
import '../../../../shared/widgets/confirm_dialog.dart';
import '../../../auth/data/models/user_profile.dart';
import '../../../auth/presentation/bloc/auth_bloc.dart';
import '../../data/repositories/users_repository.dart';

/// Admin-only: lists accounts and lets admins add viewers / data entry
/// operators. Super admins can also add admins, ban and delete.
class UsersScreen extends StatefulWidget {
  const UsersScreen({super.key});

  @override
  State<UsersScreen> createState() => _UsersScreenState();
}

class _UsersScreenState extends State<UsersScreen> {
  List<UserProfile>? _users;
  Object? _error;
  bool _loading = true;

  UsersRepository get _repo => context.read<UsersRepository>();

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final users = await _repo.fetchUsers();
      if (mounted) setState(() => _users = users);
    } catch (e) {
      if (mounted) setState(() => _error = e);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  /// Runs [action], reports the outcome and reloads the list.
  Future<void> _run(Future<void> Function() action, String successMessage) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await action();
      messenger.showSnackBar(SnackBar(
        content: Text(successMessage),
        backgroundColor: AppColors.success,
        behavior: SnackBarBehavior.floating,
      ));
      await _load();
    } catch (e) {
      messenger.showSnackBar(SnackBar(
        content: Text(ErrorFormatter.format(e)),
        backgroundColor: AppColors.error,
        behavior: SnackBarBehavior.floating,
      ));
    }
  }

  Future<void> _openCreate(UserProfile me) async {
    final created = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => RepositoryProvider.value(
        value: _repo,
        child: _UserFormSheet(roles: me.assignableRoles),
      ),
    );
    if (created == true) await _load();
  }

  Future<void> _openEdit(UserProfile me, UserProfile user) async {
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => RepositoryProvider.value(
        value: _repo,
        child: _UserFormSheet(roles: me.assignableRoles, existing: user),
      ),
    );
    if (saved == true) await _load();
  }

  Future<void> _toggleBan(UserProfile user) async {
    final ban = !user.isBanned;
    final ok = await ConfirmDialog.show(
      context,
      title: ban ? 'Ban ${user.displayName}?' : 'Unban ${user.displayName}?',
      message: ban
          ? 'They will be signed out on all devices and cannot sign in until unbanned.'
          : 'They will be able to sign in again.',
      confirmLabel: ban ? 'Ban' : 'Unban',
      destructive: ban,
    );
    if (!ok) return;
    await _run(
      () => _repo.setBanned(user.id, ban),
      ban ? '${user.displayName} was banned.' : '${user.displayName} was unbanned.',
    );
  }

  Future<void> _delete(UserProfile user) async {
    final ok = await ConfirmDialog.show(
      context,
      title: 'Delete ${user.displayName}?',
      message: 'This permanently removes the account. Data they added stays, '
          'with their name kept as the author.',
      confirmLabel: 'Delete',
      destructive: true,
    );
    if (!ok) return;
    await _run(() => _repo.deleteUser(user.id), '${user.displayName} was deleted.');
  }

  @override
  Widget build(BuildContext context) {
    final authState = context.watch<AuthBloc>().state;
    if (authState is! AuthAuthenticated) return const SizedBox.shrink();
    final me = authState.profile;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Users'),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _loading ? null : _load,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openCreate(me),
        backgroundColor: AppColors.accent,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.person_add_alt_1_rounded),
        label: const Text('Add User'),
      ),
      body: _buildBody(me),
    );
  }

  Widget _buildBody(UserProfile me) {
    if (_loading && _users == null) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null && _users == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(ErrorFormatter.format(_error), textAlign: TextAlign.center),
              const SizedBox(height: AppSpacing.md),
              ElevatedButton.icon(
                onPressed: _load,
                icon: const Icon(Icons.refresh_rounded, size: 18),
                label: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    final users = _users ?? const <UserProfile>[];
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.md, AppSpacing.md, 96),
        itemCount: users.length,
        separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.xs),
        itemBuilder: (context, i) {
          final user = users[i];
          return _UserTile(
            user: user,
            isMe: user.id == me.id,
            canEdit: me.canManage(user),
            canBanOrDelete: me.isSuperAdmin && user.id != me.id && !user.isSuperAdmin,
            onEdit: () => _openEdit(me, user),
            onToggleBan: () => _toggleBan(user),
            onDelete: () => _delete(user),
          );
        },
      ),
    );
  }
}

class _UserTile extends StatelessWidget {
  const _UserTile({
    required this.user,
    required this.isMe,
    required this.canEdit,
    required this.canBanOrDelete,
    required this.onEdit,
    required this.onToggleBan,
    required this.onDelete,
  });

  final UserProfile user;
  final bool isMe;
  final bool canEdit;
  final bool canBanOrDelete;
  final VoidCallback onEdit;
  final VoidCallback onToggleBan;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurface.withOpacity(0.55);

    return Card(
      margin: EdgeInsets.zero,
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: AppColors.accent.withOpacity(0.15),
          child: Text(
            user.displayName.isNotEmpty ? user.displayName[0].toUpperCase() : '?',
            style: const TextStyle(color: AppColors.accent, fontWeight: FontWeight.w700),
          ),
        ),
        title: Row(
          children: [
            Flexible(
              child: Text(
                isMe ? '${user.displayName} (you)' : user.displayName,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  decoration: user.isBanned ? TextDecoration.lineThrough : null,
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.xs),
            _Chip(label: user.role.label, color: AppColors.accent),
            if (user.isBanned) ...[
              const SizedBox(width: AppSpacing.xxs),
              const _Chip(label: 'Banned', color: AppColors.error),
            ],
          ],
        ),
        subtitle: Text(user.email ?? '', style: TextStyle(color: muted)),
        trailing: (canEdit || canBanOrDelete)
            ? PopupMenuButton<String>(
                onSelected: (value) {
                  switch (value) {
                    case 'edit':
                      onEdit();
                    case 'ban':
                      onToggleBan();
                    case 'delete':
                      onDelete();
                  }
                },
                itemBuilder: (_) => [
                  if (canEdit)
                    const PopupMenuItem(value: 'edit', child: Text('Edit name / role')),
                  if (canBanOrDelete)
                    PopupMenuItem(
                      value: 'ban',
                      child: Text(user.isBanned ? 'Unban' : 'Ban'),
                    ),
                  if (canBanOrDelete)
                    const PopupMenuItem(
                      value: 'delete',
                      child: Text('Delete', style: TextStyle(color: AppColors.error)),
                    ),
                ],
              )
            : null,
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.label, required this.color});
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(AppRadius.xs),
      ),
      child: Text(
        label,
        style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.w700),
      ),
    );
  }
}

/// Create a user, or edit an existing user's name and role.
class _UserFormSheet extends StatefulWidget {
  const _UserFormSheet({required this.roles, this.existing});

  final List<AppRole> roles;
  final UserProfile? existing;

  @override
  State<_UserFormSheet> createState() => _UserFormSheetState();
}

class _UserFormSheetState extends State<_UserFormSheet> {
  final _formKey = GlobalKey<FormState>();
  late final _nameCtrl = TextEditingController(text: widget.existing?.fullName ?? '');
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  late AppRole _role = widget.existing?.role ?? widget.roles.first;
  bool _obscure = true;
  bool _saving = false;

  bool get _isEdit => widget.existing != null;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    final repo = context.read<UsersRepository>();
    try {
      if (_isEdit) {
        final existing = widget.existing!;
        await repo.updateUser(
          existing.id,
          fullName: _nameCtrl.text.trim() != (existing.fullName ?? '') ? _nameCtrl.text : null,
          role: _role != existing.role ? _role : null,
        );
      } else {
        await repo.createUser(
          fullName: _nameCtrl.text,
          email: _emailCtrl.text,
          password: _passCtrl.text,
          role: _role,
        );
      }
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(ErrorFormatter.format(e)),
        backgroundColor: AppColors.error,
        behavior: SnackBarBehavior.floating,
      ));
      setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // An admin editing someone keeps that person's current role selectable.
    final roles = {...widget.roles, if (widget.existing != null) widget.existing!.role}.toList()
      ..sort((a, b) => a.index.compareTo(b.index));

    return Padding(
      padding: EdgeInsets.only(
        left: AppSpacing.lg,
        right: AppSpacing.lg,
        top: AppSpacing.lg,
        bottom: AppSpacing.lg + MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(_isEdit ? 'Edit User' : 'Add User', style: theme.textTheme.titleLarge),
              if (_isEdit) ...[
                const SizedBox(height: AppSpacing.xxs),
                Text(widget.existing!.email ?? '', style: theme.textTheme.bodySmall),
              ],
              const SizedBox(height: AppSpacing.lg),
              TextFormField(
                controller: _nameCtrl,
                enabled: !_saving,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(labelText: 'Full name'),
                validator: (v) => (v ?? '').trim().isEmpty ? 'Name is required' : null,
              ),
              if (!_isEdit) ...[
                const SizedBox(height: AppSpacing.md),
                TextFormField(
                  controller: _emailCtrl,
                  enabled: !_saving,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(labelText: 'Email'),
                  validator: (v) {
                    final value = (v ?? '').trim();
                    if (value.isEmpty) return 'Email is required';
                    if (!value.contains('@') || !value.contains('.')) return 'Enter a valid email';
                    return null;
                  },
                ),
                const SizedBox(height: AppSpacing.md),
                TextFormField(
                  controller: _passCtrl,
                  enabled: !_saving,
                  obscureText: _obscure,
                  decoration: InputDecoration(
                    labelText: 'Temporary password',
                    helperText: 'Share it with the user; they can change it after signing in.',
                    suffixIcon: IconButton(
                      onPressed: () => setState(() => _obscure = !_obscure),
                      icon: Icon(_obscure ? Icons.visibility_off_rounded : Icons.visibility_rounded, size: 20),
                    ),
                  ),
                  validator: (v) => (v ?? '').length < 8 ? 'At least 8 characters' : null,
                ),
              ],
              const SizedBox(height: AppSpacing.md),
              DropdownButtonFormField<AppRole>(
                value: _role,
                decoration: const InputDecoration(labelText: 'Role'),
                items: roles
                    .map((r) => DropdownMenuItem(
                          value: r,
                          enabled: widget.roles.contains(r),
                          child: Text(r.label),
                        ))
                    .toList(),
                onChanged: _saving
                    ? null
                    : (r) {
                        if (r != null) setState(() => _role = r);
                      },
              ),
              const SizedBox(height: AppSpacing.lg),
              ElevatedButton(
                onPressed: _saving ? null : _save,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.accent,
                  minimumSize: const Size(double.infinity, 52),
                ),
                child: _saving
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : Text(_isEdit ? 'Save' : 'Create User'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
