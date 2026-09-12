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
    Timer(const Duration(milliseconds: 1200), _continue);
  }

  Future<void> _continue() async {
    if (!mounted) return;
    final client = SupabaseConfig.client;
    final session = client.auth.currentSession;

    if (session == null) {
      context.go('/login');
      return;
    }

    try {
      await client.rpc('ensure_my_school_link');
      final profile = await client
          .from('profiles')
          .select('role, school_id, is_active')
          .eq('id', session.user.id)
          .maybeSingle();

      if (!mounted) return;

      if (profile == null || profile['is_active'] == false || profile['school_id'] == null) {
        await client.auth.signOut();
        if (mounted) context.go('/login');
        return;
      }

      final role = profile['role']?.toString().toLowerCase();
      if (role == 'parent') {
        context.go('/parent-dashboard');
      } else {
        context.go('/dashboard');
      }
    } catch (_) {
      if (!mounted) return;
      context.go('/dashboard');
    }
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
              const Text('HADI SMS', style: TextStyle(fontSize: 36, fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: -1)),
              const SizedBox(height: 8),
              Text('ENTERPRISE SCHOOL MANAGEMENT', style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 2)),
              const SizedBox(height: 48),
              const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)),
            ],
          ),
        ),
      );
}
