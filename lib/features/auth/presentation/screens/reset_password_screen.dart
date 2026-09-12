import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/auth/auth_state_notifier.dart';
import '../../../../core/network/supabase_client.dart';

class ResetPasswordScreen extends StatefulWidget {
  const ResetPasswordScreen({super.key});

  @override
  State<ResetPasswordScreen> createState() => _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends State<ResetPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();
  bool _loading = false;
  bool _obscure = true;
  bool _obscureConfirm = true;

  @override
  void dispose() {
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  Future<void> _updatePassword() async {
    if (!_formKey.currentState!.validate() || _loading) return;

    setState(() => _loading = true);
    try {
      final session = SupabaseConfig.client.auth.currentSession;
      if (session == null) {
        throw const AuthException('Your reset link is missing or has expired.');
      }

      await SupabaseConfig.client.auth.updateUser(
        UserAttributes(password: _passwordController.text),
      );

      AuthStateNotifier.instance.clearRecovery();
      await SupabaseConfig.client.auth.signOut();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Password updated successfully. Please sign in.'),
          backgroundColor: Colors.green,
        ),
      );
      context.go('/login');
    } on AuthException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message)),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Unable to update password: $e')),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String? _passwordValidator(String? value) {
    if (value == null || value.isEmpty) return 'Password is required';
    if (value.length < 8) return 'Use at least 8 characters';
    if (!RegExp(r'[A-Z]').hasMatch(value)) return 'Add at least one uppercase letter';
    if (!RegExp(r'[a-z]').hasMatch(value)) return 'Add at least one lowercase letter';
    if (!RegExp(r'[0-9]').hasMatch(value)) return 'Add at least one number';
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final session = SupabaseConfig.client.auth.currentSession;

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFFEEF2FF), Color(0xFFFFFFFF), Color(0xFFF5F3FF)],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 430),
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(28),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const Icon(Icons.lock_reset_rounded, size: 64, color: Color(0xFF6D28D9)),
                          const SizedBox(height: 18),
                          Text(
                            'Create New Password',
                            textAlign: TextAlign.center,
                            style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            session == null
                                ? 'This reset link is invalid or expired.'
                                : 'Choose a strong password for your HADI SMS account.',
                            textAlign: TextAlign.center,
                            style: const TextStyle(color: Color(0xFF64748B)),
                          ),
                          const SizedBox(height: 28),
                          TextFormField(
                            controller: _passwordController,
                            obscureText: _obscure,
                            validator: _passwordValidator,
                            decoration: InputDecoration(
                              labelText: 'New Password',
                              prefixIcon: const Icon(Icons.lock_outline_rounded),
                              suffixIcon: IconButton(
                                onPressed: () => setState(() => _obscure = !_obscure),
                                icon: Icon(_obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined),
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: _confirmController,
                            obscureText: _obscureConfirm,
                            validator: (value) => value != _passwordController.text ? 'Passwords do not match' : null,
                            decoration: InputDecoration(
                              labelText: 'Confirm Password',
                              prefixIcon: const Icon(Icons.verified_user_outlined),
                              suffixIcon: IconButton(
                                onPressed: () => setState(() => _obscureConfirm = !_obscureConfirm),
                                icon: Icon(_obscureConfirm ? Icons.visibility_outlined : Icons.visibility_off_outlined),
                              ),
                            ),
                          ),
                          const SizedBox(height: 24),
                          SizedBox(
                            height: 52,
                            child: FilledButton(
                              onPressed: session == null || _loading ? null : _updatePassword,
                              child: _loading
                                  ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                                  : const Text('Update Password'),
                            ),
                          ),
                          TextButton(
                            onPressed: _loading ? null : () => context.go('/login'),
                            child: const Text('Back to Login'),
                          ),
                        ],
                      ),
                    ),
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
