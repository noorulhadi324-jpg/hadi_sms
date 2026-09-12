import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/network/supabase_client.dart';
import '../../../../core/widgets/main_wrapper.dart';

/// ===============================================================
/// RESULT CARD - EXAMS
/// ===============================================================

final resultCardExamsProvider =
FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final client = SupabaseConfig.client;

  final schoolId = await ref.watch(
    schoolIdProvider.future,
  );

  if (schoolId == null) {
    return [];
  }

  final response = await client
      .from('exams')
      .select('*')
      .eq('school_id', schoolId)
      .order(
    'exam_date',
    ascending: false,
  );

  return List<Map<String, dynamic>>.from(response);
});

/// ===============================================================
/// RESULT CARD - STUDENTS
/// ===============================================================

final resultCardStudentsProvider =
FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final client = SupabaseConfig.client;

  final schoolId = await ref.watch(
    schoolIdProvider.future,
  );

  if (schoolId == null) {
    return [];
  }

  final response = await client
      .from('students')
      .select(
    'id,full_name,admission_number,class_name,section_name',
  )
      .eq(
    'school_id',
    schoolId,
  )
      .eq(
    'is_active',
    true,
  )
      .order(
    'full_name',
  );

  return List<Map<String, dynamic>>.from(response);
});

/// ===============================================================
/// RESULT CARD DATA
/// ===============================================================

