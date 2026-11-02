// lib/features/engineers/presentation/screens/engineer_form_sheet.dart
//
// New / Edit Engineer sheet, built from the engineer form design. The
// mock-up is ~930 px for a ~360 dp phone; sizes below are px × 0.387.

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/design_type.dart';
import '../../../../core/theme/theme_controller.dart';
import '../../../../core/utils/error_formatter.dart';
import '../../../../core/utils/feedback.dart';
import '../../../approvals/data/repositories/approvals_repository.dart';
import '../../../approvals/presentation/delete_or_request.dart';
import '../../../config/data/repositories/config_repository.dart';
import '../../../machines/data/models/engineer.dart';
import '../../../machines/presentation/bloc/machines_bloc.dart';
import '../bloc/engineers_bloc.dart';

/// machine_config type holding the Designation dropdown options.
const _designationConfigType = 'engineer_designation';

/// Shown until the options exist in machine_config (migration 009).
const _defaultDesignations = [
  'Jr Sub. Assistant Engineer',
  'Jr Assistant Engineer',
  'Asst. Service Engineer',
  'Service In Charge',
];

class EngineerFormSheet extends StatefulWidget {
  const EngineerFormSheet({
    super.key,
    this.machineId,
    this.engineer,
  });

  final String? machineId;
  final Engineer? engineer;

  /// Shows the bottom sheet. After save, refreshes the machine detail
  /// via [MachinesBloc.MachineFetchByIdRequested].
  static Future<void> show(
    BuildContext context, {
    String? machineId,
    Engineer? engineer,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) => MultiBlocProvider(
        providers: [
          BlocProvider.value(value: context.read<MachinesBloc>()),
          BlocProvider.value(value: context.read<EngineersBloc>()),
        ],
        child: EngineerFormSheet(machineId: machineId, engineer: engineer),
      ),
    );
  }

  @override
  State<EngineerFormSheet> createState() => _EngineerFormSheetState();
}

class _EngineerFormSheetState extends State<EngineerFormSheet> {
  final _formKey = GlobalKey<FormState>();
  bool _saving = false;
  late final _nameCtrl = TextEditingController(text: widget.engineer?.name ?? '');
  late final _phoneCtrl = TextEditingController(text: widget.engineer?.phone ?? '');
  late String? _designation = _blankToNull(widget.engineer?.designation);
  late bool _isActive = widget.engineer?.isActive ?? true;
  // A former employee can't be available for assignment.
  late bool _isAvailable = _isActive && (widget.engineer?.isAvailable ?? true);

  /// Options with their machine_config id (null for the built-in defaults
  /// and for the engineer's own designation when it isn't an option).
  List<({String? id, String value})> _designations = const [];
  bool _designationsOpen = false;

  @override
  void initState() {
    super.initState();
    _loadDesignations();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    super.dispose();
  }

  static String? _blankToNull(String? v) => (v == null || v.trim().isEmpty) ? null : v.trim();

  Future<void> _loadDesignations() async {
    List<({String? id, String value})> options;
    try {
      final items = await context.read<ConfigRepository>().getByType(_designationConfigType);
      options = [for (final i in items) (id: i.id, value: i.value)];
    } catch (_) {
      options = const [];
    }
    if (options.isEmpty) options = [for (final d in _defaultDesignations) (id: null, value: d)];
    if (!mounted) return;
    setState(() => _designations = _withCurrent(options));
  }

  /// Keeps the engineer's current designation selectable even if it is
  /// not (or no longer) one of the options.
  List<({String? id, String value})> _withCurrent(List<({String? id, String value})> options) {
    final current = _designation;
    if (current == null || options.any((o) => o.value.toLowerCase() == current.toLowerCase())) {
      return options;
    }
    return [(id: null, value: current), ...options];
  }

