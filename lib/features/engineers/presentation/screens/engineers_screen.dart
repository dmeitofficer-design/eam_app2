// lib/features/engineers/presentation/screens/engineers_screen.dart
//
// Engineers Directory, built from the engineers_directory.svg design.
// The design is 255 units wide; sizes below are design units × 1.41
// (≈ a 360 dp phone), noted next to each value.

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shimmer/shimmer.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/theme_controller.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../approvals/data/repositories/approvals_repository.dart';
import '../../../approvals/presentation/delete_or_request.dart';
import '../../../auth/presentation/bloc/auth_bloc.dart';
import '../bloc/engineers_bloc.dart';
import './engineer_form_sheet.dart';

// Point to the comprehensive machines feature model path
import '../../../machines/data/models/engineer.dart';

// ── Design tokens (from the SVG) ─────────────────────────────────────────────

class _Ink {
  _Ink._();

  /// #231F20 strokes and text; light text in dark mode so it stays readable.
  static Color get primary =>
      ThemeController.isDarkMode ? AppColors.textPrimary : const Color(0xFF231F20);
  static const muted = Color(0xFFAAAAAA); // designation, phone, search hint
  static const searchIcon = Color(0xFFA9A9A9);
  static const available = Color(0xFF39B54A); // status dot
  static const unavailable = Color(0xFF808285); // avatar + dot when unavailable
  static const unavailableName = Color(0xFF939598);
  static const delete = Color(0xFFFF2533);
}

class _Type {
  _Type._();

  /// Oddlini Bold is not on Google Fonts. Until the font file is bundled as
  /// the 'Oddlini' family (see pubspec.yaml), Elms Sans Bold stands in.
  static TextStyle oddlini(double size, Color color) => TextStyle(
        fontFamily: 'Oddlini',
        fontFamilyFallback: [GoogleFonts.elmsSans(fontWeight: FontWeight.w700).fontFamily!],
        fontWeight: FontWeight.w700,
        fontSize: size,
        color: color,
        height: 1.15,
      );

  static TextStyle elms(double size, Color color, FontWeight weight) =>
      GoogleFonts.elmsSans(fontSize: size, color: color, fontWeight: weight, height: 1.2);

  static TextStyle google(double size, Color color) =>
      GoogleFonts.googleSans(fontSize: size, color: color, height: 1.2);
}

class EngineersScreen extends StatefulWidget {
  const EngineersScreen({super.key});

  @override
  State<EngineersScreen> createState() => _EngineersScreenState();
}

class _EngineersScreenState extends State<EngineersScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

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
                      child: Icon(Icons.arrow_back_rounded, size: 22, color: _Ink.primary),
                    ),
                    const SizedBox(width: 8),
                    Icon(Icons.engineering_outlined, size: 22, color: _Ink.primary),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Engineers Directory',
                        style: _Type.oddlini(17, _Ink.primary), // 12 → 17
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (canManage)
                      _TapIcon(
                        tooltip: 'Register New Engineer',
                        onTap: _openAddEngineerSheet,
                        child: SizedBox(
                          width: 36, // 25.1 → 36
                          height: 36,
                          child: CustomPaint(
                            painter: _BracketFramePainter(color: _Ink.primary),
                            child: Center(child: _ThickPlus(size: 24, color: _Ink.primary)),
                          ),
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

                    Widget card(Engineer e) => _EngineerCard(engineer: e, canManage: canManage);
                    final showCreate = canManage && !isDesktop;

                    return RefreshIndicator(
                      color: _Ink.available,
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
      height: 47, // 33.33 → 47
      decoration: BoxDecoration(
        border: Border.all(color: _Ink.primary),
        borderRadius: BorderRadius.circular(23.5),
      ),
      padding: const EdgeInsets.only(left: 12, right: 6),
      child: Row(
        children: [
          const Icon(Icons.person_search_rounded, size: 32, color: _Ink.searchIcon), // 23.6 → 33
          const SizedBox(width: 6),
          Expanded(
            child: TextField(
              controller: controller,
              onChanged: onChanged,
              style: _Type.elms(17, _Ink.primary, FontWeight.w400),
              cursorColor: _Ink.primary,
              decoration: InputDecoration(
                isCollapsed: true,
                filled: false,
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                hintText: 'Search by name or contact',
                hintStyle: _Type.elms(17, _Ink.muted, FontWeight.w300), // 12 → 17
              ),
            ),
          ),
          if (hasText)
            IconButton(
              visualDensity: VisualDensity.compact,
              icon: const Icon(Icons.close_rounded, size: 20, color: _Ink.muted),
              onPressed: onClear,
            ),
        ],
      ),
    );
  }
}

