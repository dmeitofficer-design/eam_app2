// lib/features/users/presentation/screens/users_screen.dart
//
// Manage Users, built from the Manage Users designs: a blue header with the
// role legend, pill cards that reveal Edit / Ban / Delete on long-press (as
// on the Engineers page), and an animated Create User button.

import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shimmer/shimmer.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/design_type.dart';
import '../../../../core/theme/theme_controller.dart';
import '../../../../core/utils/error_formatter.dart';
import '../../../../shared/widgets/confirm_dialog.dart';
import '../../../../shared/widgets/role_avatar.dart';
import '../../../auth/data/models/user_profile.dart';
import '../../../auth/presentation/bloc/auth_bloc.dart';
import '../../data/repositories/users_repository.dart';

// ── Look of the design ───────────────────────────────────────────────────────

class _Look {
  _Look._();

  /// #F1F1F2 card / pill fill.
  static Color get fill => ThemeController.isDarkMode ? AppColors.surface1 : const Color(0xFFF1F1F2);

  /// #EEEEEF form field fill and #D1D3D4 its outline.
  static Color get field => ThemeController.isDarkMode ? AppColors.surface2 : const Color(0xFFEEEEEF);
  static Color get fieldLine => ThemeController.isDarkMode ? AppColors.surface4 : const Color(0xFFD1D3D4);

  /// Header gradient, left to right.
  static const blueDeep = Color(0xFF1C8FEA);
  static const blueLight = Color(0xFF2BC8FF);

  /// Create User outline and the focused field outline.
  static const blueLine = Color(0xFF4CC3F2);
  static const label = Color(0xFF58595B);
}

/// The design's names for the roles.
String _roleName(AppRole role) => switch (role) {
      AppRole.viewer => 'Viewer',
      AppRole.dataEntry => 'Operator',
      AppRole.admin => 'Admin',
      AppRole.superAdmin => 'Super admin',
    };

// ── Screen ───────────────────────────────────────────────────────────────────

/// Admin-only: lists accounts and lets admins add viewers / operators.
/// Super admins can also add admins, ban and delete.
class UsersScreen extends StatefulWidget {
  const UsersScreen({super.key});

  @override
  State<UsersScreen> createState() => _UsersScreenState();
}

class _UsersScreenState extends State<UsersScreen> {
  List<UserProfile>? _users;
  Object? _error;
  bool _loading = true;

  /// The card whose buttons are showing (one at a time).
  String? _openId;

  /// Role picked in the header legend; null shows everyone.
  AppRole? _filter;

