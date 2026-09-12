import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/network/supabase_client.dart';
import '../../../../core/constants/app_colors.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});
  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    Timer(const Duration(milliseconds: 1500), _continue);
  }

  void _continue() {
    if (!mounted) return;
    final session = SupabaseConfig.client.auth.currentSession;
    context.go(session == null ? '/login' : '/dashboard');
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: AppColors.secondary,
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 90,
                height: 90,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(24),
                ),
                child: const Icon(Icons.school_rounded, size: 48, color: Colors.white),
              ),
              const SizedBox(height: 32),
              const Text(
                'HADI SMS',
                style: TextStyle(fontSize: 36, fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: -1),
              ),
              const SizedBox(height: 8),
              Text(
                'ENTERPRISE SCHOOL MANAGEMENT',
                style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 2),
              ),
              const SizedBox(height: 48),
              const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)),
            ],
          ),
        ),
      );
}
