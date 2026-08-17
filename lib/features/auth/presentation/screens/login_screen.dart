// lib/features/auth/presentation/screens/login_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/constants/app_constants.dart';
import '../bloc/auth_bloc.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  // View Toggle State
  bool _isRegistering = false;

  // Sign In Controllers & Domain Selections
  final _emailCtrl = TextEditingController();
  final _passCtrl  = TextEditingController();
  bool _obscureSignIn = true;
  String _signInDomain = '@gmail.com'; // Default Domain Selector

  // Create Account Controllers & Domain Selections
  final _regEmailCtrl       = TextEditingController();
  final _regPassCtrl        = TextEditingController();
  final _regConfirmPassCtrl = TextEditingController(); 
  final _superAdminEmailCtrl = TextEditingController();
  final _superAdminPassCtrl  = TextEditingController();
  
  bool _obscureRegPass        = true;
  bool _obscureRegConfirmPass = true; 
  bool _obscureSuperAdminPass = true;
  String _selectedRole        = AppStrings.roleUser;
  
  String _regUserDomain    = '@gmail.com';   // Default New User Domain Selector
  String _superAdminDomain = '@gmail.com';   // Default Super Admin Approver Domain Selector

  // List of available domains
  final List<String> _domains = ['@gmail.com', '@dmebd.com', '@yahoo.com'];

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passCtrl.dispose();
    _regEmailCtrl.dispose();
    _regPassCtrl.dispose();
    _regConfirmPassCtrl.dispose();
    _superAdminEmailCtrl.dispose();
    _superAdminPassCtrl.dispose();
    super.dispose();
  }

  void _submitSignIn() {
    final username = _emailCtrl.text.trim();
    final pass  = _passCtrl.text;
    if (username.isEmpty || pass.isEmpty) return;

    final fullEmail = '$username$_signInDomain';
    final currentPlatform = Theme.of(context).platform.toString();

    context.read<AuthBloc>().add(
      AuthLoginRequested(
        email: fullEmail, 
        password: pass,
        platform: currentPlatform,
      ),
    );
  }

  void _submitCreateAccount() {
    final regUser        = _regEmailCtrl.text.trim();
    final regPass        = _regPassCtrl.text;
    final regConfirmPass = _regConfirmPassCtrl.text;
    final superAdminUser = _superAdminEmailCtrl.text.trim();
    final superAdminPass = _superAdminPassCtrl.text;

    if (regUser.isEmpty || regPass.isEmpty || regConfirmPass.isEmpty || superAdminUser.isEmpty || superAdminPass.isEmpty) {
      _showErrorSnackBar('Please fill out all fields.');
      return;
    }

    if (regPass != regConfirmPass) {
      _showErrorSnackBar('Passwords do not match. Please verify.');
      return;
    }

    final fullRegEmail = '$regUser$_regUserDomain';
    final fullSuperAdminEmail = '$superAdminUser$_superAdminDomain';

    context.read<AuthBloc>().add(
      AuthRegisterRequested(
        email: fullRegEmail,
        password: regPass,
        role: _selectedRole,
        adminEmail: fullSuperAdminEmail,
        adminPassword: superAdminPass,
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
            _showErrorSnackBar(
              state.message,
              onRetry: _isRegistering ? _submitCreateAccount : _submitSignIn,
            );
          } 
          else if (state is AuthRegisterSuccess) {
            ScaffoldMessenger.of(context).hideCurrentSnackBar();
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                backgroundColor: AppColors.success,
                behavior: SnackBarBehavior.floating,
                content: Text('Account successfully requested/created! Please sign in.'),
              ),
            );
            setState(() {
              _isRegistering = false; 
              _regEmailCtrl.clear();
              _regPassCtrl.clear();
              _regConfirmPassCtrl.clear();
              _superAdminEmailCtrl.clear();
              _superAdminPassCtrl.clear();
            });
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
                  child: _isRegistering 
                    ? _buildCreateAccountForm(theme, state)
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
        const SizedBox(height: AppSpacing.xl),

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

        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text("Need system access? ", style: theme.textTheme.bodyMedium?.copyWith(color: AppColors.textTertiary)),
            GestureDetector(
              onTap: isLoading ? null : () => setState(() => _isRegistering = true),
              child: Text(
                "Create Account",
                style: theme.textTheme.bodyMedium?.copyWith(color: AppColors.accent, fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
      ],
    );
  }

  // ── Layout 2: Super Admin Validated Registration Form ───────────────────
  Widget _buildCreateAccountForm(ThemeData theme, AuthState state) {
    final isLoading = state is AuthLoading;

    return Column(
      key: const ValueKey('RegisterForm'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Create Account', style: theme.textTheme.displaySmall),
        const SizedBox(height: AppSpacing.xs),
        Text(
          'Requires valid super admin clearance credentials to register.',
          style: theme.textTheme.bodyLarge?.copyWith(color: AppColors.textSecondary),
        ),
        const SizedBox(height: AppSpacing.xl),

        _buildSectionDivider(theme, 'NEW USER CREDENTIALS'),

        _buildFieldLabel(theme, 'NEW USERNAME'),
        TextField(
          controller: _regEmailCtrl,
          enabled: !isLoading,
          keyboardType: TextInputType.text,
          textInputAction: TextInputAction.next,
          style: theme.textTheme.bodyLarge,
          decoration: InputDecoration(
            hintText: 'new.user',
            suffixIcon: _buildDomainDropdown(_regUserDomain, (newValue) {
              if (newValue != null) setState(() => _regUserDomain = newValue);
            }, theme),
          ),
        ),
        const SizedBox(height: AppSpacing.md),

        _buildFieldLabel(theme, 'ACCOUNT PASSWORD'),
        TextField(
          controller: _regPassCtrl,
          enabled: !isLoading,
          obscureText: _obscureRegPass,
          textInputAction: TextInputAction.next,
          style: theme.textTheme.bodyLarge,
          decoration: InputDecoration(
            hintText: 'Minimum 8 characters',
            suffixIcon: IconButton(
              onPressed: () => setState(() => _obscureRegPass = !_obscureRegPass),
              icon: Icon(_obscureRegPass ? Icons.visibility_off_rounded : Icons.visibility_rounded, color: AppColors.textTertiary, size: 20),
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.md),

        _buildFieldLabel(theme, 'CONFIRM PASSWORD'),
        TextField(
          controller: _regConfirmPassCtrl,
          enabled: !isLoading,
          obscureText: _obscureRegConfirmPass,
          textInputAction: TextInputAction.next,
          style: theme.textTheme.bodyLarge,
          decoration: InputDecoration(
            hintText: 'Re-enter user password',
            suffixIcon: IconButton(
              onPressed: () => setState(() => _obscureRegConfirmPass = !_obscureRegConfirmPass),
              icon: Icon(_obscureRegConfirmPass ? Icons.visibility_off_rounded : Icons.visibility_rounded, color: AppColors.textTertiary, size: 20),
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.md),

        _buildFieldLabel(theme, 'ASSIGNED ACCOUNT ROLE'),
        Row(
          children: [
            Expanded(child: _buildRoleSegment(AppStrings.roleUser, 'User Access', Icons.visibility_rounded, isLoading)),
            const SizedBox(width: AppSpacing.sm),
            Expanded(child: _buildRoleSegment(AppStrings.roleAdmin, 'Admin Staff', Icons.shield_rounded, isLoading)),
          ],
        ),
        const SizedBox(height: AppSpacing.xl),

        _buildSectionDivider(theme, 'SUPER ADMIN AUTHORIZATION'),

        _buildFieldLabel(theme, 'SUPER ADMIN USERNAME'),
        TextField(
          controller: _superAdminEmailCtrl,
          enabled: !isLoading,
          keyboardType: TextInputType.text,
          textInputAction: TextInputAction.next,
          style: theme.textTheme.bodyLarge,
          decoration: InputDecoration(
            hintText: 'super.admin',
            suffixIcon: _buildDomainDropdown(_superAdminDomain, (newValue) {
              if (newValue != null) setState(() => _superAdminDomain = newValue);
            }, theme),
          ),
        ),
        const SizedBox(height: AppSpacing.md),

        _buildFieldLabel(theme, 'SUPER ADMIN PASSWORD'),
        TextField(
          controller: _superAdminPassCtrl,
          enabled: !isLoading,
          obscureText: _obscureSuperAdminPass,
          textInputAction: TextInputAction.done,
          onSubmitted: (_) => isLoading ? null : _submitCreateAccount(),
          style: theme.textTheme.bodyLarge,
          decoration: InputDecoration(
            hintText: '••••••••',
            suffixIcon: IconButton(
              onPressed: () => setState(() => _obscureSuperAdminPass = !_obscureSuperAdminPass),
              icon: Icon(_obscureSuperAdminPass ? Icons.visibility_off_rounded : Icons.visibility_rounded, color: AppColors.textTertiary, size: 20),
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.xl),

        ElevatedButton(
          onPressed: isLoading ? null : _submitCreateAccount, 
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
              : const Text('Authorize & Create Account'),
        ),
        const SizedBox(height: AppSpacing.lg),

        Center(
          child: TextButton.icon(
            onPressed: isLoading ? null : () => setState(() => _isRegistering = false),
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

  Widget _buildSectionDivider(ThemeData theme, String label) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Row(
        children: [
          Text(
            label,
            style: theme.textTheme.labelSmall?.copyWith(letterSpacing: 1.1, color: AppColors.accent, fontWeight: FontWeight.bold),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(child: Divider(color: AppColors.surface2, thickness: 1)),
        ],
      ),
    );
  }

  Widget _buildRoleSegment(String roleValue, String label, IconData icon, bool isLoading) {
    final isSelected = _selectedRole == roleValue;
    return GestureDetector(
      onTap: _isRegistering && !isLoading ? () => setState(() => _selectedRole = roleValue) : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.md, horizontal: AppSpacing.xs),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.accentSurface : AppColors.surface1,
          borderRadius: AppRadius.card,
          border: Border.all(color: isSelected ? AppColors.accent : AppColors.surface2, width: isSelected ? 1.5 : 1.0),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: isSelected ? AppColors.accent : AppColors.textTertiary),
            const SizedBox(width: AppSpacing.xs),
            Flexible(
              child: Text(
                label,
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
                style: TextStyle(
                  color: isSelected ? Colors.white : AppColors.textSecondary,
                  fontSize: 12,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}