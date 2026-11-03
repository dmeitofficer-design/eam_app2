// lib/features/engineers/presentation/screens/engineers_screen.dart
//
// Engineers Directory, built from the engineers directory designs: pill
// cards with a presence icon; long-press reveals edit / delete.

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:shimmer/shimmer.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/design_type.dart';
import '../../../../core/theme/theme_controller.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../approvals/data/repositories/approvals_repository.dart';
import '../../../approvals/presentation/delete_or_request.dart';
import '../../../auth/presentation/bloc/auth_bloc.dart';
import '../bloc/engineers_bloc.dart';
import './engineer_form_sheet.dart';

// Point to the comprehensive machines feature model path
import '../../../machines/data/models/engineer.dart';

class EngineersScreen extends StatefulWidget {
  const EngineersScreen({super.key});

  @override
  State<EngineersScreen> createState() => _EngineersScreenState();
}

class _EngineersScreenState extends State<EngineersScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  /// The card whose edit / delete buttons are showing (one at a time).
  String? _openId;

  void _closeCards() {
    if (_openId != null) setState(() => _openId = null);
  }

  @override
  void initState() {
    super.initState();
    context.read<EngineersBloc>().add(EngineersFetchAll());
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // Helper method to trigger the bottom form sheet
  void _openAddEngineerSheet() {
    EngineerFormSheet.show(
      context,
      machineId: null,
    );
  }

  void _goBack() {
    if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    } else {
      context.go('/dashboard');
    }
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final isDesktop = width >= AppConstants.tabletBreakpoint;
    final authState = context.watch<AuthBloc>().state;
    final profile = authState is AuthAuthenticated ? authState.profile : null;
    // Engineers are managed by admins; deleting goes through deleteOrRequest.
    final canManage = profile?.isAdmin ?? false;
    final hPad = isDesktop ? AppSpacing.xl : 12.0; // 8.79 → 12

    return Scaffold(
      backgroundColor: AppColors.surface0,
      // Mobile: Create New sits under the last card, as in the design.
      floatingActionButton: canManage && isDesktop ? _CreateNewButton(onTap: _openAddEngineerSheet) : null,
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: hPad),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Header: back · icon + title · add ───────────────────────
              SizedBox(
                height: 58, // top bar, 0–41 → 58
                child: Row(
                  children: [
                    _TapIcon(
                      tooltip: 'Back',
                      onTap: _goBack,
                      child: Icon(Icons.arrow_back_rounded, size: 22, color: DesignInk.primary),
                    ),
                    const SizedBox(width: 8),
                    Icon(Icons.engineering_outlined, size: 22, color: DesignInk.primary),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Engineers Directory',
                        style: DesignType.oddlini(17, DesignInk.primary), // 12 → 17
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (canManage)
                      _TapIcon(
                        tooltip: 'Register New Engineer',
                        onTap: _openAddEngineerSheet,
                        child: Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(color: DesignInk.primary, width: 1.3),
                          ),
                          alignment: Alignment.center,
                          child: _ThickPlus(size: 22, color: DesignInk.primary),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 10),

              // ── Search pill ─────────────────────────────────────────────
              _SearchPill(
                controller: _searchController,
                hasText: _searchQuery.isNotEmpty,
                onChanged: (val) => setState(() => _searchQuery = val.toLowerCase()),
                onClear: () {
                  _searchController.clear();
                  setState(() => _searchQuery = '');
                },
              ),
              const SizedBox(height: 21), // gap above first card, 15 → 21

              // ── Bloc Consumer Screen State ──────────────────────────────
              Expanded(
                child: BlocConsumer<EngineersBloc, EngineersState>(
                  listener: (context, state) {
                    if (state is EngineersError) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(state.message), backgroundColor: Colors.red),
                      );
                    } else if (state is EngineersActionFailure) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(state.message), backgroundColor: Colors.redAccent),
                      );
                    } else if (state is EngineersActionSuccess) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(state.message), backgroundColor: Colors.green),
                      );
                    }
                  },
                  builder: (context, state) {
                    if (state is EngineersInitial || state is EngineersLoading) {
                      return _ShimmerList(isDesktop: isDesktop);
                    }

                    if (state is EngineersError) {
                      return _ErrorCard(
                        message: state.message,
                        onRetry: () => context.read<EngineersBloc>().add(EngineersFetchAll()),
                      );
                    }

                    final List<Engineer> engineersList = switch (state) {
                      EngineersLoaded(:final engineers) => engineers,
                      EngineersActionSuccess(:final engineers) => engineers,
                      EngineersActionFailure(:final engineers) => engineers,
                      _ => <Engineer>[],
                    };

                    final filteredEngineers = engineersList.where((eng) {
                      final nameMatch = eng.name.toLowerCase().contains(_searchQuery);
                      final phoneMatch = (eng.phone ?? '').toLowerCase().contains(_searchQuery);
                      return nameMatch || phoneMatch;
                    }).toList();

                    if (filteredEngineers.isEmpty) {
                      return _EmptyState(
                        searching: _searchQuery.isNotEmpty,
                        canManage: canManage,
                        onCreate: _openAddEngineerSheet,
                      );
                    }

                    Widget card(Engineer e) => _EngineerCard(
                          key: ValueKey(e.id),
                          engineer: e,
                          canManage: canManage,
                          open: _openId == e.id,
                          onOpenChanged: (open) => setState(() => _openId = open ? e.id : null),
                        );
                    final showCreate = canManage && !isDesktop;

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
                      color: DesignInk.available,
                      backgroundColor: AppColors.surface1,
                      onRefresh: () async {
                        context.read<EngineersBloc>().add(EngineersFetchAll());
                      },
                      child: isDesktop
                          ? GridView.builder(
                              padding: const EdgeInsets.only(bottom: 96), // clear of Create New
                              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: 2,
                                crossAxisSpacing: AppSpacing.md,
                                mainAxisSpacing: 12,
                                mainAxisExtent: _EngineerCard.height,
                              ),
                              itemCount: filteredEngineers.length,
                              itemBuilder: (context, index) => card(filteredEngineers[index]),
                            )
                          : ListView.separated(
                              padding: const EdgeInsets.only(bottom: AppSpacing.lg),
                              physics: const AlwaysScrollableScrollPhysics(),
                              itemCount: filteredEngineers.length + (showCreate ? 1 : 0),
                              separatorBuilder: (_, i) => SizedBox(
                                // 8.5 → 12 between cards; 12.2 → 17 above Create New
                                height: i == filteredEngineers.length - 1 ? 17 : 12,
                              ),
                              itemBuilder: (context, index) => index < filteredEngineers.length
                                  ? card(filteredEngineers[index])
                                  : Align(
                                      alignment: Alignment.centerRight,
                                      child: _CreateNewButton(onTap: _openAddEngineerSheet),
                                    ),
                            ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Search pill ──────────────────────────────────────────────────────────────

class _SearchPill extends StatelessWidget {
  const _SearchPill({
    required this.controller,
    required this.hasText,
    required this.onChanged,
    required this.onClear,
  });

  final TextEditingController controller;
  final bool hasText;
  final ValueChanged<String> onChanged;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 48,
      decoration: BoxDecoration(
        border: Border.all(color: DesignInk.primary, width: 1.4),
        borderRadius: BorderRadius.circular(24),
      ),
      padding: const EdgeInsets.only(left: 5, right: 6),
      child: Row(
        children: [
          // Grey disc with a person, as in the design.
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(shape: BoxShape.circle, color: _Look.searchDisc),
            alignment: Alignment.center,
            child: const Icon(Icons.person_rounded, size: 28, color: DesignInk.searchIcon),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: TextField(
              controller: controller,
              onChanged: onChanged,
              style: DesignType.elms(17, DesignInk.primary, FontWeight.w400),
              cursorColor: DesignInk.primary,
              decoration: InputDecoration(
                isCollapsed: true,
                contentPadding: EdgeInsets.zero,
                filled: false,
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                hintText: 'Search by name or contact',
                hintStyle: DesignType.elms(17, DesignInk.muted, FontWeight.w300),
              ),
            ),
          ),
          if (hasText)
            IconButton(
              visualDensity: VisualDensity.compact,
              icon: const Icon(Icons.close_rounded, size: 20, color: DesignInk.muted),
              onPressed: onClear,
            ),
        ],
      ),
    );
  }
}