final resultCardDataProvider =
FutureProvider.autoDispose.family<
    Map<String, dynamic>,
    String>((ref, key) async {
  final parts = key.split(':');

  if (parts.length != 2) {
    throw Exception(
      'Invalid result card selection.',
    );
  }

  final examId = int.tryParse(parts[0]);
  final studentId = int.tryParse(parts[1]);

  if (examId == null || studentId == null) {
    throw Exception(
      'Invalid examination or student.',
    );
  }

  final client = SupabaseConfig.client;

  final schoolId = await ref.watch(
    schoolIdProvider.future,
  );

  if (schoolId == null) {
    throw Exception(
      'School not linked.',
    );
  }

  /// -------------------------------------------------------------
  /// STUDENTS
  /// -------------------------------------------------------------

  final studentsResponse = await client
      .from('students')
      .select('*')
      .eq(
    'school_id',
    schoolId,
  );

  final students =
  List<Map<String, dynamic>>.from(
    studentsResponse,
  );

  Map<String, dynamic>? student;

  for (final row in students) {
    final id = _toInt(row['id']);

    if (id == studentId) {
      student = row;
      break;
    }
  }

  if (student == null) {
    throw Exception(
      'Student record not found.',
    );
  }

  /// -------------------------------------------------------------
  /// EXAM
  /// -------------------------------------------------------------

  final examResponse = await client
      .from('exams')
      .select('*')
      .eq(
    'school_id',
    schoolId,
  )
      .eq(
    'id',
    examId,
  );

  final exams =
  List<Map<String, dynamic>>.from(
    examResponse,
  );

  if (exams.isEmpty) {
    throw Exception(
      'Examination not found.',
    );
  }

  final exam = exams.first;

  /// -------------------------------------------------------------
  /// EXAM RESULTS
  /// -------------------------------------------------------------

  final resultsResponse = await client
      .from('exam_results')
      .select('*')
      .eq(
    'school_id',
    schoolId,
  )
      .eq(
    'exam_id',
    examId,
  );

  final results =
  List<Map<String, dynamic>>.from(
    resultsResponse,
  );

  /// -------------------------------------------------------------
  /// EXAM SUBJECTS
  /// -------------------------------------------------------------

  final examSubjectsResponse = await client
      .from('exam_subjects')
      .select('*')
      .eq(
    'school_id',
    schoolId,
  )
      .eq(
    'exam_id',
    examId,
  );

  final examSubjects =
  List<Map<String, dynamic>>.from(
    examSubjectsResponse,
  );

  /// -------------------------------------------------------------
  /// SUBJECTS
  /// -------------------------------------------------------------

  final subjectsResponse = await client
      .from('subjects')
      .select('*')
      .eq(
    'school_id',
    schoolId,
  );

  final subjects =
  List<Map<String, dynamic>>.from(
    subjectsResponse,
  );

  /// -------------------------------------------------------------
  /// HELPER
  /// -------------------------------------------------------------

  double obtainedMarks(
      Map<String, dynamic> result,
      ) {
    final value = result['obtained_marks'];

    if (value is num) {
      return value.toDouble();
    }

    return double.tryParse(
      value?.toString() ?? '',
    ) ??
        0;
  }

  int? studentIdFrom(
      Map<String, dynamic> row,
      ) {
    return _toInt(
      row['student_id'],
    );
  }

  /// -------------------------------------------------------------
  /// STUDENT RESULTS
  /// -------------------------------------------------------------

  final myResults = results.where(
        (result) {
      return studentIdFrom(result) ==
          studentId;
    },
  ).toList();

  /// -------------------------------------------------------------
  /// CLASS / SECTION
  /// -------------------------------------------------------------

  final className =
  (student['class_name'] ?? '')
      .toString();

  final sectionName =
  (student['section_name'] ?? '')
      .toString();

  /// -------------------------------------------------------------
  /// CLASSMATES
  /// -------------------------------------------------------------

  final classmates = students.where(
        (row) {
      final rowClass =
      (row['class_name'] ?? '')
          .toString();

      final rowSection =
      (row['section_name'] ?? '')
          .toString();

      return rowClass == className &&
          rowSection == sectionName;
    },
  ).toList();

  /// -------------------------------------------------------------
  /// STUDENT TOTAL
  /// -------------------------------------------------------------

  double studentTotal(
      int id,
      ) {
    return results
        .where(
          (result) =>
      studentIdFrom(result) == id,
    )
        .fold(
      0.0,
          (
          total,
          result,
          ) =>
      total +
          obtainedMarks(result),
    );
  }

  /// -------------------------------------------------------------
  /// CLASS SCORES
  /// -------------------------------------------------------------

  final scores = classmates
      .map(
        (row) {
      final id = _toInt(
        row['id'],
      );

      if (id == null) {
        return 0.0;
      }

      return studentTotal(id);
    },
  )
      .where(
        (score) => score > 0,
  )
      .toList()
    ..sort(
          (a, b) => b.compareTo(a),
    );

  /// -------------------------------------------------------------
  /// TOTAL EXAM MARKS
  /// -------------------------------------------------------------

  double totalMarks = 0;

  for (final subject in examSubjects) {
    final marks = subject['total_marks'];

    if (marks is num) {
      totalMarks += marks.toDouble();
    } else {
      totalMarks +=
          double.tryParse(
            marks?.toString() ?? '',
          ) ??
              0;
    }
  }

  /// -------------------------------------------------------------
  /// OBTAINED MARKS
  /// -------------------------------------------------------------

  double obtained = 0;

  for (final result in myResults) {
    obtained += obtainedMarks(
      result,
    );
  }

  /// -------------------------------------------------------------
  /// PERCENTAGE
  /// -------------------------------------------------------------

  final percentage = totalMarks > 0
      ? (obtained / totalMarks) * 100
      : 0.0;

  /// -------------------------------------------------------------
  /// GRADE
  /// -------------------------------------------------------------

  String calculateGrade(
      double value,
      ) {
    if (value >= 90) {
      return 'A+';
    }

    if (value >= 80) {
      return 'A';
    }

    if (value >= 70) {
      return 'B';
    }

    if (value >= 60) {
      return 'C';
    }

    if (value >= 50) {
      return 'D';
    }

    return 'F';
  }

  /// -------------------------------------------------------------
  /// POSITION
  /// -------------------------------------------------------------

  int position = 0;

  if (obtained > 0) {
    final index =
    scores.indexOf(obtained);

    if (index >= 0) {
      position = index + 1;
    }
  }

  /// -------------------------------------------------------------
  /// SUBJECT RESULT ROWS
  /// -------------------------------------------------------------

  final rows =
  <Map<String, dynamic>>[];

  for (final result in myResults) {
    final examSubjectId =
    _toInt(
      result['exam_subject_id'],
    );

    if (examSubjectId == null) {
      continue;
    }

    Map<String, dynamic>? examSubject;

    for (final row in examSubjects) {
      if (_toInt(row['id']) ==
          examSubjectId) {
        examSubject = row;
        break;
      }
    }

    if (examSubject == null) {
      continue;
    }

    final subjectId =
    _toInt(
      examSubject['subject_id'],
    );

    Map<String, dynamic>? subject;

    for (final row in subjects) {
      if (_toInt(row['id']) ==
          subjectId) {
        subject = row;
        break;
      }
    }

    final total =
    _toDouble(
      examSubject['total_marks'],
    );

    final subjectObtained =
    obtainedMarks(result);

    final calculatedPercentage =
    total > 0
        ? (subjectObtained /
        total) *
        100
        : 0.0;

    final savedGrade =
    result['grade']
        ?.toString()
        .trim();

    final grade =
    savedGrade != null &&
        savedGrade.isNotEmpty
        ? savedGrade
        : calculateGrade(
      calculatedPercentage,
    );

    rows.add(
      {
        'subject':
        subject?['name'] ??
            'Subject',
        'obtained':
        subjectObtained,
        'total':
        total,
        'grade':
        grade,
        'remarks':
        result['remarks'] ??
            '',
      },
    );
  }

  /// Sort subjects alphabetically.
  rows.sort(
        (a, b) => a['subject']
        .toString()
        .compareTo(
      b['subject'].toString(),
    ),
  );

  return {
    'student': student,
    'exam': exam,
    'rows': rows,
    'obtained': obtained,
    'total': totalMarks,
    'percentage': percentage,
    'grade': calculateGrade(
      percentage,
    ),
    'position': position,
    'className': className,
    'section': sectionName,
  };
});

