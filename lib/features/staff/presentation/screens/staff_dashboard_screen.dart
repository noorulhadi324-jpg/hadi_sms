import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/network/supabase_client.dart';
import '../../../../core/constants/app_colors.dart';

final staffPortalProfileProvider = FutureProvider.autoDispose<Map<String, dynamic>>((ref) async {
  final client = SupabaseConfig.client;
  final user = client.auth.currentUser;
  if (user == null) throw Exception('No authenticated user.');

  final row = await client
      .from('profiles')
      .select('full_name,email,phone,role,staff_role,school_id,is_active')
      .eq('id', user.id)
      .maybeSingle();

  if (row == null || row['role']?.toString().toLowerCase() != 'staff') {
    throw Exception('Staff profile not found.');
  }
  return Map<String, dynamic>.from(row);
});

class StaffDashboardScreen extends ConsumerWidget {
  const StaffDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(staffPortalProfileProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Staff Portal'),
        actions: [
          IconButton(
            tooltip: 'Logout',
            onPressed: () async {
              await SupabaseConfig.client.auth.signOut();
              if (context.mounted) context.go('/login');
            },
            icon: const Icon(Icons.logout_rounded),
          ),
        ],
      ),
      body: profile.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text(e.toString().replaceFirst('Exception: ', ''))),
        data: (user) {
          final name = user['full_name']?.toString() ?? 'Staff Member';
          final role = user['staff_role']?.toString() ?? 'Staff';

          return ListView(
            padding: const EdgeInsets.all(24),
            children: [
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(colors: [Color(0xFF7C3AED), Color(0xFF4F46E5)]),
                  borderRadius: BorderRadius.circular(22),
                ),
                child: Row(
                  children: [
                    const CircleAvatar(radius: 30, backgroundColor: Colors.white24, child: Icon(Icons.badge_rounded, color: Colors.white, size: 32)),
                    const SizedBox(width: 16),
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('Welcome, $name', style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w900)),
                      const SizedBox(height: 5),
                      Text(role, style: const TextStyle(color: Colors.white70, fontWeight: FontWeight.w700)),
                    ])),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              const Text('Staff Access', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
              const SizedBox(height: 12),
              _card(context, 'Attendance', Icons.fact_check_rounded, '/attendance'),
              _card(context, 'Assignments', Icons.assignment_rounded, '/assignment'),
              _card(context, 'Examination', Icons.quiz_rounded, '/examination'),
              _card(context, 'Results', Icons.bar_chart_rounded, '/result'),
              _card(context, 'Profile', Icons.person_rounded, '/profile'),
              const SizedBox(height: 12),
              const Card(child: Padding(padding: EdgeInsets.all(16), child: Row(children: [Icon(Icons.lock_outline_rounded, color: AppColors.primary), SizedBox(width: 10), Expanded(child: Text('آپ کا پاس ورڈ صرف آپ خود تبدیل یا Forgot Password کے ذریعے reset کر سکتے ہیں۔ انتظامیہ کو آپ کا پاس ورڈ نظر نہیں آتا۔', style: TextStyle(fontWeight: FontWeight.w600)))]))),
            ],
          );
        },
      ),
    );
  }

  Widget _card(BuildContext context, String title, IconData icon, String route) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        leading: CircleAvatar(backgroundColor: AppColors.primary.withValues(alpha: .08), child: Icon(icon, color: AppColors.primary)),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
        trailing: const Icon(Icons.chevron_right_rounded),
        onTap: () => context.push(route),
      ),
    );
  }
}
