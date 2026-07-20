// lib/features/auth/presentation/screens/change_password_page.dart

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/feedback.dart';
import '../../data/repositories/auth_repository.dart';
import '../bloc/change_password_bloc.dart';
import '../bloc/change_password_event.dart';
import '../bloc/change_password_state.dart';

class ChangePasswordPage extends StatelessWidget {
  const ChangePasswordPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => ChangePasswordBloc(
        authRepository: context.read<AuthRepository>(),
      ),
      child: const _ChangePasswordView(),
    );
  }
}

class _ChangePasswordView extends StatefulWidget {
  const _ChangePasswordView();

  @override
  State<_ChangePasswordView> createState() => _ChangePasswordViewState();
}

class _ChangePasswordViewState extends State<_ChangePasswordView> {
  final _formKey = GlobalKey<FormState>();
  
  final _currentPasswordCtrl = TextEditingController();
  final _newPasswordCtrl = TextEditingController();
  final _confirmPasswordCtrl = TextEditingController();

  bool _obscureCurrent = true;
  bool _obscureNew = true;
  bool _obscureConfirm = true;

  @override
  void dispose() {
    _currentPasswordCtrl.dispose();
    _newPasswordCtrl.dispose();
    _confirmPasswordCtrl.dispose();
    super.dispose();
  }

  void _submitForm() {
    if (!_formKey.currentState!.validate()) return;

    context.read<ChangePasswordBloc>().add(
          ChangePasswordSubmitted(
            currentPassword: _currentPasswordCtrl.text.trim(),
            newPassword: _newPasswordCtrl.text.trim(),
          ),
        );
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final isDesktop = width >= 900;

    return Scaffold(
      backgroundColor: AppColors.surface0,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () {
            // Safe pop validation layer preventing desktop navigation breakage
            if (context.canPop()) {
              context.pop();
            } else {
              context.go('/dashboard');
            }
          },
        ),
        title: const Text('Change Password'),
      ),
      body: SafeArea(
        child: BlocListener<ChangePasswordBloc, ChangePasswordState>(
          listener: (context, state) {
            if (state is ChangePasswordSuccess) {
              AppFeedback.success(context, 'Password updated successfully.');
              
              // Safe pop navigation redirect layer on successful operations
              if (context.canPop()) {
                context.pop();
              } else {
                context.go('/dashboard');
              }
            } else if (state is ChangePasswordFailure) {
              AppFeedback.error(context, state.error);
            }
          },
          child: Center(
            child: SingleChildScrollView(
              padding: EdgeInsets.all(isDesktop ? AppSpacing.xl : AppSpacing.md),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: isDesktop ? 500 : double.infinity,
                ),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Update Credentials',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        'Ensure your account remains safe by assigning a strong secondary security combination key.',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      const SizedBox(height: AppSpacing.xl),
                      
                      // ── Current Password ─────────────────────────────────
                      _PasswordField(
                        label: 'Current Password',
                        controller: _currentPasswordCtrl,
                        obscureText: _obscureCurrent,
                        hintText: 'Enter your current account password',
                        onToggleVisibility: () => setState(() => _obscureCurrent = !_obscureCurrent),
                        validator: (v) => (v == null || v.isEmpty) ? 'Required field' : null,
                      ),
                      const SizedBox(height: AppSpacing.md),

                      const Divider(height: AppSpacing.lg),

                      // ── New Password ─────────────────────────────────────
                      _PasswordField(
                        label: 'New Password',
                        controller: _newPasswordCtrl,
                        obscureText: _obscureNew,
                        hintText: 'Minimally 6 characters long',
                        onToggleVisibility: () => setState(() => _obscureNew = !_obscureNew),
                        validator: (v) {
                          if (v == null || v.isEmpty) return 'Required field';
                          if (v.length < 6) return 'Password must be at least 6 characters';
                          return null;
                        },
                      ),
                      const SizedBox(height: AppSpacing.md),

                      // ── Confirm New Password ─────────────────────────────
                      _PasswordField(
                        label: 'Confirm New Password',
                        controller: _confirmPasswordCtrl,
                        obscureText: _obscureConfirm,
                        hintText: 'Re-type your new password string',
                        onToggleVisibility: () => setState(() => _obscureConfirm = !_obscureConfirm),
                        validator: (v) {
                          if (v != _newPasswordCtrl.text) return 'Passwords do not match';
                          return null;
                        },
                      ),
                      const SizedBox(height: AppSpacing.xxl),

                      // ── Submit Button ────────────────────────────────────
                      BlocBuilder<ChangePasswordBloc, ChangePasswordState>(
                        builder: (context, state) {
                          final isLoading = state is ChangePasswordLoading;

                          return SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              onPressed: isLoading ? null : _submitForm,
                              style: ElevatedButton.styleFrom(
                                minimumSize: const Size(double.infinity, 56),
                              ).copyWith(
                                shape: WidgetStateProperty.all(const StadiumBorder()),
                              ),
                              child: isLoading
                                  ? const SizedBox(
                                      height: 22,
                                      width: 22,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2.5,
                                        color: Colors.white,
                                      ),
                                    )
                                  : const Text(
                                      'Update Password',
                                      style: TextStyle(fontSize: 16),
                                    ),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ── Reusable Encapsulated Password Input Component ──────────────────────────
class _PasswordField extends StatelessWidget {
  const _PasswordField({
    required this.label,
    required this.controller,
    required this.obscureText,
    required this.hintText,
    required this.onToggleVisibility,
    required this.validator,
  });

  final String label;
  final TextEditingController controller;
  final bool obscureText;
  final String hintText;
  final VoidCallback onToggleVisibility;
  final String? Function(String?) validator;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label.toUpperCase(),
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                letterSpacing: 1.1,
                color: AppColors.textTertiary,
              ),
        ),
        const SizedBox(height: AppSpacing.xs),
        TextFormField(
          controller: controller,
          obscureText: obscureText,
          decoration: InputDecoration(
            hintText: hintText,
            suffixIcon: IconButton(
              icon: Icon(
                obscureText ? Icons.visibility_off_rounded : Icons.visibility_rounded,
                size: 20,
              ),
              onPressed: onToggleVisibility,
              color: AppColors.textSecondary,
            ),
          ),
          validator: validator,
        ),
      ],
    );
  }
}