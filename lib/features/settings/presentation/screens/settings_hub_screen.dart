import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_colors.dart';
import 'system_settings_screen.dart';

class SettingsHubScreen extends StatelessWidget {
  const SettingsHubScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Settings'), centerTitle: false),
      body: LayoutBuilder(builder: (context, constraints) {
        final mobile = constraints.maxWidth < 700;
        return ListView(
          padding: EdgeInsets.all(mobile ? 16 : 28),
          children: [
            Container(
              padding: const EdgeInsets.all(22),
              decoration: BoxDecoration(color: AppColors.primary, borderRadius: BorderRadius.circular(22)),
              child: const Row(children: [
                Icon(Icons.tune_rounded, color: Colors.white, size: 32),
                SizedBox(width: 14),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('HADI SMS Settings', style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w900)),
                  SizedBox(height: 4),
                  Text('Central control for school setup and connected modules.', style: TextStyle(color: Colors.white70, fontSize: 12)),
                ])),
              ]),
            ),
            const SizedBox(height: 20),
            _card(context, 'System Settings', 'General, school profile, academic sessions and fee structures', Icons.settings_applications_rounded, () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SystemSettingsScreen()))),
            _card(context, 'Teachers', 'Add, edit, activate and manage teacher accounts', Icons.school_rounded, () => context.go('/teacher')),
            _card(context, 'Parents', 'Parent profiles and child-linked parent accounts', Icons.family_restroom_rounded, () => context.go('/parent')),
            _card(context, 'Staff & Team', 'Manage non-teaching staff and responsibilities', Icons.badge_rounded, () => context.go('/staff')),
            _card(context, 'Communication', 'Announcements, direct messages and team chat', Icons.forum_rounded, () => context.go('/communication')),
            _card(context, 'School Profile', 'Update the school identity from the central settings module', Icons.school_outlined, () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SystemSettingsScreen()))),
            const SizedBox(height: 12),
            Container(padding: const EdgeInsets.all(16), decoration: BoxDecoration(color: AppColors.success.withValues(alpha: .07), borderRadius: BorderRadius.circular(16), border: Border.all(color: AppColors.success.withValues(alpha: .12))), child: const Row(children: [Icon(Icons.verified_rounded, color: AppColors.success), SizedBox(width: 10), Expanded(child: Text('Core settings, staff management and communication are now connected to the same school and role system.', style: TextStyle(color: AppColors.success, fontWeight: FontWeight.w700, fontSize: 12)))])),
          ],
        );
      }),
    );
  }

  Widget _card(BuildContext context, String title, String subtitle, IconData icon, VoidCallback onTap) {
    return Card(elevation: 0, margin: const EdgeInsets.only(bottom: 10), child: ListTile(contentPadding: const EdgeInsets.all(14), leading: Container(width: 46, height: 46, decoration: BoxDecoration(color: AppColors.primary.withValues(alpha: .08), borderRadius: BorderRadius.circular(13)), child: Icon(icon, color: AppColors.primary)), title: Text(title, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 14)), subtitle: Padding(padding: const EdgeInsets.only(top: 4), child: Text(subtitle, style: const TextStyle(fontSize: 11))), trailing: const Icon(Icons.chevron_right_rounded), onTap: onTap));
  }
}