  /// Super admins remove the option; admins send a removal request.
  /// Engineers that already have it keep their designation.
  Future<void> _removeDesignation(({String? id, String value}) option) async {
    final id = option.id;
    if (id == null) return;
    final repo = context.read<ConfigRepository>();
    final removed = await deleteOrRequest(
      context,
      target: DeletionTarget.config,
      id: id,
      label: '"${option.value}" (Designation)',
      consequence: 'Remove "${option.value}" from the designation list? '
          'Engineers who already have it keep it.',
      deleteNow: () => repo.deleteOption(id),
    );
    if (!removed || !mounted) return;
    setState(() {
      _designations = _designations.where((o) => o.id != id).toList();
      if (_designation == option.value) _designation = null;
    });
  }

  Future<void> _addDesignation() async {
    final value = (await askForText(
      context,
      title: 'Add Designation',
      message: 'It will be available for every engineer.',
      hint: 'E.g. Senior Service Engineer',
      confirmLabel: 'Add',
    ))
        ?.trim();
    if (value == null || value.isEmpty || !mounted) return;

    final existing = _designations.where((o) => o.value.toLowerCase() == value.toLowerCase());
    if (existing.isNotEmpty) {
      setState(() {
        _designation = existing.first.value;
        _designationsOpen = false;
      });
      return;
    }
    try {
      final added = await context.read<ConfigRepository>().addOption(
            configType: _designationConfigType,
            value: value,
          );
      if (!mounted) return;
      setState(() {
        _designations = [..._designations, (id: added.id, value: added.value)];
        _designation = value;
        _designationsOpen = false;
      });
    } catch (e) {
      if (mounted) AppFeedback.error(context, ErrorFormatter.format(e));
    }
  }

  void _setActive(bool value) {
    setState(() {
      _isActive = value;
      if (!value) _isAvailable = false;
    });
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);

