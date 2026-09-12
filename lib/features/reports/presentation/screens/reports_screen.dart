import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/services/report_export_service.dart';
import '../../../../core/supabase/supabase_config.dart';
import '../../../../core/widgets/main_wrapper.dart';

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  final _client = SupabaseConfig.client;
  bool _loading = true;
  bool _exporting = false;
  String? _error;
  String _schoolName = 'HADI SMS';
  int? _schoolId;

  List<Map<String, dynamic>> _students = [];
  List<Map<String, dynamic>> _attendance = [];
  List<Map<String, dynamic>> _fees = [];
  List<Map<String, dynamic>> _results = [];

  @override
  void initState() {
    super.initState();
    _loadReports();
  }

  Future<void> _loadReports() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final uid = _client.auth.currentUser?.id;
      if (uid == null) throw Exception('Please login again.');

      final profile = await _client
          .from('profiles')
          .select('school_id')
          .eq('id', uid)
          .maybeSingle();

      _schoolId = (profile?['school_id'] as num?)?.toInt();
      if (_schoolId == null) throw Exception('School profile is not linked.');

      final school = await _client
          .from('schools')
          .select('school_name')
          .eq('id', _schoolId!)
          .maybeSingle();
      _schoolName = (school?['school_name'] as String?)?.trim().isNotEmpty == true
          ? school!['school_name'] as String
          : 'HADI SMS';

      final results = await Future.wait([
        _client.from('students').select('id,admission_number,full_name,class_name,section_name,father_name,is_active').eq('school_id', _schoolId!).order('full_name'),
        _client.from('attendance').select('student_id,attendance_date,status').eq('school_id', _schoolId!).order('attendance_date', ascending: false),
        _client.from('student_fees').select('id,student_id,fee_category_id,amount,due_date,status,fee_month').eq('school_id', _schoolId!).order('fee_month', ascending: false),
        _client.from('exam_results').select('student_id,exam_id,exam_subject_id,obtained_marks,grade,remarks').eq('school_id', _schoolId!).order('created_at', ascending: false),
      ]);

      if (!mounted) return;
      setState(() {
        _students = List<Map<String, dynamic>>.from(results[0] as List);
        _attendance = List<Map<String, dynamic>>.from(results[1] as List);
        _fees = List<Map<String, dynamic>>.from(results[2] as List);
        _results = List<Map<String, dynamic>>.from(results[3] as List);
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  String _studentName(dynamic id) {
    final match = _students.where((s) => '${s['id']}' == '$id').firstOrNull;
    return (match?['full_name'] as String?) ?? 'Student #$id';
  }

  Future<void> _export(String type, {required bool excel}) async {
    if (_exporting) return;
    setState(() => _exporting = true);

    try {
      late final String title;
      late final List<String> headers;
      late final List<List<String>> rows;

      switch (type) {
        case 'students':
          title = 'Student Directory';
          headers = ['Admission No.', 'Student Name', 'Class', 'Section', 'Father Name', 'Status'];
          rows = _students.map((s) => [
            '${s['admission_number'] ?? ''}',
            '${s['full_name'] ?? ''}',
            '${s['class_name'] ?? ''}',
            '${s['section_name'] ?? ''}',
            '${s['father_name'] ?? ''}',
            s['is_active'] == true ? 'Active' : 'Inactive',
          ]).toList();
          break;
        case 'attendance':
          title = 'Attendance Report';
          headers = ['Student', 'Date', 'Status'];
          rows = _attendance.map((a) => [
            _studentName(a['student_id']),
            '${a['attendance_date'] ?? ''}',
            '${a['status'] ?? ''}',
          ]).toList();
          break;
        case 'fees':
          title = 'Fee Summary';
          headers = ['Student', 'Fee Month', 'Due Date', 'Amount', 'Status'];
          rows = _fees.map((f) => [
            _studentName(f['student_id']),
            '${f['fee_month'] ?? ''}',
            '${f['due_date'] ?? ''}',
            '${f['amount'] ?? 0}',
            '${f['status'] ?? ''}',
          ]).toList();
          break;
        default:
          title = 'Exam Results';
          headers = ['Student', 'Exam ID', 'Exam Subject ID', 'Obtained Marks', 'Grade', 'Remarks'];
          rows = _results.map((r) => [
            _studentName(r['student_id']),
            '${r['exam_id'] ?? ''}',
            '${r['exam_subject_id'] ?? ''}',
            '${r['obtained_marks'] ?? 0}',
            '${r['grade'] ?? ''}',
            '${r['remarks'] ?? ''}',
          ]).toList();
      }

      final file = excel
          ? await ReportExportService.exportExcel(title: title, headers: headers, rows: rows, schoolName: _schoolName)
          : await ReportExportService.exportPdf(title: title, headers: headers, rows: rows, schoolName: _schoolName);

      await ReportExportService.shareFile(file, subject: title);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${excel ? 'Excel' : 'PDF'} تیار ہے: ${file.path}')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Export failed: $e')));
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return MainWrapper(
      child: RefreshIndicator(
        onRefresh: _loadReports,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 32),
          children: [
            _header(),
            const SizedBox(height: 20),
            if (_loading) const Center(child: Padding(padding: EdgeInsets.all(40), child: CircularProgressIndicator()))
            else if (_error != null) _errorCard()
            else ...[
              _summaryCards(),
              const SizedBox(height: 20),
              _reportCard('Student Directory', 'Students, classes, sections and status.', Icons.school_rounded, 'students'),
              _reportCard('Attendance Report', 'Complete attendance history by student and date.', Icons.fact_check_rounded, 'attendance'),
              _reportCard('Fee Summary', 'Assigned fees, due dates, amounts and payment status.', Icons.payments_rounded, 'fees'),
              _reportCard('Exam Results', 'Obtained marks, grades and result remarks.', Icons.assessment_rounded, 'results'),
            ],
          ],
        ),
      ),
    );
  }

  Widget _header() => Row(
    children: [
      const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Reports Center', style: TextStyle(fontSize: 25, fontWeight: FontWeight.w900)),
        SizedBox(height: 4),
        Text('Real school data with PDF and Excel export.', style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
      ])),
      if (_exporting) const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2)),
    ],
  );

  Widget _summaryCards() {
    final pending = _fees.where((f) => '${f['status']}'.toLowerCase() != 'paid').length;
    final present = _attendance.where((a) => '${a['status']}'.toLowerCase() == 'present').length;
    return LayoutBuilder(builder: (context, c) {
      final columns = c.maxWidth >= 900 ? 4 : c.maxWidth >= 560 ? 2 : 1;
      final cards = [
        _stat('Students', '${_students.length}', Icons.people_alt_rounded),
        _stat('Attendance', '$present / ${_attendance.length}', Icons.fact_check_rounded),
        _stat('Fee Records', '${_fees.length}', Icons.receipt_long_rounded),
        _stat('Pending Fees', '$pending', Icons.pending_actions_rounded),
      ];
      if (columns == 1) return Column(children: cards.map((e) => Padding(padding: const EdgeInsets.only(bottom: 10), child: e)).toList());
      return GridView.count(crossAxisCount: columns, shrinkWrap: true, physics: const NeverScrollableScrollPhysics(), mainAxisSpacing: 10, crossAxisSpacing: 10, childAspectRatio: 2.6, children: cards);
    });
  }

  Widget _stat(String label, String value, IconData icon) => Card(child: Padding(padding: const EdgeInsets.all(16), child: Row(children: [Icon(icon, color: AppColors.primary), const SizedBox(width: 12), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(label, style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)), Text(value, style: const TextStyle(fontSize: 21, fontWeight: FontWeight.w900))]))])));

  Widget _reportCard(String title, String subtitle, IconData icon, String type) => Card(margin: const EdgeInsets.only(bottom: 12), child: Padding(padding: const EdgeInsets.all(16), child: LayoutBuilder(builder: (context, c) {
    final narrow = c.maxWidth < 620;
    final info = Row(children: [Container(width: 46, height: 46, decoration: BoxDecoration(color: AppColors.primary.withValues(alpha: .1), borderRadius: BorderRadius.circular(13)), child: Icon(icon, color: AppColors.primary)), const SizedBox(width: 12), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)), const SizedBox(height: 3), Text(subtitle, style: const TextStyle(color: AppColors.textSecondary, fontSize: 12))]))]);
    final actions = Wrap(spacing: 8, runSpacing: 8, children: [OutlinedButton.icon(onPressed: _exporting ? null : () => _export(type, excel: false), icon: const Icon(Icons.picture_as_pdf_outlined, size: 18), label: const Text('PDF')), OutlinedButton.icon(onPressed: _exporting ? null : () => _export(type, excel: true), icon: const Icon(Icons.table_view_outlined, size: 18), label: const Text('Excel'))]);
    return narrow ? Column(crossAxisAlignment: CrossAxisAlignment.start, children: [info, const SizedBox(height: 14), actions]) : Row(children: [Expanded(child: info), actions]);
  })));

  Widget _errorCard() => Card(child: Padding(padding: const EdgeInsets.all(20), child: Column(children: [const Icon(Icons.error_outline_rounded, size: 42, color: AppColors.error), const SizedBox(height: 10), Text(_error!, textAlign: TextAlign.center), const SizedBox(height: 12), FilledButton.icon(onPressed: _loadReports, icon: const Icon(Icons.refresh), label: const Text('Retry'))])));
}

extension _FirstOrNull<E> on Iterable<E> {
  E? get firstOrNull => isEmpty ? null : first;
}
