import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/network/supabase_client.dart';
import '../../../../core/widgets/main_wrapper.dart';

final graderDataProvider = FutureProvider.autoDispose<Map<String, dynamic>>((ref) async {
  final client = SupabaseConfig.client;
  final schoolId = await ref.watch(schoolIdProvider.future);
  if (schoolId == null) throw Exception('Your account is not linked to a school.');

  final exams = List<Map<String, dynamic>>.from(await client.from('exams').select('id,title,exam_date,status').eq('school_id', schoolId).order('exam_date', ascending: false));
  final examClasses = List<Map<String, dynamic>>.from(await client.from('exam_classes').select('exam_id,class_id,school_id').eq('school_id', schoolId));
  final examSubjects = List<Map<String, dynamic>>.from(await client.from('exam_subjects').select('id,exam_id,class_id,subject_id,total_marks,passing_marks').eq('school_id', schoolId));
  final subjects = List<Map<String, dynamic>>.from(await client.from('subjects').select('id,name,code').eq('school_id', schoolId).order('name'));
  final classes = List<Map<String, dynamic>>.from(await client.from('classes').select('id,name,section_name').eq('school_id', schoolId).order('name'));
  final students = List<Map<String, dynamic>>.from(await client.from('students').select('id,full_name,admission_number,class_name,section_name,is_active').eq('school_id', schoolId).eq('is_active', true).order('full_name'));
  final results = List<Map<String, dynamic>>.from(await client.from('exam_results').select('id,exam_id,exam_subject_id,student_id,obtained_marks,grade,remarks').eq('school_id', schoolId));
  return {'exams': exams, 'examClasses': examClasses, 'examSubjects': examSubjects, 'subjects': subjects, 'classes': classes, 'students': students, 'results': results, 'schoolId': schoolId};
});

class GraderScreen extends ConsumerStatefulWidget {
  const GraderScreen({super.key});
  @override
  ConsumerState<GraderScreen> createState() => _GraderScreenState();
}

class _GraderScreenState extends ConsumerState<GraderScreen> {
  int? examId;
  int? classId;
  int? examSubjectId;
  final Map<int, TextEditingController> marks = {};
  final Map<int, TextEditingController> remarks = {};
  bool saving = false;

  @override
  void dispose() {
    for (final c in marks.values) c.dispose();
    for (final c in remarks.values) c.dispose();
    super.dispose();
  }

  int _id(dynamic v) => v is num ? v.toInt() : int.tryParse('$v') ?? 0;
  String _name(Map<String, dynamic> s) => s['full_name']?.toString() ?? 'Student #${s['id']}';

  Map<String, dynamic>? _find(List<Map<String, dynamic>> rows, int id) {
    for (final r in rows) if (_id(r['id']) == id) return r;
    return null;
  }

  String _grade(double percentage) {
    if (percentage >= 90) return 'A+';
    if (percentage >= 80) return 'A';
    if (percentage >= 70) return 'B';
    if (percentage >= 60) return 'C';
    if (percentage >= 50) return 'D';
    return 'F';
  }

  List<Map<String, dynamic>> _students(Map<String, dynamic> d) {
    if (classId == null) return [];
    final classes = List<Map<String, dynamic>>.from(d['classes']);
    final selected = _find(classes, classId!);
    if (selected == null) return [];
    final className = selected['name']?.toString() ?? '';
    final section = selected['section_name']?.toString() ?? '';
    return List<Map<String, dynamic>>.from(d['students']).where((s) {
      return s['class_name']?.toString() == className && (section.isEmpty || s['section_name']?.toString() == section);
    }).toList();
  }

  void _prepare(Map<String, dynamic> d) {
    final students = _students(d);
    final results = List<Map<String, dynamic>>.from(d['results']);
    for (final s in students) {
      final sid = _id(s['id']);
      final existing = results.where((r) => _id(r['student_id']) == sid && _id(r['exam_subject_id']) == examSubjectId).firstOrNull;
      marks[sid] ??= TextEditingController(text: existing?['obtained_marks']?.toString() ?? '');
      remarks[sid] ??= TextEditingController(text: existing?['remarks']?.toString() ?? '');
    }
  }

