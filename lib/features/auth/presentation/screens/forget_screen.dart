import 'package:flutter/material.dart';
import '../../../../core/network/supabase_client.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() =>
      _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _emailController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  bool _isLoading = false;

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _sendResetLink() async {
    if (_isLoading) return;

    if (!_formKey.currentState!.validate()) {
      return;
    }

    final email = _emailController.text.trim().toLowerCase();

    setState(() {
      _isLoading = true;
    });

    try {
      await SupabaseConfig.client.auth.resetPasswordForEmail(
        email,
      );

      if (!mounted) return;

      // Security: registered/unregistered email reveal nahi karte.
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'If this email is registered, a password reset link has been sent.',
          ),
          duration: Duration(seconds: 5),
        ),
      );

      _emailController.clear();
    } catch (_) {
      if (!mounted) return;

      // Exact authentication error user ko expose nahi karna.
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'If this email is registered, a password reset link has been sent.',
          ),
          duration: Duration(seconds: 5),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF030712),

      appBar: AppBar(
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Text('Forgot Password'),
      ),

      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),

          child: Form(
            key: _formKey,

            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 40),

                // Logo
                Image.asset(
                  'assets/logo/logo.png',
                  width: 100,
                  height: 100,
                  fit: BoxFit.contain,
                ),

                const SizedBox(height: 30),

                const Text(
                  'Forgot Password?',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                  ),
                ),

                const SizedBox(height: 12),

                const Text(
                  'Enter your registered email address and we will send you a password reset link.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Color(0xFF9CA3AF),
                    fontSize: 15,
                    height: 1.5,
                  ),
                ),

                const SizedBox(height: 35),

                // Email
                TextFormField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.done,
                  autocorrect: false,
                  enableSuggestions: false,
                  style: const TextStyle(
                    color: Colors.white,
                  ),

                  decoration: InputDecoration(
                    labelText: 'Email Address',
                    labelStyle: const TextStyle(
                      color: Color(0xFF9CA3AF),
                    ),

                    prefixIcon: const Icon(
                      Icons.email_outlined,
                      color: Color(0xFF9CA3AF),
                    ),

                    filled: true,
                    fillColor: const Color(0xFF111827),

                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),

                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(
                        color: Color(0xFF2563EB),
                        width: 1.5,
                      ),
                    ),

                    errorBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(
                        color: Colors.redAccent,
                      ),
                    ),
                  ),

                  validator: (value) {
                    final email = value?.trim() ?? '';

                    if (email.isEmpty) {
                      return 'Please enter your email';
                    }

                    final emailRegex = RegExp(
                      r'^[^@\s]+@[^@\s]+\.[^@\s]+$',
                    );

                    if (!emailRegex.hasMatch(email)) {
                      return 'Please enter a valid email';
                    }

                    return null;
                  },
                ),

                const SizedBox(height: 24),

                // Send Reset Link
                SizedBox(
                  height: 52,

                  child: ElevatedButton(
                    onPressed:
                    _isLoading ? null : _sendResetLink,

                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF2563EB),
                      disabledBackgroundColor:
                      const Color(0xFF374151),
                      foregroundColor: Colors.white,

                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),

                    child: _isLoading
                        ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                        : const Text(
                      'Send Reset Link',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 20),

                // Back to Login
                TextButton(
                  onPressed: _isLoading
                      ? null
                      : () {
                    Navigator.pop(context);
                  },

                  child: const Text(
                    'Back to Login',
                    style: TextStyle(
                      color: Color(0xFF60A5FA),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}