import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/network/supabase_client.dart';
import '../../../../core/widgets/hadi_design_system.dart';
import '../../data/repositories/auth_repository.dart';

class LoginScreen extends StatefulWidget {
  final String? expectedRole;

  const LoginScreen({super.key, this.expectedRole});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _repo = AuthRepository();

  bool _loading = false;
  bool _obscurePassword = true;

  bool get _isTeacher => widget.expectedRole == 'teacher';
  bool get _isParent => widget.expectedRole == 'parent';
  bool get _isStaff => widget.expectedRole == 'staff';

  Color get _portalColor {
    if (_isParent) return AppColors.roleParent;
    if (_isTeacher) return AppColors.roleTeacher;
    if (_isStaff) return AppColors.roleAdmin;
    return AppColors.primary;
  }

  IconData get _portalIcon {
    if (_isParent) return Icons.family_restroom_rounded;
    if (_isTeacher) return Icons.cast_for_education_rounded;
    if (_isStaff) return Icons.badge_rounded;
    return Icons.admin_panel_settings_rounded;
  }

  String get _portalTitle {
    if (_isTeacher) return 'Teacher Portal';
    if (_isParent) return 'Parent Portal';
    if (_isStaff) return 'Staff Portal';
    return 'School Admin Portal';
  }

  String get _portalSubtitle {
    if (_isTeacher) return 'Manage classes, attendance and assignments from one place.';
    if (_isParent) return 'Follow your children’s attendance, fees, results and updates.';
    if (_isStaff) return 'Access the tools and workflows assigned to your staff role.';
    return 'Run your school operations with one connected management system.';
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate() || _loading) return;

    setState(() => _loading = true);
    try {
      await _repo.login(
        _emailController.text,
        _passwordController.text,
        expectedRole: widget.expectedRole,
      );

      final user = SupabaseConfig.client.auth.currentUser;
      final profile = user == null
          ? null
          : await SupabaseConfig.client
              .from('profiles')
              .select('role')
              .eq('id', user.id)
              .maybeSingle();

      if (!mounted) return;
      final role = profile?['role']?.toString().trim().toLowerCase();
      switch (role) {
        case 'parent':
          context.go('/parent-dashboard');
          break;
        case 'teacher':
          context.go('/teacher-dashboard');
          break;
        case 'staff':
          context.go('/staff-dashboard');
          break;
        default:
          context.go('/dashboard');
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_friendlyError(e)), backgroundColor: AppColors.error),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _friendlyError(Object error) {
    final text = error.toString().toLowerCase();
    if (text.contains('email not confirmed')) return 'Please verify your email before signing in.';
    if (text.contains('invalid login credentials')) return 'Incorrect email or password.';
    if (text.contains('not a teacher account')) return 'This email is not registered as a teacher.';
    if (text.contains('not a parent account')) return 'This email is not registered as a parent.';
    if (text.contains('not a staff account')) return 'This email is not registered as a staff account.';
    if (text.contains('inactive')) return 'Your account is inactive. Please contact the administrator.';
    if (text.contains('not linked to a school')) return 'Your account is not linked to a school.';
    if (text.contains('profile was not found')) return 'Your account profile was not found.';
    return 'Authentication failed. Please try again.';
  }

