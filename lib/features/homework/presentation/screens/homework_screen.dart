import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/network/supabase_client.dart';
import '../../../../core/widgets/main_wrapper.dart';

/// ===============================================================
/// HOMEWORK - EXISTING DATABASE INTEGRATION
///
/// Uses existing project tables:
///
///   profiles
///   classes
///   students
///   assignments
///
/// No new classes table is created.
///
/// Homework table:
///   assignments
///
/// Fields:
///   id
///   school_id
///   title
///   description
///   subject
///   assigned_class
///   assigned_section
///   assigned_date
///   due_date
///   status
///   created_by
///   created_at
///   updated_at
/// ===============================================================

/// ===============================================================
/// EXISTING CLASSES
/// ===============================================================

final homeworkClassesProvider =
FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final client = SupabaseConfig.client;

  final schoolId = await ref.watch(schoolIdProvider.future);

  if (schoolId == null) {
    throw Exception(
      'Your account is not linked to a school.',
    );
  }

  final response = await client
      .from('classes')
      .select('*')
      .eq('school_id', schoolId)
      .order('id');

  return List<Map<String, dynamic>>.from(response);
});

/// Try to find the actual class display name from the existing table.
String classDisplayName(
    Map<String, dynamic> row,
    ) {
  const possibleColumns = [
    'name',
    'class_name',
    'title',
    'display_name',
    'class',
    'grade',
  ];

  for (final column in possibleColumns) {
    final value = row[column]?.toString().trim();

    if (value != null && value.isNotEmpty) {
      return value;
    }
  }

  return 'Class #${row['id'] ?? ''}';
}

/// ===============================================================
/// HOMEWORK REALTIME PROVIDER
/// ===============================================================

final homeworkStreamProvider =
StreamProvider.autoDispose<List<Map<String, dynamic>>>(
      (ref) async* {
    final client = SupabaseConfig.client;

    final schoolId =
    await ref.watch(schoolIdProvider.future);

    if (schoolId == null) {
      throw Exception(
        'Your account is not linked to a school.',
      );
    }

    final stream = client
        .from('assignments')
        .stream(
      primaryKey: ['id'],
    )
        .eq(
      'school_id',
      schoolId,
    );

    await for (final rows in stream) {
      final result =
      List<Map<String, dynamic>>.from(rows);

      result.sort(
            (a, b) {
          final aDate = DateTime.tryParse(
            a['assigned_date']?.toString() ?? '',
          ) ??
              DateTime(2000);

          final bDate = DateTime.tryParse(
            b['assigned_date']?.toString() ?? '',
          ) ??
              DateTime(2000);

          return bDate.compareTo(aDate);
        },
      );

      yield result;
    }
  },
);

/// ===============================================================
/// HOMEWORK SCREEN
/// ===============================================================

class HomeworkScreen
    extends ConsumerStatefulWidget {
  const HomeworkScreen({
    super.key,
  });

  @override
  ConsumerState<HomeworkScreen> createState() =>
      _HomeworkScreenState();
}