// ── Look of the card design ──────────────────────────────────────────────────

class _Look {
  _Look._();

  /// #F1F1F2 card / pill fill.
  static Color get fill => ThemeController.isDarkMode ? AppColors.surface1 : const Color(0xFFF1F1F2);
  static Color get searchDisc => ThemeController.isDarkMode ? AppColors.surface2 : const Color(0xFFEEEEEF);
  static const onAssignment = Color(0xFFF8A93A); // active but not available
  static const inactive = Color(0xFF808285);
  static const createNew = Color(0xFF00AEEF);
  static const designation = Color(0xFF6D6E71);
}

/// Availability as the card shows it.
enum _Presence {
  available(DesignInk.available, 'Available'),
  onAssignment(_Look.onAssignment, 'On assignment'),
  inactive(_Look.inactive, 'Inactive');

  const _Presence(this.color, this.label);
  final Color color;
  final String label;

  static _Presence of(Engineer e) => !e.isActive
      ? inactive
      : e.isAvailable
          ? available
          : onAssignment;
}

// ── Engineer card ────────────────────────────────────────────────────────────

/// Pill card. Long-press (admins) shrinks it to the left and slides the
/// edit / delete pill in from the right; tap, scroll or opening another
/// card closes it.
class _EngineerCard extends StatefulWidget {
  const _EngineerCard({
    super.key,
    required this.engineer,
    required this.canManage,
    required this.open,
    required this.onOpenChanged,
  });