    try {
      final engineersBloc = context.read<EngineersBloc>();
      final machinesBloc = context.read<MachinesBloc>();

      final engineer = Engineer(
        id: widget.engineer?.id ?? '',
        machineId: widget.machineId,
        name: _nameCtrl.text.trim(),
        designation: _designation,
        phone: _blankToNull(_phoneCtrl.text),
        isAvailable: _isActive && _isAvailable,
        isActive: _isActive,
        createdAt: widget.engineer?.createdAt ?? DateTime.now(),
      );

      if (widget.engineer == null) {
        engineersBloc.add(EngineersCreateRequested(engineer));
      } else {
        engineersBloc.add(EngineersUpdateRequested(engineer));
      }

      // Wait a tick, then refresh the machine detail if it exists
      await Future.delayed(const Duration(milliseconds: 400));
      if (mounted) {
        if (widget.machineId != null) {
          machinesBloc.add(MachineFetchByIdRequested(widget.machineId!));
        }

        Navigator.of(context).pop();
        AppFeedback.success(
          context,
          widget.engineer == null ? 'Engineer added.' : 'Engineer updated.',
        );
      }
    } catch (e) {
      if (mounted) {
        AppFeedback.error(context, e.toString());
        setState(() => _saving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.engineer != null;
    final ink = DesignInk.primary;

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface0,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(34)), // ~90 px
        border: Border(top: BorderSide(color: ink, width: 1)),
      ),
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(21, 14, 21, 24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Handle bar (165 × 14 px)
              Center(
                child: Container(
                  width: 64,
                  height: 5,
                  decoration: BoxDecoration(
                    color: const Color(0xFF58595B),
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Text(
                isEdit ? 'Edit Engineer' : 'New Engineer',
                style: DesignType.oddlini(23, ink),
              ),
              const SizedBox(height: 26),

              _OutlinedField(
                label: 'Full Name',
                child: TextFormField(
                  controller: _nameCtrl,
                  textCapitalization: TextCapitalization.words,
                  style: _inputStyle(ink),
                  cursorColor: ink,
                  decoration: _bareInput('E.g. Mehedi Hasan'),
                  validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
                ),
              ),
              const SizedBox(height: 18),

              _DesignationField(
                value: _designation,
                options: _designations,
                open: _designationsOpen,
                onToggle: () => setState(() => _designationsOpen = !_designationsOpen),
                onSelect: (v) => setState(() {
                  _designation = v;
                  _designationsOpen = false;
                }),
                onAddAnother: _addDesignation,
                onRemove: _removeDesignation,
              ),
              const SizedBox(height: 18),

              _OutlinedField(
                label: 'Contact No.',
                child: TextFormField(
                  controller: _phoneCtrl,
                  keyboardType: TextInputType.phone,
                  style: _inputStyle(ink),
                  cursorColor: ink,
                  decoration: _bareInput('E.g. +88017123456'),
                ),
              ),
              const SizedBox(height: 18),

              _OutlinedField(
                label: 'Presence',
                contentPadding: const EdgeInsets.fromLTRB(5, 22, 5, 26),
                child: Column(
                  children: [
                    _PresenceTile(
                      title: 'Available for Assignment',
                      subtitle: _isActive ? 'ready for a tour' : 'Not available while inactive',
                      value: _isAvailable,
                      enabled: _isActive,
                      background: const Color(0xFFE0F0FC),
                      thumb: const Color(0xFF2196F3),
                      track: const Color(0xFFB3D4F0),
                      onChanged: (v) => setState(() => _isAvailable = v),
                    ),
                    const SizedBox(height: 12),
                    _PresenceTile(
                      title: 'Active Employee',
                      subtitle: 'Will be available in selection list',
                      value: _isActive,
                      enabled: true,
                      background: const Color(0xFFDDF8E3),
                      thumb: const Color(0xFF00C800),
                      track: const Color(0xFFC5DEC5),
                      onChanged: _setActive,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 22),

              Row(
                children: [
                  Expanded(
                    flex: 18, // 360 px
                    child: _ActionButton(
                      label: 'Cancel',
                      background: const Color(0xFFFDD5DA),
                      roundLeft: true,
                      leading: const _CancelMark(),
                      onTap: _saving ? null : () => Navigator.of(context).pop(),
                    ),
                  ),
                  const SizedBox(width: 15),
                  Expanded(
                    flex: 19, // 380 px
                    child: _ActionButton(
                      label: isEdit ? 'Save changes' : 'Create New',
                      background: const Color(0xFFCCFFAA),
                      roundLeft: false,
                      trailing: _saving
                          ? const SizedBox.square(
                              dimension: 22,
                              child: CircularProgressIndicator(strokeWidth: 2, color: _buttonInk),
                            )
                          : const _PlusMark(),
                      onTap: _saving ? null : _submit,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Shared styles ────────────────────────────────────────────────────────────

TextStyle _inputStyle(Color ink) => DesignType.elms(17, ink, FontWeight.w400);

InputDecoration _bareInput(String hint) => InputDecoration(
      isCollapsed: true,
      contentPadding: EdgeInsets.zero, // or the app theme's padding leaks in
      filled: false,
      border: InputBorder.none,
      enabledBorder: InputBorder.none,
      focusedBorder: InputBorder.none,
      errorBorder: InputBorder.none,
      focusedErrorBorder: InputBorder.none,
      hintText: hint,
      hintStyle: DesignType.elms(17, DesignInk.muted, FontWeight.w300),
    );

/// Pastel buttons and tiles keep dark text even in dark mode.
const _buttonInk = Color(0xFF231F20);

Color get _fieldBorder =>
    ThemeController.isDarkMode ? AppColors.textTertiary : const Color(0xFF6D6E71);

// ── Outlined field with the label in the border notch ────────────────────────

/// Rounded outline with the label sitting on its top edge (the label's
/// background covers the line, which makes the notch).
class _OutlinedField extends StatelessWidget {
  const _OutlinedField({
    required this.label,
    required this.child,
    this.contentPadding = const EdgeInsets.fromLTRB(textInset, 15, textInset, 13),
  });

  final String label;
  final Widget child;
  final EdgeInsets contentPadding;

  /// Where the label and the field text start, from the box edge.
  static const double textInset = 19;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 11), // half the label sits above the box
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            width: double.infinity,
            padding: contentPadding,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(9), // ~22 px
              border: Border.all(color: _fieldBorder, width: 1),
            ),
            child: child,
          ),
          Positioned(
            left: textInset - 5,
            top: -12,
            child: Container(
              color: AppColors.surface0,
              padding: const EdgeInsets.symmetric(horizontal: 5),
              child: Text(label, style: DesignType.elms(17, DesignInk.primary, FontWeight.w400)),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Designation dropdown (opens inline, as in the design) ────────────────────

class _DesignationField extends StatelessWidget {
  const _DesignationField({
    required this.value,
    required this.options,
    required this.open,
    required this.onToggle,
    required this.onSelect,
    required this.onAddAnother,
    required this.onRemove,
  });

  final String? value;
  final List<({String? id, String value})> options;
  final bool open;
  final VoidCallback onToggle;
  final ValueChanged<String> onSelect;
  final VoidCallback onAddAnother;
  final ValueChanged<({String? id, String value})> onRemove;

  @override
  Widget build(BuildContext context) {
    final ink = DesignInk.primary;
    final stripe = ThemeController.isDarkMode ? AppColors.surface1 : const Color(0xFFF1F1F2);

    return _OutlinedField(
      label: 'Designation',
      contentPadding: const EdgeInsets.all(1), // keep rows inside the 1 px border
      child: ClipRRect(
        borderRadius: BorderRadius.circular(9),
        child: AnimatedSize(
          duration: const Duration(milliseconds: 180),
          alignment: Alignment.topCenter,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              InkWell(
                onTap: onToggle,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(_OutlinedField.textInset, 15, 14, 13),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          open ? '' : (value ?? 'Select designation'),
                          style: value == null && !open
                              ? DesignType.elms(17, DesignInk.muted, FontWeight.w300)
                              : _inputStyle(ink),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      _Chevron(up: open, color: ink),
                    ],
                  ),
                ),
              ),
              if (open) ...[
                for (var i = 0; i < options.length; i++)
                  Material(
                    // Alternate rows are shaded, starting with the first.
                    color: i.isEven ? stripe : Colors.transparent,
                    child: InkWell(
                      onTap: () => onSelect(options[i].value),
                      child: Padding(
                        padding: const EdgeInsets.only(left: 13, right: 4),
                        child: Row(
                          children: [
                            Expanded(
                              child: Padding(
                                padding: const EdgeInsets.symmetric(vertical: 5),
                                child: Text(
                                  options[i].value,
                                  style: _inputStyle(ink),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ),
                            if (options[i].value == value)
                              Icon(Icons.check_rounded, size: 18, color: ink),
                            if (options[i].id != null)
                              IconButton(
                                tooltip: 'Remove designation',
                                visualDensity: VisualDensity.compact,
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints.tightFor(width: 32, height: 32),
                                icon: const Icon(Icons.close_rounded, size: 16, color: DesignInk.delete),
                                onPressed: () => onRemove(options[i]),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                Material(
                  color: stripe,
                  child: InkWell(
                    onTap: onAddAnother,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      child: Center(child: Text('+ Add Another', style: _inputStyle(ink))),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Thin chevron (down when closed, up when open).
class _Chevron extends StatelessWidget {
  const _Chevron({required this.up, required this.color});
  final bool up;
  final Color color;

  @override
  Widget build(BuildContext context) =>
      CustomPaint(size: const Size(22, 12), painter: _ChevronPainter(up, color));
}

class _ChevronPainter extends CustomPainter {
  _ChevronPainter(this.up, this.color);
  final bool up;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = color
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;
    final top = up ? size.height - 2 : 2.0;
    final tip = up ? 2.0 : size.height - 2;
    canvas.drawPath(
      Path()
        ..moveTo(1, top)
        ..lineTo(size.width / 2, tip)
        ..lineTo(size.width - 1, top),
      p,
    );
  }

  @override
  bool shouldRepaint(_ChevronPainter old) => old.up != up || old.color != color;
}

// ── Presence tiles ───────────────────────────────────────────────────────────

class _PresenceTile extends StatelessWidget {
  const _PresenceTile({
    required this.title,
    required this.subtitle,
    required this.value,
    required this.enabled,
    required this.background,
    required this.thumb,
    required this.track,
    required this.onChanged,
  });

  final String title;
  final String subtitle;
  final bool value;
  final bool enabled;
  final Color background;
  final Color thumb;
  final Color track;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final dark = ThemeController.isDarkMode;
    final textInk = dark ? AppColors.textPrimary : _buttonInk;

    return AnimatedOpacity(
      duration: const Duration(milliseconds: 150),
      opacity: enabled ? 1 : 0.45,
      child: Container(
        height: 47, // 120 px
        decoration: BoxDecoration(
          color: dark ? background.withValues(alpha: 0.16) : background,
          // Square on the left, pill-rounded on the right.
          borderRadius: const BorderRadius.horizontal(right: Radius.circular(24)),
        ),
        padding: const EdgeInsets.only(left: 16, right: 6),
        child: Row(
          children: [
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: DesignType.elms(16, textInk, FontWeight.w400),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    subtitle,
                    style: DesignType.elms(11, DesignInk.muted, FontWeight.w300),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            Switch(
              value: value,
              onChanged: enabled ? onChanged : null,
              activeThumbColor: thumb,
              activeTrackColor: track,
              inactiveThumbColor: const Color(0xFFBDBDBD),
              inactiveTrackColor: track.withValues(alpha: 0.5),
              trackOutlineColor: const WidgetStatePropertyAll(Colors.transparent),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Cancel / Create buttons ──────────────────────────────────────────────────

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.label,
    required this.background,
    required this.roundLeft,
    required this.onTap,
    this.leading,
    this.trailing,
  });

  final String label;
  final Color background;

  /// Cancel is rounded on the left, Create on the right.
  final bool roundLeft;
  final VoidCallback? onTap;
  final Widget? leading;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    const r = Radius.circular(25);
    final shape = RoundedRectangleBorder(
      borderRadius: roundLeft
          ? const BorderRadius.horizontal(left: r)
          : const BorderRadius.horizontal(right: r),
    );
    return Material(
      color: background,
      shape: shape,
      child: InkWell(
        onTap: onTap,
        customBorder: shape,
        child: SizedBox(
          height: 50, // 130 px
          child: Row(
            mainAxisAlignment: roundLeft ? MainAxisAlignment.start : MainAxisAlignment.end,
            children: [
              if (leading != null) ...[const SizedBox(width: 7), leading!, const SizedBox(width: 6)]
              else const SizedBox(width: 8),
              Flexible(
                child: Text(
                  label,
                  style: DesignType.elms(13.5, _buttonInk, FontWeight.w600),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (trailing != null) ...[const SizedBox(width: 4), trailing!, const SizedBox(width: 6)],
            ],
          ),
        ),
      ),
    );
  }
}

/// Red ✕ in an open circle (Cancel).
class _CancelMark extends StatelessWidget {
  const _CancelMark();

  @override
  Widget build(BuildContext context) => CustomPaint(
        size: const Size.square(34),
        painter: _OpenCircleMarkPainter(cross: true),
      );
}

/// Heavy + in an open circle (Create / Save).
class _PlusMark extends StatelessWidget {
  const _PlusMark();

  @override
  Widget build(BuildContext context) => CustomPaint(
        size: const Size.square(34),
        painter: _OpenCircleMarkPainter(cross: false),
      );
}

class _OpenCircleMarkPainter extends CustomPainter {
  _OpenCircleMarkPainter({required this.cross});
  final bool cross;

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.width / 2 - 1;
    final ring = Paint()
      ..color = _buttonInk
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2
      ..strokeCap = StrokeCap.round;
    // Gap faces the label: right side for Cancel, left side for Create.
    final start = (cross ? 18 : 198) * math.pi / 180;
    canvas.drawArc(Rect.fromCircle(center: c, radius: r), start, 317 * math.pi / 180, false, ring);

    final mark = Paint()
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round;
    if (cross) {
      mark.color = const Color(0xFFE8202A);
      final d = r * 0.42;
      canvas.drawLine(c + Offset(-d, -d), c + Offset(d, d), mark);
      canvas.drawLine(c + Offset(d, -d), c + Offset(-d, d), mark);
    } else {
      mark.color = _buttonInk;
      final d = r * 0.6;
      canvas.drawLine(c + Offset(0, -d), c + Offset(0, d), mark);
      canvas.drawLine(c + Offset(-d, 0), c + Offset(d, 0), mark);
    }
  }

  @override
  bool shouldRepaint(_OpenCircleMarkPainter old) => old.cross != cross;
}
