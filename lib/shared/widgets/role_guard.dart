// lib/shared/widgets/role_guard.dart
//
// Wraps any widget so it only renders for Admin users.
// Use the `fallback` parameter to show something else to View-Only users.
//
// Example:
//   RoleGuard(
//     child: ElevatedButton(onPressed: _delete, child: Text('Delete')),
//   )

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../features/auth/presentation/bloc/auth_bloc.dart';

class RoleGuard extends StatelessWidget {
  const RoleGuard({
    super.key,
    required this.child,
    this.fallback,
  });

  final Widget child;
  final Widget? fallback;

  @override
  Widget build(BuildContext context) {
    final authState = context.watch<AuthBloc>().state;
    final isAdmin =
        authState is AuthAuthenticated && authState.profile.isAdmin;

    if (isAdmin) return child;
    return fallback ?? const SizedBox.shrink();
  }
}
