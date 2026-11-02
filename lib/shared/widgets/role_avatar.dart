// lib/shared/widgets/role_avatar.dart

import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/design_type.dart';
import '../../features/auth/data/models/user_profile.dart';

/// Person silhouette in a role-colored ring, with the role's badge on the
/// chest: viewer = eye, data entry = keyboard, admin = shield + lock,
/// super admin = lightning.
class RoleAvatar extends StatelessWidget {
  const RoleAvatar({super.key, required this.role, this.size = 40});

  final AppRole role;

  /// Outer diameter including the ring (design: r 12.83 + 2 stroke → ~40 dp).
  final double size;

  static Color ringColor(AppRole role) => switch (role) {
        AppRole.viewer => const Color(0xFF58595B),
        AppRole.dataEntry => const Color(0xFFF8A93A),
        AppRole.admin => const Color(0xFF00C8F5),
        AppRole.superAdmin => const Color(0xFF3FFF00),
      };

  @override
  Widget build(BuildContext context) {
    final ring = size * 0.07; // stroke 2 on a 28.7 circle
    final gap = size * 0.025;
    final inner = size - 2 * (ring + gap);
    final ink = DesignInk.primary;
    final badgeColor = AppColors.surface0; // white in light mode, dark in dark mode

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: ringColor(role), width: ring),
      ),
      alignment: Alignment.center,
      child: ClipOval(
        child: SizedBox(
          width: inner,
          height: inner,
          child: Stack(
            children: [
              Positioned.fill(child: CustomPaint(painter: _SilhouettePainter(ink))),
              Align(
                alignment: const Alignment(0, 0.66),
                child: _RoleBadge(role: role, size: inner * 0.4, color: badgeColor, ink: ink),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RoleBadge extends StatelessWidget {
  const _RoleBadge({required this.role, required this.size, required this.color, required this.ink});
  final AppRole role;
  final double size;
  final Color color;
  final Color ink;

  @override
  Widget build(BuildContext context) => switch (role) {
        AppRole.viewer => Icon(Icons.visibility_rounded, size: size, color: color),
        AppRole.dataEntry => Icon(Icons.keyboard_rounded, size: size, color: color),
        AppRole.admin => SizedBox(
            width: size,
            height: size,
            child: Stack(
              alignment: Alignment.center,
              children: [
                Icon(Icons.shield_outlined, size: size, color: color),
                Padding(
                  padding: EdgeInsets.only(top: size * 0.08),
                  child: Icon(Icons.lock_rounded, size: size * 0.42, color: color),
                ),
              ],
            ),
          ),
        AppRole.superAdmin => Icon(Icons.bolt_rounded, size: size * 1.1, color: color),
      };
}

/// Head and shoulders filling the lower part of the circle.
class _SilhouettePainter extends CustomPainter {
  _SilhouettePainter(this.color);
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final paint = Paint()..color = color;
    canvas.drawCircle(Offset(w * 0.5, w * 0.33), w * 0.23, paint);
    canvas.drawRRect(
      RRect.fromLTRBR(w * 0.06, w * 0.6, w * 0.94, w * 1.3, Radius.circular(w * 0.34)),
      paint,
    );
  }

  @override
  bool shouldRepaint(_SilhouettePainter old) => old.color != color;
}