  Future<void> _save(Map<String, dynamic> d) async {
    if (examSubjectId == null) return;
    final subject = _find(List<Map<String, dynamic>>.from(d['examSubjects']), examSubjectId!);
    if (subject == null) return;
    final total = (subject['total_marks'] as num?)?.toDouble() ?? 0;
    final passing = (subject['passing_marks'] as num?)?.toDouble() ?? 0;
    if (total <= 0) return;
    final students = _students(d);
    if (students.isEmpty) return;
    setState(() => saving = true);
    try {
      final client = SupabaseConfig.client;
      final schoolId = d['schoolId'];
      for (final s in students) {
        final sid = _id(s['id']);
        final raw = double.tryParse(marks[sid]?.text.trim() ?? '');
        if (raw == null) continue;
        if (raw < 0 || raw > total) throw Exception('${_name(s)}: marks must be between 0 and $total.');
        final pct = raw / total * 100;
        final grade = raw < passing ? 'F' : _grade(pct);
        final payload = {'school_id': schoolId, 'exam_id': examId, 'exam_subject_id': examSubjectId, 'student_id': sid, 'obtained_marks': raw, 'grade': grade, 'remarks': remarks[sid]?.text.trim().isEmpty == true ? null : remarks[sid]!.text.trim()};
        final existing = await client.from('exam_results').select('id').eq('school_id', schoolId).eq('exam_subject_id', examSubjectId!).eq('student_id', sid).maybeSingle();
        if (existing == null) {
          await client.from('exam_results').insert(payload);
        } else {
          await client.from('exam_results').update(payload).eq('id', existing['id']).eq('school_id', schoolId);
        }
      }
      ref.invalidate(graderDataProvider);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Marks saved successfully.')));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))));
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(graderDataProvider);
    return MainWrapper(child: async.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Column(mainAxisSize: MainAxisSize.min, children: [Text(e.toString()), const SizedBox(height: 12), FilledButton(onPressed: () => ref.invalidate(graderDataProvider), child: const Text('Retry'))])),
      data: (d) { _prepare(d); return _build(d); },
    ));
  }

  Widget _build(Map<String, dynamic> d) {
    final exams = List<Map<String, dynamic>>.from(d['exams']);
    final classes = List<Map<String, dynamic>>.from(d['classes']);
    final examSubjects = List<Map<String, dynamic>>.from(d['examSubjects']);
    final subjects = List<Map<String, dynamic>>.from(d['subjects']);
    final filteredSubjects = examSubjects.where((x) => examId != null && classId != null && _id(x['exam_id']) == examId && _id(x['class_id']) == classId).toList();
    final selectedSubject = _find(examSubjects, examSubjectId ?? 0);
    final total = (selectedSubject?['total_marks'] as num?)?.toDouble() ?? 0;
    final passing = (selectedSubject?['passing_marks'] as num?)?.toDouble() ?? 0;
    final students = _students(d);

    return LayoutBuilder(builder: (context, c) {
      final mobile = c.maxWidth < 700;
      return ListView(padding: EdgeInsets.all(mobile ? 16 : 28), children: [
        Row(children: [const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('Exam Grader', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900)), SizedBox(height: 5), Text('Enter, calculate and save student marks.', style: TextStyle(color: AppColors.textSecondary, fontSize: 13))])), if (!mobile) FilledButton.icon(onPressed: saving ? null : () => _save(d), icon: const Icon(Icons.save_rounded), label: const Text('Save Marks'))]),
        const SizedBox(height: 22),
        Card(child: Padding(padding: const EdgeInsets.all(18), child: Wrap(spacing: 14, runSpacing: 14, children: [
          SizedBox(width: mobile ? double.infinity : 230, child: DropdownButtonFormField<int>(value: examId, decoration: const InputDecoration(labelText: 'Examination'), items: exams.map((e) => DropdownMenuItem(value: _id(e['id']), child: Text(e['title']?.toString() ?? 'Exam'))).toList(), onChanged: (v) => setState(() { examId = v; classId = null; examSubjectId = null; }))),
          SizedBox(width: mobile ? double.infinity : 230, child: DropdownButtonFormField<int>(value: classId, decoration: const InputDecoration(labelText: 'Class / Section'), items: classes.where((c) => d['examClasses'].any((x) => _id(x['exam_id']) == examId && _id(x['class_id']) == _id(c['id']))).map((c) => DropdownMenuItem(value: _id(c['id']), child: Text('${c['name']} ${c['section_name'] ?? ''}'))).toList(), onChanged: (v) => setState(() { classId = v; examSubjectId = null; }))),
          SizedBox(width: mobile ? double.infinity : 230, child: DropdownButtonFormField<int>(value: examSubjectId, decoration: const InputDecoration(labelText: 'Subject'), items: filteredSubjects.map((x) { final s = _find(subjects, _id(x['subject_id'])); return DropdownMenuItem(value: _id(x['id']), child: Text(s?['name']?.toString() ?? 'Subject')); }).toList(), onChanged: (v) => setState(() { examSubjectId = v; }))),
        ]))),
        if (examSubjectId != null) ...[
          const SizedBox(height: 18),
          Card(child: Padding(padding: const EdgeInsets.all(16), child: Wrap(spacing: 24, runSpacing: 10, children: [Text('Total Marks: ${total.toStringAsFixed(0)}'), Text('Passing Marks: ${passing.toStringAsFixed(0)}'), Text('Students: ${students.length}')]))),
          const SizedBox(height: 12),
          Card(child: SingleChildScrollView(scrollDirection: Axis.horizontal, child: DataTable(columns: const [DataColumn(label: Text('#')), DataColumn(label: Text('Student')), DataColumn(label: Text('Admission No.')), DataColumn(label: Text('Obtained Marks')), DataColumn(label: Text('Grade')), DataColumn(label: Text('Remarks'))], rows: students.asMap().entries.map((entry) { final i = entry.key + 1; final s = entry.value; final sid = _id(s['id']); final controller = marks[sid]!; final value = double.tryParse(controller.text); final grade = value == null || total <= 0 ? '—' : (value < passing ? 'F' : _grade(value / total * 100)); return DataRow(cells: [DataCell(Text('$i')), DataCell(Text(_name(s), style: const TextStyle(fontWeight: FontWeight.w700))), DataCell(Text(s['admission_number']?.toString() ?? '—')), DataCell(SizedBox(width: 130, child: TextField(controller: controller, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: InputDecoration(hintText: '0 - ${total.toStringAsFixed(0)}'), onChanged: (_) => setState(() {})))), DataCell(Text(grade, style: TextStyle(fontWeight: FontWeight.w800, color: grade == 'F' ? AppColors.error : AppColors.success))), DataCell(SizedBox(width: 220, child: TextField(controller: remarks[sid], decoration: const InputDecoration(hintText: 'Optional'))))]); }).toList())),
          ),
          const SizedBox(height: 16),
          Align(alignment: Alignment.centerRight, child: FilledButton.icon(onPressed: saving ? null : () => _save(d), icon: saving ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.save_rounded), label: Text(saving ? 'Saving...' : 'Save All Marks'))),
        ] else const Padding(padding: EdgeInsets.all(50), child: Center(child: Text('Select examination, class and subject to start grading.'))),
      ]);
    });
  }
}