  UsersRepository get _repo => context.read<UsersRepository>();

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  void _closeCards() {
    if (_openId != null) setState(() => _openId = null);
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

  void _snack(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: color, behavior: SnackBarBehavior.floating),
    );
  }

  /// Runs [action], reports the outcome and reloads the list.
  Future<void> _run(Future<void> Function() action, String successMessage) async {
    try {
      await action();
      _snack(successMessage, AppColors.success);
      await _load();
    } catch (e) {
      _snack(ErrorFormatter.format(e), AppColors.error);
    }
  }

  Future<void> _openForm(UserProfile me, [UserProfile? existing]) async {
    _closeCards();
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: AppColors.surface0,
      barrierColor: Colors.black.withValues(alpha: 0.35),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      builder: (_) => RepositoryProvider.value(
        value: _repo,
        child: _UserFormSheet(roles: me.assignableRoles, existing: existing),
      ),
    );
    if (saved == true) {
      if (mounted) {
        _snack(
          existing == null ? 'User created.' : '${existing.displayName} was updated.',
          AppColors.success,
        );
      }
      await _load();
    }
  }

  Future<void> _toggleBan(UserProfile user) async {
    _closeCards();
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
    _closeCards();
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
    final isDesktop = MediaQuery.of(context).size.width >= AppConstants.tabletBreakpoint;

    return Scaffold(
      backgroundColor: AppColors.surface0,
      body: SafeArea(
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: isDesktop ? 720 : double.infinity),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
              child: Column(
                children: [
                  _Header(
                    selected: _filter,
                    onSelect: (role) => setState(() {
                      _openId = null;
                      _filter = _filter == role ? null : role;
                    }),
                  ),
                  const SizedBox(height: 14),
                  Expanded(child: _buildBody(me)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBody(UserProfile me) {
    if (_loading && _users == null) return const _ShimmerList();
    if (_error != null && _users == null) {
      return _ErrorState(message: ErrorFormatter.format(_error), onRetry: _load);
    }

    final users = (_users ?? const <UserProfile>[]).where((u) => _filter == null || u.role == _filter).toList();
    final canCreate = me.assignableRoles.isNotEmpty;

    final create = Padding(
      padding: const EdgeInsets.only(right: 2),
      child: Align(
        alignment: Alignment.centerRight,
        child: _CreateUserButton(label: 'Create User', onPressed: () => _openForm(me)),
      ),
    );

    // Tapping empty space or scrolling closes an open card.
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onTap: _closeCards,
      child: NotificationListener<ScrollStartNotification>(
        onNotification: (_) {
          _closeCards();
          return false;
        },
        child: RefreshIndicator(
          color: _Look.blueDeep,
          backgroundColor: AppColors.surface1,
          onRefresh: _load,
          child: ListView(
            padding: const EdgeInsets.only(left: 4, right: 4, bottom: AppSpacing.lg),
            physics: const AlwaysScrollableScrollPhysics(),
            children: [
              if (users.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 40),
                  child: Center(
                    child: Text(
                      _filter == null ? 'No users yet.' : 'No ${_roleName(_filter!).toLowerCase()}s.',
                      style: DesignType.elms(14, DesignInk.muted, FontWeight.w300),
                    ),
                  ),
                ),
              for (final user in users) ...[
                _UserCard(
                  key: ValueKey(user.id),
                  user: user,
                  canEdit: me.canManage(user),
                  canBanOrDelete: me.isSuperAdmin && user.id != me.id && !user.isSuperAdmin,
                  open: _openId == user.id,
                  onOpenChanged: (open) => setState(() => _openId = open ? user.id : null),
                  onEdit: () => _openForm(me, user),
                  onToggleBan: () => _toggleBan(user),
                  onDelete: () => _delete(user),
                ),
                const SizedBox(height: 8),
              ],
              if (canCreate) ...[const SizedBox(height: 12), create],
            ],
          ),
        ),
      ),
    );
  }
}

// ── Header: title on a blue gradient, role legend on a white panel ───────────

class _Header extends StatelessWidget {
  const _Header({required this.selected, required this.onSelect});
  final AppRole? selected;
  final ValueChanged<AppRole> onSelect;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        gradient: const LinearGradient(colors: [_Look.blueDeep, _Look.blueLight]),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(5, 0, 5, 6),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 18, 10, 14),
              child: Text('Manage Users', style: DesignType.oddlini(19, Colors.white)),
            ),
            DecoratedBox(
              decoration: BoxDecoration(
                color: AppColors.surface0,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 9),
                child: Row(
                  children: [
                    for (final role in AppRole.values)
                      Expanded(
                        child: _LegendItem(
                          role: role,
                          selected: selected == role,
                          dimmed: selected != null && selected != role,
                          onTap: () => onSelect(role),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A role in the legend; tapping it shows only that role's users.
class _LegendItem extends StatelessWidget {
  const _LegendItem({required this.role, required this.selected, required this.dimmed, required this.onTap});
  final AppRole role;
  final bool selected;
  final bool dimmed;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final name = role == AppRole.superAdmin ? 'super admin' : _roleName(role);
    return Tooltip(
      message: selected ? 'Show everyone' : 'Show ${_roleName(role).toLowerCase()}s only',
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          HapticFeedback.selectionClick();
          onTap();
        },
        child: AnimatedOpacity(
          opacity: dimmed ? 0.35 : 1,
          duration: const Duration(milliseconds: 200),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedScale(
                scale: selected ? 1.12 : 1,
                duration: const Duration(milliseconds: 320),
                curve: Curves.easeOutBack,
                child: RoleAvatar(role: role, size: 40),
              ),
              const SizedBox(height: 3),
              Text(
                name,
                style: DesignType.elms(12, ThemeController.isDarkMode ? AppColors.textSecondary : _Look.label, FontWeight.w300),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── User card ────────────────────────────────────────────────────────────────

/// Pill card. Long-press shrinks it to the left and slides Edit and
/// Ban | Delete in from the right; tap, scroll or another card closes it.
class _UserCard extends StatefulWidget {
  const _UserCard({
    super.key,
    required this.user,
    required this.canEdit,
    required this.canBanOrDelete,
    required this.open,
    required this.onOpenChanged,
    required this.onEdit,
    required this.onToggleBan,
    required this.onDelete,
  });

  static const double height = 60;
  static const double actionsWidth = 84;
  static const double gap = 6;

  final UserProfile user;
  final bool canEdit;
  final bool canBanOrDelete;
  final bool open;
  final ValueChanged<bool> onOpenChanged;
  final VoidCallback onEdit;
  final VoidCallback onToggleBan;
  final VoidCallback onDelete;

  bool get hasActions => canEdit || canBanOrDelete;

  @override
  State<_UserCard> createState() => _UserCardState();
}

class _UserCardState extends State<_UserCard> with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 360),
    reverseDuration: const Duration(milliseconds: 220),
    value: widget.open ? 1 : 0,
  );
  // A little overshoot when opening makes it feel springy.
  late final Animation<double> _reveal = CurvedAnimation(
    parent: _ctrl,
    curve: Curves.easeOutBack,
    reverseCurve: Curves.easeInCubic,
  );
  bool _pressed = false;

  @override
  void didUpdateWidget(_UserCard old) {
    super.didUpdateWidget(old);
    if (widget.open != old.open) {
      unawaited(widget.open ? _ctrl.forward() : _ctrl.reverse());
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _setPressed(bool v) {
    if (_pressed != v) setState(() => _pressed = v);
  }

  void _toggle() {
    if (!widget.hasActions) return;
    HapticFeedback.mediumImpact();
    widget.onOpenChanged(!widget.open);
  }

  void _close() {
    if (!widget.open) return;
    HapticFeedback.selectionClick();
    widget.onOpenChanged(false);
  }

  @override
  Widget build(BuildContext context) {
    const reserved = _UserCard.actionsWidth + _UserCard.gap;
    return SizedBox(
      height: _UserCard.height,
      child: AnimatedBuilder(
        animation: _reveal,
        builder: (context, _) {
          final t = _reveal.value; // may overshoot 1 slightly
          final shown = t.clamp(0.0, 1.0);
          return Stack(
            clipBehavior: Clip.none,
            children: [
              if (widget.hasActions && _ctrl.value > 0)
                Positioned(
                  right: 0,
                  top: 0,
                  bottom: 0,
                  width: _UserCard.actionsWidth,
                  child: Opacity(
                    opacity: shown,
                    child: Transform.translate(
                      offset: Offset((1 - t) * 32, 0),
                      child: Transform.scale(
                        scale: 0.85 + 0.15 * shown,
                        child: _Actions(
                          showEdit: widget.canEdit,
                          showBanDelete: widget.canBanOrDelete,
                          banned: widget.user.isBanned,
                          onEdit: widget.onEdit,
                          onToggleBan: widget.onToggleBan,
                          onDelete: widget.onDelete,
                        ),
                      ),
                    ),
                  ),
                ),
              Positioned(
                left: 0,
                top: 0,
                bottom: 0,
                right: reserved * t,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTapDown: (_) => _setPressed(true),
                  onTapUp: (_) => _setPressed(false),
                  onTapCancel: () => _setPressed(false),
                  onTap: _close,
                  onLongPressStart: (_) => _setPressed(true),
                  onLongPressEnd: (_) => _setPressed(false),
                  onLongPress: _toggle,
                  child: AnimatedScale(
                    scale: _pressed ? 0.975 : 1,
                    duration: const Duration(milliseconds: 120),
                    curve: Curves.easeOut,
                    child: _CardBody(user: widget.user),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _CardBody extends StatelessWidget {
  const _CardBody({required this.user});
  final UserProfile user;

  @override
  Widget build(BuildContext context) {
    final banned = user.isBanned;
    return DecoratedBox(
      decoration: ShapeDecoration(color: _Look.fill, shape: const StadiumBorder()),
      child: Padding(
        padding: const EdgeInsets.only(left: 9, right: 16),
        child: Row(
          children: [
            Opacity(opacity: banned ? 0.45 : 1, child: RoleAvatar(role: user.role, size: 41)),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          user.displayName,
                          style: DesignType.oddlini(18, banned ? DesignInk.unavailableName : DesignInk.primary),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (banned) ...[
                        const SizedBox(width: 6),
                        DecoratedBox(
                          decoration: const ShapeDecoration(
                            shape: StadiumBorder(side: BorderSide(color: DesignInk.delete)),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                            child: Text('Banned', style: DesignType.elms(9.5, DesignInk.delete, FontWeight.w700)),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 1),
                  Text(
                    user.email ?? '',
                    style: DesignType.elms(12.5, DesignInk.subtitle, FontWeight.w300).copyWith(letterSpacing: 0.3),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Edit on top; Ban | Delete below in a red pill.
class _Actions extends StatelessWidget {
  const _Actions({
    required this.showEdit,
    required this.showBanDelete,
    required this.banned,
    required this.onEdit,
    required this.onToggleBan,
    required this.onDelete,
  });
  final bool showEdit;
  final bool showBanDelete;
  final bool banned;
  final VoidCallback onEdit;
  final VoidCallback onToggleBan;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final ink = DesignInk.primary;
    final edit = DecoratedBox(
      decoration: ShapeDecoration(
        color: _Look.fill,
        shape: StadiumBorder(side: BorderSide(color: ThemeController.isDarkMode ? AppColors.textSecondary : _Look.label)),
      ),
      child: _TactileButton(
        tooltip: 'Edit name / role',
        onTap: onEdit,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.edit, size: 13, color: ink),
            const SizedBox(width: 3),
            Text('Edit', style: DesignType.elms(11.5, ink, FontWeight.w700)),
          ],
        ),
      ),
    );
    final banDelete = DecoratedBox(
      decoration: ShapeDecoration(
        color: AppColors.surface0,
        shape: const StadiumBorder(side: BorderSide(color: DesignInk.delete, width: 1.2)),
      ),
      child: Row(
        children: [
          Expanded(
            child: _TactileButton(
              tooltip: banned ? 'Unban' : 'Ban',
              onTap: onToggleBan,
              strongHaptic: !banned,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(banned ? Icons.lock_open_rounded : Icons.block_rounded, size: 10, color: DesignInk.delete),
                  const SizedBox(width: 2),
                  Text(banned ? 'Unban' : 'Ban', style: DesignType.elms(8.5, ink, FontWeight.w700)),
                ],
              ),
            ),
          ),
          Container(width: 1, color: DesignInk.delete),
          Expanded(
            child: _TactileButton(
              tooltip: 'Delete',
              onTap: onDelete,
              strongHaptic: true,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.delete_outline_rounded, size: 11, color: DesignInk.delete),
                  const SizedBox(width: 1),
                  Text('Delete', style: DesignType.elms(8.5, ink, FontWeight.w700)),
                ],
              ),
            ),
          ),
        ],
      ),
    );

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (showEdit) SizedBox(height: 24, child: edit),
        if (showEdit && showBanDelete) const SizedBox(height: 6),
        if (showBanDelete) SizedBox(height: 24, child: banDelete),
      ],
    );
  }
}

/// Shrinks while pressed, ticks on touch and taps on release.
class _TactileButton extends StatefulWidget {
  const _TactileButton({
    required this.tooltip,
    required this.onTap,
    required this.child,
    this.strongHaptic = false,
  });
  final String tooltip;
  final VoidCallback onTap;
  final Widget child;

  /// Heavier feedback for destructive actions.
  final bool strongHaptic;

  @override
  State<_TactileButton> createState() => _TactileButtonState();
}

class _TactileButtonState extends State<_TactileButton> {
  bool _down = false;

  void _set(bool down) {
    if (_down != down) setState(() => _down = down);
  }

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: widget.tooltip,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (_) {
          HapticFeedback.selectionClick();
          _set(true);
        },
        onTapCancel: () => _set(false),
        onTapUp: (_) => _set(false),
        onTap: () {
          widget.strongHaptic ? HapticFeedback.mediumImpact() : HapticFeedback.lightImpact();
          widget.onTap();
        },
        child: AnimatedScale(
          scale: _down ? 0.82 : 1,
          duration: Duration(milliseconds: _down ? 90 : 260),
          curve: _down ? Curves.easeOut : Curves.elasticOut,
          child: Center(child: widget.child),
        ),
      ),
    );
  }
}

// ── Create User button ───────────────────────────────────────────────────────

/// Pill with a "+" in a circle. On tap the "+" turns a quarter with a
/// springy overshoot while blue fills the circle from left to right, with
/// haptic ticks that build up to a firm tap; then [onPressed] runs. The
/// circle empties again when [onPressed] finishes, and the "+" keeps
/// turning while it is busy.
class _CreateUserButton extends StatefulWidget {
  const _CreateUserButton({required this.label, required this.onPressed});
  final String label;
  final Future<void> Function()? onPressed;

  @override
  State<_CreateUserButton> createState() => _CreateUserButtonState();
}

class _CreateUserButtonState extends State<_CreateUserButton> with TickerProviderStateMixin {
  late final AnimationController _fill = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 520),
    reverseDuration: const Duration(milliseconds: 320),
  );
  late final AnimationController _spin = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  );
  bool _down = false;
  bool _running = false;

  @override
  void dispose() {
    _fill.dispose();
    _spin.dispose();
    super.dispose();
  }

  void _set(bool down) {
    if (_down != down) setState(() => _down = down);
  }

  Future<void> _tap() async {
    final onPressed = widget.onPressed;
    if (onPressed == null || _running) return;
    _running = true;
    unawaited(HapticFeedback.lightImpact());

    // Ticks as the fill passes a third and two thirds, then a firm tap.
    var ticks = 0;
    void tick() {
      final next = _fill.value >= 0.66 ? 2 : (_fill.value >= 0.33 ? 1 : 0);
      if (next > ticks) {
        ticks = next;
        unawaited(HapticFeedback.selectionClick());
      }
    }

    _fill.addListener(tick);
    await _fill.forward(from: 0);
    _fill.removeListener(tick);
    unawaited(HapticFeedback.mediumImpact());

    // Keep turning if the action takes a while (e.g. creating the account).
    final slow = Timer(const Duration(milliseconds: 250), () {
      if (mounted) unawaited(_spin.repeat());
    });
    try {
      await onPressed();
    } finally {
      slow.cancel();
      if (mounted) {
        _spin.stop();
        _spin.value = 0;
        await _fill.reverse();
      }
      _running = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onPressed != null;
    return Opacity(
      opacity: enabled ? 1 : 0.5,
      child: Tooltip(
        message: widget.label,
        child: GestureDetector(
          onTapDown: (_) => _set(true),
          onTapUp: (_) => _set(false),
          onTapCancel: () => _set(false),
          onTap: _tap,
          child: AnimatedScale(
            scale: _down ? 0.94 : 1,
            duration: Duration(milliseconds: _down ? 90 : 420),
            curve: _down ? Curves.easeOut : Curves.elasticOut,
            child: DecoratedBox(
              decoration: ShapeDecoration(
                color: _Look.fill,
                shape: const StadiumBorder(side: BorderSide(color: _Look.blueLine, width: 1.3)),
              ),
              child: SizedBox(
                height: 50,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const SizedBox(width: 17),
                    Text(
                      widget.label,
                      style: DesignType.elms(15, DesignInk.primary, FontWeight.w500).copyWith(letterSpacing: 0.9),
                    ),
                    const SizedBox(width: 5),
                    SizedBox.square(
                      dimension: 37,
                      child: AnimatedBuilder(
                        animation: Listenable.merge([_fill, _spin]),
                        builder: (context, _) {
                          final fill = Curves.easeInOutCubic.transform(_fill.value);
                          // Quarter turn with overshoot, plus spinning while busy.
                          final turn = Curves.easeOutBack.transform(_fill.value) * 0.25 + _spin.value * 0.5;
                          return CustomPaint(
                            painter: _PlusCirclePainter(
                              fill: fill,
                              turn: turn,
                              ring: DesignInk.primary,
                              background: _Look.fill,
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(width: 5),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Ringed circle with the design's blue "+". [fill] (0–1) floods the circle
/// with blue from the left, turning the "+" white where it passes.
class _PlusCirclePainter extends CustomPainter {
  _PlusCirclePainter({required this.fill, required this.turn, required this.ring, required this.background});
  final double fill;
  final double turn;
  final Color ring;
  final Color background;

  static const _blue = LinearGradient(colors: [_Look.blueDeep, _Look.blueLight]);

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.width / 2;
    final circle = Rect.fromCircle(center: c, radius: r - 0.6);

    canvas.drawCircle(c, r - 0.6, Paint()..color = background);

    void plus(Paint paint) {
      canvas.save();
      canvas.translate(c.dx, c.dy);
      canvas.rotate(turn * 2 * math.pi);
      final arm = r * 0.62;
      canvas.drawLine(Offset(0, -arm), Offset(0, arm), paint);
      canvas.drawLine(Offset(-arm, 0), Offset(arm, 0), paint);
      canvas.restore();
    }

    final stroke = r * 0.24;
    plus(
      Paint()
        ..shader = _blue.createShader(circle)
        ..strokeWidth = stroke
        ..strokeCap = StrokeCap.round,
    );

    if (fill > 0) {
      canvas.save();
      canvas.clipPath(Path()..addOval(circle));
      canvas.clipRect(Rect.fromLTWH(circle.left, circle.top, circle.width * fill, circle.height));
      canvas.drawRect(circle, Paint()..shader = _blue.createShader(circle));
      plus(
        Paint()
          ..color = Colors.white
          ..strokeWidth = stroke
          ..strokeCap = StrokeCap.round,
      );
      canvas.restore();
    }

    canvas.drawCircle(
      c,
      r - 0.6,
      Paint()
        ..color = ring
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.1,
    );
  }

  @override
  bool shouldRepaint(_PlusCirclePainter old) =>
      old.fill != fill || old.turn != turn || old.ring != ring || old.background != background;
}

// ── Add / Edit User sheet ────────────────────────────────────────────────────

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
  void initState() {
    super.initState();
    // The password hint names the person being added.
    _nameCtrl.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) {
      unawaited(HapticFeedback.heavyImpact());
      return;
    }
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
      unawaited(HapticFeedback.heavyImpact());
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(ErrorFormatter.format(e)),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
        ),
      );
      setState(() => _saving = false);
    }
  }

  InputDecoration _decoration(String label, {Widget? suffix}) {
    OutlineInputBorder line(Color color, [double width = 1]) => OutlineInputBorder(
          borderRadius: BorderRadius.circular(9),
          borderSide: BorderSide(color: color, width: width),
        );
    return InputDecoration(
      labelText: label,
      labelStyle: DesignType.elms(14, DesignInk.muted, FontWeight.w300),
      floatingLabelStyle: DesignType.elms(13, DesignInk.primary, FontWeight.w400),
      filled: true,
      fillColor: _Look.field,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 15),
      border: line(_Look.fieldLine),
      enabledBorder: line(_Look.fieldLine),
      disabledBorder: line(_Look.fieldLine),
      focusedBorder: line(_Look.blueLine, 1.4),
      errorBorder: line(DesignInk.delete),
      focusedErrorBorder: line(DesignInk.delete, 1.4),
      errorStyle: DesignType.elms(11.5, DesignInk.delete, FontWeight.w400),
      suffixIcon: suffix,
    );
  }

  @override
  Widget build(BuildContext context) {
    final ink = DesignInk.primary;
    final fieldText = DesignType.elms(15, ink, FontWeight.w400);
    // An admin editing someone keeps that person's current role selectable.
    final roles = {...widget.roles, if (widget.existing != null) widget.existing!.role}.toList()
      ..sort((a, b) => a.index.compareTo(b.index));
    final firstName = firstNameOf(_nameCtrl.text);

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 10, 20, 28),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 44,
                  height: 4,
                  decoration: BoxDecoration(
                    color: ThemeController.isDarkMode ? AppColors.textTertiary : _Look.label,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 22),
              Text(_isEdit ? 'Edit User' : 'Add User', textAlign: TextAlign.center, style: DesignType.oddlini(22, ink)),
              if (_isEdit) ...[
                const SizedBox(height: 4),
                Text(
                  widget.existing!.email ?? '',
                  textAlign: TextAlign.center,
                  style: DesignType.elms(12.5, DesignInk.subtitle, FontWeight.w300),
                ),
              ],
              const SizedBox(height: 22),
              TextFormField(
                controller: _nameCtrl,
                enabled: !_saving,
                autofocus: !_isEdit,
                style: fieldText,
                cursorColor: ink,
                textCapitalization: TextCapitalization.words,
                textInputAction: TextInputAction.next,
                decoration: _decoration('Full name'),
                validator: (v) => (v ?? '').trim().isEmpty ? 'Name is required' : null,
              ),
              if (!_isEdit) ...[
                const SizedBox(height: 12),
                TextFormField(
                  controller: _emailCtrl,
                  enabled: !_saving,
                  style: fieldText,
                  cursorColor: ink,
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.next,
                  decoration: _decoration('Email'),
                  validator: (v) {
                    final value = (v ?? '').trim();
                    if (value.isEmpty) return 'Email is required';
                    if (!value.contains('@') || !value.contains('.')) return 'Enter a valid email';
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _passCtrl,
                  enabled: !_saving,
                  style: fieldText,
                  cursorColor: ink,
                  obscureText: _obscure,
                  decoration: _decoration(
                    'Temporary Password',
                    suffix: IconButton(
                      tooltip: _obscure ? 'Show password' : 'Hide password',
                      onPressed: () {
                        HapticFeedback.selectionClick();
                        setState(() => _obscure = !_obscure);
                      },
                      icon: Icon(
                        _obscure ? Icons.visibility_rounded : Icons.visibility_off_rounded,
                        size: 22,
                        color: DesignInk.muted,
                      ),
                    ),
                  ),
                  validator: (v) => (v ?? '').length < 8 ? 'At least 8 characters' : null,
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(8, 5, 8, 0),
                  child: Text(
                    firstName.isEmpty
                        ? 'Share it with them.'
                        : 'Share it with $firstName.',
                    style: DesignType.elms(12.5, DesignInk.subtitle, FontWeight.w300),
                  ),
                ),
              ],
              const SizedBox(height: 14),
              DropdownButtonFormField<AppRole>(
                initialValue: _role,
                style: DesignType.oddlini(15, ink),
                dropdownColor: AppColors.surface0,
                borderRadius: BorderRadius.circular(12),
                icon: Icon(Icons.keyboard_arrow_down_rounded, size: 28, color: DesignInk.subtitle),
                decoration: _decoration('Role').copyWith(floatingLabelBehavior: FloatingLabelBehavior.never, labelText: null),
                items: roles
                    .map(
                      (r) => DropdownMenuItem(
                        value: r,
                        enabled: widget.roles.contains(r),
                        child: Text(_roleName(r)),
                      ),
                    )
                    .toList(),
                onChanged: _saving
                    ? null
                    : (r) {
                        if (r == null) return;
                        HapticFeedback.selectionClick();
                        setState(() => _role = r);
                      },
              ),
              const SizedBox(height: 30),
              Center(
                child: _CreateUserButton(
                  label: _isEdit ? 'Save' : 'Create User',
                  onPressed: _saving ? null : _save,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Loading / error ──────────────────────────────────────────────────────────

class _ShimmerList extends StatelessWidget {
  const _ShimmerList();

  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: AppColors.surface2,
      highlightColor: AppColors.surface4,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        itemCount: 6,
        separatorBuilder: (_, __) => const SizedBox(height: 8),
        itemBuilder: (_, __) => DecoratedBox(
          decoration: ShapeDecoration(color: AppColors.surface1, shape: const StadiumBorder()),
          child: const SizedBox(height: _UserCard.height),
        ),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message, required this.onRetry});
  final String message;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    final ink = DesignInk.primary;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.cloud_off_rounded, size: 40, color: DesignInk.muted),
            const SizedBox(height: AppSpacing.md),
            Text('Unable to load users', style: DesignType.oddlini(17, ink)),
            const SizedBox(height: AppSpacing.xs),
            Text(
              message,
              textAlign: TextAlign.center,
              style: DesignType.elms(13, DesignInk.muted, FontWeight.w300),
            ),
            const SizedBox(height: AppSpacing.lg),
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                foregroundColor: ink,
                side: BorderSide(color: ink),
                shape: const StadiumBorder(),
              ),
              onPressed: () {
                HapticFeedback.lightImpact();
                onRetry();
              },
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: Text('Retry', style: DesignType.elms(13, ink, FontWeight.w600)),
            ),
          ],
        ),
      ),
    );
  }
}
