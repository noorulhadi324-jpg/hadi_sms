import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/network/supabase_client.dart';
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

  String get _portalTitle {
    if (_isTeacher) return 'Teacher Portal';
    if (_isParent) return 'Parent Portal';
    if (_isStaff) return 'Staff Portal';
    return 'School Admin Portal';
  }

  String get _portalSubtitle {
    if (_isTeacher) return 'Sign in to manage your classes, attendance and assignments.';
    if (_isParent) return 'Sign in to view your children, attendance, fees and results.';
    if (_isStaff) return 'Sign in to access the school staff portal.';
    return 'Sign in to manage your school and access the administration dashboard.';
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
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
          : await SupabaseConfig.client.from('profiles').select('role').eq('id', user.id).maybeSingle();
      if (!mounted) return;
      final role = profile?['role']?.toString().toLowerCase();
      if (role == 'parent') {
        context.go('/parent-dashboard');
      } else if (role == 'teacher') {
        context.go('/teacher-dashboard');
      } else if (role == 'staff') {
        context.go('/staff-dashboard');
      } else {
        context.go('/dashboard');
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_friendlyError(e)), backgroundColor: AppColors.error, behavior: SnackBarBehavior.floating),
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

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final portalColor = _isParent
        ? const Color(0xFF0F766E)
        : _isTeacher
            ? const Color(0xFF2563EB)
            : _isStaff
                ? const Color(0xFF7C3AED)
                : AppColors.primary;

    return Scaffold(
      backgroundColor: Colors.white,
      body: Row(
        children: [
          if (width > 900)
            Expanded(
              flex: 5,
              child: Container(
                decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [portalColor, AppColors.primary])),
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(64),
                    child: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Icon(_isParent ? Icons.family_restroom_rounded : _isTeacher ? Icons.cast_for_education_rounded : _isStaff ? Icons.badge_rounded : Icons.school_rounded, color: Colors.white, size: 56),
                      const SizedBox(height: 28),
                      Text('HADI SMS', style: GoogleFonts.inter(color: Colors.white, fontSize: 48, fontWeight: FontWeight.w900)),
                      const SizedBox(height: 10),
                      Text(_portalTitle.toUpperCase(), style: GoogleFonts.inter(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w800, letterSpacing: 2)),
                      const SizedBox(height: 16),
                      Text(_portalSubtitle, style: GoogleFonts.inter(color: Colors.white.withOpacity(.82), fontSize: 18, height: 1.6)),
                    ]),
                  ),
                ),
              ),
            ),
          Expanded(
            flex: 4,
            child: Container(
              color: AppColors.background,
              child: Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(40),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 400),
                    child: Form(
                      key: _formKey,
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(_portalTitle, style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w900)),
                        const SizedBox(height: 8),
                        Text(_portalSubtitle, style: const TextStyle(color: AppColors.textSecondary, fontSize: 15)),
                        const SizedBox(height: 36),
                        const Text('Email Address', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                        const SizedBox(height: 8),
                        TextFormField(controller: _emailController, keyboardType: TextInputType.emailAddress, decoration: const InputDecoration(hintText: 'name@school.com', prefixIcon: Icon(Icons.email_outlined)), validator: (v) => v == null || !v.contains('@') ? 'Enter a valid email' : null),
                        const SizedBox(height: 20),
                        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                          const Text('Password', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                          TextButton(onPressed: () => context.push('/forgot-password'), child: const Text('Forgot Password?')),
                        ]),
                        TextFormField(controller: _passwordController, obscureText: _obscurePassword, decoration: InputDecoration(hintText: '••••••••', prefixIcon: const Icon(Icons.lock_outline), suffixIcon: IconButton(onPressed: () => setState(() => _obscurePassword = !_obscurePassword), icon: Icon(_obscurePassword ? Icons.visibility_outlined : Icons.visibility_off_outlined))), validator: (v) => v == null || v.length < 6 ? 'Minimum 6 characters' : null),
                        const SizedBox(height: 32),
                        SizedBox(width: double.infinity, child: FilledButton(onPressed: _loading ? null : _handleLogin, style: FilledButton.styleFrom(backgroundColor: portalColor, padding: const EdgeInsets.symmetric(vertical: 17)), child: _loading ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : Text(_isParent ? 'Open Parent Portal' : _isTeacher ? 'Open Teacher Portal' : _isStaff ? 'Open Staff Portal' : 'Access Admin Dashboard'))),
                        const SizedBox(height: 20),
                        const Divider(),
                        const SizedBox(height: 8),
                        Center(child: Wrap(alignment: WrapAlignment.center, spacing: 4, children: [
                          if (!_isTeacher) TextButton.icon(onPressed: () => context.go('/teacher-login'), icon: const Icon(Icons.cast_for_education_rounded, size: 17), label: const Text('Teacher')),
                          if (!_isParent) TextButton.icon(onPressed: () => context.go('/parent-login'), icon: const Icon(Icons.family_restroom_rounded, size: 17), label: const Text('Parent')),
                          if (!_isStaff) TextButton.icon(onPressed: () => context.go('/staff-login'), icon: const Icon(Icons.badge_rounded, size: 17), label: const Text('Staff')),
                          if (_isTeacher || _isParent || _isStaff) TextButton.icon(onPressed: () => context.go('/login'), icon: const Icon(Icons.admin_panel_settings_outlined, size: 17), label: const Text('Admin')),
                        ])),
                      ]),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