  static const double height = 72;
  static const double actionsWidth = 42;
  static const double gap = 8;

  final Engineer engineer;
  final bool canManage;
  final bool open;
  final ValueChanged<bool> onOpenChanged;

  @override
  State<_EngineerCard> createState() => _EngineerCardState();
}

class _EngineerCardState extends State<_EngineerCard> with SingleTickerProviderStateMixin {
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
  void didUpdateWidget(_EngineerCard old) {
    super.didUpdateWidget(old);
    if (widget.open != old.open) widget.open ? _ctrl.forward() : _ctrl.reverse();
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
    if (!widget.canManage) return;
    HapticFeedback.mediumImpact();
    widget.onOpenChanged(!widget.open);
  }

  void _close() {
    if (!widget.open) return;
    HapticFeedback.selectionClick();
    widget.onOpenChanged(false);
  }

  void _edit() {
    widget.onOpenChanged(false);
    EngineerFormSheet.show(context, machineId: widget.engineer.machineId, engineer: widget.engineer);
  }

  Future<void> _delete() async {
    final e = widget.engineer;
    final bloc = context.read<EngineersBloc>();
    widget.onOpenChanged(false);
    await deleteOrRequest(
      context,
      target: DeletionTarget.engineer,
      id: e.id,
      label: e.name,
      consequence: 'Remove ${e.name} from the engineers directory?',
      deleteNow: () async => bloc.add(EngineersDeleteRequested(e.id)),
    );
  }

