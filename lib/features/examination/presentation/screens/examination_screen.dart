import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/network/supabase_client.dart';
import '../../../../core/widgets/main_wrapper.dart';


// ============================================================
// EXAM MODEL
// ============================================================

class ExamModel {
  final int id;
  final String title;
  final String? description;
  final String examDate;
  final String status;
  final List<Map<String, dynamic>> examClasses;

  const ExamModel({
    required this.id,
    required this.title,
    this.description,
    required this.examDate,
    required this.status,
    required this.examClasses,
  });

  factory ExamModel.fromMap(Map<String, dynamic> map) {
    final rawClasses = map['exam_classes'];

    final classes = rawClasses is List
        ? rawClasses
        .whereType<Map>()
        .map(
          (e) => Map<String, dynamic>.from(e),
    )
        .toList()
        : <Map<String, dynamic>>[];

    return ExamModel(
      id: (map['id'] as num).toInt(),
      title: map['title']?.toString() ?? '',
      description: map['description']?.toString(),
      examDate: map['exam_date']?.toString() ?? '',
      status: map['status']?.toString() ?? 'upcoming',
      examClasses: classes,
    );
  }
}


// ============================================================
// REPOSITORY
// ============================================================

class ExaminationsRepository {
  final SupabaseClient client;

  ExaminationsRepository(this.client);

  Future<int> getSchoolId() async {
    final user = client.auth.currentUser;

    if (user == null) {
      throw Exception('No authenticated user.');
    }

    final profile = await client
        .from('profiles')
        .select('school_id')
        .eq('id', user.id)
        .maybeSingle()
        .timeout(
      const Duration(seconds: 10),
    );

    final value = profile?['school_id'];

    if (value == null) {
      throw Exception(
        'No school linked with your account.',
      );
    }

    return (value as num).toInt();
  }

  // ----------------------------------------------------------
  // EXAMS
  // ----------------------------------------------------------

  Future<List<ExamModel>> getExams() async {
    final schoolId = await getSchoolId();

    final response = await client
        .from('exams')
        .select('''
          id,
          title,
          description,
          exam_date,
          status,
          exam_classes(
            exam_id,
            class_id,
            classes(
              id,
              name,
              section_name
            )
          )
        ''')
        .eq('school_id', schoolId)
        .order('exam_date', ascending: false)
        .timeout(
      const Duration(seconds: 15),
    );

    return response
        .whereType<Map>()
        .map(
          (item) => ExamModel.fromMap(
        Map<String, dynamic>.from(item),
      ),
    )
        .toList();
  }

  // ----------------------------------------------------------
  // CLASSES
  // ----------------------------------------------------------

  Future<List<Map<String, dynamic>>> getClasses() async {
    final schoolId = await getSchoolId();

    final response = await client
        .from('classes')
        .select(
      'id,name,section_name',
    )
        .eq('school_id', schoolId)
        .order('name')
        .timeout(
      const Duration(seconds: 10),
    );

    return response
        .whereType<Map>()
        .map(
          (item) => Map<String, dynamic>.from(item),
    )
        .toList();
  }

  // ----------------------------------------------------------
  // SUBJECTS
  // ----------------------------------------------------------

  Future<List<Map<String, dynamic>>> getSubjects() async {
    final schoolId = await getSchoolId();

    final response = await client
        .from('subjects')
        .select(
      'id,name,code',
    )
        .eq('school_id', schoolId)
        .order('name')
        .timeout(
      const Duration(seconds: 10),
    );

    return response
        .whereType<Map>()
        .map(
          (item) => Map<String, dynamic>.from(item),
    )
        .toList();
  }

  // ----------------------------------------------------------
  // CREATE EXAM
  // ----------------------------------------------------------