// ── Engineer card ────────────────────────────────────────────────────────────

class _EngineerCard extends StatelessWidget {
  const _EngineerCard({required this.engineer, required this.canManage});

  static const double height = 70; // 49.8 → 70

  final Engineer engineer;
  final bool canManage;

  Future<void> _delete(BuildContext context) async {
    final bloc = context.read<EngineersBloc>();
    await deleteOrRequest(
      context,
      target: DeletionTarget.engineer,
      id: engineer.id,
      label: engineer.name,
      consequence: 'Remove ${engineer.name} from the engineers directory?',
      deleteNow: () async => bloc.add(EngineersDeleteRequested(engineer.id)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final available = engineer.isAvailable;
    final ink = _Ink.primary;
    final avatarColor = available ? ink : _Ink.unavailable;
    final nameColor = available ? ink : _Ink.unavailableName;
    final hasDesignation = engineer.designation != null && engineer.designation!.isNotEmpty;

    return Opacity(
      // Former employees stay listed but faded.
      opacity: engineer.isActive ? 1.0 : 0.55,
      child: Container(
        height: height,
        decoration: BoxDecoration(
          border: Border.all(color: ink, width: 0.7), // 0.5 → 0.7
          borderRadius: BorderRadius.circular(10), // 7.11 → 10
        ),
        padding: const EdgeInsets.fromLTRB(8, 0, 6, 0),
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
                    width: 33, // r 11.7 → 16.5
                    height: 33,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: avatarColor, width: 0.7),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      engineer.name.isNotEmpty ? engineer.name[0].toUpperCase() : '?',
                      style: _Type.oddlini(22, avatarColor), // 15.9 → 22
                    ),
                  ),
                  Positioned(
                    left: 23,
                    top: 23,
                    child: Container(
                      width: 8, // r 2.92 → 4
                      height: 8,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: available ? _Ink.available : _Ink.unavailable,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 6),

            // Name · designation · phone
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          engineer.name,
                          style: _Type.oddlini(17, nameColor), // 12 → 17
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 6),
                      _StatusLabel(available: available),
                    ],
                  ),
                  if (hasDesignation)
                    Text(
                      engineer.designation!,
                      style: _Type.elms(12.7, _Ink.muted, FontWeight.w300), // 9 → 12.7
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      const Icon(Icons.phone_iphone_rounded, size: 12, color: _Ink.muted),
                      const SizedBox(width: 3),
                      Flexible(
                        child: Text(
                          engineer.phone?.isNotEmpty == true ? engineer.phone! : 'No contact listed',
                          style: _Type.google(13.3, _Ink.muted), // 9.42 → 13.3
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Edit / delete in an outlined, divided pill.
            if (canManage) ...[
              const SizedBox(width: 8),
              Container(
                width: 38, // 26.86 → 38
                height: 60, // 42.44 → 60
                decoration: BoxDecoration(
                  border: Border.all(color: ink, width: 0.7),
                  borderRadius: BorderRadius.circular(8), // 5.42 → 8
                ),
                child: Column(
                  children: [
                    Expanded(
                      child: _TapIcon(
                        tooltip: 'Edit Profile',
                        onTap: () => EngineerFormSheet.show(
                          context,
                          machineId: engineer.machineId,
                          engineer: engineer,
                        ),
                        child: Icon(Icons.edit, size: 17, color: ink),
                      ),
                    ),
                    Container(height: 1, color: ink), // 0.75 → 1
                    Expanded(
                      child: _TapIcon(
                        tooltip: 'Delete Profile',
                        onTap: () => _delete(context),
                        child: const Icon(Icons.delete_outline_rounded, size: 17, color: _Ink.delete),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// "available" with a check-in-circle icon, or "Unavailable" with a clock.
class _StatusLabel extends StatelessWidget {
  const _StatusLabel({required this.available});
  final bool available;

  @override
  Widget build(BuildContext context) {
    final ink = _Ink.primary;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          available ? Icons.published_with_changes_rounded : Icons.update_rounded,
          size: 11, // 7.7 → 11
          color: ink,
        ),
        const SizedBox(width: 3),
        Text(
          available ? 'available' : 'Unavailable',
          style: _Type.google(available ? 10 : 8.5, ink), // 7 → 10, 6 → 8.5
        ),
      ],
    );
  }
}

// ── Create New pill (bottom right) ───────────────────────────────────────────

class _CreateNewButton extends StatelessWidget {
  const _CreateNewButton({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ink = _Ink.primary;
    return Material(
      color: AppColors.surface0,
      shape: StadiumBorder(side: BorderSide(color: ink, width: 1)), // 0.75 → 1
      child: InkWell(
        onTap: onTap,
        customBorder: const StadiumBorder(),
        child: SizedBox(
          height: 50, // 35.15 → 50
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(width: 16), // design width 91.26 → ~129 with the real font
              Text('Create New', style: _Type.elms(12.7, ink, FontWeight.w600)), // 9 → 12.7
              const SizedBox(width: 6),
              SizedBox(
                width: 36,
                height: 36,
                child: CustomPaint(
                  painter: _OpenCirclePainter(color: ink),
                  child: Center(child: _ThickPlus(size: 21, color: ink)),
                ),
              ),
              const SizedBox(width: 7),
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

/// Frame around the header "+": a rounded square drawn as three strokes,
/// leaving the gaps the design has (left middle, top and bottom left).
/// Coordinates are the design's, relative to its 25.12-unit box.
class _BracketFramePainter extends CustomPainter {
  _BracketFramePainter({required this.color});
  final Color color;

  static const _box = 25.12;
  static const _r = 5.42;

  @override
  void paint(Canvas canvas, Size size) {
    final k = size.width / _box;
    final p = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    Offset o(double x, double y) => Offset(x * k, y * k);
    final radius = Radius.circular(_r * k);

    // Right bracket: top edge → top-right corner → right side → bottom-right corner.
    canvas.drawPath(
      Path()
        ..moveTo(o(16.72, 0).dx, 0)
        ..lineTo(o(_box - _r, 0).dx, 0)
        ..arcToPoint(o(_box, _r), radius: radius)
        ..lineTo(o(_box, _box - _r).dx, o(_box, _box - _r).dy)
        ..arcToPoint(o(_box - _r, _box), radius: radius)
        ..lineTo(o(18.26, _box).dx, o(18.26, _box).dy),
      p,
    );
    // Bottom-left corner.
    canvas.drawPath(
      Path()
        ..moveTo(o(6.01, _box).dx, o(6.01, _box).dy)
        ..lineTo(o(_r, _box).dx, o(_r, _box).dy)
        ..arcToPoint(o(0, _box - _r), radius: radius)
        ..lineTo(0, o(0, 18.2).dy),
      p,
    );
    // Top-left corner.
    canvas.drawPath(
      Path()
        ..moveTo(0, o(0, 6.99).dy)
        ..lineTo(0, o(0, _r).dy)
        ..arcToPoint(o(_r, 0), radius: radius),
      p,
    );
  }

  @override
  bool shouldRepaint(_BracketFramePainter old) => old.color != color;
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
          const Icon(Icons.engineering_outlined, size: 56, color: _Ink.muted),
          const SizedBox(height: AppSpacing.md),
          Text(
            searching ? 'No engineers match your search.' : 'No engineers registered yet.',
            style: _Type.elms(14, _Ink.muted, FontWeight.w300),
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
    final ink = _Ink.primary;

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
                color: isNetworkIssue ? _Ink.muted : _Ink.delete,
                size: 40,
              ),
              const SizedBox(height: AppSpacing.md),
              Text(
                isNetworkIssue ? 'Connection Error' : 'Unable to Load Data',
                style: _Type.oddlini(17, ink),
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                message,
                style: _Type.elms(13, _Ink.muted, FontWeight.w300),
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
                label: Text('Retry', style: _Type.elms(13, ink, FontWeight.w600)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