  @override
  Widget build(BuildContext context) {
    const reserved = _EngineerCard.actionsWidth + _EngineerCard.gap;
    return SizedBox(
      height: _EngineerCard.height,
      child: AnimatedBuilder(
        animation: _reveal,
        builder: (context, _) {
          final t = _reveal.value; // may overshoot 1 slightly
          final shown = t.clamp(0.0, 1.0);
          return Stack(
            clipBehavior: Clip.none,
            children: [
              if (widget.canManage && _ctrl.value > 0)
                Positioned(
                  right: 0,
                  top: 0,
                  bottom: 0,
                  width: _EngineerCard.actionsWidth,
                  child: Opacity(
                    opacity: shown,
                    child: Transform.translate(
                      offset: Offset((1 - t) * 28, 0),
                      child: Transform.scale(
                        scale: 0.85 + 0.15 * shown,
                        child: _ActionPill(onEdit: _edit, onDelete: _delete),
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
                    child: _CardBody(engineer: widget.engineer),
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
  const _CardBody({required this.engineer});
  final Engineer engineer;

  @override
  Widget build(BuildContext context) {
    final presence = _Presence.of(engineer);
    final inactive = presence == _Presence.inactive;
    final ink = DesignInk.primary;
    final avatarInk = inactive ? _Look.inactive : ink;
    final hasDesignation = engineer.designation != null && engineer.designation!.isNotEmpty;

    return Container(
      decoration: ShapeDecoration(
        color: _Look.fill,
        shape: StadiumBorder(side: BorderSide(color: ink, width: 1.3)),
      ),
      padding: const EdgeInsets.only(left: 13, right: 12),
      child: Row(
        children: [
          // Avatar: outlined circle, initial, status dot on the lower right.
          SizedBox(
            width: 36,
            height: 36,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  width: 35,
                  height: 35,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: avatarInk, width: 1.2),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    engineer.name.isNotEmpty ? engineer.name[0].toUpperCase() : '?',
                    style: DesignType.oddlini(22, avatarInk),
                  ),
                ),
                Positioned(
                  left: 25,
                  top: 26,
                  child: Container(
                    width: 9,
                    height: 9,
                    decoration: BoxDecoration(shape: BoxShape.circle, color: presence.color),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 9),

          // Name · designation · phone
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  engineer.name,
                  style: DesignType.oddlini(17, inactive ? DesignInk.unavailableName : ink),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (hasDesignation)
                  Text(
                    engineer.designation!,
                    style: DesignType.elms(12.5, inactive ? DesignInk.muted : _Look.designation, FontWeight.w300),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                Row(
                  children: [
                    const Icon(Icons.phone_iphone_rounded, size: 12, color: DesignInk.muted),
                    const SizedBox(width: 3),
                    Flexible(
                      child: Text(
                        engineer.phone?.isNotEmpty == true ? engineer.phone! : 'No contact listed',
                        style: DesignType.google(13, DesignInk.muted),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 6),
          _PresenceIcon(presence: presence),
        ],
      ),
    );
  }
}

/// Green check (available), orange clock (on assignment), grey clock (inactive).
class _PresenceIcon extends StatelessWidget {
  const _PresenceIcon({required this.presence});
  final _Presence presence;

  @override
  Widget build(BuildContext context) {
    final c = presence.color;
    return Tooltip(
      message: presence.label,
      child: SizedBox.square(
        dimension: 42,
        child: presence == _Presence.available
            ? Icon(Icons.published_with_changes_rounded, size: 42, color: c)
            : CustomPaint(painter: _ClockPainter(c)),
      ),
    );
  }
}

/// The design's waiting clock: a filled dial with light hands, inside a ring
/// that is solid with an arrowhead on the left half and dotted on the right.
class _ClockPainter extends CustomPainter {
  _ClockPainter(this.color);
  final Color color;

  static double _rad(double deg) => deg * math.pi / 180;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final c = size.center(Offset.zero);
    final ringR = w * 0.42;
    final stroke = w * 0.085;

    // Solid arc: from the bottom, round the left, to the top right.
    const start = 100.0, sweep = 205.0;
    canvas.drawArc(
      Rect.fromCircle(center: c, radius: ringR),
      _rad(start),
      _rad(sweep),
      false,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke
        ..strokeCap = StrokeCap.round,
    );

    // Arrowhead at the end of the arc, pointing clockwise.
    final end = _rad(start + sweep);
    final tip = c + Offset(math.cos(end), math.sin(end)) * ringR;
    final along = Offset(-math.sin(end), math.cos(end)); // clockwise tangent
    final out = Offset(math.cos(end), math.sin(end));
    final head = w * 0.13;
    canvas.drawPath(
      Path()
        ..moveTo((tip + along * head).dx, (tip + along * head).dy)
        ..lineTo((tip + out * head * 0.8).dx, (tip + out * head * 0.8).dy)
        ..lineTo((tip - out * head * 0.8).dx, (tip - out * head * 0.8).dy)
        ..close(),
      Paint()..color = color,
    );

    // Dotted right half.
    final dot = Paint()..color = color;
    for (var deg = start + sweep + 26; deg < start + 360 - 8; deg += 21) {
      final a = _rad(deg);
      canvas.drawCircle(c + Offset(math.cos(a), math.sin(a)) * ringR, stroke * 0.42, dot);
    }

    // Filled dial with hands.
    final dialR = w * 0.27;
    canvas.drawCircle(c, dialR, Paint()..color = color);
    final hand = Paint()
      ..color = AppColors.surface0
      ..strokeWidth = w * 0.055
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(c, c + Offset(0, -dialR * 0.62), hand);
    canvas.drawLine(c, c + Offset(dialR * 0.45, dialR * 0.3), hand);
  }

  @override
  bool shouldRepaint(_ClockPainter old) => old.color != color;
}

/// Edit (top) and delete (bottom) in a vertical pill.
class _ActionPill extends StatelessWidget {
  const _ActionPill({required this.onEdit, required this.onDelete});
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final ink = DesignInk.primary;
    return Container(
      decoration: BoxDecoration(
        color: _Look.fill,
        borderRadius: BorderRadius.circular(21),
      ),
      child: Column(
        children: [
          Expanded(
            child: _TactileButton(
              tooltip: 'Edit Profile',
              onTap: onEdit,
              child: Icon(Icons.edit, size: 22, color: ink),
            ),
          ),
          Container(height: 1, margin: const EdgeInsets.symmetric(horizontal: 6), color: DesignInk.muted),
          Expanded(
            child: _TactileButton(
              tooltip: 'Delete Profile',
              onTap: onDelete,
              strongHaptic: true,
              child: const Icon(Icons.delete_outline_rounded, size: 23, color: DesignInk.delete),
            ),
          ),
        ],
      ),
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
          scale: _down ? 0.8 : 1,
          duration: Duration(milliseconds: _down ? 90 : 260),
          curve: _down ? Curves.easeOut : Curves.elasticOut,
          child: Center(child: widget.child),
        ),
      ),
    );
  }
}

// ── Create New pill (bottom right) ───────────────────────────────────────────

class _CreateNewButton extends StatelessWidget {
  const _CreateNewButton({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ink = DesignInk.primary;
    return Material(
      color: _Look.fill,
      shape: StadiumBorder(side: BorderSide(color: ink, width: 1.2)),
      child: InkWell(
        onTap: () {
          HapticFeedback.lightImpact();
          onTap();
        },
        customBorder: const StadiumBorder(),
        child: SizedBox(
          height: 50,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(width: 18),
              Text('Create New', style: DesignType.elms(14, _Look.createNew, FontWeight.w600)),
              const SizedBox(width: 6),
              SizedBox(
                width: 38,
                height: 38,
                child: CustomPaint(
                  painter: _OpenCirclePainter(color: ink),
                  child: Center(child: _ThickPlus(size: 22, color: ink)),
                ),
              ),
              const SizedBox(width: 6),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Small drawing helpers ────────────────────────────────────────────────────

/// The design's heavy "+" (stroke 3 design units, round caps).
class _ThickPlus extends StatelessWidget {
  const _ThickPlus({required this.size, required this.color});
  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) =>
      CustomPaint(size: Size.square(size), painter: _PlusPainter(color, size * 0.19));
}

class _PlusPainter extends CustomPainter {
  _PlusPainter(this.color, this.stroke);
  final Color color;
  final double stroke;

  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = color
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round;
    final inset = stroke / 2;
    canvas.drawLine(Offset(size.width / 2, inset), Offset(size.width / 2, size.height - inset), p);
    canvas.drawLine(Offset(inset, size.height / 2), Offset(size.width - inset, size.height / 2), p);
  }

  @override
  bool shouldRepaint(_PlusPainter old) => old.color != color || old.stroke != stroke;
}

/// Circle around the Create New "+", open on the left facing the label
/// (arc from 198° to 155°, as in the design).
class _OpenCirclePainter extends CustomPainter {
  _OpenCirclePainter({required this.color});
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..strokeCap = StrokeCap.round;
    final rect = Rect.fromCircle(center: size.center(Offset.zero), radius: size.width / 2 - 0.5);
    const start = 198 * math.pi / 180;
    const sweep = 317 * math.pi / 180;
    canvas.drawArc(rect, start, sweep, false, p);
  }

  @override
  bool shouldRepaint(_OpenCirclePainter old) => old.color != color;
}

/// Borderless tap target with a tooltip.
class _TapIcon extends StatelessWidget {
  const _TapIcon({required this.tooltip, required this.onTap, required this.child});
  final String tooltip;
  final VoidCallback onTap;
  final Widget child;

  @override
  Widget build(BuildContext context) => Tooltip(
        message: tooltip,
        child: InkResponse(
          onTap: onTap,
          radius: 22,
          child: Center(widthFactor: 1, heightFactor: 1, child: child),
        ),
      );
}

// ── Empty / loading / error states ───────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.searching, required this.canManage, required this.onCreate});
  final bool searching;
  final bool canManage;
  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.engineering_outlined, size: 56, color: DesignInk.muted),
          const SizedBox(height: AppSpacing.md),
          Text(
            searching ? 'No engineers match your search.' : 'No engineers registered yet.',
            style: DesignType.elms(14, DesignInk.muted, FontWeight.w300),
          ),
          if (!searching && canManage) ...[
            const SizedBox(height: AppSpacing.lg),
            _CreateNewButton(onTap: onCreate),
          ],
        ],
      ),
    );
  }
}

class _ShimmerList extends StatelessWidget {
  const _ShimmerList({required this.isDesktop});
  final bool isDesktop;

  @override
  Widget build(BuildContext context) {
    Widget block() => Container(
          height: _EngineerCard.height,
          decoration: BoxDecoration(
            color: AppColors.surface1,
            borderRadius: BorderRadius.circular(10),
          ),
        );
    return Shimmer.fromColors(
      baseColor: AppColors.surface2,
      highlightColor: AppColors.surface4,
      child: isDesktop
          ? GridView.builder(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: AppSpacing.md,
                mainAxisSpacing: 12,
                mainAxisExtent: _EngineerCard.height,
              ),
              itemCount: 6,
              itemBuilder: (_, __) => block(),
            )
          : ListView.separated(
              itemCount: 7,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (_, __) => block(),
            ),
    );
  }
}

class _ErrorCard extends StatelessWidget {
  const _ErrorCard({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final bool isNetworkIssue = message.toLowerCase().contains('internet') ||
        message.toLowerCase().contains('connection') ||
        message.toLowerCase().contains('timed out') ||
        message.toLowerCase().contains('supabase');
    final ink = DesignInk.primary;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Container(
          padding: const EdgeInsets.all(AppSpacing.xl),
          decoration: BoxDecoration(
            border: Border.all(color: ink, width: 0.7),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                isNetworkIssue ? Icons.wifi_off_rounded : Icons.cloud_off_rounded,
                color: isNetworkIssue ? DesignInk.muted : DesignInk.delete,
                size: 40,
              ),
              const SizedBox(height: AppSpacing.md),
              Text(
                isNetworkIssue ? 'Connection Error' : 'Unable to Load Data',
                style: DesignType.oddlini(17, ink),
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                message,
                style: DesignType.elms(13, DesignInk.muted, FontWeight.w300),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSpacing.lg),
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: ink,
                  side: BorderSide(color: ink),
                  shape: const StadiumBorder(),
                ),
                onPressed: onRetry,
                icon: const Icon(Icons.refresh_rounded, size: 18),
                label: Text('Retry', style: DesignType.elms(13, ink, FontWeight.w600)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