  Future<void> createExam({
    required String title,
    required String description,
    required DateTime date,
    required List<int> classIds,
    required List<int> subjectIds,
    required double totalMarks,
    required double passingMarks,
  }) async {
    final schoolId = await getSchoolId();
    final user = client.auth.currentUser;

    if (title.trim().isEmpty) {
      throw Exception(
        'Exam title is required.',
      );
    }

    if (classIds.isEmpty) {
      throw Exception(
        'Please select at least one class.',
      );
    }

    if (subjectIds.isEmpty) {
      throw Exception(
        'Please select at least one subject.',
      );
    }

    if (totalMarks <= 0) {
      throw Exception(
        'Total marks must be greater than 0.',
      );
    }

    if (passingMarks < 0 ||
        passingMarks > totalMarks) {
      throw Exception(
        'Passing marks are invalid.',
      );
    }

    final examResponse = await client
        .from('exams')
        .insert({
      'school_id': schoolId,
      'title': title.trim(),
      'description': description.trim().isEmpty
          ? null
          : description.trim(),
      'exam_date':
      '${date.year.toString().padLeft(4, '0')}-'
          '${date.month.toString().padLeft(2, '0')}-'
          '${date.day.toString().padLeft(2, '0')}',
      'status': 'upcoming',
      'created_by': user?.id,
    })
        .select('id')
        .single()
        .timeout(
      const Duration(seconds: 15),
    );

    final examId =
    (examResponse['id'] as num).toInt();

    // Classes
    final examClasses = classIds
        .map(
          (classId) => {
        'exam_id': examId,
        'class_id': classId,
        'school_id': schoolId,
      },
    )
        .toList();

    await client
        .from('exam_classes')
        .insert(examClasses)
        .timeout(
      const Duration(seconds: 15),
    );

    // Subjects for every selected class
    final examSubjects = <Map<String, dynamic>>[];

    for (final classId in classIds) {
      for (final subjectId in subjectIds) {
        examSubjects.add({
          'school_id': schoolId,
          'exam_id': examId,
          'class_id': classId,
          'subject_id': subjectId,
          'total_marks': totalMarks,
          'passing_marks': passingMarks,
        });
      }
    }

    await client
        .from('exam_subjects')
        .insert(examSubjects)
        .timeout(
      const Duration(seconds: 15),
    );
  }

  // ----------------------------------------------------------
  // DELETE EXAM
  // ----------------------------------------------------------

  Future<void> deleteExam(int examId) async {
    final schoolId = await getSchoolId();

    await client
        .from('exams')
        .delete()
        .eq('id', examId)
        .eq('school_id', schoolId)
        .timeout(
      const Duration(seconds: 15),
    );
  }
}


// ============================================================
// PROVIDERS
// ============================================================

final examinationsRepositoryProvider =
Provider<ExaminationsRepository>((ref) {
  return ExaminationsRepository(
    SupabaseConfig.client,
  );
});


final examinationsProvider =
FutureProvider<List<ExamModel>>((ref) async {
  final repository =
  ref.read(examinationsRepositoryProvider);

  return repository.getExams();
});


final classesProvider =
FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final repository =
  ref.read(examinationsRepositoryProvider);

  return repository.getClasses();
});


final subjectsProvider =
FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final repository =
  ref.read(examinationsRepositoryProvider);

  return repository.getSubjects();
});


// ============================================================
// SCREEN
// ============================================================

class ExaminationsScreen extends ConsumerWidget {
  const ExaminationsScreen({
    super.key,
  });

  @override
  Widget build(
      BuildContext context,
      WidgetRef ref,
      ) {
    final examsAsync =
    ref.watch(examinationsProvider);

    return MainWrapper(
      child: examsAsync.when(
        loading: () => const _LoadingView(),

        error: (error, stack) {
          return _ErrorView(
            error: error.toString(),
            onRetry: () {
              ref.invalidate(
                examinationsProvider,
              );
            },
          );
        },

        data: (exams) {
          return _ExaminationsContent(
            exams: exams,
          );
        },
      ),
    );
  }
}


// ============================================================
// CONTENT
// ============================================================

class _ExaminationsContent extends ConsumerWidget {
  final List<ExamModel> exams;

  const _ExaminationsContent({
    required this.exams,
  });

