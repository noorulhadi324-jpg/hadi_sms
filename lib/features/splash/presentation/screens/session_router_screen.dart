import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/widgets/hadi_design_system.dart';
import '../../../../core/network/supabase_client.dart';

class SessionRouterScreen extends StatefulWidget {
  const SessionRouterScreen({super.key});

  @override
  State<SessionRouterScreen> createState() => _SessionRouterScreenState();
}

class _SessionRouterScreenState extends State<SessionRouterScreen> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer(const Duration(milliseconds: 550), _route);
  }

  Future<void> _route() async {
    final client = SupabaseConfig.client;
    final session = client.auth.currentSession;

    if (session == null) {
      if (mounted) context.go('/login');
      return;
    }

    try {
      await client.rpc('ensure_my_school_link');
      final profile = await client
          .from('profiles')
          .select('role, school_id, is_active')
          .eq('id', session.user.id)
          .maybeSingle();

      if (profile == null || profile['is_active'] == false || profile['school_id'] == null) {
        await client.auth.signOut();
        if (mounted) context.go('/login');
        return;
      }

      if (!mounted) return;
      switch (profile['role']?.toString().trim().toLowerCase()) {
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
    } catch (_) {
      await client.auth.signOut();
      if (mounted) context.go('/login');
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [AppColors.secondary, AppColors.primaryDark],
          ),
        ),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              HadiBrandLogo(size: 92),
              const SizedBox(height: 24),
              const Text(
                'HADI SMS',
                style: TextStyle(
                  fontSize: 35,
                  fontWeight: FontWeight.w900,
                  color: Colors.white,
                  letterSpacing: -1,
                ),
              ),
              const SizedBox(height: 7),
              Text(
                'SMART SCHOOL MANAGEMENT',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: .62),
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 2,
                ),
              ),
              const SizedBox(height: 40),
              const SizedBox(
                width: 25,
                height: 25,
                child: CircularProgressIndicator(
                  strokeWidth: 2.2,
                  color: Colors.white,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