/// ===============================================================
/// HELPERS
/// ===============================================================

int? _toInt(
    dynamic value,
    ) {
  if (value == null) {
    return null;
  }

  if (value is int) {
    return value;
  }

  if (value is num) {
    return value.toInt();
  }

  return int.tryParse(
    value.toString(),
  );
}

double _toDouble(
    dynamic value,
    ) {
  if (value == null) {
    return 0;
  }

  if (value is num) {
    return value.toDouble();
  }

  return double.tryParse(
    value.toString(),
  ) ??
      0;
}

/// ===============================================================
/// RESULT CARD SCREEN
/// ===============================================================

class ResultCardScreen
    extends ConsumerStatefulWidget {
  const ResultCardScreen({
    super.key,
  });

  @override
  ConsumerState<ResultCardScreen>
  createState() =>
      _ResultCardScreenState();
}

class _ResultCardScreenState
    extends ConsumerState<ResultCardScreen> {
  int? examId;
  int? studentId;

  @override
  Widget build(
      BuildContext context,
      ) {
    final exams =
    ref.watch(
      resultCardExamsProvider,
    );

    final students =
    ref.watch(
      resultCardStudentsProvider,
    );

    return MainWrapper(
      child: exams.when(
        loading: () => const Center(
          child:
          CircularProgressIndicator(),
        ),
        error: (
            error,
            stack,
            ) =>
            _ErrorView(
              message: error.toString(),
              onRetry: () {
                ref.invalidate(
                  resultCardExamsProvider,
                );
              },
            ),
        data: (examList) =>
            students.when(
              loading: () => const Center(
                child:
                CircularProgressIndicator(),
              ),
              error: (
                  error,
                  stack,
                  ) =>
                  _ErrorView(
                    message: error.toString(),
                    onRetry: () {
                      ref.invalidate(
                        resultCardStudentsProvider,
                      );
                    },
                  ),
              data: (studentList) =>
                  _buildBody(
                    context,
                    examList,
                    studentList,
                  ),
            ),
      ),
    );
  }

  /// =============================================================
  /// BODY
  /// =============================================================

  Widget _buildBody(
      BuildContext context,
      List<Map<String, dynamic>> exams,
      List<Map<String, dynamic>> students,
      ) {
    return ListView(
      padding: const EdgeInsets.all(
        22,
      ),
      children: [
        const Text(
          'Result Card',
          style: TextStyle(
            fontSize: 28,
            fontWeight:
            FontWeight.w900,
          ),
        ),

        const SizedBox(
          height: 5,
        ),

        const Text(
          'Generate, preview and print the final student result card.',
        ),

        const SizedBox(
          height: 22,
        ),

        Card(
          child: Padding(
            padding:
            const EdgeInsets.all(
              18,
            ),
            child: Wrap(
              spacing: 14,
              runSpacing: 14,
              children: [
                SizedBox(
                  width: 320,
                  child:
                  DropdownButtonFormField<
                      int>(
                    value: examId,
                    decoration:
                    const InputDecoration(
                      labelText:
                      'Examination',
                      border:
                      OutlineInputBorder(),
                      prefixIcon:
                      Icon(
                        Icons
                            .assignment_rounded,
                      ),
                    ),
                    items: exams.map(
                          (
                          exam,
                          ) {
                        final id =
                        _toInt(
                          exam['id'],
                        );

                        return DropdownMenuItem<
                            int>(
                          value: id,
                          child: Text(
                            exam['title']
                                ?.toString() ??
                                'Examination',
                          ),
                        );
                      },
                    ).toList(),
                    onChanged: (
                        value,
                        ) {
                      setState(
                            () {
                          examId =
                              value;

                          /// New exam means
                          /// reset student.
                          studentId =
                          null;
                        },
                      );
                    },
                  ),
                ),

                SizedBox(
                  width: 320,
                  child:
                  DropdownButtonFormField<
                      int>(
                    value: studentId,
                    decoration:
                    const InputDecoration(
                      labelText:
                      'Student',
                      border:
                      OutlineInputBorder(),
                      prefixIcon:
                      Icon(
                        Icons
                            .person_rounded,
                      ),
                    ),
                    items: students.map(
                          (
                          student,
                          ) {
                        final id =
                        _toInt(
                          student['id'],
                        );

                        return DropdownMenuItem<
                            int>(
                          value: id,
                          child: Text(
                            student['full_name']
                                ?.toString() ??
                                'Student',
                          ),
                        );
                      },
                    ).toList(),
                    onChanged: (
                        value,
                        ) {
                      setState(
                            () {
                          studentId =
                              value;
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),

        const SizedBox(
          height: 22,
        ),

        if (examId != null &&
            studentId != null)
          ref.watch(
            resultCardDataProvider(
              '$examId:$studentId',
            ),
          ).when(
            loading: () =>
            const Center(
              child:
              Padding(
                padding:
                EdgeInsets.all(
                  30,
                ),
                child:
                CircularProgressIndicator(),
              ),
            ),
            error: (
                error,
                stack,
                ) =>
                _ErrorView(
                  message:
                  error.toString(),
                  onRetry: () {
                    ref.invalidate(
                      resultCardDataProvider(
                        '$examId:$studentId',
                      ),
                    );
                  },
                ),
            data: (
                data,
                ) =>
                _buildResultCard(
                  context,
                  data,
                ),
          ),
      ],
    );
  }

  /// =============================================================
  /// RESULT CARD PREVIEW
  /// =============================================================

  Widget _buildResultCard(
      BuildContext context,
      Map<String, dynamic> data,
      ) {
    final student =
    data['student']
    as Map<String, dynamic>;

    final exam =
    data['exam']
    as Map<String, dynamic>;

    final rows =
    List<Map<String, dynamic>>.from(
      data['rows'] as List,
    );

    final percentage =
    _toDouble(
      data['percentage'],
    );

    final position =
        _toInt(
          data['position'],
        ) ??
            0;

    return Card(
      elevation: 2,
      child: Padding(
        padding:
        const EdgeInsets.all(
          24,
        ),
        child: Column(
          crossAxisAlignment:
          CrossAxisAlignment.start,
          children: [
            /// HEADER
            Center(
              child: Column(
                children: [
                  const Text(
                    'RESULT CARD',
                    style: TextStyle(
                      fontSize: 26,
                      fontWeight:
                      FontWeight.w900,
                      color:
                      AppColors.primary,
                    ),
                  ),
                  const SizedBox(
                    height: 5,
                  ),
                  Text(
                    exam['title']
                        ?.toString() ??
                        'Examination',
                    style:
                    const TextStyle(
                      fontSize: 17,
                      fontWeight:
                      FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),

            const Divider(
              height: 32,
            ),

            /// STUDENT INFO
            Wrap(
              spacing: 30,
              runSpacing: 12,
              children: [
                _infoItem(
                  'Student',
                  student['full_name']
                      ?.toString() ??
                      '—',
                ),
                _infoItem(
                  'Admission No.',
                  student[
                  'admission_number']
                      ?.toString() ??
                      '—',
                ),
                _infoItem(
                  'Class',
                  '${data['className'] ?? '—'} ${data['section'] ?? ''}'
                      .trim(),
                ),
                _infoItem(
                  'Position',
                  position > 0
                      ? position
                      .toString()
                      : '—',
                ),
              ],
            ),

            const SizedBox(
              height: 24,
            ),

            /// SUBJECT TABLE
            if (rows.isEmpty)
              Container(
                width:
                double.infinity,
                padding:
                const EdgeInsets.all(
                  18,
                ),
                decoration:
                BoxDecoration(
                  border:
                  Border.all(
                    color:
                    Colors.grey,
                  ),
                  borderRadius:
                  BorderRadius
                      .circular(
                    8,
                  ),
                ),
                child: const Text(
                  'No marks have been entered for this student yet.',
                ),
              )
            else
              SingleChildScrollView(
                scrollDirection:
                Axis.horizontal,
                child: Table(
                  defaultColumnWidth:
                  const IntrinsicColumnWidth(),
                  border:
                  TableBorder.all(
                    color:
                    Colors.grey,
                  ),
                  children: [
                    const TableRow(
                      children: [
                        _TableHeader(
                          'Subject',
                        ),
                        _TableHeader(
                          'Obtained',
                        ),
                        _TableHeader(
                          'Total',
                        ),
                        _TableHeader(
                          'Grade',
                        ),
                      ],
                    ),
                    ...rows.map(
                          (
                          row,
                          ) =>
                          TableRow(
                            children: [
                              _TableCell(
                                row['subject']
                                    ?.toString() ??
                                    'Subject',
                              ),
                              _TableCell(
                                _formatNumber(
                                  row[
                                  'obtained'],
                                ),
                              ),
                              _TableCell(
                                _formatNumber(
                                  row['total'],
                                ),
                              ),
                              _TableCell(
                                row['grade']
                                    ?.toString() ??
                                    '—',
                              ),
                            ],
                          ),
                    ),
                  ],
                ),
              ),

            const SizedBox(
              height: 24,
            ),

            /// SUMMARY
            Wrap(
              spacing: 18,
              runSpacing: 12,
              children: [
                _summaryBox(
                  'Total Marks',
                  '${_formatNumber(data['obtained'])} / ${_formatNumber(data['total'])}',
                ),
                _summaryBox(
                  'Percentage',
                  '${percentage.toStringAsFixed(2)}%',
                ),
                _summaryBox(
                  'Overall Grade',
                  data['grade']
                      ?.toString() ??
                      '—',
                ),
                _summaryBox(
                  'Position',
                  position > 0
                      ? position
                      .toString()
                      : '—',
                ),
              ],
            ),

            const SizedBox(
              height: 24,
            ),

            /// PDF BUTTON
            Align(
              alignment:
              Alignment.centerRight,
              child:
              FilledButton.icon(
                onPressed: () =>
                    _printResultCard(
                      data,
                    ),
                icon: const Icon(
                  Icons
                      .picture_as_pdf_rounded,
                ),
                label: const Text(
                  'Export / Print PDF',
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// =============================================================
  /// INFO ITEM
  /// =============================================================

  Widget _infoItem(
      String label,
      String value,
      ) {
    return SizedBox(
      width: 210,
      child: Column(
        crossAxisAlignment:
        CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style:
            const TextStyle(
              fontSize: 12,
              fontWeight:
              FontWeight.w600,
              color:
              Colors.grey,
            ),
          ),
          const SizedBox(
            height: 3,
          ),
          Text(
            value,
            style:
            const TextStyle(
              fontSize: 15,
              fontWeight:
              FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  /// =============================================================
  /// SUMMARY BOX
  /// =============================================================

  Widget _summaryBox(
      String title,
      String value,
      ) {
    return Container(
      width: 190,
      padding:
      const EdgeInsets.all(
        14,
      ),
      decoration:
      BoxDecoration(
        border:
        Border.all(
          color:
          Colors.grey.shade300,
        ),
        borderRadius:
        BorderRadius.circular(
          10,
        ),
      ),
      child: Column(
        crossAxisAlignment:
        CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style:
            const TextStyle(
              fontSize: 12,
              fontWeight:
              FontWeight.w600,
            ),
          ),
          const SizedBox(
            height: 4,
          ),
          Text(
            value,
            style:
            const TextStyle(
              fontSize: 18,
              fontWeight:
              FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }

  /// =============================================================
  /// PRINT / PDF
  /// =============================================================

  Future<void> _printResultCard(
      Map<String, dynamic> data,
      ) async {
    try {
      final document =
      pw.Document();

      final student =
      data['student']
      as Map<String, dynamic>;

      final exam =
      data['exam']
      as Map<String, dynamic>;

      final rows =
      List<Map<String, dynamic>>.from(
        data['rows'] as List,
      );

      final percentage =
      _toDouble(
        data['percentage'],
      );

      final position =
          _toInt(
            data['position'],
          ) ??
              0;

      document.addPage(
        pw.Page(
          pageFormat:
          PdfPageFormat.a4,
          margin:
          const pw.EdgeInsets.all(
            32,
          ),
          build: (
              context,
              ) {
            return pw.Column(
              crossAxisAlignment:
              pw.CrossAxisAlignment
                  .start,
              children: [
                pw.Center(
                  child: pw.Column(
                    children: [
                      pw.Text(
                        'RESULT CARD',
                        style:
                        pw.TextStyle(
                          fontSize: 25,
                          fontWeight:
                          pw.FontWeight
                              .bold,
                        ),
                      ),
                      pw.SizedBox(
                        height: 6,
                      ),
                      pw.Text(
                        exam['title']
                            ?.toString() ??
                            'Examination',
                        style:
                        pw.TextStyle(
                          fontSize: 15,
                          fontWeight:
                          pw.FontWeight
                              .bold,
                        ),
                      ),
                    ],
                  ),
                ),

                pw.SizedBox(
                  height: 20,
                ),

                pw.Divider(),

                pw.SizedBox(
                  height: 10,
                ),

                pw.Text(
                  'Student: ${student['full_name'] ?? '—'}',
                ),

                pw.SizedBox(
                  height: 5,
                ),

                pw.Text(
                  'Admission No.: ${student['admission_number'] ?? '—'}',
                ),

                pw.SizedBox(
                  height: 5,
                ),

                pw.Text(
                  'Class: ${(data['className'] ?? '—').toString()} ${(data['section'] ?? '').toString()}'
                      .trim(),
                ),

                pw.SizedBox(
                  height: 5,
                ),

                pw.Text(
                  'Position: ${position > 0 ? position : '—'}',
                ),

                pw.SizedBox(
                  height: 18,
                ),

                if (rows.isNotEmpty)
                  pw.Table.fromTextArray(
                    headers: [
                      'Subject',
                      'Obtained',
                      'Total',
                      'Grade',
                    ],
                    data: rows.map(
                          (
                          row,
                          ) {
                        return [
                          row['subject']
                              ?.toString() ??
                              'Subject',
                          _formatNumber(
                            row[
                            'obtained'],
                          ),
                          _formatNumber(
                            row['total'],
                          ),
                          row['grade']
                              ?.toString() ??
                              '—',
                        ];
                      },
                    ).toList(),
                  )
                else
                  pw.Text(
                    'No marks entered.',
                  ),

                pw.SizedBox(
                  height: 18,
                ),

                pw.Text(
                  'Total Marks: ${_formatNumber(data['obtained'])} / ${_formatNumber(data['total'])}',
                  style:
                  pw.TextStyle(
                    fontWeight:
                    pw.FontWeight.bold,
                  ),
                ),

                pw.SizedBox(
                  height: 5,
                ),

                pw.Text(
                  'Percentage: ${percentage.toStringAsFixed(2)}%',
                ),

                pw.SizedBox(
                  height: 5,
                ),

                pw.Text(
                  'Overall Grade: ${data['grade'] ?? '—'}',
                ),

                pw.SizedBox(
                  height: 5,
                ),

                pw.Text(
                  'Position: ${position > 0 ? position : '—'}',
                ),

                pw.Spacer(),

                pw.Divider(),

                pw.SizedBox(
                  height: 20,
                ),

                pw.Row(
                  mainAxisAlignment:
                  pw.MainAxisAlignment
                      .spaceBetween,
                  children: [
                    pw.Text(
                      'Class Teacher',
                    ),
                    pw.Text(
                      'Principal',
                    ),
                  ],
                ),
              ],
            );
          },
        ),
      );

      final bytes =
      Uint8List.fromList(
        await document.save(),
      );

      await Printing.layoutPdf(
        onLayout: (
            format,
            ) async {
          return bytes;
        },
      );
    } catch (error) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(
        SnackBar(
          content: Text(
            'PDF generation failed: $error',
          ),
        ),
      );
    }
  }
}

/// ===============================================================
/// TABLE HEADER
/// ===============================================================

class _TableHeader
    extends StatelessWidget {
  final String text;

  const _TableHeader(
      this.text,
      );

  @override
  Widget build(
      BuildContext context,
      ) {
    return Padding(
      padding:
      const EdgeInsets.all(
        10,
      ),
      child: Text(
        text,
        style:
        const TextStyle(
          fontWeight:
          FontWeight.w800,
        ),
      ),
    );
  }
}

/// ===============================================================
/// TABLE CELL
/// ===============================================================

class _TableCell
    extends StatelessWidget {
  final String text;

  const _TableCell(
      this.text,
      );

  @override
  Widget build(
      BuildContext context,
      ) {
    return Padding(
      padding:
      const EdgeInsets.all(
        10,
      ),
      child: Text(
        text,
      ),
    );
  }
}

/// ===============================================================
/// ERROR VIEW
/// ===============================================================

class _ErrorView
    extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ErrorView({
    required this.message,
    required this.onRetry,
  });

  @override
  Widget build(
      BuildContext context,
      ) {
    return Center(
      child: Padding(
        padding:
        const EdgeInsets.all(
          24,
        ),
        child: Column(
          mainAxisSize:
          MainAxisSize.min,
          children: [
            const Icon(
              Icons
                  .error_outline_rounded,
              size: 48,
            ),
            const SizedBox(
              height: 12,
            ),
            Text(
              message,
              textAlign:
              TextAlign.center,
            ),
            const SizedBox(
              height: 14,
            ),
            OutlinedButton.icon(
              onPressed: onRetry,
              icon: const Icon(
                Icons.refresh_rounded,
              ),
              label: const Text(
                'Retry',
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// ===============================================================
/// NUMBER FORMAT
/// ===============================================================

String _formatNumber(
    dynamic value,
    ) {
  final number =
  _toDouble(value);

  if (number ==
      number.roundToDouble()) {
    return number
        .toInt()
        .toString();
  }

  return number
      .toStringAsFixed(2);
}