  @override
  Widget build(
      BuildContext context,
      WidgetRef ref,
      ) {
    final upcoming = exams
        .where(
          (e) => e.status == 'upcoming',
    )
        .length;

    final completed = exams
        .where(
          (e) => e.status == 'completed',
    )
        .length;

    final cancelled = exams
        .where(
          (e) => e.status == 'cancelled',
    )
        .length;

    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(
          examinationsProvider,
        );

        await ref.read(
          examinationsProvider.future,
        );
      },
      child: LayoutBuilder(
        builder: (
            context,
            constraints,
            ) {
          final isMobile =
              constraints.maxWidth < 650;

          return ListView(
            physics:
            const AlwaysScrollableScrollPhysics(),
            padding: EdgeInsets.all(
              isMobile ? 16 : 28,
            ),
            children: [
              _buildHeader(
                context,
                ref,
                isMobile,
              ),

              const SizedBox(height: 24),

              _buildStats(
                constraints.maxWidth,
                exams.length,
                upcoming,
                completed,
                cancelled,
              ),

              const SizedBox(height: 28),

              _buildFeaturedExam(),

              const SizedBox(height: 30),

              Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Exam Schedule',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight:
                        FontWeight.w900,
                      ),
                    ),
                  ),
                  Text(
                    '${exams.length} Exams',
                    style: const TextStyle(
                      color:
                      AppColors.textSecondary,
                      fontWeight:
                      FontWeight.w600,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 14),

              if (exams.isEmpty)
                _EmptyExams(
                  onAdd: () {
                    _showScheduleDialog(
                      context,
                      ref,
                    );
                  },
                )
              else
                ...exams.map(
                      (exam) => Padding(
                    padding:
                    const EdgeInsets.only(
                      bottom: 12,
                    ),
                    child: _ExamCard(
                      exam: exam,
                      onDelete: () async {
                        final confirm =
                        await _confirmDelete(
                          context,
                          exam.title,
                        );

                        if (confirm != true) {
                          return;
                        }

                        try {
                          await ref
                              .read(
                            examinationsRepositoryProvider,
                          )
                              .deleteExam(
                            exam.id,
                          );

                          ref.invalidate(
                            examinationsProvider,
                          );

                          if (context.mounted) {
                            ScaffoldMessenger.of(
                              context,
                            ).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'Exam deleted successfully.',
                                ),
                              ),
                            );
                          }
                        } catch (e) {
                          if (context.mounted) {
                            ScaffoldMessenger.of(
                              context,
                            ).showSnackBar(
                              SnackBar(
                                content: Text(
                                  e.toString(),
                                ),
                              ),
                            );
                          }
                        }
                      },
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  // ----------------------------------------------------------
  // HEADER
  // ----------------------------------------------------------

  Widget _buildHeader(
      BuildContext context,
      WidgetRef ref,
      bool mobile,
      ) {
    final title = const Column(
      crossAxisAlignment:
      CrossAxisAlignment.start,
      children: [
        Text(
          'Examinations',
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.w900,
            letterSpacing: -.8,
          ),
        ),
        SizedBox(height: 5),
        Text(
          'Manage exams, schedules and student results.',
          style: TextStyle(
            color: AppColors.textSecondary,
            fontSize: 13,
          ),
        ),
      ],
    );

    final button = FilledButton.icon(
      onPressed: () {
        _showScheduleDialog(
          context,
          ref,
        );
      },
      icon: const Icon(
        Icons.add_rounded,
        size: 20,
      ),
      label: const Text(
        'Schedule Exam',
      ),
    );

    if (mobile) {
      return Column(
        crossAxisAlignment:
        CrossAxisAlignment.start,
        children: [
          title,
          const SizedBox(height: 15),
          button,
        ],
      );
    }

    return Row(
      children: [
        Expanded(
          child: title,
        ),
        button,
      ],
    );
  }

  // ----------------------------------------------------------
  // STATS
  // ----------------------------------------------------------

  Widget _buildStats(
      double screenWidth,
      int total,
      int upcoming,
      int completed,
      int cancelled,
      ) {
    final mobile =
        screenWidth < 600;

    final width = mobile
        ? (screenWidth - 44) / 2
        : (screenWidth - 92) / 4;

    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: [
        _StatCard(
          width: width,
          title: 'Total Exams',
          value: '$total',
          icon:
          Icons.assignment_rounded,
        ),
        _StatCard(
          width: width,
          title: 'Upcoming',
          value: '$upcoming',
          icon:
          Icons.schedule_rounded,
        ),
        _StatCard(
          width: width,
          title: 'Completed',
          value: '$completed',
          icon:
          Icons.check_circle_rounded,
        ),
        _StatCard(
          width: width,
          title: 'Cancelled',
          value: '$cancelled',
          icon:
          Icons.cancel_rounded,
        ),
      ],
    );
  }

