import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/network/supabase_client.dart';
import '../../../../core/widgets/main_wrapper.dart';

/// ===============================================================
/// RESULT DATA
/// ===============================================================

class ResultsData {
  final List<Map<String, dynamic>> exams;
  final List<Map<String, dynamic>> examClasses;
  final List<Map<String, dynamic>> examSubjects;
  final List<Map<String, dynamic>> examResults;
  final List<Map<String, dynamic>> students;
  final List<Map<String, dynamic>> classes;

  const ResultsData({
    required this.exams,
    required this.examClasses,
    required this.examSubjects,
    required this.examResults,
    required this.students,
    required this.classes,
  });
}

/// ===============================================================
/// RIVERPOD - RESULTS DATA
///
/// Existing tables:
///   exams
///   exam_classes
///   exam_subjects
///   exam_results
///   students
///   classes
///
/// IMPORTANT:
/// We do not assume school_id exists in every exam-related table.
/// School filtering is applied where the existing table supports it.
/// ===============================================================

final resultsDataProvider =
FutureProvider.autoDispose<ResultsData>((ref) async {
  final client = SupabaseConfig.client;

  final schoolId =
  await ref.watch(
    schoolIdProvider.future,
  );

  if (schoolId == null) {
    throw Exception(
      'Your account is not linked to a school.',
    );
  }

  /// -------------------------------------------------------------
  /// EXAMS
  /// -------------------------------------------------------------
  ///
  /// We intentionally do NOT use:
  /// .eq('school_id', schoolId)
  ///
  /// because we have not confirmed that `exams` contains
  /// school_id. Supabase RLS should control access.
  final examsResponse =
  await client
      .from('exams')
      .select('*');

  /// -------------------------------------------------------------
  /// EXAM CLASSES
  /// -------------------------------------------------------------

  final examClassesResponse =
  await client
      .from('exam_classes')
      .select('*')
      .eq(
    'school_id',
    schoolId,
  );

  /// -------------------------------------------------------------
  /// EXAM SUBJECTS
  /// -------------------------------------------------------------
  ///
  /// Do not assume school_id exists here.
  final examSubjectsResponse =
  await client
      .from('exam_subjects')
      .select('*');

  /// -------------------------------------------------------------
  /// EXAM RESULTS
  /// -------------------------------------------------------------

  final examResultsResponse =
  await client
      .from('exam_results')
      .select('*')
      .eq(
    'school_id',
    schoolId,
  );

  /// -------------------------------------------------------------
  /// STUDENTS
  /// -------------------------------------------------------------

  final studentsResponse =
  await client
      .from('students')
      .select('*')
      .eq(
    'school_id',
    schoolId,
  );

  /// -------------------------------------------------------------
  /// CLASSES
  /// -------------------------------------------------------------

  final classesResponse =
  await client
      .from('classes')
      .select('*')
      .eq(
    'school_id',
    schoolId,
  );

  return ResultsData(
    exams:
    List<Map<String, dynamic>>.from(
      examsResponse,
    ),

    examClasses:
    List<Map<String, dynamic>>.from(
      examClassesResponse,
    ),

    examSubjects:
    List<Map<String, dynamic>>.from(
      examSubjectsResponse,
    ),

    examResults:
    List<Map<String, dynamic>>.from(
      examResultsResponse,
    ),

    students:
    List<Map<String, dynamic>>.from(
      studentsResponse,
    ),

    classes:
    List<Map<String, dynamic>>.from(
      classesResponse,
    ),
  );
});

/// ===============================================================
/// RIVERPOD SEARCH
/// ===============================================================

final resultSearchProvider =
StateProvider.autoDispose<String>(
      (ref) => '',
);

/// ===============================================================
/// RIVERPOD EXAM FILTER
/// ===============================================================

final resultExamFilterProvider =
StateProvider.autoDispose<int?>(
      (ref) => null,
);