class _HomeworkScreenState
    extends ConsumerState<HomeworkScreen> {
  String _search = '';
  String _filter = 'All';

  bool _saving = false;

  /// =============================================================
  /// FILTER HOMEWORK
  /// =============================================================

  List<Map<String, dynamic>> _filtered(
      List<Map<String, dynamic>> data,
      ) {
    final query =
    _search.trim().toLowerCase();

    return data.where(
          (item) {
        final title =
            item['title']
                ?.toString()
                .toLowerCase() ??
                '';

        final subject =
            item['subject']
                ?.toString()
                .toLowerCase() ??
                '';

        final className =
            item['assigned_class']
                ?.toString()
                .toLowerCase() ??
                '';

        final section =
            item['assigned_section']
                ?.toString()
                .toLowerCase() ??
                '';

        final status =
            item['status']
                ?.toString()
                .toLowerCase() ??
                '';

        final matchesSearch =
            query.isEmpty ||
                title.contains(query) ||
                subject.contains(query) ||
                className.contains(query) ||
                section.contains(query) ||
                status.contains(query);

        final matchesFilter =
            _filter == 'All' ||
                status ==
                    _filter.toLowerCase();

        return matchesSearch &&
            matchesFilter;
      },
    ).toList();
  }

  /// =============================================================
  /// ADD
  /// =============================================================

  Future<void> _addHomework() async {
    await _openHomeworkDialog();
  }

  /// =============================================================
  /// EDIT
  /// =============================================================

  Future<void> _editHomework(
      Map<String, dynamic> homework,
      ) async {
    await _openHomeworkDialog(
      homework: homework,
    );
  }

  /// =============================================================
  /// ADD / EDIT DIALOG
  /// =============================================================

  Future<void> _openHomeworkDialog({
    Map<String, dynamic>? homework,
  }) async {
    final titleController =
    TextEditingController(
      text:
      homework?['title']
          ?.toString() ??
          '',
    );

    final descriptionController =
    TextEditingController(
      text:
      homework?['description']
          ?.toString() ??
          '',
    );

    final subjectController =
    TextEditingController(
      text:
      homework?['subject']
          ?.toString() ??
          '',
    );

    String selectedClass =
        homework?['assigned_class']
            ?.toString() ??
            '';

    String selectedSection =
        homework?['assigned_section']
            ?.toString() ??
            '';

    DateTime assignedDate =
        DateTime.tryParse(
          homework?['assigned_date']
              ?.toString() ??
              '',
        ) ??
            DateTime.now();

    DateTime? dueDate =
    DateTime.tryParse(
      homework?['due_date']
          ?.toString() ??
          '',
    );

    String status =
        homework?['status']
            ?.toString() ??
            'active';

    const statuses = [
      'active',
      'pending',
      'completed',
      'cancelled',
    ];

    if (!statuses.contains(status)) {
      status = 'active';
    }

    final isEditing =
        homework != null;

    /// Load existing classes before opening dialog.
    List<Map<String, dynamic>> classes = [];

    try {
      classes = await ref.read(
        homeworkClassesProvider.future,
      );
    } catch (e) {
      _showError(
        e.toString().replaceFirst(
          'Exception: ',
          '',
        ),
      );
      return;
    }

    /// Make sure old saved class still exists.
    final classNames = <String>[];

    for (final row in classes) {
      final name =
      classDisplayName(row);

      if (name.isNotEmpty &&
          !classNames.contains(name)) {
        classNames.add(name);
      }
    }

    /// If editing an old homework whose class
    /// no longer exists, preserve it.
    if (selectedClass.isNotEmpty &&
        !classNames.contains(selectedClass)) {
      classNames.insert(
        0,
        selectedClass,
      );
    }

    /// Load sections from students for selected class.
    Future<List<String>> loadSections(
        String className,
        ) async {
      if (className.trim().isEmpty) {
        return [];
      }

      final schoolId =
      await ref.read(
        schoolIdProvider.future,
      );

      if (schoolId == null) {
        return [];
      }

      try {
        final response =
        await SupabaseConfig.client
            .from('students')
            .select('section_name')
            .eq(
          'school_id',
          schoolId,
        )
            .eq(
          'class_name',
          className,
        );

        final values =
        <String>{};

        for (final row in response as List) {
          final value =
          row['section_name']
              ?.toString()
              .trim();

          if (value != null &&
              value.isNotEmpty) {
            values.add(value);
          }
        }

        final result =
        values.toList()..sort();

        return result;
      } catch (_) {
        return [];
      }
    }

    await showDialog<void>(
      context: context,
      barrierDismissible:
      !_saving,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (
              dialogContext,
              setDialogState,
              ) {
            return AlertDialog(
              title: Text(
                isEditing
                    ? 'Edit Homework'
                    : 'Add Homework',
                style:
                const TextStyle(
                  fontWeight:
                  FontWeight.w900,
                ),
              ),

              content: SizedBox(
                width: 560,

                child:
                SingleChildScrollView(
                  child: Column(
                    mainAxisSize:
                    MainAxisSize.min,
                    children: [
                      /// TITLE
                      _DialogField(
                        controller:
                        titleController,
                        label:
                        'Homework Title *',
                        icon:
                        Icons.title_rounded,
                      ),

                      const SizedBox(
                        height: 12,
                      ),

                      /// DESCRIPTION
                      _DialogField(
                        controller:
                        descriptionController,
                        label:
                        'Instructions / Description',
                        icon:
                        Icons.description_outlined,
                        maxLines: 4,
                      ),

                      const SizedBox(
                        height: 12,
                      ),

                      /// SUBJECT
                      _DialogField(
                        controller:
                        subjectController,
                        label:
                        'Subject',
                        icon:
                        Icons.menu_book_outlined,
                      ),

                      const SizedBox(
                        height: 12,
                      ),

                      /// CLASS
                      DropdownButtonFormField<
                          String>(
                        value:
                        selectedClass.isEmpty
                            ? null
                            : selectedClass,

                        decoration:
                        const InputDecoration(
                          labelText:
                          'Class *',
                          prefixIcon:
                          Icon(
                            Icons.class_outlined,
                          ),
                        ),

                        items: classNames
                            .map(
                              (
                              className,
                              ) =>
                              DropdownMenuItem<
                                  String>(
                                value:
                                className,
                                child:
                                Text(
                                  className,
                                  overflow:
                                  TextOverflow.ellipsis,
                                ),
                              ),
                        )
                            .toList(),

                        hint:
                        classNames.isEmpty
                            ? const Text(
                          'No classes found',
                        )
                            : const Text(
                          'Select class',
                        ),

                        onChanged:
                            (value) async {
                          if (value ==
                              null) {
                            return;
                          }

                          setDialogState(
                                () {
                              selectedClass =
                                  value;
                              selectedSection =
                              '';
                            },
                          );

                          /// Rebuild dialog after sections
                          /// are loaded.
                          await loadSections(
                            value,
                          );

                          if (!dialogContext
                              .mounted) {
                            return;
                          }

                          setDialogState(
                                () {},
                          );
                        },
                      ),

                      const SizedBox(
                        height: 12,
                      ),

                      /// SECTION
                      FutureBuilder<List<String>>(
                        future:
                        loadSections(
                          selectedClass,
                        ),

                        builder:
                            (
                            context,
                            snapshot,
                            ) {
                          final sections =
                              snapshot.data ??
                                  <String>[];

                          final sectionItems =
                          <String>[
                            ...sections,
                          ];

                          if (selectedSection
                              .isNotEmpty &&
                              !sectionItems
                                  .contains(
                                selectedSection,
                              )) {
                            sectionItems.insert(
                              0,
                              selectedSection,
                            );
                          }

                          if (sectionItems
                              .isEmpty) {
                            return _DialogField(
                              controller:
                              TextEditingController(
                                text:
                                selectedSection,
                              ),
                              label:
                              'Section',
                              icon:
                              Icons.category_outlined,
                            );
                          }

                          return DropdownButtonFormField<
                              String>(
                            value:
                            selectedSection
                                .isEmpty
                                ? null
                                : selectedSection,

                            decoration:
                            const InputDecoration(
                              labelText:
                              'Section',
                              prefixIcon:
                              Icon(
                                Icons.category_outlined,
                              ),
                            ),

                            items:
                            sectionItems
                                .map(
                                  (
                                  section,
                                  ) =>
                                  DropdownMenuItem<
                                      String>(
                                    value:
                                    section,
                                    child:
                                    Text(
                                      section,
                                    ),
                                  ),
                            )
                                .toList(),

                            hint:
                            const Text(
                              'Select section',
                            ),

                            onChanged:
                                (
                                value,
                                ) {
                              if (value ==
                                  null) {
                                return;
                              }

                              setDialogState(
                                    () {
                                  selectedSection =
                                      value;
                                },
                              );
                            },
                          );
                        },
                      ),

                      const SizedBox(
                        height: 12,
                      ),

                      /// ASSIGNED DATE
                      _DateTile(
                        label:
                        'Assigned Date',
                        date:
                        assignedDate,
                        icon:
                        Icons.calendar_today_outlined,
                        onTap:
                            () async {
                          final selected =
                          await showDatePicker(
                            context:
                            dialogContext,
                            initialDate:
                            assignedDate,
                            firstDate:
                            DateTime(
                              2020,
                            ),
                            lastDate:
                            DateTime(
                              2100,
                            ),
                          );

                          if (selected ==
                              null) {
                            return;
                          }

                          setDialogState(
                                () {
                              assignedDate =
                                  selected;
                            },
                          );
                        },
                      ),

                      const SizedBox(
                        height: 9,
                      ),

                      /// DUE DATE
                      _DateTile(
                        label:
                        'Due Date',
                        date:
                        dueDate,
                        icon:
                        Icons.event_available_outlined,
                        optional:
                        true,
                        onClear:
                        dueDate == null
                            ? null
                            : () {
                          setDialogState(
                                () {
                              dueDate =
                              null;
                            },
                          );
                        },
                        onTap:
                            () async {
                          final selected =
                          await showDatePicker(
                            context:
                            dialogContext,
                            initialDate:
                            dueDate ??
                                assignedDate,
                            firstDate:
                            DateTime(
                              2020,
                            ),
                            lastDate:
                            DateTime(
                              2100,
                            ),
                          );

                          if (selected ==
                              null) {
                            return;
                          }

                          setDialogState(
                                () {
                              dueDate =
                                  selected;
                            },
                          );
                        },
                      ),

                      const SizedBox(
                        height: 12,
                      ),

                      /// STATUS
                      DropdownButtonFormField<
                          String>(
                        value:
                        status,

                        decoration:
                        const InputDecoration(
                          labelText:
                          'Status',
                          prefixIcon:
                          Icon(
                            Icons.flag_outlined,
                          ),
                        ),

                        items:
                        statuses
                            .map(
                              (
                              value,
                              ) =>
                              DropdownMenuItem<
                                  String>(
                                value:
                                value,
                                child:
                                Text(
                                  _capitalize(
                                    value,
                                  ),
                                ),
                              ),
                        )
                            .toList(),

                        onChanged:
                            (value) {
                          if (value ==
                              null) {
                            return;
                          }

                          setDialogState(
                                () {
                              status =
                                  value;
                            },
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ),

              actions: [
                if (isEditing)
                  TextButton(
                    onPressed:
                    _saving
                        ? null
                        : () {
                      Navigator.of(
                        dialogContext,
                      ).pop();

                      _deleteHomework(
                        homework!,
                      );
                    },
                    child:
                    const Text(
                      'Delete',
                      style:
                      TextStyle(
                        color:
                        AppColors.error,
                      ),
                    ),
                  ),

                const Spacer(),

                TextButton(
                  onPressed:
                  _saving
                      ? null
                      : () {
                    Navigator.of(
                      dialogContext,
                    ).pop();
                  },
                  child:
                  const Text(
                    'Cancel',
                  ),
                ),

                FilledButton(
                  onPressed:
                  _saving
                      ? null
                      : () async {
                    final title =
                    titleController
                        .text
                        .trim();

                    if (title.isEmpty) {
                      _showError(
                        'Homework title is required.',
                      );
                      return;
                    }

                    if (selectedClass
                        .trim()
                        .isEmpty) {
                      _showError(
                        'Please select a class.',
                      );
                      return;
                    }

                    setDialogState(
                          () {
                        _saving =
                        true;
                      },
                    );

                    try {
                      await _saveHomework(
                        homework:
                        homework,
                        title:
                        title,
                        description:
                        descriptionController
                            .text
                            .trim(),
                        subject:
                        subjectController
                            .text
                            .trim(),
                        assignedClass:
                        selectedClass
                            .trim(),
                        assignedSection:
                        selectedSection
                            .trim(),
                        assignedDate:
                        assignedDate,
                        dueDate:
                        dueDate,
                        status:
                        status,
                      );

                      if (!mounted) {
                        return;
                      }

                      Navigator.of(
                        dialogContext,
                      ).pop();

                      _showSuccess(
                        isEditing
                            ? 'Homework updated successfully.'
                            : 'Homework added successfully.',
                      );
                    } catch (e) {
                      setDialogState(
                            () {
                          _saving =
                          false;
                        },
                      );

                      if (!mounted) {
                        return;
                      }

                      _showError(
                        e.toString()
                            .replaceFirst(
                          'Exception: ',
                          '',
                        ),
                      );
                    }
                  },

                  child:
                  _saving
                      ? const SizedBox(
                    width: 18,
                    height: 18,
                    child:
                    CircularProgressIndicator(
                      strokeWidth: 2,
                      color:
                      Colors.white,
                    ),
                  )
                      : Text(
                    isEditing
                        ? 'Update'
                        : 'Save',
                  ),
                ),
              ],
            );
          },
        );
      },
    );

    titleController.dispose();
    descriptionController.dispose();
    subjectController.dispose();
  }

  /// =============================================================
  /// SAVE HOMEWORK
  /// =============================================================

  Future<void> _saveHomework({
    required Map<String, dynamic>? homework,
    required String title,
    required String description,
    required String subject,
    required String assignedClass,
    required String assignedSection,
    required DateTime assignedDate,
    required DateTime? dueDate,
    required String status,
  }) async {
    final client =
        SupabaseConfig.client;

    final schoolId =
    await ref.read(
      schoolIdProvider.future,
    );

    if (schoolId == null) {
      throw Exception(
        'Your account is not linked to a school.',
      );
    }

    final user =
        client.auth.currentUser;

    if (user == null) {
      throw Exception(
        'No authenticated user found.',
      );
    }

    final data =
    <String, dynamic>{
      'school_id':
      schoolId,

      'title':
      title,

      'description':
      description.isEmpty
          ? null
          : description,

      'subject':
      subject.isEmpty
          ? null
          : subject,

      'assigned_class':
      assignedClass,

      'assigned_section':
      assignedSection.isEmpty
          ? null
          : assignedSection,

      'assigned_date':
      _formatDate(
        assignedDate,
      ),

      'due_date':
      dueDate == null
          ? null
          : _formatDate(
        dueDate,
      ),

      'status':
      status,

      'updated_at':
      DateTime.now()
          .toUtc()
          .toIso8601String(),
    };

    /// UPDATE
    if (homework != null) {
      final id =
      homework['id'];

      if (id == null) {
        throw Exception(
          'Homework ID is missing.',
        );
      }

      await client
          .from('assignments')
          .update(data)
          .eq(
        'id',
        id,
      )
          .eq(
        'school_id',
        schoolId,
      );

      return;
    }

    /// INSERT
    data['created_by'] =
        user.id;

    await client
        .from('assignments')
        .insert(data);
  }

  /// =============================================================
  /// DELETE
  /// =============================================================

  Future<void> _deleteHomework(
      Map<String, dynamic> homework,
      ) async {
    final confirmed =
    await showDialog<bool>(
      context: context,
      builder:
          (dialogContext) {
        return AlertDialog(
          title:
          const Text(
            'Delete Homework?',
            style:
            TextStyle(
              fontWeight:
              FontWeight.w900,
            ),
          ),
          content:
          Text(
            'Are you sure you want to delete "${homework['title'] ?? 'this homework'}"?',
          ),
          actions: [
            TextButton(
              onPressed:
                  () {
                Navigator.of(
                  dialogContext,
                ).pop(false);
              },
              child:
              const Text(
                'Cancel',
              ),
            ),
            FilledButton(
              style:
              FilledButton.styleFrom(
                backgroundColor:
                AppColors.error,
              ),
              onPressed:
                  () {
                Navigator.of(
                  dialogContext,
                ).pop(true);
              },
              child:
              const Text(
                'Delete',
              ),
            ),
          ],
        );
      },
    );

    if (confirmed != true) {
      return;
    }

    try {
      final client =
          SupabaseConfig.client;

      final schoolId =
      await ref.read(
        schoolIdProvider.future,
      );

      if (schoolId == null) {
        throw Exception(
          'Your account is not linked to a school.',
        );
      }

      final id =
      homework['id'];

      if (id == null) {
        throw Exception(
          'Homework ID is missing.',
        );
      }

      await client
          .from('assignments')
          .delete()
          .eq(
        'id',
        id,
      )
          .eq(
        'school_id',
        schoolId,
      );

      _showSuccess(
        'Homework deleted successfully.',
      );
    } on PostgrestException catch (e) {
      _showError(
        e.message,
      );
    } catch (e) {
      _showError(
        e.toString()
            .replaceFirst(
          'Exception: ',
          '',
        ),
      );
    }
  }

  /// =============================================================
  /// REFRESH
  /// =============================================================

  Future<void> _refresh() async {
    ref.invalidate(
      homeworkStreamProvider,
    );

    ref.invalidate(
      homeworkClassesProvider,
    );

    await Future<void>.delayed(
      const Duration(
        milliseconds: 300,
      ),
    );
  }

  /// =============================================================
  /// MESSAGES
  /// =============================================================

  void _showSuccess(
      String message,
      ) {
    if (!mounted) return;

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(
      SnackBar(
        content:
        Text(message),
        behavior:
        SnackBarBehavior.floating,
        backgroundColor:
        AppColors.success,
      ),
    );
  }

  void _showError(
      String message,
      ) {
    if (!mounted) return;

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(
      SnackBar(
        content:
        Text(message),
        behavior:
        SnackBarBehavior.floating,
        backgroundColor:
        AppColors.error,
      ),
    );
  }

  /// =============================================================
  /// BUILD
  /// =============================================================

  @override
  Widget build(
      BuildContext context,
      ) {
    final homework =
    ref.watch(
      homeworkStreamProvider,
    );

    return MainWrapper(
      child:
      homework.when(
        loading:
            () =>
        const _Loading(),

        error:
            (error, stack) =>
            _ErrorState(
              message:
              error.toString()
                  .replaceFirst(
                'Exception: ',
                '',
              ),
              onRetry:
              _refresh,
            ),

        data:
            (items) {
          final filtered =
          _filtered(
            items,
          );

          final total =
              items.length;

          final active =
              items.where(
                    (item) =>
                _status(item) ==
                    'active',
              ).length;

          final pending =
              items.where(
                    (item) =>
                _status(item) ==
                    'pending',
              ).length;

          final overdue =
              items.where(
                    (item) {
                  final due =
                  DateTime.tryParse(
                    item['due_date']
                        ?.toString() ??
                        '',
                  );

                  if (due == null) {
                    return false;
                  }

                  return due.isBefore(
                    DateTime.now(),
                  ) &&
                      _status(item) !=
                          'completed';
                },
              ).length;

          return RefreshIndicator(
            onRefresh:
            _refresh,

            child:
            ListView(
              physics:
              const AlwaysScrollableScrollPhysics(),

              padding:
              const EdgeInsets.fromLTRB(
                18,
                18,
                18,
                30,
              ),

              children: [
                _PageHeader(
                  count:
                  total,
                  onAdd:
                  _addHomework,
                ),

                const SizedBox(
                  height: 16,
                ),

                _SearchBox(
                  value:
                  _search,
                  onChanged:
                      (value) {
                    setState(
                          () {
                        _search =
                            value;
                      },
                    );
                  },
                ),

                const SizedBox(
                  height: 12,
                ),

                _FilterBar(
                  value:
                  _filter,
                  onChanged:
                      (value) {
                    setState(
                          () {
                        _filter =
                            value;
                      },
                    );
                  },
                ),

                const SizedBox(
                  height: 18,
                ),

                _Metrics(
                  total:
                  total,
                  active:
                  active,
                  pending:
                  pending,
                  overdue:
                  overdue,
                ),

                const SizedBox(
                  height: 22,
                ),

                Row(
                  children: [
                    const Expanded(
                      child:
                      Column(
                        crossAxisAlignment:
                        CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Homework',
                            style:
                            TextStyle(
                              fontSize:
                              18,
                              fontWeight:
                              FontWeight.w900,
                            ),
                          ),
                          SizedBox(
                            height:
                            3,
                          ),
                          Text(
                            'Real-time assignments from your school',
                            style:
                            TextStyle(
                              color:
                              AppColors
                                  .textSecondary,
                              fontSize:
                              9.5,
                            ),
                          ),
                        ],
                      ),
                    ),

                    if (filtered.length !=
                        items.length)
                      Text(
                        '${filtered.length} found',
                        style:
                        const TextStyle(
                          color:
                          AppColors.primary,
                          fontSize:
                          9.5,
                          fontWeight:
                          FontWeight.w800,
                        ),
                      ),
                  ],
                ),

                const SizedBox(
                  height: 10,
                ),

                if (filtered.isEmpty)
                  _EmptyState(
                    searched:
                    _search.isNotEmpty ||
                        _filter !=
                            'All',
                    onAdd:
                    _addHomework,
                  )
                else
                  ...filtered.map(
                        (item) =>
                        _HomeworkCard(
                          item:
                          item,
                          onEdit:
                              () =>
                              _editHomework(
                                item,
                              ),
                          onDelete:
                              () =>
                              _deleteHomework(
                                item,
                              ),
                        ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}

/// ===============================================================
/// HEADER
/// ===============================================================

class _PageHeader
    extends StatelessWidget {
  final int count;
  final VoidCallback onAdd;

  const _PageHeader({
    required this.count,
    required this.onAdd,
  });

  @override
  Widget build(
      BuildContext context,
      ) {
    return Row(
      children: [
        Container(
          width:
          52,
          height:
          52,
          decoration:
          BoxDecoration(
            gradient:
            const LinearGradient(
              colors: [
                AppColors.primary,
                Color(0xFF7C5CFF),
              ],
            ),
            borderRadius:
            BorderRadius.circular(
              15,
            ),
          ),
          child:
          const Icon(
            Icons.menu_book_rounded,
            color:
            Colors.white,
            size:
            26,
          ),
        ),

        const SizedBox(
          width:
          12,
        ),

        Expanded(
          child:
          Column(
            crossAxisAlignment:
            CrossAxisAlignment.start,
            children: [
              const Text(
                'Homework',
                style:
                TextStyle(
                  fontSize:
                  23,
                  fontWeight:
                  FontWeight.w900,
                ),
              ),
              Text(
                '$count homework record(s)',
                style:
                const TextStyle(
                  color:
                  AppColors
                      .textSecondary,
                  fontSize:
                  10,
                ),
              ),
            ],
          ),
        ),

        FilledButton.icon(
          onPressed:
          onAdd,
          icon:
          const Icon(
            Icons.add_rounded,
            size:
            18,
          ),
          label:
          const Text(
            'Add',
          ),
        ),
      ],
    );
  }
}

/// ===============================================================
/// SEARCH
/// ===============================================================

class _SearchBox
    extends StatelessWidget {
  final String value;
  final ValueChanged<String>
  onChanged;

  const _SearchBox({
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(
      BuildContext context,
      ) {
    return TextField(
      onChanged:
      onChanged,
      decoration:
      InputDecoration(
        hintText:
        'Search homework, subject, class...',

        prefixIcon:
        const Icon(
          Icons.search_rounded,
        ),

        suffixIcon:
        value.isEmpty
            ? null
            : IconButton(
          onPressed:
              () =>
              onChanged(
                '',
              ),
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
}

/// ===============================================================
/// FILTER
/// ===============================================================

class _FilterBar
    extends StatelessWidget {
  final String value;
  final ValueChanged<String>
  onChanged;

  const _FilterBar({
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(
      BuildContext context,
      ) {
    const filters = [
      'All',
      'Active',
      'Pending',
      'Completed',
      'Cancelled',
    ];

    return SingleChildScrollView(
      scrollDirection:
      Axis.horizontal,
      child:
      Row(
        children:
        filters.map(
              (filter) {
            final selected =
                value ==
                    filter;

            return Padding(
              padding:
              const EdgeInsets.only(
                right:
                7,
              ),
              child:
              ChoiceChip(
                label:
                Text(
                  filter,
                ),
                selected:
                selected,
                onSelected:
                    (_) =>
                    onChanged(
                      filter,
                    ),
              ),
            );
          },
        ).toList(),
      ),
    );
  }
}

/// ===============================================================
/// METRICS
/// ===============================================================

class _Metrics
    extends StatelessWidget {
  final int total;
  final int active;
  final int pending;
  final int overdue;

  const _Metrics({
    required this.total,
    required this.active,
    required this.pending,
    required this.overdue,
  });

  @override
  Widget build(
      BuildContext context,
      ) {
    final metrics = [
      _Metric(
        'Total',
        '$total',
        'All homework',
        Icons.grid_view_rounded,
        AppColors.primary,
      ),
      _Metric(
        'Active',
        '$active',
        'Currently active',
        Icons.check_circle_outline_rounded,
        AppColors.success,
      ),
      _Metric(
        'Pending',
        '$pending',
        'Needs attention',
        Icons.schedule_rounded,
        AppColors.warning,
      ),
      _Metric(
        'Overdue',
        '$overdue',
        'Past due',
        Icons.warning_amber_rounded,
        AppColors.error,
      ),
    ];

    return LayoutBuilder(
      builder:
          (_, constraints) {
        final columns =
        constraints.maxWidth >=
            900
            ? 4
            : constraints.maxWidth >=
            560
            ? 2
            : 1;

        return GridView.builder(
          shrinkWrap:
          true,
          physics:
          const NeverScrollableScrollPhysics(),

          itemCount:
          metrics.length,

          gridDelegate:
          SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount:
            columns,
            crossAxisSpacing:
            9,
            mainAxisSpacing:
            9,
            mainAxisExtent:
            94,
          ),

          itemBuilder:
              (_, index) =>
              _MetricCard(
                metric:
                metrics[index],
              ),
        );
      },
    );
  }
}

class _Metric {
  final String title;
  final String value;
  final String detail;
  final IconData icon;
  final Color color;

  const _Metric(
      this.title,
      this.value,
      this.detail,
      this.icon,
      this.color,
      );
}

class _MetricCard
    extends StatelessWidget {
  final _Metric metric;

  const _MetricCard({
    required this.metric,
  });

  @override
  Widget build(
      BuildContext context,
      ) {
    return Container(
      padding:
      const EdgeInsets.all(
        12,
      ),

      decoration:
      BoxDecoration(
        color:
        Colors.white,
        borderRadius:
        BorderRadius.circular(
          16,
        ),
        border:
        Border.all(
          color:
          AppColors.border,
        ),
      ),

      child:
      Row(
        children: [
          Container(
            width:
            40,
            height:
            40,
            decoration:
            BoxDecoration(
              color:
              metric.color
                  .withOpacity(
                .10,
              ),
              borderRadius:
              BorderRadius.circular(
                11,
              ),
            ),
            child:
            Icon(
              metric.icon,
              color:
              metric.color,
              size:
              19,
            ),
          ),

          const SizedBox(
            width:
            9,
          ),

          Expanded(
            child:
            Column(
              crossAxisAlignment:
              CrossAxisAlignment.start,
              mainAxisAlignment:
              MainAxisAlignment.center,
              children: [
                Text(
                  metric.title,
                  style:
                  const TextStyle(
                    color:
                    AppColors
                        .textSecondary,
                    fontSize:
                    9,
                  ),
                ),
                Text(
                  metric.value,
                  style:
                  const TextStyle(
                    fontSize:
                    19,
                    fontWeight:
                    FontWeight.w900,
                  ),
                ),
                Text(
                  metric.detail,
                  maxLines:
                  1,
                  overflow:
                  TextOverflow.ellipsis,
                  style:
                  TextStyle(
                    color:
                    metric.color,
                    fontSize:
                    8,
                    fontWeight:
                    FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// ===============================================================
/// HOMEWORK CARD
/// ===============================================================

class _HomeworkCard
    extends StatelessWidget {
  final Map<String, dynamic>
  item;

  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _HomeworkCard({
    required this.item,
    required this.onEdit,
    required this.onDelete,
  });

  String _date(
      dynamic value,
      ) {
    final date =
    DateTime.tryParse(
      value?.toString() ??
          '',
    );

    if (date == null) {
      return '--';
    }

    return '${date.day.toString().padLeft(2, '0')}/'
        '${date.month.toString().padLeft(2, '0')}/'
        '${date.year}';
  }

  Color _statusColor(
      String status,
      ) {
    switch (
    status.toLowerCase()) {
      case 'active':
        return AppColors.success;

      case 'pending':
        return AppColors.warning;

      case 'completed':
        return AppColors.info;

      case 'cancelled':
        return AppColors.error;

      default:
        return AppColors
            .textSecondary;
    }
  }

  @override
  Widget build(
      BuildContext context,
      ) {
    final title =
    item['title']
        ?.toString()
        .trim()
        .isNotEmpty ==
        true
        ? item['title'].toString()
        : 'Untitled Homework';

    final description =
        item['description']
            ?.toString()
            .trim() ??
            '';

    final subject =
        item['subject']
            ?.toString()
            .trim() ??
            '';

    final className =
        item['assigned_class']
            ?.toString()
            .trim() ??
            '';

    final section =
        item['assigned_section']
            ?.toString()
            .trim() ??
            '';

    final status =
        item['status']
            ?.toString()
            .trim() ??
            '';

    final statusColor =
    _statusColor(
      status,
    );

    return Padding(
      padding:
      const EdgeInsets.only(
        bottom:
        9,
      ),

      child:
      Material(
        color:
        Colors.white,

        borderRadius:
        BorderRadius.circular(
          18,
        ),

        child:
        InkWell(
          onTap:
          onEdit,

          borderRadius:
          BorderRadius.circular(
            18,
          ),

          child:
          Container(
            padding:
            const EdgeInsets.all(
              13,
            ),

            decoration:
            BoxDecoration(
              borderRadius:
              BorderRadius.circular(
                18,
              ),

              border:
              Border.all(
                color:
                AppColors.border,
              ),
            ),

            child:
            Row(
              crossAxisAlignment:
              CrossAxisAlignment.start,

              children: [
                Container(
                  width:
                  45,
                  height:
                  45,

                  decoration:
                  BoxDecoration(
                    color:
                    AppColors
                        .primary
                        .withOpacity(
                      .09,
                    ),
                    borderRadius:
                    BorderRadius.circular(
                      13,
                    ),
                  ),

                  child:
                  const Icon(
                    Icons.menu_book_rounded,
                    color:
                    AppColors.primary,
                    size:
                    21,
                  ),
                ),

                const SizedBox(
                  width:
                  11,
                ),

                Expanded(
                  child:
                  Column(
                    crossAxisAlignment:
                    CrossAxisAlignment
                        .start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child:
                            Text(
                              title,
                              maxLines:
                              1,
                              overflow:
                              TextOverflow
                                  .ellipsis,
                              style:
                              const TextStyle(
                                fontSize:
                                12,
                                fontWeight:
                                FontWeight
                                    .w900,
                              ),
                            ),
                          ),

                          if (status
                              .isNotEmpty)
                            Container(
                              padding:
                              const EdgeInsets
                                  .symmetric(
                                horizontal:
                                7,
                                vertical:
                                4,
                              ),
                              decoration:
                              BoxDecoration(
                                color:
                                statusColor
                                    .withOpacity(
                                  .10,
                                ),
                                borderRadius:
                                BorderRadius.circular(
                                  20,
                                ),
                              ),
                              child:
                              Text(
                                _capitalize(
                                  status,
                                ),
                                style:
                                TextStyle(
                                  color:
                                  statusColor,
                                  fontSize:
                                  7.5,
                                  fontWeight:
                                  FontWeight
                                      .w900,
                                ),
                              ),
                            ),
                        ],
                      ),

                      if (description
                          .isNotEmpty)
                        Padding(
                          padding:
                          const EdgeInsets
                              .only(
                            top:
                            3,
                          ),
                          child:
                          Text(
                            description,
                            maxLines:
                            2,
                            overflow:
                            TextOverflow
                                .ellipsis,
                            style:
                            const TextStyle(
                              color:
                              AppColors
                                  .textSecondary,
                              fontSize:
                              9,
                              height:
                              1.25,
                            ),
                          ),
                        ),

                      const SizedBox(
                        height:
                        8,
                      ),

                      Wrap(
                        spacing:
                        11,
                        runSpacing:
                        5,
                        children: [
                          if (subject
                              .isNotEmpty)
                            _Info(
                              icon:
                              Icons.book_outlined,
                              text:
                              subject,
                            ),

                          if (className
                              .isNotEmpty)
                            _Info(
                              icon:
                              Icons.class_outlined,
                              text:
                              section.isEmpty
                                  ? className
                                  : '$className • $section',
                            ),

                          _Info(
                            icon:
                            Icons.calendar_today_outlined,
                            text:
                            'Assigned ${_date(item['assigned_date'])}',
                          ),

                          if (item['due_date'] !=
                              null)
                            _Info(
                              icon:
                              Icons.event_available_outlined,
                              text:
                              'Due ${_date(item['due_date'])}',
                            ),
                        ],
                      ),
                    ],
                  ),
                ),

                PopupMenuButton<String>(
                  tooltip:
                  'Homework options',

                  onSelected:
                      (value) {
                    if (value ==
                        'edit') {
                      onEdit();
                    }

                    if (value ==
                        'delete') {
                      onDelete();
                    }
                  },

                  itemBuilder:
                      (_) =>
                  const [
                    PopupMenuItem(
                      value:
                      'edit',
                      child:
                      Text(
                        'Edit',
                      ),
                    ),
                    PopupMenuItem(
                      value:
                      'delete',
                      child:
                      Text(
                        'Delete',
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// ===============================================================
/// INFO
/// ===============================================================

class _Info
    extends StatelessWidget {
  final IconData icon;
  final String text;

  const _Info({
    required this.icon,
    required this.text,
  });

  @override
  Widget build(
      BuildContext context,
      ) {
    return Row(
      mainAxisSize:
      MainAxisSize.min,
      children: [
        Icon(
          icon,
          size:
          12,
          color:
          AppColors
              .textSecondary,
        ),
        const SizedBox(
          width:
          3,
        ),
        Text(
          text,
          style:
          const TextStyle(
            color:
            AppColors
                .textSecondary,
            fontSize:
            8,
            fontWeight:
            FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

/// ===============================================================
/// DIALOG FIELD
/// ===============================================================

class _DialogField
    extends StatelessWidget {
  final TextEditingController
  controller;

  final String label;
  final IconData icon;
  final int maxLines;

  const _DialogField({
    required this.controller,
    required this.label,
    required this.icon,
    this.maxLines = 1,
  });

  @override
  Widget build(
      BuildContext context,
      ) {
    return TextField(
      controller:
      controller,

      maxLines:
      maxLines,

      textCapitalization:
      TextCapitalization
          .sentences,

      decoration:
      InputDecoration(
        labelText:
        label,

        alignLabelWithHint:
        maxLines > 1,

        prefixIcon:
        Icon(
          icon,
        ),
      ),
    );
  }
}

/// ===============================================================
/// DATE TILE
/// ===============================================================

class _DateTile
    extends StatelessWidget {
  final String label;
  final DateTime? date;
  final IconData icon;
  final VoidCallback onTap;

  final bool optional;
  final VoidCallback? onClear;

  const _DateTile({
    required this.label,
    required this.date,
    required this.icon,
    required this.onTap,
    this.optional = false,
    this.onClear,
  });

  @override
  Widget build(
      BuildContext context,
      ) {
    return InkWell(
      borderRadius:
      BorderRadius.circular(
        13,
      ),

      onTap:
      onTap,

      child:
      Container(
        padding:
        const EdgeInsets.all(
          13,
        ),

        decoration:
        BoxDecoration(
          border:
          Border.all(
            color:
            AppColors.border,
          ),

          borderRadius:
          BorderRadius.circular(
            13,
          ),
        ),

        child:
        Row(
          children: [
            Icon(
              icon,
              color:
              AppColors.primary,
              size:
              20,
            ),

            const SizedBox(
              width:
              10,
            ),

            Expanded(
              child:
              Column(
                crossAxisAlignment:
                CrossAxisAlignment
                    .start,
                children: [
                  Text(
                    label,
                    style:
                    const TextStyle(
                      color:
                      AppColors
                          .textSecondary,
                      fontSize:
                      8.5,
                    ),
                  ),

                  const SizedBox(
                    height:
                    2,
                  ),

                  Text(
                    date == null
                        ? optional
                        ? 'Not set'
                        : 'Select date'
                        : _displayDate(
                      date!,
                    ),
                    style:
                    const TextStyle(
                      fontSize:
                      11,
                      fontWeight:
                      FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),

            if (onClear != null)
              IconButton(
                onPressed:
                onClear,
                icon:
                const Icon(
                  Icons.clear_rounded,
                  size:
                  18,
                ),
              )
            else
              const Icon(
                Icons.chevron_right_rounded,
                color:
                AppColors
                    .textSecondary,
              ),
          ],
        ),
      ),
    );
  }
}

/// ===============================================================
/// EMPTY
/// ===============================================================

class _EmptyState
    extends StatelessWidget {
  final bool searched;
  final VoidCallback onAdd;

  const _EmptyState({
    required this.searched,
    required this.onAdd,
  });

  @override
  Widget build(
      BuildContext context,
      ) {
    return Container(
      padding:
      const EdgeInsets.all(
        30,
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
      Column(
        children: [
          Icon(
            searched
                ? Icons.search_off_rounded
                : Icons.menu_book_outlined,
            size:
            44,
            color:
            AppColors
                .textSecondary,
          ),

          const SizedBox(
            height:
            10,
          ),

          Text(
            searched
                ? 'No matching homework found.'
                : 'No homework has been added yet.',
            textAlign:
            TextAlign.center,
            style:
            const TextStyle(
              fontSize:
              13,
              fontWeight:
              FontWeight.w800,
            ),
          ),

          const SizedBox(
            height:
            5,
          ),

          Text(
            searched
                ? 'Try another search or filter.'
                : 'Add the first homework to your school.',
            textAlign:
            TextAlign.center,
            style:
            const TextStyle(
              color:
              AppColors
                  .textSecondary,
              fontSize:
              9.5,
            ),
          ),

          if (!searched)
            Padding(
              padding:
              const EdgeInsets.only(
                top:
                14,
              ),
              child:
              FilledButton.tonal(
                onPressed:
                onAdd,
                child:
                const Text(
                  'Add Homework',
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// ===============================================================
/// LOADING
/// ===============================================================

class _Loading
    extends StatelessWidget {
  const _Loading();

  @override
  Widget build(
      BuildContext context,
      ) {
    return const Center(
      child:
      CircularProgressIndicator(
        strokeWidth:
        2,
      ),
    );
  }
}

/// ===============================================================
/// ERROR
/// ===============================================================

class _ErrorState
    extends StatelessWidget {
  final String message;

  final Future<void> Function()
  onRetry;

  const _ErrorState({
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
            20,
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
                42,
              ),

              const SizedBox(
                height:
                10,
              ),

              const Text(
                'Unable to load homework',
                style:
                TextStyle(
                  fontSize:
                  15,
                  fontWeight:
                  FontWeight.w900,
                ),
              ),

              const SizedBox(
                height:
                7,
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
                14,
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

/// ===============================================================
/// UTILITIES
/// ===============================================================

String _formatDate(
    DateTime date,
    ) {
  return '${date.year}-'
      '${date.month.toString().padLeft(2, '0')}-'
      '${date.day.toString().padLeft(2, '0')}';
}

String _displayDate(
    DateTime date,
    ) {
  return '${date.day.toString().padLeft(2, '0')}/'
      '${date.month.toString().padLeft(2, '0')}/'
      '${date.year}';
}

String _capitalize(
    String value,
    ) {
  if (value.isEmpty) {
    return value;
  }

  return value[0].toUpperCase() +
      value.substring(1);
}

String _status(
    Map<String, dynamic> item,
    ) {
  return item['status']
      ?.toString()
      .trim()
      .toLowerCase() ??
      '';
}