  // ----------------------------------------------------------
  // FEATURED
  // ----------------------------------------------------------

  Widget _buildFeaturedExam() {
    final upcoming = exams
        .where(
          (e) => e.status == 'upcoming',
    )
        .toList();

    final exam = upcoming.isNotEmpty
        ? upcoming.first
        : exams.isNotEmpty
        ? exams.first
        : null;

    if (exam == null) {
      return Card(
        color: AppColors.primary,
        child: const Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'No examination cycle scheduled yet.',
            style: TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      );
    }

    return Card(
      color: AppColors.primary,
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment:
          CrossAxisAlignment.start,
          children: [
            Container(
              padding:
              const EdgeInsets.symmetric(
                horizontal: 10,
                vertical: 6,
              ),
              decoration: BoxDecoration(
                color:
                Colors.white.withOpacity(.15),
                borderRadius:
                BorderRadius.circular(20),
              ),
              child: const Text(
                'CURRENT EXAMINATION',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.2,
                ),
              ),
            ),

            const SizedBox(height: 14),

            Text(
              exam.title,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.w900,
              ),
            ),

            if (exam.description != null &&
                exam.description!
                    .trim()
                    .isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(
                exam.description!,
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 13,
                ),
              ),
            ],

            const SizedBox(height: 20),

            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                _MiniBadge(
                  label:
                  _formatDate(exam.examDate),
                  icon:
                  Icons.calendar_month_rounded,
                ),
                _MiniBadge(
                  label:
                  '${exam.examClasses.length} Classes',
                  icon:
                  Icons.grid_view_rounded,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ----------------------------------------------------------
  // SCHEDULE DIALOG
  // ----------------------------------------------------------

  Future<void> _showScheduleDialog(
      BuildContext context,
      WidgetRef ref,
      ) async {
    final titleController =
    TextEditingController();

    final descriptionController =
    TextEditingController();

    final totalMarksController =
    TextEditingController(
      text: '100',
    );

    final passingMarksController =
    TextEditingController(
      text: '40',
    );

    DateTime selectedDate =
    DateTime.now();

    final selectedClasses = <int>{};
    final selectedSubjects = <int>{};

    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (
              context,
              setDialogState,
              ) {
            final classesAsync =
            ref.watch(classesProvider);

            final subjectsAsync =
            ref.watch(subjectsProvider);

            return AlertDialog(
              title: const Text(
                'Schedule New Exam',
                style: TextStyle(
                  fontWeight:
                  FontWeight.w900,
                ),
              ),

              content: SizedBox(
                width: 620,
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment:
                    CrossAxisAlignment.start,
                    children: [
                      // TITLE
                      TextField(
                        controller:
                        titleController,
                        decoration:
                        const InputDecoration(
                          labelText:
                          'Exam Title',
                          hintText:
                          'e.g. Annual Examination',
                          prefixIcon: Icon(
                            Icons.assignment_rounded,
                          ),
                        ),
                      ),

                      const SizedBox(height: 14),

                      // DESCRIPTION
                      TextField(
                        controller:
                        descriptionController,
                        maxLines: 2,
                        decoration:
                        const InputDecoration(
                          labelText:
                          'Description',
                          hintText:
                          'Exam description',
                          prefixIcon: Icon(
                            Icons.notes_rounded,
                          ),
                        ),
                      ),

                      const SizedBox(height: 18),

                      // DATE
                      InkWell(
                        onTap: () async {
                          final picked =
                          await showDatePicker(
                            context: context,
                            firstDate:
                            DateTime(2020),
                            lastDate:
                            DateTime(2100),
                            initialDate:
                            selectedDate,
                          );

                          if (picked != null) {
                            setDialogState(
                                  () {
                                selectedDate =
                                    picked;
                              },
                            );
                          }
                        },
                        child: InputDecorator(
                          decoration:
                          const InputDecoration(
                            labelText:
                            'Exam Date',
                            prefixIcon: Icon(
                              Icons
                                  .calendar_month_rounded,
                            ),
                          ),
                          child: Text(
                            _formatDate(
                              selectedDate
                                  .toIso8601String()
                                  .split('T')
                                  .first,
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(height: 22),

                      // CLASSES
                      const Text(
                        'Select Classes',
                        style: TextStyle(
                          fontWeight:
                          FontWeight.w800,
                        ),
                      ),

                      const SizedBox(height: 8),

                      classesAsync.when(
                        loading: () =>
                        const Padding(
                          padding:
                          EdgeInsets.symmetric(
                            vertical: 10,
                          ),
                          child:
                          LinearProgressIndicator(),
                        ),

                        error: (error, _) =>
                            Container(
                              width:
                              double.infinity,
                              padding:
                              const EdgeInsets.all(
                                12,
                              ),
                              decoration:
                              BoxDecoration(
                                color: Colors.red
                                    .withOpacity(.08),
                                borderRadius:
                                BorderRadius
                                    .circular(10),
                              ),
                              child: Text(
                                'Classes Error:\n$error',
                                style:
                                const TextStyle(
                                  color: Colors.red,
                                  fontSize: 12,
                                ),
                              ),
                            ),

                        data: (classes) {
                          if (classes.isEmpty) {
                            return const Text(
                              'No classes found.',
                              style: TextStyle(
                                color:
                                AppColors
                                    .textSecondary,
                              ),
                            );
                          }

                          return Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children:
                            classes.map(
                                  (item) {
                                final id =
                                (item['id']
                                as num)
                                    .toInt();

                                final name =
                                    item['name']
                                        ?.toString() ??
                                        '';

                                final section =
                                    item['section_name']
                                        ?.toString() ??
                                        '';

                                final label =
                                section.isEmpty
                                    ? name
                                    : '$name - $section';

                                return FilterChip(
                                  selected:
                                  selectedClasses
                                      .contains(
                                    id,
                                  ),
                                  label:
                                  Text(label),
                                  onSelected:
                                      (value) {
                                    setDialogState(
                                          () {
                                        if (value) {
                                          selectedClasses
                                              .add(
                                            id,
                                          );
                                        } else {
                                          selectedClasses
                                              .remove(
                                            id,
                                          );
                                        }
                                      },
                                    );
                                  },
                                );
                              },
                            ).toList(),
                          );
                        },
                      ),

                      const SizedBox(height: 22),

                      // SUBJECTS
                      const Text(
                        'Select Subjects',
                        style: TextStyle(
                          fontWeight:
                          FontWeight.w800,
                        ),
                      ),

                      const SizedBox(height: 8),

                      subjectsAsync.when(
                        loading: () =>
                        const Padding(
                          padding:
                          EdgeInsets.symmetric(
                            vertical: 10,
                          ),
                          child:
                          LinearProgressIndicator(),
                        ),

                        error: (error, _) =>
                            Container(
                              width:
                              double.infinity,
                              padding:
                              const EdgeInsets.all(
                                12,
                              ),
                              decoration:
                              BoxDecoration(
                                color: Colors.red
                                    .withOpacity(.08),
                                borderRadius:
                                BorderRadius
                                    .circular(10),
                              ),
                              child: Text(
                                'Subjects Error:\n$error',
                                style:
                                const TextStyle(
                                  color: Colors.red,
                                  fontSize: 12,
                                ),
                              ),
                            ),

                        data: (subjects) {
                          if (subjects.isEmpty) {
                            return const Text(
                              'No subjects found. Please add subjects first.',
                              style: TextStyle(
                                color:
                                AppColors
                                    .textSecondary,
                              ),
                            );
                          }

                          return Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children:
                            subjects.map(
                                  (item) {
                                final id =
                                (item['id']
                                as num)
                                    .toInt();

                                final name =
                                    item['name']
                                        ?.toString() ??
                                        '';

                                return FilterChip(
                                  selected:
                                  selectedSubjects
                                      .contains(
                                    id,
                                  ),
                                  label:
                                  Text(name),
                                  onSelected:
                                      (value) {
                                    setDialogState(
                                          () {
                                        if (value) {
                                          selectedSubjects
                                              .add(
                                            id,
                                          );
                                        } else {
                                          selectedSubjects
                                              .remove(
                                            id,
                                          );
                                        }
                                      },
                                    );
                                  },
                                );
                              },
                            ).toList(),
                          );
                        },
                      ),

                      const SizedBox(height: 22),

                      // MARKS
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller:
                              totalMarksController,
                              keyboardType:
                              const TextInputType
                                  .numberWithOptions(
                                decimal: true,
                              ),
                              decoration:
                              const InputDecoration(
                                labelText:
                                'Total Marks',
                              ),
                            ),
                          ),
                          const SizedBox(
                            width: 12,
                          ),
                          Expanded(
                            child: TextField(
                              controller:
                              passingMarksController,
                              keyboardType:
                              const TextInputType
                                  .numberWithOptions(
                                decimal: true,
                              ),
                              decoration:
                              const InputDecoration(
                                labelText:
                                'Passing Marks',
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),

              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.pop(
                      dialogContext,
                    );
                  },
                  child:
                  const Text('Cancel'),
                ),

                FilledButton.icon(
                  onPressed: () async {
                    try {
                      final totalMarks =
                          double.tryParse(
                            totalMarksController
                                .text
                                .trim(),
                          ) ??
                              100;

                      final passingMarks =
                          double.tryParse(
                            passingMarksController
                                .text
                                .trim(),
                          ) ??
                              40;

                      await ref
                          .read(
                        examinationsRepositoryProvider,
                      )
                          .createExam(
                        title:
                        titleController
                            .text,
                        description:
                        descriptionController
                            .text,
                        date:
                        selectedDate,
                        classIds:
                        selectedClasses
                            .toList(),
                        subjectIds:
                        selectedSubjects
                            .toList(),
                        totalMarks:
                        totalMarks,
                        passingMarks:
                        passingMarks,
                      );

                      if (dialogContext
                          .mounted) {
                        Navigator.pop(
                          dialogContext,
                          true,
                        );
                      }
                    } catch (e) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(
                          context,
                        ).showSnackBar(
                          SnackBar(
                            content:
                            Text(
                              e.toString(),
                            ),
                          ),
                        );
                      }
                    }
                  },
                  icon: const Icon(
                    Icons.save_rounded,
                  ),
                  label:
                  const Text('Create Exam'),
                ),
              ],
            );
          },
        );
      },
    );

    titleController.dispose();
    descriptionController.dispose();
    totalMarksController.dispose();
    passingMarksController.dispose();

    if (result == true) {
      ref.invalidate(
        examinationsProvider,
      );

      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(
          const SnackBar(
            content: Text(
              'Exam scheduled successfully.',
            ),
          ),
        );
      }
    }
  }

  // ----------------------------------------------------------
  // DELETE CONFIRM
  // ----------------------------------------------------------

  Future<bool?> _confirmDelete(
      BuildContext context,
      String title,
      ) {
    return showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text(
            'Delete Exam?',
            style: TextStyle(
              fontWeight:
              FontWeight.w900,
            ),
          ),
          content: Text(
            'Are you sure you want to delete "$title"?',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(
                  context,
                  false,
                );
              },
              child:
              const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.pop(
                  context,
                  true,
                );
              },
              child:
              const Text('Delete'),
            ),
          ],
        );
      },
    );
  }

  // ----------------------------------------------------------
  // DATE
  // ----------------------------------------------------------

  static String _formatDate(
      String date,
      ) {
    try {
      final parsed =
      DateTime.parse(date);

      const months = [
        'Jan',
        'Feb',
        'Mar',
        'Apr',
        'May',
        'Jun',
        'Jul',
        'Aug',
        'Sep',
        'Oct',
        'Nov',
        'Dec',
      ];

      return '${parsed.day} '
          '${months[parsed.month - 1]} '
          '${parsed.year}';
    } catch (_) {
      return date;
    }
  }
}


