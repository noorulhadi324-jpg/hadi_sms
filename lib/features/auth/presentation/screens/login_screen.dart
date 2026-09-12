import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/network/supabase_client.dart';
import '../../data/repositories/auth_repository.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

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
      await _repo.login(_emailController.text, _passwordController.text);

      final user = SupabaseConfig.client.auth.currentUser;
      final profile = user == null
          ? null
          : await SupabaseConfig.client
              .from('profiles')
              .select('role')
              .eq('id', user.id)
              .maybeSingle();

      if (!mounted) return;
      final role = profile?['role']?.toString().toLowerCase();
      context.go(role == 'parent' ? '/parent-dashboard' : '/dashboard');
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_friendlyError(e)),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _friendlyError(Object error) {
    final text = error.toString().toLowerCase();
    if (text.contains('email not confirmed')) return 'Please verify your email before signing in.';
    if (text.contains('invalid login credentials')) return 'Incorrect email or password.';
    if (text.contains('inactive')) return 'Your account is inactive. Please contact the administrator.';
    if (text.contains('not linked to a school')) return 'Your account is not linked to a school. Please contact the school administrator.';
    if (text.contains('profile was not found')) return 'Your account profile was not found. Please contact the administrator.';
    return 'Authentication failed. Please try again.';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Row(
        children: [
          if (MediaQuery.sizeOf(context).width > 900)
            Expanded(
              flex: 5,
              child: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [AppColors.primary, Color(0xFF8B5CF6)],
                  ),
                ),
                child: Stack(
                  children: [
                    Positioned(
                      top: -100,
                      left: -100,
                      child: CircleAvatar(radius: 200, backgroundColor: Colors.white.withOpacity(0.05)),
                    ),
                    Center(
                      child: Padding(
                        padding: const EdgeInsets.all(64),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(color: Colors.white.withOpacity(0.15), borderRadius: BorderRadius.circular(24)),
                              child: const Icon(Icons.school_rounded, color: Colors.white, size: 48),
                            ),
                            const SizedBox(height: 32),
                            Text('HADI SMS', style: GoogleFonts.inter(color: Colors.white, fontSize: 48, fontWeight: FontWeight.w900, letterSpacing: -1)),
                            const SizedBox(height: 16),
                            Text('The complete enterprise solution for modern educational institutions. Manage students, attendance, and finances with ease.', style: GoogleFonts.inter(color: Colors.white.withOpacity(0.8), fontSize: 18, height: 1.6, fontWeight: FontWeight.w500)),
                          ],
                        ),
                      ),
                    ),
                  ],
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
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (MediaQuery.sizeOf(context).width <= 900) ...[
                          Center(child: Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: AppColors.primary.withOpacity(0.1), borderRadius: BorderRadius.circular(16)), child: const Icon(Icons.school_rounded, color: AppColors.primary, size: 32))),
                          const SizedBox(height: 24),
                        ],
                        const Text('Sign In', style: TextStyle(fontSize: 32, fontWeight: FontWeight.w900, letterSpacing: -0.5)),
                        const SizedBox(height: 8),
                        const Text('Enter your credentials to access your dashboard.', style: TextStyle(color: AppColors.textSecondary, fontSize: 15)),
                        const SizedBox(height: 40),
                        Form(
                          key: _formKey,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              const Text('Email Address', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                              const SizedBox(height: 10),
                              TextFormField(controller: _emailController, decoration: const InputDecoration(hintText: 'name@school.com', prefixIcon: Icon(Icons.email_outlined, size: 20)), validator: (v) => v == null || !v.contains('@') ? 'Enter a valid email' : null),
                              const SizedBox(height: 24),
                              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                                const Text('Password', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                                TextButton(onPressed: () => context.push('/forgot-password'), style: TextButton.styleFrom(visualDensity: VisualDensity.compact), child: const Text('Forgot Password?')),
                              ]),
                              const SizedBox(height: 6),
                              TextFormField(controller: _passwordController, obscureText: _obscurePassword, decoration: InputDecoration(hintText: '••••••••', prefixIcon: const Icon(Icons.lock_outline, size: 20), suffixIcon: IconButton(onPressed: () => setState(() => _obscurePassword = !_obscurePassword), icon: Icon(_obscurePassword ? Icons.visibility_outlined : Icons.visibility_off_outlined, size: 20))), validator: (v) => v == null || v.length < 6 ? 'Minimum 6 characters' : null),
                              const SizedBox(height: 40),
                              FilledButton(onPressed: _loading ? null : _handleLogin, style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 18)), child: _loading ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Text('Access Dashboard')),
                              const SizedBox(height: 24),
                              Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                                const Text("Don't have a school account?", style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
                                TextButton(onPressed: () => context.push('/register-school'), child: const Text('Register Now')),
                              ]),
                            ],
                          ),
                        ),
                      ],
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
