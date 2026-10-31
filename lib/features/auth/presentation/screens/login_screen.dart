// lib/features/auth/presentation/screens/login_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/error_formatter.dart';
import '../../data/repositories/auth_repository.dart';
import '../bloc/auth_bloc.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

enum _LoginView { signIn, forgotPassword }

class _LoginScreenState extends State<LoginScreen> {
  _LoginView _view = _LoginView.signIn;

  // Sign In Controllers & Domain Selections
  final _emailCtrl = TextEditingController();
  final _passCtrl  = TextEditingController();
  bool _obscureSignIn = true;
  String _signInDomain = '@gmail.com'; // Default Domain Selector

  // Forgot Password Controllers
  final _resetEmailCtrl   = TextEditingController();
  final _resetCodeCtrl    = TextEditingController();
  final _resetPassCtrl    = TextEditingController();
  final _resetConfirmCtrl = TextEditingController();
  String _resetDomain = '@gmail.com';
  bool _resetCodeSent = false;
  bool _resetBusy = false;
  bool _obscureResetPass = true;

  // List of available domains
  final List<String> _domains = ['@gmail.com', '@dmebd.com', '@yahoo.com'];

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passCtrl.dispose();
    _resetEmailCtrl.dispose();
    _resetCodeCtrl.dispose();
    _resetPassCtrl.dispose();
    _resetConfirmCtrl.dispose();
    super.dispose();
  }

  /// A full address typed into the username field wins over the domain picker.
  String _composeEmail(String username, String domain) =>
      username.contains('@') ? username : '$username$domain';

  void _submitSignIn() {
    final username = _emailCtrl.text.trim();
    final pass  = _passCtrl.text;
    if (username.isEmpty || pass.isEmpty) return;

    final fullEmail = _composeEmail(username, _signInDomain);
    final currentPlatform = Theme.of(context).platform.toString();

    context.read<AuthBloc>().add(
      AuthLoginRequested(
        email: fullEmail, 
        password: pass,
        platform: currentPlatform,
      ),
    );
  }

  void _openForgotPassword() {
    setState(() {
      _view = _LoginView.forgotPassword;
      _resetCodeSent = false;
      _resetEmailCtrl.text = _emailCtrl.text.trim();
      _resetDomain = _signInDomain;
      _resetCodeCtrl.clear();
      _resetPassCtrl.clear();
      _resetConfirmCtrl.clear();
    });
  }

  String get _resetEmail =>
      _composeEmail(_resetEmailCtrl.text.trim(), _resetDomain);

  Future<void> _sendResetCode() async {
    if (_resetEmailCtrl.text.trim().isEmpty) {
      _showErrorSnackBar('Enter your username or email.');
      return;
    }
    setState(() => _resetBusy = true);
    try {
      await context.read<AuthRepository>().sendPasswordResetCode(_resetEmail);
      if (!mounted) return;
      setState(() => _resetCodeSent = true);
      _showSuccessSnackBar('A reset code was sent to $_resetEmail.');
    } catch (e) {
      if (mounted) _showErrorSnackBar(ErrorFormatter.format(e));
    } finally {
      if (mounted) setState(() => _resetBusy = false);
    }
  }

  Future<void> _submitNewPassword() async {
    final code = _resetCodeCtrl.text.trim();
    final pass = _resetPassCtrl.text;
    if (code.isEmpty) {
      _showErrorSnackBar('Enter the code from the email.');
      return;
    }
    if (pass.length < 8) {
      _showErrorSnackBar('Password must be at least 8 characters.');
      return;
    }
    if (pass != _resetConfirmCtrl.text) {
      _showErrorSnackBar('Passwords do not match. Please verify.');
      return;
    }
    setState(() => _resetBusy = true);
    try {
      await context.read<AuthRepository>().resetPasswordWithCode(
            email: _resetEmail,
            code: code,
            newPassword: pass,
          );
      if (!mounted) return;
      _showSuccessSnackBar('Password updated. Signing you in…');
      // The code signed the user in; load their profile and continue.
      context.read<AuthBloc>().add(AuthStarted());
    } catch (e) {
      if (mounted) _showErrorSnackBar(ErrorFormatter.format(e));
    } finally {
      if (mounted) setState(() => _resetBusy = false);
    }
  }

  void _showSuccessSnackBar(String message) {
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: AppColors.success,
        behavior: SnackBarBehavior.floating,
        content: Text(message),
      ),
    );
  }

  void _showErrorSnackBar(String message, {VoidCallback? onRetry}) {
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w500),
        ),
        backgroundColor: Colors.redAccent.shade700,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        action: onRetry != null
            ? SnackBarAction(
                label: 'RETRY',
                textColor: Colors.amberAccent,
                onPressed: onRetry,
              )
            : null,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: AppColors.surface0,
      body: BlocConsumer<AuthBloc, AuthState>(
        listener: (context, state) {
          if (state is AuthError) {
            _showErrorSnackBar(state.message, onRetry: _submitSignIn);
          }
        },
        builder: (context, state) {
          return Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.xl),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 440),
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 300),
                  switchInCurve: Curves.easeInOutCubic,
                  switchOutCurve: Curves.easeInOutCubic,
                  child: _view == _LoginView.forgotPassword
                    ? _buildForgotPasswordForm(theme)
                    : _buildSignInForm(theme, state),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  // ── Layout 1: Sign In View ──────────────────────────────────────────────
  Widget _buildSignInForm(ThemeData theme, AuthState state) {
    final isLoading = state is AuthLoading;

    return Column(
      key: const ValueKey('SignInForm'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Center(
          child: Container(
            padding: const EdgeInsets.all(AppSpacing.sm),
            decoration: BoxDecoration(
              color: const Color.fromARGB(0, 26, 26, 26),
              borderRadius: BorderRadius.circular(AppRadius.md),
              border: Border.all(color: AppColors.surface2),
            ),
            child: SvgPicture.asset(
              'assets/icons/dasgboard_logo.svg',
              width: 42,
              height: 42,
              placeholderBuilder: (context) => const SizedBox(
                width: 42,
                height: 42,
                child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.accent),
              ),
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.xl),
        Text('Welcome back.', style: theme.textTheme.displaySmall),
        const SizedBox(height: AppSpacing.xs),
        Text(
          'DME CLIENT EAM platform.',
          style: theme.textTheme.bodyLarge?.copyWith(color: AppColors.textSecondary),
        ),
        const SizedBox(height: AppSpacing.xxl),

        _buildFieldLabel(theme, 'USERNAME'),
        TextField(
          controller: _emailCtrl,
          enabled: !isLoading,
          keyboardType: TextInputType.text,
          textInputAction: TextInputAction.next,
          style: theme.textTheme.bodyLarge,
          decoration: InputDecoration(
            hintText: 'username',
            suffixIcon: _buildDomainDropdown(_signInDomain, (newValue) {
              if (newValue != null) setState(() => _signInDomain = newValue);
            }, theme),
          ),
        ),
        const SizedBox(height: AppSpacing.md),

        _buildFieldLabel(theme, 'PASSWORD'),
        TextField(
          controller: _passCtrl,
          enabled: !isLoading,
          obscureText: _obscureSignIn,
          textInputAction: TextInputAction.done,
          onSubmitted: (_) => isLoading ? null : _submitSignIn(),
          style: theme.textTheme.bodyLarge,
          decoration: InputDecoration(
            hintText: '••••••••',
            suffixIcon: IconButton(
              onPressed: () => setState(() => _obscureSignIn = !_obscureSignIn),
              icon: Icon(
                _obscureSignIn ? Icons.visibility_off_rounded : Icons.visibility_rounded,
                color: AppColors.textTertiary,
                size: 20,
              ),
            ),
          ),
        ),
        Align(
          alignment: Alignment.centerRight,
          child: TextButton(
            onPressed: isLoading ? null : _openForgotPassword,
            child: Text(
              'Forgot password?',
              style: theme.textTheme.bodyMedium?.copyWith(color: AppColors.accent, fontWeight: FontWeight.w600),
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.md),

        ElevatedButton(
          onPressed: isLoading ? null : _submitSignIn, 
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.accent,
            minimumSize: const Size(double.infinity, 52),
          ),
          child: isLoading
              ? const SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                )
              : const Text('Sign In'),
        ),
        const SizedBox(height: AppSpacing.lg),

        Center(
          child: Text(
            'Need access? Ask your administrator to create an account.',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(color: AppColors.textTertiary),
          ),
        ),
      ],
    );
  }

  // ── Layout 2: Forgot Password (emailed code) ─────────────────────────────
  Widget _buildForgotPasswordForm(ThemeData theme) {
    final busy = _resetBusy;

    return Column(
      key: const ValueKey('ForgotPasswordForm'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Reset Password', style: theme.textTheme.displaySmall),
        const SizedBox(height: AppSpacing.xs),
        Text(
          _resetCodeSent
              ? 'Enter the code we emailed to $_resetEmail and choose a new password.'
              : 'We will email you a code to reset your password.',
          style: theme.textTheme.bodyLarge?.copyWith(color: AppColors.textSecondary),
        ),
        const SizedBox(height: AppSpacing.xl),

        _buildFieldLabel(theme, 'USERNAME'),
        TextField(
          controller: _resetEmailCtrl,
          enabled: !busy && !_resetCodeSent,
          keyboardType: TextInputType.text,
          textInputAction: TextInputAction.done,
          onSubmitted: (_) => busy || _resetCodeSent ? null : _sendResetCode(),
          style: theme.textTheme.bodyLarge,
          decoration: InputDecoration(
            hintText: 'username',
            suffixIcon: _buildDomainDropdown(_resetDomain, (newValue) {
              if (newValue != null && !_resetCodeSent) setState(() => _resetDomain = newValue);
            }, theme),
          ),
        ),
        const SizedBox(height: AppSpacing.md),

        if (_resetCodeSent) ...[
          _buildFieldLabel(theme, 'CODE FROM EMAIL'),
          TextField(
            controller: _resetCodeCtrl,
            enabled: !busy,
            keyboardType: TextInputType.number,
            textInputAction: TextInputAction.next,
            style: theme.textTheme.bodyLarge,
            decoration: const InputDecoration(hintText: '123456'),
          ),
          const SizedBox(height: AppSpacing.md),

          _buildFieldLabel(theme, 'NEW PASSWORD'),
          TextField(
            controller: _resetPassCtrl,
            enabled: !busy,
            obscureText: _obscureResetPass,
            textInputAction: TextInputAction.next,
            style: theme.textTheme.bodyLarge,
            decoration: InputDecoration(
              hintText: 'Minimum 8 characters',
              suffixIcon: IconButton(
                onPressed: () => setState(() => _obscureResetPass = !_obscureResetPass),
                icon: Icon(_obscureResetPass ? Icons.visibility_off_rounded : Icons.visibility_rounded, color: AppColors.textTertiary, size: 20),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.md),

          _buildFieldLabel(theme, 'CONFIRM PASSWORD'),
          TextField(
            controller: _resetConfirmCtrl,
            enabled: !busy,
            obscureText: _obscureResetPass,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => busy ? null : _submitNewPassword(),
            style: theme.textTheme.bodyLarge,
            decoration: const InputDecoration(hintText: 'Re-enter new password'),
          ),
          const SizedBox(height: AppSpacing.md),
        ],

        const SizedBox(height: AppSpacing.md),
        ElevatedButton(
          onPressed: busy ? null : (_resetCodeSent ? _submitNewPassword : _sendResetCode),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.accent,
            minimumSize: const Size(double.infinity, 52),
          ),
          child: busy
              ? const SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                )
              : Text(_resetCodeSent ? 'Set New Password' : 'Send Reset Code'),
        ),
        if (_resetCodeSent)
          Center(
            child: TextButton(
              onPressed: busy ? null : _sendResetCode,
              child: Text('Resend code', style: TextStyle(color: AppColors.textSecondary)),
            ),
          ),
        const SizedBox(height: AppSpacing.lg),

        Center(
          child: TextButton.icon(
            onPressed: busy ? null : () => setState(() => _view = _LoginView.signIn),
            icon: Icon(Icons.arrow_back_rounded, size: 16, color: AppColors.textSecondary),
            label: Text('Back to Sign In', style: TextStyle(color: AppColors.textSecondary, fontWeight: FontWeight.w600)),
          ),
        ),
      ],
    );
  }

  // ── Embedded Domain Picker Generator ─────────────────────────────────────
  Widget _buildDomainDropdown(String currentValue, ValueChanged<String?> onChanged, ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.only(right: AppSpacing.sm),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: currentValue,
          onChanged: onChanged,
          icon: Icon(Icons.arrow_drop_down, color: AppColors.textTertiary, size: 20),
          alignment: Alignment.centerRight,
          dropdownColor: AppColors.surface1,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: AppColors.textTertiary,
            fontWeight: FontWeight.w600,
          ),
          items: _domains.map<DropdownMenuItem<String>>((String value) {
            return DropdownMenuItem<String>(
              value: value,
              child: Text(value),
            );
          }).toList(),
        ),
      ),
    );
  }

  // ── Supporting Widget UI Subroutines ─────────────────────────────────────
  Widget _buildFieldLabel(ThemeData theme, String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.xs),
      child: Text(
        title,
        style: theme.textTheme.labelSmall?.copyWith(letterSpacing: 1.2, color: AppColors.textTertiary, fontWeight: FontWeight.w700),
      ),
    );
  }
}
