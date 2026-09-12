import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../data/repositories/auth_repository.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});
  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final formKey = GlobalKey<FormState>();
  final email = TextEditingController();
  final repo = AuthRepository();
  bool loading = false;

  @override
  void dispose() {
    email.dispose();
    super.dispose();
  }

  Future<void> send() async {
    if (!formKey.currentState!.validate() || loading) return;
    setState(() => loading = true);
    try {
      await repo.resetPassword(email.text);
    } catch (_) {}
    if (!mounted) return;
    setState(() => loading = false);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('If this email is registered, a reset link has been sent.'),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Forgot Password')),
        body: Form(
          key: formKey,
          child: ListView(
            padding: const EdgeInsets.all(24),
            children: [
              const SizedBox(height: 40),
              Image.asset('assets/logo/logo.png', height: 100,
                  errorBuilder: (_, __, ___) =>
                      const Icon(Icons.school, size: 80)),
              const SizedBox(height: 28),
              const Text('Forgot Password?',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
              const SizedBox(height: 24),
              TextFormField(
                controller: email,
                validator: (v) =>
                    v == null || !v.contains('@') ? 'Enter a valid email' : null,
                decoration: const InputDecoration(
                  labelText: 'Email Address',
                  prefixIcon: Icon(Icons.email_outlined),
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                height: 52,
                child: ElevatedButton(
                  onPressed: loading ? null : send,
                  child: loading
                      ? const CircularProgressIndicator()
                      : const Text('Send Reset Link'),
                ),
              ),
              TextButton(
                onPressed: loading ? null : () => context.pop(),
                child: const Text('Back to Login'),
              ),
            ],
          ),
        ),
      );
}
