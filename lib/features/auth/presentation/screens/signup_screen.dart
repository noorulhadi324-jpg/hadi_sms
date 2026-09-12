import 'package:flutter/material.dart';

import '../../../../core/network/supabase_client.dart';
import 'login_screen.dart';

class SignUpScreen extends StatefulWidget {
  const SignUpScreen({super.key});

  @override
  State<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends State<SignUpScreen> {
  final _formKey = GlobalKey<FormState>();

  final TextEditingController _nameController =
  TextEditingController();

  final TextEditingController _emailController =
  TextEditingController();

  final TextEditingController _phoneController =
  TextEditingController();

  final TextEditingController _passwordController =
  TextEditingController();

  final TextEditingController _confirmPasswordController =
  TextEditingController();

  bool _isLoading = false;

  bool _acceptTerms = false;

  bool _obscurePassword = true;

  bool _obscureConfirmPassword = true;

  String _selectedRole = "Student";

  final List<String> _roles = [
    "Admin",
    "Teacher",
    "Student",
    "Parent",
  ];

  Future<void> _handleSignUp() async {
    if (_isLoading) return;

    if (!_formKey.currentState!.validate()) return;

    if (!_acceptTerms) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Please accept Terms & Conditions"),
        ),
      );
      return;
    }

    if (_passwordController.text.trim() !=
        _confirmPasswordController.text.trim()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Passwords do not match"),
        ),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final response = await SupabaseConfig.client.auth.signUp(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
        data: {
          "full_name": _nameController.text.trim(),
          "phone": _phoneController.text.trim(),
          "role_name": _selectedRole,
        },
      );

      if (response.user != null) {
        if (!mounted) return;

        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (_) => AlertDialog(
            title: const Text("Account Created"),
            content: const Text(
              "Verification email has been sent.\n\nPlease verify your account before login.",
            ),
            actions: [
              ElevatedButton(
                onPressed: () {
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const LoginScreen(),
                    ),
                  );
                },
                child: const Text("Go To Login"),
              )
            ],
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;

      String message = e.toString();

      if (message.contains("over_email_send_rate_limit")) {
        message =
        "Verification email was sent recently.\n\nPlease wait 60 seconds and try again.";
      } else if (message.contains("User already registered")) {
        message =
        "This email is already registered. Please login instead.";
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: Colors.red,
          content: Text(message),
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
        backgroundColor: const Color(0xff030712),

        body: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),

              child: SizedBox(
                width: 430,

                child: Form(
                  key: _formKey,

                  child: Column(
                    crossAxisAlignment:
                    CrossAxisAlignment.stretch,

                    children: [

                      const Icon(
                        Icons.school,
                        color: Color(0xFF2563EB),
                        size: 80,
                      ),

                      const SizedBox(height: 20),

                      const Text(
                        "CREATE ACCOUNT",
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 30,
                        ),
                      ),

                      const SizedBox(height: 10),

                      const Text(
                        "Create your School ERP account",
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.grey,
                        ),
                      ),

                      const SizedBox(height: 35),

                      /// Full Name

                      TextFormField(
                        controller: _nameController,
                        style: const TextStyle(
                          color: Colors.white,
                        ),
                        decoration: InputDecoration(
                          hintText: "Full Name",
                          prefixIcon: const Icon(
                            Icons.person_outline,
                            color: Colors.white70,
                          ),
                          filled: true,
                          fillColor: const Color(0xff111827),
                          border: OutlineInputBorder(
                            borderRadius:
                            BorderRadius.circular(14),
                            borderSide: BorderSide.none,
                          ),
                        ),
                        validator: (value) {
                          if (value == null ||
                              value
                                  .trim()
                                  .isEmpty) {
                            return "Enter full name";
                          }
                          return null;
                        },
                      ),

                      const SizedBox(height: 18),

                      /// Email

                      TextFormField(
                        controller: _emailController,
                        keyboardType:
                        TextInputType.emailAddress,
                        style: const TextStyle(
                          color: Colors.white,
                        ),
                        decoration: InputDecoration(
                          hintText: "Email Address",
                          prefixIcon: const Icon(
                            Icons.email_outlined,
                            color: Colors.white70,
                          ),
                          filled: true,
                          fillColor: const Color(0xff111827),
                          border: OutlineInputBorder(
                            borderRadius:
                            BorderRadius.circular(14),
                            borderSide: BorderSide.none,
                          ),
                        ),
                        validator: (value) {
                          if (value == null ||
                              value
                                  .trim()
                                  .isEmpty ||
                              !value.contains("@")) {
                            return "Enter valid email";
                          }
                          return null;
                        },
                      ),

                      const SizedBox(height: 18),

                      /// Phone

                      TextFormField(
                        controller: _phoneController,
                        keyboardType:
                        TextInputType.phone,
                        style: const TextStyle(
                          color: Colors.white,
                        ),
                        decoration: InputDecoration(
                          hintText: "Phone Number",
                          prefixIcon: const Icon(
                            Icons.phone_outlined,
                            color: Colors.white70,
                          ),
                          filled: true,
                          fillColor: const Color(0xff111827),
                          border: OutlineInputBorder(
                            borderRadius:
                            BorderRadius.circular(14),
                            borderSide: BorderSide.none,
                          ),
                        ),
                        validator: (value) {
                          if (value == null ||
                              value
                                  .trim()
                                  .isEmpty) {
                            return "Enter phone number";
                          }
                          return null;
                        },
                      ),

                      const SizedBox(height: 18),

                      /// Role

                      DropdownButtonFormField<String>(
                        initialValue: _selectedRole,
                        dropdownColor: const Color(0xff111827),
                        style: const TextStyle(color: Colors.white),
                        decoration: InputDecoration(
                          prefixIcon: const Icon(
                            Icons.badge_outlined,
                            color: Colors.white70,
                          ),
                          filled: true,
                          fillColor: const Color(0xff111827),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: BorderSide.none,
                          ),
                        ),
                        items: _roles.map((role) {
                          return DropdownMenuItem(
                            value: role,
                            child: Text(role),
                          );
                        }).toList(),
                        onChanged: (value) {
                          setState(() {
                            _selectedRole = value!;
                          });
                        },
                      ),

                      const SizedBox(height: 18),

                      /// Password

                      TextFormField(
                        controller: _passwordController,
                        obscureText: _obscurePassword,
                        style: const TextStyle(color: Colors.white),
                        decoration: InputDecoration(
                          hintText: "Password",
                          prefixIcon: const Icon(
                            Icons.lock_outline,
                            color: Colors.white70,
                          ),
                          suffixIcon: IconButton(
                            icon: Icon(
                              _obscurePassword
                                  ? Icons.visibility_off
                                  : Icons.visibility,
                              color: Colors.white70,
                            ),
                            onPressed: () {
                              setState(() {
                                _obscurePassword = !_obscurePassword;
                              });
                            },
                          ),
                          filled: true,
                          fillColor: const Color(0xff111827),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: BorderSide.none,
                          ),
                        ),
                        validator: (value) {
                          if (value == null || value.length < 6) {
                            return "Password must be at least 6 characters";
                          }
                          return null;
                        },
                      ),

                      const SizedBox(height: 18),

                      /// Confirm Password

                      TextFormField(
                        controller: _confirmPasswordController,
                        obscureText: _obscureConfirmPassword,
                        style: const TextStyle(color: Colors.white),
                        decoration: InputDecoration(
                          hintText: "Confirm Password",
                          prefixIcon: const Icon(
                            Icons.lock_reset,
                            color: Colors.white70,
                          ),
                          suffixIcon: IconButton(
                            icon: Icon(
                              _obscureConfirmPassword
                                  ? Icons.visibility_off
                                  : Icons.visibility,
                              color: Colors.white70,
                            ),
                            onPressed: () {
                              setState(() {
                                _obscureConfirmPassword =
                                !_obscureConfirmPassword;
                              });
                            },
                          ),
                          filled: true,
                          fillColor: const Color(0xff111827),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: BorderSide.none,
                          ),
                        ),
                        validator: (value) {
                          if (value != _passwordController.text) {
                            return "Passwords do not match";
                          }
                          return null;
                        },
                      ),

                      const SizedBox(height: 20),

                      /// Terms

                      Row(
                        children: [
                          Checkbox(
                            value: _acceptTerms,
                            activeColor: const Color(0xFF2563EB),
                            onChanged: (value) {
                              setState(() {
                                _acceptTerms = value ?? false;
                              });
                            },
                          ),
                          Expanded(
                            child: Text(
                              "I agree to the Terms & Conditions",
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: .7),
                              ),
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 30), Container(
                        width: double.infinity,
                        height: 55,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(14),
                          gradient: const LinearGradient(
                            colors: [
                              Color(0xFF2563EB),
                              Color(0xFF3B82F6),
                            ],
                          ),
                        ),
                        child: ElevatedButton(
                          onPressed: _isLoading ? null : _handleSignUp,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.transparent,
                            shadowColor: Colors.transparent,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          child: _isLoading
                              ? const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                Colors.white,
                              ),
                            ),
                          )
                              : const Text(
                            "CREATE ACCOUNT",
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1,
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(height: 25),

                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            "Already have an account?",
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.6),
                            ),
                          ),
                          TextButton(
                            onPressed: () {
                              Navigator.pushReplacement(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => const LoginScreen(),
                                ),
                              );
                            },
                            child: const Text(
                              "Sign In",
                              style: TextStyle(
                                color: Color(0xFF3B82F6),
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 20),
                    ],
                  ),
                ),
              ),
            ),
          ),
        )
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }
}