  String? _validateEmail(String? value) {
    final email = value?.trim() ?? '';
    if (email.isEmpty) return 'Email address is required.';
    final valid = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(email);
    return valid ? null : 'Enter a valid email address.';
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final compact = width < 720;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: EdgeInsets.all(compact ? 18 : 28),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1120),
              child: HadiGlassCard(
                padding: EdgeInsets.zero,
                child: IntrinsicHeight(
                  child: compact
                      ? _buildForm(context, compact: true)
                      : Row(
                          children: [
                            Expanded(child: _buildHero(context)),
                            Expanded(flex: 5, child: _buildForm(context)),
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

  Widget _buildHero(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(52),
      decoration: BoxDecoration(
        borderRadius: const BorderRadius.horizontal(left: Radius.circular(22)),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [_portalColor, AppColors.primaryDark],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          HadiBrandLogo(size: 58),
          const SizedBox(height: 30),
          Icon(_portalIcon, color: Colors.white.withValues(alpha: .95), size: 42),
          const SizedBox(height: 22),
          Text(
            'HADI SMS',
            style: GoogleFonts.inter(color: Colors.white, fontSize: 42, fontWeight: FontWeight.w900, letterSpacing: -1.6),
          ),
          const SizedBox(height: 6),
          Text(
            _portalTitle.toUpperCase(),
            style: GoogleFonts.inter(color: Colors.white.withValues(alpha: .9), fontSize: 12, fontWeight: FontWeight.w800, letterSpacing: 2.1),
          ),
          const SizedBox(height: 18),
          Text(
            _portalSubtitle,
            style: GoogleFonts.inter(color: Colors.white.withValues(alpha: .82), fontSize: 16, height: 1.55),
          ),
          const SizedBox(height: 28),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: const [
              HadiStatusBadge(label: 'Secure Access', color: Colors.white),
              HadiStatusBadge(label: 'Cloud Connected', color: Colors.white),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildForm(BuildContext context, {bool compact = false}) {
    return Padding(
      padding: EdgeInsets.all(compact ? 24 : 48),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            HadiBrandLogo(size: 46, showWordmark: true),
            const SizedBox(height: 28),
            Text(_portalTitle, style: const TextStyle(fontSize: 30, fontWeight: FontWeight.w900, letterSpacing: -.7)),
            const SizedBox(height: 7),
            Text(_portalSubtitle, style: const TextStyle(color: AppColors.textSecondary, fontSize: 14, height: 1.5)),
            const SizedBox(height: 30),
            const Text('Email Address', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800)),
            const SizedBox(height: 8),
            TextFormField(
              controller: _emailController,
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.next,
              autofillHints: const [AutofillHints.username, AutofillHints.email],
              decoration: const InputDecoration(hintText: 'name@school.com', prefixIcon: Icon(Icons.alternate_email_rounded)),
              validator: _validateEmail,
            ),
            const SizedBox(height: 18),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Password', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800)),
                TextButton(onPressed: () => context.push('/forgot-password'), child: const Text('Forgot password?')),
              ],
            ),
            TextFormField(
              controller: _passwordController,
              obscureText: _obscurePassword,
              textInputAction: TextInputAction.done,
              autofillHints: const [AutofillHints.password],
              onFieldSubmitted: (_) => _handleLogin(),
              decoration: InputDecoration(
                hintText: 'Enter your password',
                prefixIcon: const Icon(Icons.lock_outline_rounded),
                suffixIcon: IconButton(
                  tooltip: _obscurePassword ? 'Show password' : 'Hide password',
                  onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                  icon: Icon(_obscurePassword ? Icons.visibility_outlined : Icons.visibility_off_outlined),
                ),
              ),
              validator: (v) => (v == null || v.length < 6) ? 'Minimum 6 characters.' : null,
            ),
            const SizedBox(height: 26),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _loading ? null : _handleLogin,
                icon: _loading
                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : Icon(_portalIcon, size: 18),
                label: Text(_loading ? 'Signing in…' : 'Continue to portal'),
                style: FilledButton.styleFrom(backgroundColor: _portalColor),
              ),
            ),
            const SizedBox(height: 22),
            const Divider(),
            const SizedBox(height: 10),
            Center(
              child: Wrap(
                alignment: WrapAlignment.center,
                spacing: 2,
                children: [
                  if (!_isTeacher) TextButton(onPressed: () => context.go('/teacher-login'), child: const Text('Teacher')),
                  if (!_isParent) TextButton(onPressed: () => context.go('/parent-login'), child: const Text('Parent')),
                  if (!_isStaff) TextButton(onPressed: () => context.go('/staff-login'), child: const Text('Staff')),
                  if (_isTeacher || _isParent || _isStaff) TextButton(onPressed: () => context.go('/login'), child: const Text('Admin')),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Center(
              child: TextButton.icon(
                onPressed: () => context.push('/register-school'),
                icon: const Icon(Icons.add_business_rounded, size: 17),
                label: const Text('Register a new school'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
