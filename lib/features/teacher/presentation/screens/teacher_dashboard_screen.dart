import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/network/supabase_client.dart';

class TeacherDashboardScreen extends StatefulWidget {
  const TeacherDashboardScreen({super.key});

  @override
  State<TeacherDashboardScreen> createState() => _TeacherDashboardScreenState();
}

class _TeacherDashboardScreenState extends State<TeacherDashboardScreen> {
  bool _loading = true;
  String? _error;
  Map<String, dynamic>? _profile;
  int _studentCount = 0;
  int _assignmentCount = 0;

  SupabaseClient get _client => SupabaseConfig.client;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final user = _client.auth.currentUser;
      if (user == null) throw const AuthException('Please login again.');

      final profile = await _client
          .from('profiles')
          .select('full_name, email, phone, role, school_id, subject, assigned_class, assigned_section, is_active')
          .eq('id', user.id)
          .maybeSingle();

      if (profile == null || profile['role']?.toString().toLowerCase() != 'teacher') {
        await _client.auth.signOut();
        if (mounted) context.go('/teacher-login');
        return;
      }
      if (profile['is_active'] == false || profile['school_id'] == null) {
        await _client.auth.signOut();
        if (mounted) context.go('/teacher-login');
        return;
      }

      final schoolId = profile['school_id'];
      final className = profile['assigned_class']?.toString().trim() ?? '';
      final section = profile['assigned_section']?.toString().trim() ?? '';

      var studentQuery = _client
          .from('students')
          .select('id')
          .eq('school_id', schoolId)
          .ilike('class_name', className);
      if (section.isNotEmpty) {
        studentQuery = studentQuery.ilike('section_name', section);
      }
      final students = await studentQuery;

      final assignments = await _client
          .from('assignments')
          .select('id')
          .eq('school_id', schoolId)
          .eq('created_by', user.id);

      if (!mounted) return;
      setState(() {
        _profile = Map<String, dynamic>.from(profile);
        _studentCount = List.from(students).length;
        _assignmentCount = List.from(assignments).length;
        _loading = false;
      });
    } on PostgrestException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.message;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString().replaceFirst('Exception: ', '');
        _loading = false;
      });
    }
  }

  Future<void> _logout() async {
    await _client.auth.signOut();
    if (mounted) context.go('/teacher-login');
  }

  @override
  Widget build(BuildContext context) {
    final profile = _profile ?? const <String, dynamic>{};
    final name = profile['full_name']?.toString().trim();
    final teacherName = name == null || name.isEmpty ? 'Teacher' : name;
    final subject = profile['subject']?.toString() ?? '-';
    final className = profile['assigned_class']?.toString() ?? '-';
    final section = profile['assigned_section']?.toString() ?? '';

    return Scaffold(
      backgroundColor: const Color(0xFFF6F8FC),
      appBar: AppBar(
        title: const Text('Teacher Portal', style: TextStyle(fontWeight: FontWeight.w900)),
        actions: [
          IconButton(onPressed: _load, tooltip: 'Refresh', icon: const Icon(Icons.refresh_rounded)),
          IconButton(onPressed: _logout, tooltip: 'Logout', icon: const Icon(Icons.logout_rounded)),
          const SizedBox(width: 8),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Padding(padding: const EdgeInsets.all(24), child: Column(mainAxisSize: MainAxisSize.min, children: [const Icon(Icons.error_outline_rounded, size: 52), const SizedBox(height: 12), Text(_error!, textAlign: TextAlign.center), const SizedBox(height: 16), FilledButton.icon(onPressed: _load, icon: const Icon(Icons.refresh_rounded), label: const Text('Try Again'))])))
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
                    children: [
                      Card(
                        elevation: 0,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
                        child: Padding(
                          padding: const EdgeInsets.all(22),
                          child: Row(children: [
                            CircleAvatar(radius: 32, backgroundColor: AppColors.primary.withOpacity(.12), child: const Icon(Icons.person_rounded, size: 34, color: AppColors.primary)),
                            const SizedBox(width: 16),
                            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('Welcome back', style: TextStyle(color: Colors.grey.shade600, fontSize: 13)), const SizedBox(height: 4), Text(teacherName, style: const TextStyle(fontSize: 23, fontWeight: FontWeight.w900)), const SizedBox(height: 5), Text('$subject • $className${section.isEmpty ? '' : ' • Section $section'}', style: const TextStyle(color: AppColors.textSecondary))])),
                          ]),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Wrap(spacing: 12, runSpacing: 12, children: [
                        _StatCard('My Students', '$_studentCount', Icons.groups_rounded),
                        _StatCard('My Assignments', '$_assignmentCount', Icons.assignment_rounded),
                      ]),
                      const SizedBox(height: 22),
                      const Text('Teaching Tools', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
                      const SizedBox(height: 10),
                      _PortalTile(icon: Icons.fact_check_rounded, title: 'Attendance', subtitle: 'Mark and review attendance for your class.', onTap: () => context.push('/attendance')),
                      _PortalTile(icon: Icons.assignment_rounded, title: 'Assignments', subtitle: 'Create and manage class assignments.', onTap: () => context.push('/assignment')),
                      _PortalTile(icon: Icons.menu_book_rounded, title: 'Examinations', subtitle: 'Enter and review examination results.', onTap: () => context.push('/examination')),
                      _PortalTile(icon: Icons.grade_rounded, title: 'Results', subtitle: 'Review student academic results.', onTap: () => context.push('/result')),
                      _PortalTile(icon: Icons.person_outline_rounded, title: 'My Profile', subtitle: 'View your account details.', onTap: () => context.push('/profile')),
                    ],
                  ),
                ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  const _StatCard(this.title, this.value, this.icon);

  @override
  Widget build(BuildContext context) => SizedBox(
        width: 220,
        child: Card(
          elevation: 0,
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Row(children: [
              Container(padding: const EdgeInsets.all(11), decoration: BoxDecoration(color: Theme.of(context).colorScheme.primaryContainer, borderRadius: BorderRadius.circular(12)), child: Icon(icon)),
              const SizedBox(width: 12),
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: const TextStyle(fontSize: 12, color: Colors.grey)), const SizedBox(height: 4), Text(value, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900))]),
            ]),
          ),
        ),
      );
}

class _PortalTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  const _PortalTile({required this.icon, required this.title, required this.subtitle, required this.onTap});

  @override
  Widget build(BuildContext context) => Card(
        elevation: 0,
        margin: const EdgeInsets.only(bottom: 10),
        child: ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
          leading: Container(padding: const EdgeInsets.all(11), decoration: BoxDecoration(color: AppColors.primary.withOpacity(.10), borderRadius: BorderRadius.circular(12)), child: Icon(icon, color: AppColors.primary)),
          title: Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
          subtitle: Text(subtitle),
          trailing: const Icon(Icons.chevron_right_rounded),
          onTap: onTap,
        ),
      );
}