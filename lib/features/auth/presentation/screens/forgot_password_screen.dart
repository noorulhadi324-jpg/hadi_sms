import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
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
  String? message;
  bool success = false;

  @override
  void dispose() {
    email.dispose();
    super.dispose();
  }

  Future<void> send() async {
    if (!formKey.currentState!.validate() || loading) return;
    setState(() {
      loading = true;
      message = null;
    });
    try {
      await repo.resetPassword(email.text);
      if (!mounted) return;
      setState(() {
        loading = false;
        success = true;
        message = 'اگر یہ email رجسٹرڈ ہے تو password reset link بھیج دی گئی ہے۔ Inbox اور Spam/Junk دونوں چیک کریں۔';
      });
    } on AuthException catch (e) {
      if (!mounted) return;
      setState(() {
        loading = false;
        success = false;
        message = e.message;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        loading = false;
        success = false;
        message = 'Reset email بھیجنے میں مسئلہ آیا۔ دوبارہ کوشش کریں۔';
      });
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Forgot Password')),
        body: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 430),
              child: Form(
                key: formKey,
                child: Column(
                  children: [
                    Image.asset('assets/logo/logo.png', height: 90, errorBuilder: (_, __, ___) => const Icon(Icons.school, size: 70)),
                    const SizedBox(height: 22),
                    const Text('Forgot Password?', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900)),
                    const SizedBox(height: 8),
                    const Text('اپنے account کی registered email لکھیں۔', textAlign: TextAlign.center, style: TextStyle(color: Colors.grey)),
                    const SizedBox(height: 24),
                    TextFormField(
                      controller: email,
                      keyboardType: TextInputType.emailAddress,
                      validator: (v) => v == null || !v.contains('@') ? 'Enter a valid email' : null,
                      decoration: const InputDecoration(labelText: 'Email Address', prefixIcon: Icon(Icons.email_outlined)),
                    ),
                    const SizedBox(height: 20),
                    if (message != null)
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(14),
                        margin: const EdgeInsets.only(bottom: 18),
                        decoration: BoxDecoration(color: (success ? Colors.green : Colors.red).withValues(alpha: .08), borderRadius: BorderRadius.circular(12)),
                        child: Text(message!, style: TextStyle(color: success ? Colors.green.shade800 : Colors.red.shade800, fontWeight: FontWeight.w600)),
                      ),
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: FilledButton(
                        onPressed: loading ? null : send,
                        child: loading ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Text('Send Reset Link'),
                      ),
                    ),
                    TextButton(onPressed: loading ? null : () => context.pop(), child: const Text('Back to Login')),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
}