// ============================================================
// EXAM CARD
// ============================================================

class _ExamCard extends StatelessWidget {
  final ExamModel exam;
  final VoidCallback onDelete;

  const _ExamCard({
    required this.exam,
    required this.onDelete,
  });

  @override
  Widget build(
      BuildContext context,
      ) {
    final isUpcoming =
        exam.status == 'upcoming';

    final isCompleted =
        exam.status == 'completed';

    final icon = isUpcoming
        ? Icons.schedule_rounded
        : isCompleted
        ? Icons.check_circle_outline_rounded
        : Icons.cancel_outlined;

    final iconColor = isUpcoming
        ? AppColors.info
        : isCompleted
        ? AppColors.success
        : Colors.red;

    final classNames = exam.examClasses
        .map(
          (item) {
        final classData =
        item['classes'];

        if (classData is! Map) {
          return '';
        }

        final name =
            classData['name']
                ?.toString() ??
                '';

        final section =
            classData['section_name']
                ?.toString() ??
                '';

        return section.isEmpty
            ? name
            : '$name - $section';
      },
    )
        .where(
          (name) => name.isNotEmpty,
    )
        .join(', ');

    return Card(
      child: Padding(
        padding:
        const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              width: 50,
              height: 50,
              decoration:
              BoxDecoration(
                color: iconColor
                    .withOpacity(.10),
                borderRadius:
                BorderRadius.circular(
                  14,
                ),
              ),
              child: Icon(
                icon,
                color: iconColor,
              ),
            ),

            const SizedBox(width: 14),

            Expanded(
              child: Column(
                crossAxisAlignment:
                CrossAxisAlignment.start,
                children: [
                  Text(
                    exam.title,
                    maxLines: 1,
                    overflow:
                    TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontWeight:
                      FontWeight.w800,
                      fontSize: 15,
                    ),
                  ),

                  const SizedBox(height: 5),

                  Text(
                    '${_formatDate(exam.examDate)}'
                        '${classNames.isEmpty ? '' : ' • $classNames'}',
                    maxLines: 2,
                    overflow:
                    TextOverflow.ellipsis,
                    style:
                    const TextStyle(
                      fontSize: 12,
                      color:
                      AppColors
                          .textSecondary,
                    ),
                  ),
                ],
              ),
            ),

            PopupMenuButton<String>(
              onSelected: (value) {
                if (value ==
                    'delete') {
                  onDelete();
                }
              },
              itemBuilder:
                  (context) => const [
                PopupMenuItem(
                  value: 'delete',
                  child: Row(
                    children: [
                      Icon(
                        Icons
                            .delete_outline_rounded,
                      ),
                      SizedBox(width: 8),
                      Text('Delete'),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  static String _formatDate(
      String date,
      ) {
    try {
      final parsed =
      DateTime.parse(date);

      const months = [
        'Jan',
        'Feb',
        'Mar',
        'Apr',
        'May',
        'Jun',
        'Jul',
        'Aug',
        'Sep',
        'Oct',
        'Nov',
        'Dec',
      ];

      return '${parsed.day} '
          '${months[parsed.month - 1]} '
          '${parsed.year}';
    } catch (_) {
      return date;
    }
  }
}


// ============================================================
// STAT CARD
// ============================================================

class _StatCard extends StatelessWidget {
  final double width;
  final String title;
  final String value;
  final IconData icon;

  const _StatCard({
    required this.width,
    required this.title,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(
      BuildContext context,
      ) {
    return SizedBox(
      width: width,
      child: Card(
        child: Padding(
          padding:
          const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration:
                BoxDecoration(
                  color: AppColors
                      .primary
                      .withOpacity(.10),
                  borderRadius:
                  BorderRadius.circular(
                    12,
                  ),
                ),
                child: Icon(
                  icon,
                  color:
                  AppColors.primary,
                  size: 20,
                ),
              ),

              const SizedBox(width: 12),

              Expanded(
                child: Column(
                  crossAxisAlignment:
                  CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow:
                      TextOverflow.ellipsis,
                      style:
                      const TextStyle(
                        fontSize: 11,
                        color: AppColors
                            .textSecondary,
                        fontWeight:
                        FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      value,
                      style:
                      const TextStyle(
                        fontSize: 21,
                        fontWeight:
                        FontWeight.w900,
                      ),
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


// ============================================================
// MINI BADGE
// ============================================================

class _MiniBadge extends StatelessWidget {
  final String label;
  final IconData icon;

  const _MiniBadge({
    required this.label,
    required this.icon,
  });

  @override
  Widget build(
      BuildContext context,
      ) {
    return Container(
      padding:
      const EdgeInsets.symmetric(
        horizontal: 12,
        vertical: 8,
      ),
      decoration:
      BoxDecoration(
        color:
        Colors.white.withOpacity(.14),
        borderRadius:
        BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize:
        MainAxisSize.min,
        children: [
          Icon(
            icon,
            color: Colors.white,
            size: 15,
          ),
          const SizedBox(width: 7),
          Text(
            label,
            style:
            const TextStyle(
              color: Colors.white,
              fontSize: 11,
              fontWeight:
              FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}


// ============================================================
// EMPTY
// ============================================================

class _EmptyExams
    extends StatelessWidget {
  final VoidCallback onAdd;

  const _EmptyExams({
    required this.onAdd,
  });

  @override
  Widget build(
      BuildContext context,
      ) {
    return Card(
      child: Padding(
        padding:
        const EdgeInsets.all(35),
        child: Column(
          children: [
            Icon(
              Icons
                  .assignment_outlined,
              size: 55,
              color: AppColors
                  .primary
                  .withOpacity(.45),
            ),

            const SizedBox(height: 14),

            const Text(
              'No Exams Scheduled',
              style: TextStyle(
                fontSize: 18,
                fontWeight:
                FontWeight.w900,
              ),
            ),

            const SizedBox(height: 6),

            const Text(
              'Create your first examination schedule.',
              textAlign:
              TextAlign.center,
              style: TextStyle(
                color:
                AppColors
                    .textSecondary,
              ),
            ),

            const SizedBox(height: 18),

            FilledButton.icon(
              onPressed: onAdd,
              icon: const Icon(
                Icons.add_rounded,
              ),
              label: const Text(
                'Schedule Exam',
              ),
            ),
          ],
        ),
      ),
    );
  }
}


// ============================================================
// LOADING
// ============================================================

class _LoadingView
    extends StatelessWidget {
  const _LoadingView();

  @override
  Widget build(
      BuildContext context,
      ) {
    return const Center(
      child: CircularProgressIndicator(),
    );
  }
}


// ============================================================
// ERROR
// ============================================================

class _ErrorView
    extends StatelessWidget {
  final String error;
  final VoidCallback onRetry;

  const _ErrorView({
    required this.error,
    required this.onRetry,
  });

  @override
  Widget build(
      BuildContext context,
      ) {
    return Center(
      child: Padding(
        padding:
        const EdgeInsets.all(30),
        child: Column(
          mainAxisSize:
          MainAxisSize.min,
          children: [
            const Icon(
              Icons
                  .error_outline_rounded,
              size: 50,
              color: Colors.red,
            ),

            const SizedBox(height: 12),

            const Text(
              'Unable to load examinations',
              style: TextStyle(
                fontWeight:
                FontWeight.w900,
                fontSize: 18,
              ),
            ),

            const SizedBox(height: 8),

            Text(
              error,
              textAlign:
              TextAlign.center,
              style:
              const TextStyle(
                color:
                AppColors
                    .textSecondary,
              ),
            ),

            const SizedBox(height: 18),

            FilledButton(
              onPressed: onRetry,
              child:
              const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}