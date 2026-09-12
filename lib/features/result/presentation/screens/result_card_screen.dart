import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/network/supabase_client.dart';
import '../../../../core/widgets/hadi_design_system.dart';
import '../../../../core/widgets/main_wrapper.dart';

final resultCardExamsProvider = FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final c = SupabaseConfig.client;
  final sid = await ref.watch(schoolIdProvider.future);
  if (sid == null) return [];
  return List<Map<String, dynamic>>.from(await c.from('exams').select('*').eq('school_id', sid).order('exam_date', ascending: false));
});

final resultCardStudentsProvider = FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final c = SupabaseConfig.client;
  final sid = await ref.watch(schoolIdProvider.future);
  if (sid == null) return [];
  return List<Map<String, dynamic>>.from(await c.from('students').select('id,full_name,admission_number,class_name,section_name').eq('school_id', sid).eq('is_active', true).order('full_name'));
});

final resultCardDataProvider = FutureProvider.autoDispose.family<Map<String, dynamic>, String>((ref, key) async {
  final parts = key.split(':');
  if (parts.length != 2) throw Exception('Invalid result card selection.');
  final examId = int.tryParse(parts[0]);
  final studentId = int.tryParse(parts[1]);
  if (examId == null || studentId == null) throw Exception('Invalid result card selection.');

  final c = SupabaseConfig.client;
  final sid = await ref.watch(schoolIdProvider.future);
  if (sid == null) throw Exception('School not linked.');

  final results = List<Map<String, dynamic>>.from(await c.from('exam_results').select('*').eq('school_id', sid).eq('exam_id', examId));
  final examSubjects = List<Map<String, dynamic>>.from(await c.from('exam_subjects').select('*').eq('school_id', sid).eq('exam_id', examId));
  final subjectRows = List<Map<String, dynamic>>.from(await c.from('subjects').select('*').eq('school_id', sid));
  final students = List<Map<String, dynamic>>.from(await c.from('students').select('id,full_name,admission_number,class_name,section_name').eq('school_id', sid).eq('is_active', true));
  final exams = List<Map<String, dynamic>>.from(await c.from('exams').select('*').eq('school_id', sid).eq('id', examId));

  final st = students.where((x) => (x['id'] as num?)?.toInt() == studentId).firstOrNull;
  if (st == null) throw Exception('Student not found.');
  final exam = exams.firstOrNull ?? <String, dynamic>{};

  double obtained(Map<String, dynamic> r) => (r['obtained_marks'] as num?)?.toDouble() ?? 0;
  double studentTotal(int id) => results.where((r) => (r['student_id'] as num?)?.toInt() == id).fold(0.0, (a, r) => a + obtained(r));

  final mine = results.where((r) => (r['student_id'] as num?)?.toInt() == studentId).toList();
  final className = (st['class_name'] ?? '').toString();
  final section = (st['section_name'] ?? '').toString();
  final classmates = students.where((s) => (s['class_name'] ?? '').toString() == className && (s['section_name'] ?? '').toString() == section).toList();
  final scores = classmates.map((s) => studentTotal((s['id'] as num).toInt())).where((x) => x > 0).toList()..sort((a, b) => b.compareTo(a));

  final total = examSubjects.fold<double>(0, (a, s) => a + ((s['total_marks'] as num?)?.toDouble() ?? 0));
  final got = mine.fold<double>(0, (a, r) => a + obtained(r));
  final pct = total > 0 ? got / total * 100 : 0;

  String grade(double p) => p >= 90 ? 'A+' : p >= 80 ? 'A' : p >= 70 ? 'B' : p >= 60 ? 'C' : p >= 50 ? 'D' : 'F';

  final rows = mine.map((r) {
    final es = examSubjects.where((x) => (x['id'] as num?)?.toInt() == (r['exam_subject_id'] as num?)?.toInt()).firstOrNull ?? <String, dynamic>{};
    final sj = subjectRows.where((x) => (x['id'] as num?)?.toInt() == (es['subject_id'] as num?)?.toInt()).firstOrNull ?? <String, dynamic>{};
    final tm = (es['total_marks'] as num?)?.toDouble() ?? 0;
    final op = obtained(r);
    return <String, dynamic>{
      'subject': sj['name'] ?? 'Subject',
      'obtained': op,
      'total': tm,
      'grade': r['grade'] ?? grade(tm > 0 ? op / tm * 100 : 0),
      'remarks': r['remarks'] ?? '',
    };
  }).toList();

  return {'student': st, 'exam': exam, 'rows': rows, 'obtained': got, 'total': total, 'percentage': pct, 'grade': grade(pct), 'position': got > 0 ? scores.indexOf(got) + 1 : 0, 'className': className, 'section': section};
});

class ResultCardScreen extends ConsumerStatefulWidget {
  const ResultCardScreen({super.key});
  @override
  ConsumerState<ResultCardScreen> createState() => _ResultCardScreenState();
}

class _ResultCardScreenState extends ConsumerState<ResultCardScreen> {
  int? examId;
  int? studentId;