/// ===============================================================
/// RIVERPOD CLASS FILTER
/// ===============================================================

final resultClassFilterProvider =
StateProvider.autoDispose<int?>(
      (ref) => null,
);

/// ===============================================================
/// RESULTS SCREEN
/// ===============================================================

class ResultsScreen
    extends ConsumerWidget {
  const ResultsScreen({
    super.key,
  });

  @override
  Widget build(
      BuildContext context,
      WidgetRef ref,
      ) {
    final result =
    ref.watch(
      resultsDataProvider,
    );

    return MainWrapper(
      child:
      result.when(
        loading:
            () =>
        const Center(
          child:
          CircularProgressIndicator(
            strokeWidth:
            2,
          ),
        ),

        error:
            (error, stack) =>
            _ErrorView(
              message:
              error.toString()
                  .replaceFirst(
                'Exception: ',
                '',
              ),
              onRetry:
                  () {
                ref.invalidate(
                  resultsDataProvider,
                );
              },
            ),

        data:
            (data) =>
            _ResultsContent(
              data:
              data,
            ),
      ),
    );
  }
}

/// ===============================================================
/// RESULTS CONTENT
/// ===============================================================

class _ResultsContent
    extends ConsumerWidget {
  final ResultsData data;

  const _ResultsContent({
    required this.data,
  });

  /// -------------------------------------------------------------
  /// ID
  /// -------------------------------------------------------------

  int? _id(dynamic value) {
    if (value == null) {
      return null;
    }

    if (value is int) {
      return value;
    }

    return int.tryParse(
      value.toString(),
    );
  }

  /// -------------------------------------------------------------
  /// FIND ROW BY ID
  /// -------------------------------------------------------------

  Map<String, dynamic>? _findById(
      List<Map<String, dynamic>> rows,
      dynamic id,
      ) {
    final target =
    _id(id);

    if (target == null) {
      return null;
    }

    for (final row in rows) {
      if (_id(row['id']) ==
          target) {
        return row;
      }
    }

    return null;
  }

  /// -------------------------------------------------------------
  /// GET TEXT FROM POSSIBLE COLUMNS
  /// -------------------------------------------------------------

  String _text(
      Map<String, dynamic>? row,
      List<String> columns,
      String fallback,
      ) {
    if (row == null) {
      return fallback;
    }

    for (final column in columns) {
      final value =
      row[column]
          ?.toString()
          .trim();

      if (value != null &&
          value.isNotEmpty) {
        return value;
      }
    }

    return fallback;
  }

  /// -------------------------------------------------------------
  /// STUDENT NAME
  /// -------------------------------------------------------------

  String _studentName(
      Map<String, dynamic>? student,
      ) {
    if (student == null) {
      return 'Unknown Student';
    }

    final direct =
    _text(
      student,
      [
        'name',
        'full_name',
        'student_name',
        'studentName',
      ],
      '',
    );

    if (direct.isNotEmpty) {
      return direct;
    }

    final first =
        student['first_name']
            ?.toString()
            .trim() ??
            '';

    final last =
        student['last_name']
            ?.toString()
            .trim() ??
            '';

    final combined =
    '$first $last'.trim();

    if (combined.isNotEmpty) {
      return combined;
    }

    return 'Student #${student['id'] ?? ''}';
  }

  /// -------------------------------------------------------------
  /// ADMISSION NUMBER
  /// -------------------------------------------------------------

  String _admissionNumber(
      Map<String, dynamic>? student,
      ) {
    return _text(
      student,
      [
        'admission_number',
        'admission_no',
        'admissionNumber',
        'registration_number',
        'registration_no',
        'student_number',
      ],
      '',
    );
  }

  /// -------------------------------------------------------------
  /// EXAM NAME
  /// -------------------------------------------------------------

  String _examName(
      Map<String, dynamic>? exam,
      ) {
    return _text(
      exam,
      [
        'name',
        'title',
        'exam_name',
        'examName',
      ],
      'Examination',
    );
  }

  /// -------------------------------------------------------------
  /// SUBJECT NAME
  /// -------------------------------------------------------------

  String _subjectName(
      Map<String, dynamic>? subject,
      ) {
    return _text(
      subject,
      [
        'name',
        'title',
        'subject_name',
        'subjectName',
      ],
      'Subject',
    );
  }

  /// -------------------------------------------------------------
  /// CLASS NAME
  /// -------------------------------------------------------------

  String _className(
      Map<String, dynamic>? classRow,
      ) {
    return _text(
      classRow,
      [
        'name',
        'class_name',
        'title',
        'display_name',
        'class',
        'grade',
      ],
      'Class',
    );
  }

  /// -------------------------------------------------------------
  /// FILTER BY CLASS
  /// -------------------------------------------------------------

  bool _resultBelongsToClass(
      Map<String, dynamic> result,
      int classId,
      ) {
    final examId =
    _id(
      result['exam_id'],
    );

    if (examId == null) {
      return false;
    }

    /// First check exam_classes.
    for (final row
    in data.examClasses) {
      final rowExamId =
      _id(
        row['exam_id'],
      );

      final rowClassId =
      _id(
        row['class_id'],
      );

      if (rowExamId ==
          examId &&
          rowClassId ==
              classId) {
        return true;
      }
    }

    /// Fallback: check student's class_id.
    final student =
    _findById(
      data.students,
      result['student_id'],
    );

    if (student != null) {
      final studentClassId =
      _id(
        student['class_id'],
      );

      if (studentClassId ==
          classId) {
        return true;
      }
    }

    return false;
  }

  /// -------------------------------------------------------------
  /// FILTER RESULTS
  /// -------------------------------------------------------------

  List<Map<String, dynamic>>
  _filteredResults(
      String search,
      int? examId,
      int? classId,
      ) {
    final query =
    search
        .trim()
        .toLowerCase();

    return data.examResults
        .where(
          (result) {
        final resultExamId =
        _id(
          result['exam_id'],
        );

        if (examId != null &&
            resultExamId !=
                examId) {
          return false;
        }

        if (classId != null &&
            !_resultBelongsToClass(
              result,
              classId,
            )) {
          return false;
        }

        final student =
        _findById(
          data.students,
          result['student_id'],
        );

        final exam =
        _findById(
          data.exams,
          result['exam_id'],
        );

        final studentName =
        _studentName(
          student,
        ).toLowerCase();

        final admission =
        _admissionNumber(
          student,
        ).toLowerCase();

        final examName =
        _examName(
          exam,
        ).toLowerCase();

        if (query.isEmpty) {
          return true;
        }

        return studentName
            .contains(query) ||
            admission
                .contains(query) ||
            examName
                .contains(query);
      },
    ).toList();
  }

  /// -------------------------------------------------------------
  /// FAIL GRADE
  /// -------------------------------------------------------------

  bool _isFail(
      String grade,
      ) {
    final value =
    grade
        .trim()
        .toUpperCase();

    return value == 'F' ||
        value == 'FAIL' ||
        value == 'FAILED';
  }

  /// -------------------------------------------------------------
  /// PASSING RATE
  /// -------------------------------------------------------------

  String _passingRate() {
    if (data.examResults.isEmpty) {
      return '0%';
    }

    int total =
    0;

    int passed =
    0;

    for (final result
    in data.examResults) {
      final grade =
          result['grade']
              ?.toString()
              .trim() ??
              '';

      if (grade.isEmpty) {
        continue;
      }

      total++;

      if (!_isFail(
        grade,
      )) {
        passed++;
      }
    }

    if (total == 0) {
      return '—';
    }

    return '${((passed / total) * 100).toStringAsFixed(1)}%';
  }

  /// -------------------------------------------------------------
  /// TOP PERFORMERS
  /// -------------------------------------------------------------

  int _topPerformers() {
    final students =
    <int>{};

    for (final result
    in data.examResults) {
      final grade =
          result['grade']
              ?.toString()
              .trim() ??
              '';

      final studentId =
      _id(
        result['student_id'],
      );

      if (studentId != null &&
          grade.isNotEmpty &&
          !_isFail(
            grade,
          )) {
        students.add(
          studentId,
        );
      }
    }

    return students.length;
  }

  /// -------------------------------------------------------------
  /// TOTAL MARKS
  /// -------------------------------------------------------------

  double? _totalMarks(
      Map<String, dynamic>? subject,
      ) {
    if (subject == null) {
      return null;
    }

    const columns = [
      'total_marks',
      'totalMarks',
      'max_marks',
      'maximum_marks',
      'full_marks',
      'fullMarks',
      'marks',
    ];

    for (final column in columns) {
      final value =
      double.tryParse(
        subject[column]
            ?.toString() ??
            '',
      );

      if (value != null &&
          value > 0) {
        return value;
      }
    }

    return null;
  }

  /// =============================================================
  /// BUILD
  /// =============================================================

  @override
  Widget build(
      BuildContext context,
      WidgetRef ref,
      ) {
    final search =
    ref.watch(
      resultSearchProvider,
    );

    final selectedExam =
    ref.watch(
      resultExamFilterProvider,
    );

    final selectedClass =
    ref.watch(
      resultClassFilterProvider,
    );

    final results =
    _filteredResults(
      search,
      selectedExam,
      selectedClass,
    );

    return RefreshIndicator(
      onRefresh:
          () async {
        ref.invalidate(
          resultsDataProvider,
        );

        await ref.read(
          resultsDataProvider.future,
        );
      },

      child:
      ListView(
        physics:
        const AlwaysScrollableScrollPhysics(),

        padding:
        const EdgeInsets.all(
          24,
        ),

        children: [
          _header(),

          const SizedBox(
            height:
            24,
          ),

          _summaryStats(),

          const SizedBox(
            height:
            30,
          ),

          const Text(
            'Search Student Result',
            style:
            TextStyle(
              fontSize:
              18,
              fontWeight:
              FontWeight.w800,
            ),
          ),

          const SizedBox(
            height:
            16,
          ),

          _searchBox(
            ref,
            search,
          ),

          const SizedBox(
            height:
            14,
          ),

          _filters(
            ref,
            selectedExam,
            selectedClass,
          ),

          const SizedBox(
            height:
            30,
          ),

          Row(
            children: [
              const Expanded(
                child:
                Text(
                  'Recent Results Published',
                  style:
                  TextStyle(
                    fontWeight:
                    FontWeight.bold,
                    fontSize:
                    16,
                  ),
                ),
              ),

              Text(
                '${results.length} result(s)',
                style:
                const TextStyle(
                  color:
                  AppColors
                      .textSecondary,
                  fontSize:
                  11,
                ),
              ),
            ],
          ),

          const SizedBox(
            height:
            16,
          ),

          if (results.isEmpty)
            _empty()
          else
            ...results
                .take(50)
                .map(
                  (result) =>
                  _resultTile(
                    result,
                  ),
            ),
        ],
      ),
    );
  }

  /// =============================================================
  /// HEADER
  /// =============================================================

  Widget _header() {
    return const Column(
      crossAxisAlignment:
      CrossAxisAlignment.start,
      children: [
        Text(
          'Performance Center',
          style:
          TextStyle(
            fontSize:
            24,
            fontWeight:
            FontWeight.w900,
            letterSpacing:
            -0.5,
          ),
        ),

        SizedBox(
          height:
          4,
        ),

        Text(
          'Analyze student performance and grades.',
          style:
          TextStyle(
            color:
            AppColors
                .textSecondary,
            fontSize:
            13,
          ),
        ),
      ],
    );
  }

  /// =============================================================
  /// SUMMARY
  /// =============================================================

  Widget _summaryStats() {
    return Row(
      children: [
        Expanded(
          child:
          _statItem(
            'Passing Rate',
            _passingRate(),
            AppColors.success,
          ),
        ),

        const SizedBox(
          width:
          16,
        ),

        Expanded(
          child:
          _statItem(
            'Top Performers',
            '${_topPerformers()}',
            AppColors.primary,
          ),
        ),
      ],
    );
  }

  Widget _statItem(
      String label,
      String value,
      Color color,
      ) {
    return Container(
      padding:
      const EdgeInsets.all(
        20,
      ),

      decoration:
      BoxDecoration(
        color:
        color.withOpacity(
          .06,
        ),

        borderRadius:
        BorderRadius.circular(
          20,
        ),

        border:
        Border.all(
          color:
          color.withOpacity(
            .12,
          ),
        ),
      ),

      child:
      Column(
        children: [
          Text(
            value,
            style:
            TextStyle(
              color:
              color,
              fontWeight:
              FontWeight.w900,
              fontSize:
              24,
            ),
          ),

          const SizedBox(
            height:
            3,
          ),

          Text(
            label,
            style:
            TextStyle(
              color:
              color.withOpacity(
                .7,
              ),
              fontWeight:
              FontWeight.w700,
              fontSize:
              11,
            ),
          ),
        ],
      ),
    );
  }

  /// =============================================================
  /// SEARCH BOX
  /// =============================================================

  Widget _searchBox(
      WidgetRef ref,
      String value,
      ) {
    return TextField(
      onChanged:
          (text) {
        ref
            .read(
          resultSearchProvider
              .notifier,
        )
            .state = text;
      },

      decoration:
      InputDecoration(
        hintText:
        'Enter student admission number or name...',

        prefixIcon:
        const Icon(
          Icons.search_rounded,
        ),

        suffixIcon:
        value.isEmpty
            ? null
            : IconButton(
          onPressed:
              () {
            ref
                .read(
              resultSearchProvider
                  .notifier,
            )
                .state = '';
          },
          icon:
          const Icon(
            Icons.clear_rounded,
          ),
        ),

        filled:
        true,

        fillColor:
        Colors.white,

        border:
        OutlineInputBorder(
          borderRadius:
          BorderRadius.circular(
            15,
          ),
          borderSide:
          const BorderSide(
            color:
            AppColors.border,
          ),
        ),

        enabledBorder:
        OutlineInputBorder(
          borderRadius:
          BorderRadius.circular(
            15,
          ),
          borderSide:
          const BorderSide(
            color:
            AppColors.border,
          ),
        ),

        focusedBorder:
        OutlineInputBorder(
          borderRadius:
          BorderRadius.circular(
            15,
          ),
          borderSide:
          const BorderSide(
            color:
            AppColors.primary,
            width:
            1.2,
          ),
        ),
      ),
    );
  }

  /// =============================================================
  /// FILTERS
  /// =============================================================

  Widget _filters(
      WidgetRef ref,
      int? selectedExam,
      int? selectedClass,
      ) {
    return Wrap(
      spacing:
      10,
      runSpacing:
      10,

      children: [
        SizedBox(
          width:
          240,

          child:
          DropdownButtonFormField<int?>(
            value:
            selectedExam,

            decoration:
            const InputDecoration(
              labelText:
              'Examination',
              prefixIcon:
              Icon(
                Icons.assignment_outlined,
              ),
            ),

            items: [
              const DropdownMenuItem<int?>(
                value:
                null,
                child:
                Text(
                  'All Examinations',
                ),
              ),

              ...data.exams.map(
                    (exam) {
                  final id =
                  _id(
                    exam['id'],
                  );

                  if (id == null) {
                    return null;
                  }

                  return DropdownMenuItem<
                      int?>(
                    value:
                    id,
                    child:
                    Text(
                      _examName(
                        exam,
                      ),
                      overflow:
                      TextOverflow.ellipsis,
                    ),
                  );
                },
              ).whereType<
                  DropdownMenuItem<int?>>(),
            ],

            onChanged:
                (value) {
              ref
                  .read(
                resultExamFilterProvider
                    .notifier,
              )
                  .state = value;
            },
          ),
        ),

        SizedBox(
          width:
          240,

          child:
          DropdownButtonFormField<int?>(
            value:
            selectedClass,

            decoration:
            const InputDecoration(
              labelText:
              'Class',
              prefixIcon:
              Icon(
                Icons.class_outlined,
              ),
            ),

            items: [
              const DropdownMenuItem<int?>(
                value:
                null,
                child:
                Text(
                  'All Classes',
                ),
              ),

              ...data.classes.map(
                    (classRow) {
                  final id =
                  _id(
                    classRow['id'],
                  );

                  if (id == null) {
                    return null;
                  }

                  return DropdownMenuItem<
                      int?>(
                    value:
                    id,
                    child:
                    Text(
                      _className(
                        classRow,
                      ),
                    ),
                  );
                },
              ).whereType<
                  DropdownMenuItem<int?>>(),
            ],

            onChanged:
                (value) {
              ref
                  .read(
                resultClassFilterProvider
                    .notifier,
              )
                  .state = value;
            },
          ),
        ),
      ],
    );
  }

  /// =============================================================
  /// RESULT CARD
  /// =============================================================

  Widget _resultTile(
      Map<String, dynamic> result,
      ) {
    final student =
    _findById(
      data.students,
      result['student_id'],
    );

    final exam =
    _findById(
      data.exams,
      result['exam_id'],
    );

    final subject =
    _findById(
      data.examSubjects,
      result['exam_subject_id'],
    );

    final studentName =
    _studentName(
      student,
    );

    final admission =
    _admissionNumber(
      student,
    );

    final examName =
    _examName(
      exam,
    );

    final subjectName =
    _subjectName(
      subject,
    );

    final obtained =
        double.tryParse(
          result['obtained_marks']
              ?.toString() ??
              '',
        ) ??
            0;

    final total =
    _totalMarks(
      subject,
    );

    final percentage =
    total != null &&
        total > 0
        ? (obtained /
        total) *
        100
        : null;

    final grade =
        result['grade']
            ?.toString()
            .trim() ??
            '';

    final failed =
    _isFail(
      grade,
    );

    return Card(
      margin:
      const EdgeInsets.only(
        bottom:
        12,
      ),

      elevation:
      0,

      shape:
      RoundedRectangleBorder(
        borderRadius:
        BorderRadius.circular(
          16,
        ),

        side:
        const BorderSide(
          color:
          AppColors.border,
        ),
      ),

      child:
      Padding(
        padding:
        const EdgeInsets.symmetric(
          horizontal:
          18,
          vertical:
          14,
        ),

        child:
        Row(
          children: [
            CircleAvatar(
              radius:
              23,

              backgroundColor:
              failed
                  ? AppColors.error
                  .withOpacity(
                .08,
              )
                  : AppColors.background,

              child:
              Text(
                studentName
                    .isEmpty
                    ? '?'
                    : studentName[0]
                    .toUpperCase(),

                style:
                TextStyle(
                  fontWeight:
                  FontWeight.bold,
                  color:
                  failed
                      ? AppColors.error
                      : AppColors.primary,
                ),
              ),
            ),

            const SizedBox(
              width:
              13,
            ),

            Expanded(
              child:
              Column(
                crossAxisAlignment:
                CrossAxisAlignment.start,

                children: [
                  Text(
                    studentName,
                    maxLines:
                    1,
                    overflow:
                    TextOverflow.ellipsis,
                    style:
                    const TextStyle(
                      fontWeight:
                      FontWeight.w800,
                      fontSize:
                      14,
                    ),
                  ),

                  if (admission.isNotEmpty)
                    Text(
                      'Admission: $admission',
                      style:
                      const TextStyle(
                        fontSize:
                        10,
                        color:
                        AppColors
                            .textSecondary,
                      ),
                    ),

                  const SizedBox(
                    height:
                    4,
                  ),

                  Text(
                    '$examName • $subjectName',
                    maxLines:
                    1,
                    overflow:
                    TextOverflow.ellipsis,
                    style:
                    const TextStyle(
                      fontSize:
                      10,
                      color:
                      AppColors
                          .textSecondary,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(
              width:
              10,
            ),

            Column(
              crossAxisAlignment:
              CrossAxisAlignment.end,

              children: [
                Text(
                  grade.isEmpty
                      ? '—'
                      : grade,

                  style:
                  TextStyle(
                    fontWeight:
                    FontWeight.w900,
                    color:
                    failed
                        ? AppColors.error
                        : AppColors.primary,
                    fontSize:
                    17,
                  ),
                ),

                if (percentage != null)
                  Text(
                    '${percentage.toStringAsFixed(1)}%',
                    style:
                    const TextStyle(
                      fontSize:
                      11,
                      color:
                      AppColors
                          .textSecondary,
                    ),
                  )
                else
                  Text(
                    'Marks: ${obtained.toStringAsFixed(0)}',
                    style:
                    const TextStyle(
                      fontSize:
                      11,
                      color:
                      AppColors
                          .textSecondary,
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// =============================================================
  /// EMPTY
  /// =============================================================

  Widget _empty() {
    return Container(
      padding:
      const EdgeInsets.all(
        35,
      ),

      decoration:
      BoxDecoration(
        color:
        Colors.white,

        borderRadius:
        BorderRadius.circular(
          20,
        ),

        border:
        Border.all(
          color:
          AppColors.border,
        ),
      ),

      child:
      const Column(
        children: [
          Icon(
            Icons.assignment_outlined,
            size:
            48,
            color:
            AppColors
                .textSecondary,
          ),

          SizedBox(
            height:
            12,
          ),

          Text(
            'No results found',
            style:
            TextStyle(
              fontSize:
              15,
              fontWeight:
              FontWeight.w800,
            ),
          ),

          SizedBox(
            height:
            5,
          ),

          Text(
            'No examination results match the selected filters.',
            textAlign:
            TextAlign.center,
            style:
            TextStyle(
              color:
              AppColors
                  .textSecondary,
              fontSize:
              10,
            ),
          ),
        ],
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
      child:
      Padding(
        padding:
        const EdgeInsets.all(
          24,
        ),

        child:
        Container(
          padding:
          const EdgeInsets.all(
            24,
          ),

          decoration:
          BoxDecoration(
            color:
            Colors.white,

            borderRadius:
            BorderRadius.circular(
              18,
            ),

            border:
            Border.all(
              color:
              AppColors.error
                  .withOpacity(
                .15,
              ),
            ),
          ),

          child:
          Column(
            mainAxisSize:
            MainAxisSize.min,

            children: [
              const Icon(
                Icons.cloud_off_rounded,
                color:
                AppColors.error,
                size:
                45,
              ),

              const SizedBox(
                height:
                12,
              ),

              const Text(
                'Unable to load results',
                style:
                TextStyle(
                  fontSize:
                  16,
                  fontWeight:
                  FontWeight.w900,
                ),
              ),

              const SizedBox(
                height:
                8,
              ),

              Text(
                message,
                textAlign:
                TextAlign.center,
                style:
                const TextStyle(
                  color:
                  AppColors
                      .textSecondary,
                  fontSize:
                  10,
                ),
              ),

              const SizedBox(
                height:
                16,
              ),

              FilledButton(
                onPressed:
                onRetry,
                child:
                const Text(
                  'Retry',
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}