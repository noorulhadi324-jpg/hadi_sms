import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/network/supabase_client.dart';

class ParentDashboardData {
  final List<Map<String, dynamic>> children;
  final Map<int, List<Map<String, dynamic>>> workByStudent;
  final List<Map<String, dynamic>> notifications;
  final int attendancePresent;
  final int attendanceAbsent;
  final int homeworkCount;
  final int assignmentCount;
  final double pendingFees;
  final List<Map<String, dynamic>> recentResults;

  const ParentDashboardData({
    required this.children,
    required this.workByStudent,
    required this.notifications,
    required this.attendancePresent,
    required this.attendanceAbsent,
    required this.homeworkCount,
    required this.assignmentCount,
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

  if ((profile['role']?.toString().toLowerCase() ?? '') != 'parent') {
    throw const AuthException('This account is not a parent account.');
  }

  if (profile['is_active'] == false) {
    throw const AuthException('This parent account is inactive.');
  }

  final schoolId = profile['school_id'];
  if (schoolId == null) {
    throw const AuthException('Parent account is not linked to a school.');
  }

  // RLS returns only children linked to this parent (explicit parent_student_links
  // or the legacy parent_email fallback), so one parent can safely have multiple children.
  final childrenResponse = await client
      .from('students')
      .select(
        'id, admission_number, full_name, class_name, section_name, '
        'date_of_birth, is_active, father_name, parent_email, mobile_number',
      )
      .eq('school_id', schoolId)
      .eq('is_active', true)
      .order('full_name');

  final children = List<Map<String, dynamic>>.from(childrenResponse);
  final childIds = children
      .map((e) => int.tryParse(e['id']?.toString() ?? ''))
      .whereType<int>()
      .toList();

  int present = 0;
  int absent = 0;
  double pendingFees = 0;
  List<Map<String, dynamic>> recentResults = [];
  List<Map<String, dynamic>> notifications = [];
  final workByStudent = <int, List<Map<String, dynamic>>>{
    for (final id in childIds) id: <Map<String, dynamic>>[],
  };

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

    final workResponse = await client
        .from('assignments')
        .select(
          'id, title, description, subject, assigned_class, assigned_section, '
          'assigned_date, start_date, due_date, status, work_type, audience',
        )
        .eq('school_id', schoolId)
        .order('start_date', ascending: false);
    final workRows = List<Map<String, dynamic>>.from(workResponse);

    final workIds = workRows
        .map((row) => int.tryParse(row['id']?.toString() ?? ''))
        .whereType<int>()
        .toList();

    final targetMap = <int, Set<int>>{};
    if (workIds.isNotEmpty) {
      final targetsResponse = await client
          .from('assignment_students')
          .select('assignment_id, student_id')
          .inFilter('assignment_id', workIds);
      for (final target in targetsResponse) {
        final assignmentId = int.tryParse(target['assignment_id']?.toString() ?? '');
        final studentId = int.tryParse(target['student_id']?.toString() ?? '');
        if (assignmentId == null || studentId == null) continue;
        targetMap.putIfAbsent(assignmentId, () => <int>{}).add(studentId);
      }
    }

    bool sameText(dynamic a, dynamic b) {
      return (a?.toString().trim().toLowerCase() ?? '') ==
          (b?.toString().trim().toLowerCase() ?? '');
    }

    bool isCurrent(Map<String, dynamic> row) {
      final status = row['status']?.toString().toLowerCase() ?? 'active';
      if (status == 'completed' || status == 'cancelled') return false;
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final start = DateTime.tryParse(
        (row['start_date'] ?? row['assigned_date'])?.toString() ?? '',
      );
      final due = DateTime.tryParse(row['due_date']?.toString() ?? '');
      if (start != null && DateTime(start.year, start.month, start.day).isAfter(today)) {
        return false;
      }
      if (due != null && DateTime(due.year, due.month, due.day).isBefore(today)) {
        return false;
      }
      return true;
    }

    for (final row in workRows) {
      if (!isCurrent(row)) continue;
      final assignmentId = int.tryParse(row['id']?.toString() ?? '');
      final audience = row['audience']?.toString() == 'students' ? 'students' : 'class';

      for (final child in children) {
        final childId = int.tryParse(child['id']?.toString() ?? '');
        if (childId == null) continue;

        bool applies = false;
        if (audience == 'students') {
          applies = assignmentId != null && (targetMap[assignmentId]?.contains(childId) ?? false);
        } else {
          final classMatches = sameText(child['class_name'], row['assigned_class']);
          final assignedSection = row['assigned_section']?.toString().trim() ?? '';
          final sectionMatches = assignedSection.isEmpty ||
              sameText(child['section_name'], assignedSection);
          applies = classMatches && sectionMatches;
        }

        if (applies) {
          workByStudent.putIfAbsent(childId, () => <Map<String, dynamic>>[]).add(row);
        }
      }
    }

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
        .select(
          'student_id, exam_id, exam_subject_id, obtained_marks, grade, '
          'remarks, created_at',
        )
        .eq('school_id', schoolId)
        .inFilter('student_id', childIds)
        .order('created_at', ascending: false)
        .limit(10);
    recentResults = List<Map<String, dynamic>>.from(results);

    final notificationResponse = await client
        .from('parent_work_notifications')
        .select(
          'id, student_id, assignment_id, title, message, is_read, created_at',
        )
        .order('created_at', ascending: false)
        .limit(20);
    notifications = List<Map<String, dynamic>>.from(notificationResponse);
  }

  var homeworkCount = 0;
  var assignmentCount = 0;
  for (final rows in workByStudent.values) {
    for (final row in rows) {
      if (row['work_type']?.toString() == 'homework') {
        homeworkCount++;
      } else {
        assignmentCount++;
      }
    }
  }

  return ParentDashboardData(
    children: children,
    workByStudent: workByStudent,
    notifications: notifications,
    attendancePresent: present,
    attendanceAbsent: absent,
    homeworkCount: homeworkCount,
    assignmentCount: assignmentCount,
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
        title: const Text(
          'Parent Dashboard',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
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
                const Icon(
                  Icons.error_outline_rounded,
                  size: 54,
                  color: AppColors.error,
                ),
                const SizedBox(height: 12),
                Text(
                  error
                      .toString()
                      .replaceFirst('AuthException(message: ', '')
                      .replaceFirst('Exception: ', '')
                      .replaceFirst(')', ''),
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
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(20),
            children: [
              if (data.notifications.isNotEmpty) ...[
                Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'School Work Updates',
                        style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.10),
                        borderRadius: BorderRadius.circular(99),
                      ),
                      child: Text(
                        '${data.notifications.where((n) => n['is_read'] != true).length} new',
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                ...data.notifications.take(5).map(
                      (notification) => Card(
                        elevation: 0,
                        margin: const EdgeInsets.only(bottom: 8),
                        child: ListTile(
                          leading: Icon(
                            notification['is_read'] == true
                                ? Icons.notifications_none_rounded
                                : Icons.notifications_active_rounded,
                            color: AppColors.primary,
                          ),
                          title: Text(
                            notification['title']?.toString() ?? 'School work update',
                            style: const TextStyle(fontWeight: FontWeight.w800),
                          ),
                          subtitle: Text(notification['message']?.toString() ?? ''),
                        ),
                      ),
                    ),
                const SizedBox(height: 16),
              ],
              const Text(
                'My Children',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 12),
              if (data.children.isEmpty)
                const _InfoCard(
                  icon: Icons.person_off_outlined,
                  title: 'No child linked yet',
                  subtitle:
                      'Ask the school administration to link your parent account with the student record.',
                )
              else
                ...data.children.map((child) {
                  final childId = int.tryParse(child['id']?.toString() ?? '');
                  final work = childId == null
                      ? const <Map<String, dynamic>>[]
                      : data.workByStudent[childId] ?? const <Map<String, dynamic>>[];
                  return _ChildCard(child: child, work: work);
                }),
              const SizedBox(height: 14),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  _MetricCard(
                    title: 'Present',
                    value: '${data.attendancePresent}',
                    icon: Icons.check_circle_outline_rounded,
                  ),
                  _MetricCard(
                    title: 'Absent',
                    value: '${data.attendanceAbsent}',
                    icon: Icons.cancel_outlined,
                  ),
                  _MetricCard(
                    title: 'Homework',
                    value: '${data.homeworkCount}',
                    icon: Icons.menu_book_outlined,
                  ),
                  _MetricCard(
                    title: 'Assignments',
                    value: '${data.assignmentCount}',
                    icon: Icons.assignment_outlined,
                  ),
                  _MetricCard(
                    title: 'Pending Fees',
                    value: 'PKR ${data.pendingFees.toStringAsFixed(0)}',
                    icon: Icons.payments_outlined,
                  ),
                ],
              ),
              const SizedBox(height: 22),
              const Text(
                'Recent Results',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 10),
              if (data.recentResults.isEmpty)
                const _InfoCard(
                  icon: Icons.assessment_outlined,
                  title: 'No results available',
                  subtitle:
                      'Exam results will appear here after the school publishes them.',
                )
              else
                ...data.recentResults.map(
                  (result) => Card(
                    elevation: 0,
                    margin: const EdgeInsets.only(bottom: 8),
                    child: ListTile(
                      leading: const Icon(Icons.assessment_outlined),
                      title: Text(
                        'Marks: ${result['obtained_marks'] ?? '-'}',
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      subtitle: Text(
                        'Grade: ${result['grade'] ?? '-'}'
                        '${result['remarks'] == null ? '' : ' • ${result['remarks']}'}',
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ChildCard extends StatelessWidget {
  const _ChildCard({required this.child, required this.work});

  final Map<String, dynamic> child;
  final List<Map<String, dynamic>> work;

  String _date(dynamic value) {
    final parsed = DateTime.tryParse(value?.toString() ?? '');
    if (parsed == null) return 'No due date';
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return '${parsed.day} ${months[parsed.month - 1]} ${parsed.year}';
  }

  @override
  Widget build(BuildContext context) {
    final name = child['full_name']?.toString() ?? 'Student';
    final initial = name.trim().isEmpty ? '?' : name.trim()[0].toUpperCase();
    final className = child['class_name']?.toString() ?? '-';
    final section = child['section_name']?.toString().trim() ?? '';

    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(child: Text(initial)),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(name, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
                      Text(
                        '$className${section.isEmpty ? '' : ' • Section $section'} • Admission: ${child['admission_number'] ?? '-'}',
                        style: const TextStyle(color: AppColors.textSecondary),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            const Divider(height: 1),
            const SizedBox(height: 12),
            const Text(
              'Current Homework & Assignments',
              style: TextStyle(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            if (work.isEmpty)
              const Text(
                'No current school work for this child.',
                style: TextStyle(color: AppColors.textSecondary),
              )
            else
              ...work.map((item) {
                final isHomework = item['work_type']?.toString() == 'homework';
                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        isHomework ? Icons.menu_book_outlined : Icons.assignment_outlined,
                        color: AppColors.primary,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              item['title']?.toString() ?? (isHomework ? 'Homework' : 'Assignment'),
                              style: const TextStyle(fontWeight: FontWeight.w800),
                            ),
                            Text(
                              '${item['subject'] ?? 'Subject'} • Due ${_date(item['due_date'])}',
                              style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                            ),
                            if ((item['description']?.toString().trim() ?? '').isNotEmpty) ...[
                              const SizedBox(height: 3),
                              Text(item['description'].toString()),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              }),
          ],
        ),
      ),
    );
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({required this.title, required this.value, required this.icon});

  final String title;
  final String value;
  final IconData icon;

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
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: const TextStyle(fontSize: 12)),
                    const SizedBox(height: 4),
                    Text(
                      value,
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({required this.icon, required this.title, required this.subtitle});

  final IconData icon;
  final String title;
  final String subtitle;

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
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
                    const SizedBox(height: 4),
                    Text(subtitle),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
}