  @override
  Widget build(BuildContext context) {
    final exams = ref.watch(resultCardExamsProvider);
    final students = ref.watch(resultCardStudentsProvider);
    return MainWrapper(
      child: exams.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => _errorState(context, e),
        data: (examList) => students.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => _errorState(context, e),
          data: (studentList) => _body(context, examList, studentList),
        ),
      ),
    );
  }

  Widget _body(BuildContext context, List<Map<String, dynamic>> exams, List<Map<String, dynamic>> students) {
    final width = MediaQuery.sizeOf(context).width;
    final compact = width < 700;
    return ListView(
      padding: EdgeInsets.all(compact ? 14 : 22),
      children: [
        Row(children: [
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: const [Text('Result Card', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900)), SizedBox(height: 5), Text('Generate, preview and print the final student result card.', style: TextStyle(color: AppColors.textSecondary))])),
          if (!compact && examId != null && studentId != null) OutlinedButton.icon(onPressed: () => _printCurrent(context), icon: const Icon(Icons.print_rounded), label: const Text('Print')),
        ]),
        const SizedBox(height: 20),
        HadiGlassCard(
          padding: EdgeInsets.all(compact ? 14 : 18),
          child: Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              SizedBox(width: compact ? double.infinity : 300, child: DropdownButtonFormField<int>(
                value: examId,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Examination'),
                items: exams.map((e) => DropdownMenuItem<int>(value: (e['id'] as num).toInt(), child: Text((e['title'] ?? 'Examination').toString(), overflow: TextOverflow.ellipsis))).toList(),
                onChanged: (v) => setState(() { examId = v; studentId = null; }),
              )),
              SizedBox(width: compact ? double.infinity : 300, child: DropdownButtonFormField<int>(
                value: studentId,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Student'),
                items: students.map((s) => DropdownMenuItem<int>(value: (s['id'] as num).toInt(), child: Text((s['full_name'] ?? 'Student').toString(), overflow: TextOverflow.ellipsis))).toList(),
                onChanged: (v) => setState(() => studentId = v),
              )),
            ],
          ),
        ),
        const SizedBox(height: 18),
        if (examId != null && studentId != null)
          ref.watch(resultCardDataProvider('$examId:$studentId')).when(
            loading: () => const Padding(padding: EdgeInsets.all(48), child: Center(child: CircularProgressIndicator())),
            error: (e, _) => _errorState(context, e),
            data: (data) => _result(context, data),
          ),
      ],
    );
  }

  Widget _result(BuildContext context, Map<String, dynamic> data) {
    final st = data['student'] as Map<String, dynamic>;
    final rows = List<Map<String, dynamic>>.from(data['rows']);
    final pct = (data['percentage'] as num).toDouble();
    final grade = data['grade'].toString();
    return HadiGlassCard(
      tint: Theme.of(context).colorScheme.surface,
      padding: const EdgeInsets.all(24),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Center(child: Column(children: [
          const HadiStatusBadge(label: 'OFFICIAL RESULT', color: AppColors.moduleExams),
          const SizedBox(height: 10),
          Text('RESULT CARD', style: TextStyle(fontSize: 26, fontWeight: FontWeight.w900, color: AppColors.moduleExams)),
          Text('${data['exam']['title'] ?? 'Examination'}', style: const TextStyle(color: AppColors.textSecondary, fontWeight: FontWeight.w700)),
        ])),
        const SizedBox(height: 22),
        Wrap(spacing: 24, runSpacing: 8, children: [Text('Student: ${st['full_name'] ?? '—'}', style: const TextStyle(fontWeight: FontWeight.w700)), Text('Admission: ${st['admission_number'] ?? '—'}'), Text('Class: ${data['className']} ${data['section']}'.trim()), Text('Position: ${data['position'] > 0 ? data['position'] : '—'}')]),
        const SizedBox(height: 18),
        LayoutBuilder(builder: (context, constraints) {
          if (constraints.maxWidth < 620) {
            return SingleChildScrollView(scrollDirection: Axis.horizontal, child: ConstrainedBox(constraints: const BoxConstraints(minWidth: 620), child: _resultTable(rows)));
          }
          return _resultTable(rows);
        }),
        const SizedBox(height: 20),
        Wrap(spacing: 12, runSpacing: 12, children: [
          _summaryTile('Obtained', '${data['obtained']} / ${data['total']}', AppColors.moduleExams),
          _summaryTile('Percentage', '${pct.toStringAsFixed(2)}%', AppColors.moduleStudents),
          _summaryTile('Grade', grade, AppColors.accent),
        ]),
        const SizedBox(height: 22),
        Align(alignment: Alignment.centerRight, child: FilledButton.icon(onPressed: () => _print(data), icon: const Icon(Icons.picture_as_pdf_rounded), label: const Text('Export / Print PDF'))),
      ]),
    );
  }

  Widget _resultTable(List<Map<String, dynamic>> rows) {
    return Table(
      border: TableBorder.all(color: AppColors.border),
      columnWidths: const {0: FlexColumnWidth(3), 1: FlexColumnWidth(1.2), 2: FlexColumnWidth(1.2), 3: FlexColumnWidth(1)},
      children: [
        _tableRow(const ['Subject', 'Obtained', 'Total', 'Grade'], header: true),
        ...rows.map((r) => _tableRow([r['subject'].toString(), r['obtained'].toString(), r['total'].toString(), r['grade'].toString()])),
      ],
    );
  }

  TableRow _tableRow(List<String> values, {bool header = false}) => TableRow(children: values.map((v) => Padding(padding: const EdgeInsets.all(10), child: Text(v, style: TextStyle(fontWeight: header ? FontWeight.w900 : FontWeight.w600)))).toList());

  Widget _summaryTile(String title, String value, Color color) => Container(width: 170, padding: const EdgeInsets.all(15), decoration: BoxDecoration(color: color.withValues(alpha: .08), borderRadius: BorderRadius.circular(16), border: Border.all(color: color.withValues(alpha: .18))), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: const TextStyle(color: AppColors.textSecondary, fontSize: 11, fontWeight: FontWeight.w700)), const SizedBox(height: 5), Text(value, style: TextStyle(color: color, fontSize: 18, fontWeight: FontWeight.w900))]));

  Widget _errorState(BuildContext context, Object error) => Center(child: HadiGlassCard(padding: const EdgeInsets.all(24), child: Column(mainAxisSize: MainAxisSize.min, children: [const Icon(Icons.error_outline_rounded, color: AppColors.error, size: 34), const SizedBox(height: 10), Text('Could not load result card', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)), const SizedBox(height: 6), Text(error.toString(), textAlign: TextAlign.center, style: const TextStyle(color: AppColors.textSecondary)), const SizedBox(height: 12), OutlinedButton.icon(onPressed: () { ref.invalidate(resultCardExamsProvider); ref.invalidate(resultCardStudentsProvider); }, icon: const Icon(Icons.refresh_rounded), label: const Text('Retry'))])));

  Future<void> _printCurrent(BuildContext context) async {
    if (examId == null || studentId == null) return;
    final data = await ref.read(resultCardDataProvider('$examId:$studentId').future);
    if (context.mounted) await _print(data);
  }

  Future<void> _print(Map<String, dynamic> data) async {
    final doc = pw.Document();
    final st = data['student'] as Map<String, dynamic>;
    final rows = List<Map<String, dynamic>>.from(data['rows']);
    final branding = await _branding();
    final logoBytes = branding['logo'] as Uint8List?;
    final schoolName = branding['name'].toString();

    doc.addPage(pw.Page(pageFormat: PdfPageFormat.a4, build: (_) => pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
      if (logoBytes != null) pw.Center(child: pw.Image(pw.MemoryImage(logoBytes), width: 54, height: 54)),
      pw.Center(child: pw.Text(schoolName, style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold))),
      pw.SizedBox(height: 5),
      pw.Center(child: pw.Text('RESULT CARD', style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold))),
      pw.Center(child: pw.Text('${data['exam']['title'] ?? 'Examination'}')),
      pw.SizedBox(height: 18),
      pw.Text('Student: ${st['full_name'] ?? '—'}'), pw.Text('Admission: ${st['admission_number'] ?? '—'}'), pw.Text('Class: ${data['className']} ${data['section']}'), pw.Text('Position: ${data['position'] > 0 ? data['position'] : '—'}'),
      pw.SizedBox(height: 15),
      pw.Table.fromTextArray(headers: ['Subject', 'Obtained', 'Total', 'Grade'], data: rows.map((r) => [r['subject'].toString(), r['obtained'].toString(), r['total'].toString(), r['grade'].toString()]).toList()),
      pw.SizedBox(height: 15),
      pw.Text('Total: ${data['obtained']} / ${data['total']}'), pw.Text('Percentage: ${(data['percentage'] as num).toStringAsFixed(2)}%'), pw.Text('Overall Grade: ${data['grade']}'),
    ])));

    final bytes = Uint8List.fromList(await doc.save());
    await Printing.layoutPdf(onLayout: (_) async => bytes);
  }

  Future<Map<String, dynamic>> _branding() async {
    final sid = await ref.read(schoolIdProvider.future);
    if (sid == null) return {'name': 'HADI SMS', 'logo': null};
    final row = await SupabaseConfig.client.from('schools').select('school_name,logo_url').eq('id', sid).maybeSingle();
    Uint8List? bytes;
    final logoUrl = row?['logo_url']?.toString();
    if (logoUrl != null && logoUrl.isNotEmpty) {
      try {
        final request = await NetworkAssetBundle(Uri.parse(logoUrl)).load(logoUrl);
        bytes = request.buffer.asUint8List();
      } catch (_) {}
    }
    return {'name': (row?['school_name']?.toString().trim().isEmpty ?? true) ? 'HADI SMS' : row!['school_name'].toString(), 'logo': bytes};
  }
}
