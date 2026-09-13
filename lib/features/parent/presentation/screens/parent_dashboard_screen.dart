import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/network/supabase_client.dart';

class ParentDashboardData {
  final List<Map<String, dynamic>> children;
  final int attendancePresent;
  final int attendanceAbsent;
  final int homeworkCount;
  final double pendingFees;
  final List<Map<String, dynamic>> recentResults;

  const ParentDashboardData({
    required this.children,
    required this.attendancePresent,
    required this.attendanceAbsent,
    required this.homeworkCount,
    required this.pendingFees,
    required this.recentResults,
  });
}

final parentDashboardProvider =
    FutureProvider.autoDispose<ParentDashboardData>((ref) async {
  final client = SupabaseConfig.client;
  final user = client.auth.currentUser;

  if (user == null) {
    throw const AuthException('Please login again.');
  }

  final profile = await client
      .from('profiles')
      .select('id, full_name, email, school_id, role, is_active')
      .eq('id', user.id)
      .maybeSingle();

  if (profile == null) {
    throw const AuthException('Parent profile was not found.');
  }

  if (profile['role'] != 'parent') {
    throw const AuthException('This account is not a parent account.');
  }

  final schoolId = profile['school_id'];
  final email = (profile['email'] ?? user.email ?? '').toString().trim().toLowerCase();

  if (schoolId == null || email.isEmpty) {
    throw const AuthException('Parent account is not linked to a school.');
  }

  final childrenResponse = await client
      .from('students')
      .select('id, admission_number, full_name, class_name, section_name, date_of_birth, is_active, father_name, parent_email, mobile_number')
      .eq('school_id', schoolId)
      .ilike('parent_email', email)
      .order('full_name');

  final children = List<Map<String, dynamic>>.from(childrenResponse);
  final childIds = children
      .map((e) => e['id'])
      .where((e) => e != null)
      .toList();

  int present = 0;
  int absent = 0;
  int homeworkCount = 0;
  double pendingFees = 0;
  List<Map<String, dynamic>> recentResults = [];

  if (childIds.isNotEmpty) {
    final attendance = await client
        .from('attendance')
        .select('student_id, status')
        .eq('school_id', schoolId)
        .inFilter('student_id', childIds);

    for (final row in attendance) {
      final status = row['status']?.toString().toLowerCase();
      if (status == 'present') present++;
      if (status == 'absent') absent++;
    }

    final assignments = await client
        .from('assignments')
        .select('id, title, subject, assigned_class, assigned_section, due_date, status')
        .eq('school_id', schoolId)
        .order('due_date', ascending: true)
        .limit(20);
    homeworkCount = assignments.length;

    final fees = await client
        .from('student_fees')
        .select('amount, status')
        .eq('school_id', schoolId)
        .inFilter('student_id', childIds);

    for (final row in fees) {
      final status = row['status']?.toString().toLowerCase();
      if (status != 'paid' && status != 'cancelled') {
        final amount = row['amount'];
        if (amount is num) {
          pendingFees += amount.toDouble();
        } else {
          pendingFees += double.tryParse(amount?.toString() ?? '') ?? 0;
        }
      }
    }

    final results = await client
        .from('exam_results')
        .select('student_id, exam_id, exam_subject_id, obtained_marks, grade, remarks, created_at')
        .eq('school_id', schoolId)
        .inFilter('student_id', childIds)
        .order('created_at', ascending: false)
        .limit(10);
    recentResults = List<Map<String, dynamic>>.from(results);
  }

  return ParentDashboardData(
    children: children,
    attendancePresent: present,
    attendanceAbsent: absent,
    homeworkCount: homeworkCount,
    pendingFees: pendingFees,
    recentResults: recentResults,
  );
});

class ParentDashboardScreen extends ConsumerWidget {
  const ParentDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(parentDashboardProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFF7F9FC),
      appBar: AppBar(
        title: const Text('Parent Dashboard', style: TextStyle(fontWeight: FontWeight.w800)),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: () => ref.invalidate(parentDashboardProvider),
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.error_outline_rounded, size: 54, color: AppColors.error),
                const SizedBox(height: 12),
                Text(
                  error.toString().replaceFirst('AuthException(message: ', '').replaceFirst('Exception: ', '').replaceFirst(')', ''),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                FilledButton.icon(
                  onPressed: () => ref.invalidate(parentDashboardProvider),
                  icon: const Icon(Icons.refresh_rounded),
                  label: const Text('Try Again'),
                ),
              ],
            ),
          ),
        ),
        data: (data) => RefreshIndicator(
          onRefresh: () async => ref.invalidate(parentDashboardProvider),
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              const Text('My Children', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
              const SizedBox(height: 12),
              if (data.children.isEmpty)
                const _InfoCard(
                  icon: Icons.person_off_outlined,
                  title: 'No child linked yet',
                  subtitle: 'Ask the school administration to link your email with the student record.',
                )
              else
                ...data.children.map((child) => Card(
                      elevation: 0,
                      margin: const EdgeInsets.only(bottom: 10),
                      child: ListTile(
                        leading: CircleAvatar(child: Text((child['full_name'] ?? '?').toString().substring(0, 1).toUpperCase())),
                        title: Text(child['full_name']?.toString() ?? 'Student', style: const TextStyle(fontWeight: FontWeight.w800)),
                        subtitle: Text('${child['class_name'] ?? '-'}${child['section_name'] == null ? '' : ' • ${child['section_name']}'}\nAdmission: ${child['admission_number'] ?? '-'}'),
                        isThreeLine: true,
                      ),
                    )),
              const SizedBox(height: 14),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  _MetricCard(title: 'Present', value: '${data.attendancePresent}', icon: Icons.check_circle_outline_rounded),
                  _MetricCard(title: 'Absent', value: '${data.attendanceAbsent}', icon: Icons.cancel_outlined),
                  _MetricCard(title: 'Homework', value: '${data.homeworkCount}', icon: Icons.menu_book_outlined),
                  _MetricCard(title: 'Pending Fees', value: 'PKR ${data.pendingFees.toStringAsFixed(0)}', icon: Icons.payments_outlined),
                ],
              ),
              const SizedBox(height: 22),
              const Text('Recent Results', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
              const SizedBox(height: 10),
              if (data.recentResults.isEmpty)
                const _InfoCard(icon: Icons.assessment_outlined, title: 'No results available', subtitle: 'Exam results will appear here after the school publishes them.')
              else
                ...data.recentResults.map((result) => Card(
                      elevation: 0,
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ListTile(
                        leading: const Icon(Icons.assessment_outlined),
                        title: Text('Marks: ${result['obtained_marks'] ?? '-'}', style: const TextStyle(fontWeight: FontWeight.w700)),
                        subtitle: Text('Grade: ${result['grade'] ?? '-'}${result['remarks'] == null ? '' : ' • ${result['remarks']}'}'),
                      ),
                    )),
            ],
          ),
        ),
      ),
    );
  }
}

class _MetricCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  const _MetricCard({required this.title, required this.value, required this.icon});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 190,
      child: Card(
        elevation: 0,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Icon(icon, size: 28),
              const SizedBox(width: 12),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: const TextStyle(fontSize: 12)), const SizedBox(height: 4), Text(value, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900))])),
            ],
          ),
        ),
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  const _InfoCard({required this.icon, required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) => Card(
        elevation: 0,
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, size: 30),
              const SizedBox(width: 14),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: const TextStyle(fontWeight: FontWeight.w800)), const SizedBox(height: 4), Text(subtitle)])),
            ],
          ),
        ),
      );
}
