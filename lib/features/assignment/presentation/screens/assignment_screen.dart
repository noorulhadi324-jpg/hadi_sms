import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/network/supabase_client.dart';

class AssignmentsScreen extends StatefulWidget {
  const AssignmentsScreen({super.key});

  @override
  State<AssignmentsScreen> createState() =>
      _AssignmentsScreenState();
}

class _AssignmentsScreenState
    extends State<AssignmentsScreen> {
  final SupabaseClient _client =
      SupabaseConfig.client;

  List<Map<String, dynamic>> _assignments = [];

  bool _loading = true;
  bool _saving = false;

  String _search = '';

  int? _schoolId;

  @override
  void initState() {
    super.initState();
    _loadAssignments();
  }

  // ============================================================
  // SCHOOL ID
  // ============================================================

  Future<int?> _getSchoolId() async {
    try {
      final result = await _client.rpc(
        'get_my_school_id',
      );

      if (result is int) {
        return result;
      }

      if (result is num) {
        return result.toInt();
      }

      return int.tryParse(
        result?.toString() ?? '',
      );
    } catch (e) {
      debugPrint(
        'get_my_school_id error: $e',
      );

      return null;
    }
  }

  // ============================================================
  // LOAD ASSIGNMENTS
  // ============================================================

  Future<void> _loadAssignments() async {
    if (mounted) {
      setState(() {
        _loading = true;
      });
    }

    try {
      final schoolId =
      await _getSchoolId();

      if (schoolId == null) {
        throw Exception(
          'Your account is not linked to a school.',
        );
      }

      final response = await _client
          .from('assignments')
          .select(
        'id, school_id, title, description, subject, '
            'assigned_class, assigned_section, assigned_date, '
            'due_date, status, created_by, created_at, updated_at',
      )
          .eq(
        'school_id',
        schoolId,
      )
          .order(
        'assigned_date',
        ascending: false,
      );

      if (!mounted) return;

      setState(() {
        _schoolId = schoolId;

        _assignments =
        List<Map<String, dynamic>>.from(
          response,
        );

        _loading = false;
      });
    } on PostgrestException catch (e) {
      debugPrint(
        'Assignments DB error: ${e.message}',
      );

      if (!mounted) return;

      setState(() {
        _loading = false;
      });

      _showError(
        e.message,
      );
    } catch (e) {
      debugPrint(
        'Assignments load error: $e',
      );

      if (!mounted) return;

      setState(() {
        _loading = false;
      });

      _showError(
        e.toString().replaceFirst(
          'Exception: ',
          '',
        ),
      );
    }
  }

  // ============================================================
  // ADD / EDIT ASSIGNMENT
  // ============================================================

  Future<void> _openAssignmentDialog({
    Map<String, dynamic>? assignment,
  }) async {
    final titleController =
    TextEditingController(
      text:
      assignment?['title']?.toString() ?? '',
    );

    final descriptionController =
    TextEditingController(
      text:
      assignment?['description']?.toString() ?? '',
    );

    final subjectController =
    TextEditingController(
      text:
      assignment?['subject']?.toString() ?? '',
    );

    final classController =
    TextEditingController(
      text:
      assignment?['assigned_class']?.toString() ?? '',
    );

    final sectionController =
    TextEditingController(
      text:
      assignment?['assigned_section']?.toString() ?? '',
    );

    DateTime assignedDate =
        _parseDate(
          assignment?['assigned_date'],
        ) ??
            DateTime.now();

    DateTime? dueDate =
    _parseDate(
      assignment?['due_date'],
    );

    String status =
        assignment?['status']?.toString() ??
            'active';

    if (![
      'active',
      'pending',
      'completed',
      'cancelled',
    ].contains(status)) {
      status = 'active';
    }

    final bool isEditing =
        assignment != null;

    await showDialog(
      context: context,
      barrierDismissible: !_saving,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (
              context,
              setDialogState,
              ) {
            return AlertDialog(
              title: Text(
                isEditing
                    ? 'Edit Assignment'
                    : 'Add Assignment',
                style: const TextStyle(
                  fontWeight:
                  FontWeight.w800,
                ),
              ),

              content: SizedBox(
                width: 520,

                child:
                SingleChildScrollView(
                  child: Column(
                    mainAxisSize:
                    MainAxisSize.min,
                    children: [
                      // TITLE
                      TextField(
                        controller:
                        titleController,
                        textCapitalization:
                        TextCapitalization
                            .sentences,
                        decoration:
                        const InputDecoration(
                          labelText:
                          'Assignment Title',
                          prefixIcon:
                          Icon(
                            Icons
                                .assignment_outlined,
                          ),
                        ),
                      ),

                      const SizedBox(
                        height: 14,
                      ),

                      // DESCRIPTION
                      TextField(
                        controller:
                        descriptionController,
                        maxLines: 4,
                        textCapitalization:
                        TextCapitalization
                            .sentences,
                        decoration:
                        const InputDecoration(
                          labelText:
                          'Description',
                          alignLabelWithHint:
                          true,
                          prefixIcon:
                          Icon(
                            Icons
                                .description_outlined,
                          ),
                        ),
                      ),

                      const SizedBox(
                        height: 14,
                      ),

                      // SUBJECT
                      TextField(
                        controller:
                        subjectController,
                        decoration:
                        const InputDecoration(
                          labelText:
                          'Subject',
                          prefixIcon:
                          Icon(
                            Icons
                                .menu_book_outlined,
                          ),
                        ),
                      ),

                      const SizedBox(
                        height: 14,
                      ),

                      // CLASS + SECTION
                      Row(
                        children: [
                          Expanded(
                            child:
                            TextField(
                              controller:
                              classController,
                              decoration:
                              const InputDecoration(
                                labelText:
                                'Class',
                                prefixIcon:
                                Icon(
                                  Icons
                                      .class_outlined,
                                ),
                              ),
                            ),
                          ),

                          const SizedBox(
                            width: 12,
                          ),

                          Expanded(
                            child:
                            TextField(
                              controller:
                              sectionController,
                              decoration:
                              const InputDecoration(
                                labelText:
                                'Section',
                                prefixIcon:
                                Icon(
                                  Icons
                                      .category_outlined,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(
                        height: 14,
                      ),

                      // ASSIGNED DATE
                      _dateTile(
                        label:
                        'Assigned Date',
                        date:
                        assignedDate,
                        icon: Icons
                            .calendar_today_outlined,
                        onTap:
                            () async {
                          final selected =
                          await showDatePicker(
                            context:
                            context,
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

                          setDialogState(() {
                            assignedDate =
                                selected;
                          });
                        },
                      ),

                      const SizedBox(
                        height: 10,
                      ),

                      // DUE DATE
                      _dateTile(
                        label:
                        dueDate == null
                            ? 'Due Date'
                            : 'Due Date',
                        date:
                        dueDate,
                        icon: Icons
                            .event_available_outlined,
                        optional: true,
                        onTap:
                            () async {
                          final selected =
                          await showDatePicker(
                            context:
                            context,
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

                          setDialogState(() {
                            dueDate =
                                selected;
                          });
                        },
                        onClear:
                        dueDate != null
                            ? () {
                          setDialogState(
                                () {
                              dueDate =
                              null;
                            },
                          );
                        }
                            : null,
                      ),

                      const SizedBox(
                        height: 14,
                      ),

                      // STATUS
                      DropdownButtonFormField<
                          String>(
                        value: status,

                        decoration:
                        const InputDecoration(
                          labelText:
                          'Status',
                          prefixIcon:
                          Icon(
                            Icons
                                .flag_outlined,
                          ),
                        ),

                        items: const [
                          DropdownMenuItem(
                            value: 'active',
                            child: Text(
                              'Active',
                            ),
                          ),
                          DropdownMenuItem(
                            value: 'pending',
                            child: Text(
                              'Pending',
                            ),
                          ),
                          DropdownMenuItem(
                            value: 'completed',
                            child: Text(
                              'Completed',
                            ),
                          ),
                          DropdownMenuItem(
                            value: 'cancelled',
                            child: Text(
                              'Cancelled',
                            ),
                          ),
                        ],

                        onChanged:
                            (value) {
                          if (value ==
                              null) {
                            return;
                          }

                          setDialogState(() {
                            status =
                                value;
                          });
                        },
                      ),
                    ],
                  ),
                ),
              ),

              actions: [
                TextButton(
                  onPressed:
                  _saving
                      ? null
                      : () {
                    Navigator.pop(
                      dialogContext,
                    );
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

                    if (title
                        .isEmpty) {
                      _showError(
                        'Assignment title is required.',
                      );
                      return;
                    }

                    setDialogState(() {
                      _saving =
                      true;
                    });

                    try {
                      await _saveAssignment(
                        assignment:
                        assignment,
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
                        classController
                            .text
                            .trim(),
                        assignedSection:
                        sectionController
                            .text
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

                      Navigator.pop(
                        dialogContext,
                      );

                      _showSuccess(
                        assignment ==
                            null
                            ? 'Assignment added successfully.'
                            : 'Assignment updated successfully.',
                      );
                    } catch (e) {
                      if (!mounted) {
                        return;
                      }

                      setDialogState(() {
                        _saving =
                        false;
                      });

                      _showError(
                        e.toString()
                            .replaceFirst(
                          'Exception: ',
                          '',
                        ),
                      );
                    }
                  },

                  child: _saving
                      ? const SizedBox(
                    width: 20,
                    height: 20,
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
    classController.dispose();
    sectionController.dispose();
  }

  // ============================================================
  // SAVE
  // ============================================================

  Future<void> _saveAssignment({
    Map<String, dynamic>? assignment,
    required String title,
    required String description,
    required String subject,
    required String assignedClass,
    required String assignedSection,
    required DateTime assignedDate,
    required DateTime? dueDate,
    required String status,
  }) async {
    final schoolId =
        _schoolId ?? await _getSchoolId();

    if (schoolId == null) {
      throw Exception(
        'Your account is not linked to a school.',
      );
    }

    final currentUser =
        _client.auth.currentUser;

    if (currentUser == null) {
      throw Exception(
        'No authenticated user found.',
      );
    }

    final data = {
      'school_id': schoolId,

      'title': title,

      'description':
      description.isEmpty
          ? null
          : description,

      'subject':
      subject.isEmpty
          ? null
          : subject,

      'assigned_class':
      assignedClass.isEmpty
          ? null
          : assignedClass,

      'assigned_section':
      assignedSection.isEmpty
          ? null
          : assignedSection,

      'assigned_date':
      _formatDate(
        assignedDate,
      ),

      'due_date': dueDate == null
          ? null
          : _formatDate(
        dueDate,
      ),

      'status': status,

      'updated_at':
      DateTime.now()
          .toUtc()
          .toIso8601String(),
    };

    // ==========================================================
    // UPDATE
    // ==========================================================

    if (assignment != null) {
      final id =
      assignment['id'];

      if (id == null) {
        throw Exception(
          'Assignment ID is missing.',
        );
      }

      await _client
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

      await _loadAssignments();

      return;
    }

    // ==========================================================
    // INSERT
    // ==========================================================

    data['created_by'] =
        currentUser.id;

    await _client
        .from('assignments')
        .insert(data);

    await _loadAssignments();
  }

  // ============================================================
  // DELETE
  // ============================================================

  Future<void> _deleteAssignment(
      Map<String, dynamic> assignment,
      ) async {
    final confirmed =
    await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text(
            'Delete Assignment?',
            style: TextStyle(
              fontWeight:
              FontWeight.w800,
            ),
          ),

          content: Text(
            'Are you sure you want to delete '
                '"${assignment['title'] ?? 'this assignment'}"?',
          ),

          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(
                  dialogContext,
                  false,
                );
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

              onPressed: () {
                Navigator.pop(
                  dialogContext,
                  true,
                );
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
      final schoolId =
          _schoolId ??
              await _getSchoolId();

      if (schoolId == null) {
        throw Exception(
          'Your account is not linked to a school.',
        );
      }

      final id =
      assignment['id'];

      if (id == null) {
        throw Exception(
          'Assignment ID is missing.',
        );
      }

      await _client
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

      await _loadAssignments();

      if (!mounted) return;

      _showSuccess(
        'Assignment deleted successfully.',
      );
    } on PostgrestException catch (e) {
      if (!mounted) return;

      _showError(
        e.message,
      );
    } catch (e) {
      if (!mounted) return;

      _showError(
        e.toString().replaceFirst(
          'Exception: ',
          '',
        ),
      );
    }
  }

  // ============================================================
  // SEARCH
  // ============================================================

  List<Map<String, dynamic>>
  get _filteredAssignments {
    final query =
    _search.trim().toLowerCase();

    if (query.isEmpty) {
      return _assignments;
    }

    return _assignments.where(
          (item) {
        final title =
            item['title']
                ?.toString()
                .toLowerCase() ??
                '';

        final description =
            item['description']
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

        return title.contains(query) ||
            description.contains(query) ||
            subject.contains(query) ||
            className.contains(query) ||
            section.contains(query) ||
            status.contains(query);
      },
    ).toList();
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(
      BuildContext context,
      ) {
    final filtered =
        _filteredAssignments;

    final activeCount =
        _assignments.where(
              (a) =>
          a['status']?.toString() ==
              'active',
        ).length;

    final pendingCount =
        _assignments.where(
              (a) =>
          a['status']?.toString() ==
              'pending',
        ).length;

    final completedCount =
        _assignments.where(
              (a) =>
          a['status']?.toString() ==
              'completed',
        ).length;

    return Scaffold(
      backgroundColor:
      AppColors.background,

      body: RefreshIndicator(
        onRefresh:
        _loadAssignments,

        child: CustomScrollView(
          physics:
          const AlwaysScrollableScrollPhysics(),

          slivers: [
            SliverPadding(
              padding:
              const EdgeInsets.fromLTRB(
                24,
                28,
                24,
                10,
              ),

              sliver:
              SliverToBoxAdapter(
                child:
                _buildHeader(),
              ),
            ),

            SliverPadding(
              padding:
              const EdgeInsets.symmetric(
                horizontal: 24,
              ),

              sliver:
              SliverToBoxAdapter(
                child:
                _buildMetrics(
                  activeCount,
                  pendingCount,
                  completedCount,
                ),
              ),
            ),

            SliverPadding(
              padding:
              const EdgeInsets.fromLTRB(
                24,
                24,
                24,
                10,
              ),

              sliver:
              SliverToBoxAdapter(
                child:
                _buildSearch(),
              ),
            ),

            if (_loading)
              const SliverFillRemaining(
                hasScrollBody:
                false,

                child: Center(
                  child:
                  CircularProgressIndicator(),
                ),
              )
            else if (filtered.isEmpty)
              SliverFillRemaining(
                hasScrollBody:
                false,

                child:
                _buildEmptyState(),
              )
            else
              SliverPadding(
                padding:
                const EdgeInsets.fromLTRB(
                  24,
                  12,
                  24,
                  40,
                ),

                sliver:
                SliverList.builder(
                  itemCount:
                  filtered.length,

                  itemBuilder:
                      (context, index) {
                    return _buildAssignmentCard(
                      filtered[index],
                    );
                  },
                ),
              ),
          ],
        ),
      ),

      floatingActionButton:
      FloatingActionButton.extended(
        onPressed: _loading
            ? null
            : () =>
            _openAssignmentDialog(),

        icon: const Icon(
          Icons.add_rounded,
        ),

        label:
        const Text(
          'Add Assignment',
        ),
      ),
    );
  }

  // ============================================================
  // HEADER
  // ============================================================

  Widget _buildHeader() {
    return Row(
      crossAxisAlignment:
      CrossAxisAlignment.start,

      children: [
        const Expanded(
          child: Column(
            crossAxisAlignment:
            CrossAxisAlignment.start,

            children: [
              Text(
                'Assignments',

                style: TextStyle(
                  fontSize: 28,
                  fontWeight:
                  FontWeight.w900,
                  letterSpacing: -0.7,
                ),
              ),

              SizedBox(
                height: 6,
              ),

              Text(
                'Create, review and track student assignments.',

                style: TextStyle(
                  color:
                  AppColors.textSecondary,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),

        IconButton(
          tooltip: 'Refresh',

          onPressed:
          _loadAssignments,

          icon: const Icon(
            Icons.refresh_rounded,
          ),
        ),
      ],
    );
  }

  // ============================================================
  // METRICS
  // ============================================================

  Widget _buildMetrics(
      int active,
      int pending,
      int completed,
      ) {
    return LayoutBuilder(
      builder:
          (context, constraints) {
        final cards = [
          _metricCard(
            'Total',
            _assignments.length
                .toString(),
            'All assignments',
            Icons.assignment_rounded,
            AppColors.primary,
          ),

          _metricCard(
            'Active',
            active.toString(),
            'Currently active',
            Icons
                .check_circle_outline_rounded,
            AppColors.success,
          ),

          _metricCard(
            'Pending',
            pending.toString(),
            'Needs attention',
            Icons.schedule_rounded,
            const Color(
              0xFFF59E0B,
            ),
          ),

          _metricCard(
            'Completed',
            completed.toString(),
            'Finished',
            Icons
                .task_alt_rounded,
            const Color(
              0xFF2563EB,
            ),
          ),
        ];

        if (constraints.maxWidth >=
            800) {
          return Row(
            children: [
              for (int i = 0;
              i < cards.length;
              i++) ...[
                Expanded(
                  child:
                  cards[i],
                ),

                if (i !=
                    cards.length - 1)
                  const SizedBox(
                    width: 14,
                  ),
              ],
            ],
          );
        }

        return Wrap(
          spacing: 14,
          runSpacing: 14,
          children:
          cards.map(
                (card) {
              return SizedBox(
                width:
                (constraints.maxWidth -
                    14) /
                    2,
                child: card,
              );
            },
          ).toList(),
        );
      },
    );
  }

  // ============================================================
  // METRIC CARD
  // ============================================================

  Widget _metricCard(
      String title,
      String value,
      String subtitle,
      IconData icon,
      Color color,
      ) {
    return Card(
      child: Padding(
        padding:
        const EdgeInsets.all(
          18,
        ),

        child: Row(
          children: [
            Container(
              width: 46,
              height: 46,

              decoration:
              BoxDecoration(
                color:
                color.withOpacity(
                  .10,
                ),

                borderRadius:
                BorderRadius.circular(
                  14,
                ),
              ),

              child: Icon(
                icon,
                color: color,
              ),
            ),

            const SizedBox(
              width: 12,
            ),

            Expanded(
              child: Column(
                crossAxisAlignment:
                CrossAxisAlignment.start,

                children: [
                  Text(
                    title,

                    style:
                    const TextStyle(
                      fontSize: 11,
                      fontWeight:
                      FontWeight.w700,
                    ),
                  ),

                  const SizedBox(
                    height: 2,
                  ),

                  Text(
                    value,

                    style:
                    const TextStyle(
                      fontSize: 22,
                      fontWeight:
                      FontWeight.w900,
                    ),
                  ),

                  Text(
                    subtitle,

                    style: const TextStyle(
                      fontSize: 10,
                      color:
                      AppColors
                          .textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // SEARCH
  // ============================================================

  Widget _buildSearch() {
    return TextField(
      onChanged:
          (value) {
        setState(() {
          _search =
              value;
        });
      },

      decoration:
      InputDecoration(
        hintText:
        'Search assignments, subject, class...',

        prefixIcon:
        const Icon(
          Icons.search_rounded,
        ),

        suffixIcon:
        _search.isNotEmpty
            ? IconButton(
          onPressed:
              () {
            setState(() {
              _search =
              '';
            });
          },
          icon:
          const Icon(
            Icons
                .clear_rounded,
          ),
        )
            : null,
      ),
    );
  }

  // ============================================================
  // ASSIGNMENT CARD
  // ============================================================

  Widget _buildAssignmentCard(
      Map<String, dynamic> item,
      ) {
    final title =
        item['title']
            ?.toString()
            .trim() ??
            'Untitled Assignment';

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
            ?.toString() ??
            'active';

    final assignedDate =
    _parseDate(
      item['assigned_date'],
    );

    final dueDate =
    _parseDate(
      item['due_date'],
    );

    final statusColor =
    _statusColor(
      status,
    );

    return Card(
      margin:
      const EdgeInsets.only(
        bottom: 14,
      ),

      child: Padding(
        padding:
        const EdgeInsets.all(
          18,
        ),

        child: Column(
          crossAxisAlignment:
          CrossAxisAlignment.start,

          children: [
            Row(
              crossAxisAlignment:
              CrossAxisAlignment.start,

              children: [
                Container(
                  width: 46,
                  height: 46,

                  decoration:
                  BoxDecoration(
                    color:
                    AppColors.primary
                        .withOpacity(
                      .10,
                    ),

                    borderRadius:
                    BorderRadius.circular(
                      14,
                    ),
                  ),

                  child:
                  const Icon(
                    Icons
                        .assignment_rounded,
                    color:
                    AppColors.primary,
                  ),
                ),

                const SizedBox(
                  width: 14,
                ),

                Expanded(
                  child: Column(
                    crossAxisAlignment:
                    CrossAxisAlignment.start,

                    children: [
                      Text(
                        title,

                        style:
                        const TextStyle(
                          fontSize: 16,
                          fontWeight:
                          FontWeight.w800,
                        ),
                      ),

                      if (subject
                          .isNotEmpty)
                        Padding(
                          padding:
                          const EdgeInsets
                              .only(
                            top: 4,
                          ),
                          child:
                          Text(
                            subject,

                            style:
                            const TextStyle(
                              color:
                              AppColors.primary,
                              fontSize:
                              12,
                              fontWeight:
                              FontWeight.w700,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),

                _statusChip(
                  status,
                  statusColor,
                ),

                PopupMenuButton<
                    String>(
                  onSelected:
                      (value) {
                    if (value ==
                        'edit') {
                      _openAssignmentDialog(
                        assignment:
                        item,
                      );
                    }

                    if (value ==
                        'delete') {
                      _deleteAssignment(
                        item,
                      );
                    }
                  },

                  itemBuilder:
                      (context) =>
                  const [
                    PopupMenuItem(
                      value:
                      'edit',
                      child:
                      ListTile(
                        contentPadding:
                        EdgeInsets.zero,
                        leading:
                        Icon(
                          Icons
                              .edit_outlined,
                        ),
                        title:
                        Text(
                          'Edit',
                        ),
                      ),
                    ),

                    PopupMenuItem(
                      value:
                      'delete',
                      child:
                      ListTile(
                        contentPadding:
                        EdgeInsets.zero,
                        leading:
                        Icon(
                          Icons
                              .delete_outline,
                        ),
                        title:
                        Text(
                          'Delete',
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),

            if (description
                .isNotEmpty) ...[
              const SizedBox(
                height: 14,
              ),

              Text(
                description,

                maxLines: 3,

                overflow:
                TextOverflow
                    .ellipsis,

                style: const TextStyle(
                  color:
                  AppColors
                      .textSecondary,
                  fontSize: 12,
                  height: 1.4,
                ),
              ),
            ],

            const SizedBox(
              height: 16,
            ),

            Wrap(
              spacing: 8,
              runSpacing: 8,

              children: [
                if (className
                    .isNotEmpty ||
                    section
                        .isNotEmpty)
                  _infoChip(
                    Icons
                        .school_outlined,
                    'Class $className'
                        '${section.isNotEmpty ? ' • $section' : ''}',
                  ),

                if (assignedDate !=
                    null)
                  _infoChip(
                    Icons
                        .calendar_today_outlined,
                    'Assigned ${_formatDisplayDate(assignedDate)}',
                  ),

                if (dueDate !=
                    null)
                  _infoChip(
                    Icons
                        .event_available_outlined,
                    'Due ${_formatDisplayDate(dueDate)}',
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // STATUS CHIP
  // ============================================================

  Widget _statusChip(
      String status,
      Color color,
      ) {
    return Container(
      padding:
      const EdgeInsets
          .symmetric(
        horizontal: 9,
        vertical: 6,
      ),

      decoration:
      BoxDecoration(
        color:
        color.withOpacity(
          .10,
        ),

        borderRadius:
        BorderRadius.circular(
          20,
        ),
      ),

      child: Text(
        status
            .toUpperCase(),

        style: TextStyle(
          color: color,
          fontSize: 9,
          fontWeight:
          FontWeight.w900,
        ),
      ),
    );
  }

  // ============================================================
  // INFO CHIP
  // ============================================================

  Widget _infoChip(
      IconData icon,
      String text,
      ) {
    return Container(
      padding:
      const EdgeInsets
          .symmetric(
        horizontal: 10,
        vertical: 7,
      ),

      decoration:
      BoxDecoration(
        color:
        AppColors.background,

        borderRadius:
        BorderRadius.circular(
          10,
        ),

        border: Border.all(
          color:
          AppColors.border,
        ),
      ),

      child: Row(
        mainAxisSize:
        MainAxisSize.min,

        children: [
          Icon(
            icon,
            size: 14,
            color:
            AppColors
                .textSecondary,
          ),

          const SizedBox(
            width: 6,
          ),

          Text(
            text,

            style:
            const TextStyle(
              fontSize: 10,
              fontWeight:
              FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // DATE TILE
  // ============================================================

  Widget _dateTile({
    required String label,
    required DateTime? date,
    required IconData icon,
    required VoidCallback onTap,
    bool optional = false,
    VoidCallback? onClear,
  }) {
    return InkWell(
      borderRadius:
      BorderRadius.circular(
        12,
      ),

      onTap: onTap,

      child: Container(
        width:
        double.infinity,

        padding:
        const EdgeInsets
            .symmetric(
          horizontal: 14,
          vertical: 13,
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
            12,
          ),
        ),

        child: Row(
          children: [
            Icon(
              icon,
              size: 20,
              color:
              AppColors.primary,
            ),

            const SizedBox(
              width: 12,
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
                      fontSize: 11,
                      fontWeight:
                      FontWeight.w700,
                    ),
                  ),

                  const SizedBox(
                    height: 3,
                  ),

                  Text(
                    date == null
                        ? optional
                        ? 'Not set'
                        : 'Select date'
                        : _formatDisplayDate(
                      date,
                    ),

                    style: TextStyle(
                      color:
                      date == null
                          ? AppColors
                          .textSecondary
                          : AppColors
                          .textPrimary,
                      fontSize: 13,
                      fontWeight:
                      FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),

            if (onClear !=
                null)
              IconButton(
                tooltip:
                'Clear date',
                onPressed:
                onClear,
                icon:
                const Icon(
                  Icons
                      .clear_rounded,
                  size: 18,
                ),
              )
            else
              const Icon(
                Icons
                    .chevron_right_rounded,
                color:
                AppColors
                    .textSecondary,
              ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // EMPTY STATE
  // ============================================================

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding:
        const EdgeInsets.all(
          30,
        ),

        child: Column(
          mainAxisSize:
          MainAxisSize.min,

          children: [
            Container(
              width: 80,
              height: 80,

              decoration:
              BoxDecoration(
                color:
                AppColors.primary
                    .withOpacity(
                  .08,
                ),
                shape:
                BoxShape.circle,
              ),

              child:
              const Icon(
                Icons
                    .assignment_outlined,
                size: 38,
                color:
                AppColors.primary,
              ),
            ),

            const SizedBox(
              height: 18,
            ),

            Text(
              _search.isEmpty
                  ? 'No assignments yet'
                  : 'No matching assignments',

              style:
              const TextStyle(
                fontSize: 19,
                fontWeight:
                FontWeight.w800,
              ),
            ),

            const SizedBox(
              height: 7,
            ),

            Text(
              _search.isEmpty
                  ? 'Create your first assignment for students.'
                  : 'Try another search term.',

              textAlign:
              TextAlign.center,

              style:
              const TextStyle(
                color:
                AppColors
                    .textSecondary,
                fontSize: 12,
              ),
            ),

            if (_search.isEmpty) ...[
              const SizedBox(
                height: 18,
              ),

              FilledButton.icon(
                onPressed:
                    () =>
                    _openAssignmentDialog(),

                icon:
                const Icon(
                  Icons.add_rounded,
                ),

                label:
                const Text(
                  'Add Assignment',
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // ============================================================
  // STATUS COLOR
  // ============================================================

  Color _statusColor(
      String status,
      ) {
    switch (status) {
      case 'active':
        return AppColors.success;

      case 'pending':
        return const Color(
          0xFFF59E0B,
        );

      case 'completed':
        return const Color(
          0xFF2563EB,
        );

      case 'cancelled':
        return AppColors.error;

      default:
        return AppColors
            .textSecondary;
    }
  }

  // ============================================================
  // DATE HELPERS
  // ============================================================

  DateTime? _parseDate(
      dynamic value,
      ) {
    if (value == null) {
      return null;
    }

    if (value is DateTime) {
      return value;
    }

    return DateTime.tryParse(
      value.toString(),
    );
  }

  String _formatDate(
      DateTime date,
      ) {
    final year =
    date.year.toString();

    final month =
    date.month
        .toString()
        .padLeft(
      2,
      '0',
    );

    final day =
    date.day
        .toString()
        .padLeft(
      2,
      '0',
    );

    return '$year-$month-$day';
  }

  String _formatDisplayDate(
      DateTime? date,
      ) {
    if (date == null) {
      return 'Not set';
    }

    final day =
    date.day
        .toString()
        .padLeft(
      2,
      '0',
    );

    final month =
    date.month
        .toString()
        .padLeft(
      2,
      '0',
    );

    return '$day/$month/${date.year}';
  }

  // ============================================================
  // SNACKBARS
  // ============================================================

  void _showSuccess(
      String message,
      ) {
    if (!mounted) return;

    ScaffoldMessenger.of(
      context,
    )
        .hideCurrentSnackBar();

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(
      SnackBar(
        content:
        Text(message),
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
    )
        .hideCurrentSnackBar();

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(
      SnackBar(
        content:
        Text(message),
        backgroundColor:
        AppColors.error,
      ),
    );
  }
}