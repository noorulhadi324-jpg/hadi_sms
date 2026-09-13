import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/network/supabase_client.dart';

class SessionRouterScreen extends StatefulWidget {
  const SessionRouterScreen({super.key});
  @override
  State<SessionRouterScreen> createState() => _SessionRouterScreenState();
}

class _SessionRouterScreenState extends State<SessionRouterScreen> {
  @override
  void initState() {
    super.initState();
    Timer(const Duration(milliseconds: 700), _route);
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
      final profile = await client.from('profiles').select('role, school_id, is_active').eq('id', session.user.id).maybeSingle();
      if (profile == null || profile['is_active'] == false || profile['school_id'] == null) {
        await client.auth.signOut();
        if (mounted) context.go('/login');
        return;
      }
      final role = profile['role']?.toString().trim().toLowerCase();
      if (!mounted) return;
      if (role == 'parent') {
        context.go('/parent-dashboard');
      } else if (role == 'teacher') {
        context.go('/teacher-dashboard');
      } else if (role == 'staff') {
        context.go('/staff-dashboard');
      } else {
        context.go('/dashboard');
      }
    } catch (_) {
      await client.auth.signOut();
      if (mounted) context.go('/login');
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: AppColors.secondary,
        body: Center(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(width: 88, height: 88, decoration: BoxDecoration(color: Colors.white.withValues(alpha: .10), borderRadius: BorderRadius.circular(24)), child: const Icon(Icons.school_rounded, size: 46, color: Colors.white)),
            const SizedBox(height: 28),
            const Text('HADI SMS', style: TextStyle(fontSize: 34, fontWeight: FontWeight.w900, color: Colors.white)),
            const SizedBox(height: 8),
            Text('SECURE PORTAL', style: TextStyle(color: Colors.white.withValues(alpha: .55), fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 2)),
            const SizedBox(height: 42),
            const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)),
          ]),
        ),
      );
}
