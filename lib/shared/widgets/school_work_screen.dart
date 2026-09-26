import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/constants/app_colors.dart';
import '../../core/network/supabase_client.dart';
import '../../core/widgets/main_wrapper.dart';

class SchoolWorkScreen extends StatefulWidget {
  const SchoolWorkScreen({
    super.key,
    required this.workType,
    required this.title,
    required this.singularLabel,
    required this.icon,
  });

  final String workType;
  final String title;
  final String singularLabel;
  final IconData icon;

  @override
  State<SchoolWorkScreen> createState() => _SchoolWorkScreenState();
}

class _SchoolWorkScreenState extends State<SchoolWorkScreen> {
  final SupabaseClient _client = SupabaseConfig.client;

  bool _loading = true;
  String? _error;
  int? _schoolId;
  String _role = '';
  String _search = '';
  String _view = 'current';
  List<Map<String, dynamic>> _records = const [];
  List<Map<String, dynamic>> _classes = const [];
  List<Map<String, dynamic>> _students = const [];
  List<Map<String, dynamic>> _subjects = const [];

  bool get _canManage => const ['principal', 'staff', 'teacher'].contains(_role);

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<Map<String, dynamic>?> _loadProfile() async {
    final uid = _client.auth.currentUser?.id;
    if (uid == null) return null;
    return _client
        .from('profiles')
        .select('school_id, role, subject, assigned_class, assigned_section, is_active')
        .eq('id', uid)
        .maybeSingle();
  }

  Future<int?> _resolveSchoolId(Map<String, dynamic>? profile) async {
    try {
      final value = await _client.rpc('get_my_school_id');
      if (value is int) return value;
      if (value is num) return value.toInt();
      final parsed = int.tryParse(value?.toString() ?? '');
      if (parsed != null) return parsed;
    } catch (_) {}
    final value = profile?['school_id'];
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '');
  }

  Future<void> _load() async {
    if (!mounted) return;
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final profile = await _loadProfile();
      final schoolId = await _resolveSchoolId(profile);
      if (schoolId == null) {
        throw Exception('Your account is not linked to a school.');
      }

      final role = profile?['role']?.toString().trim().toLowerCase() ?? '';
      if (profile?['is_active'] == false) {
        throw Exception('Your account is inactive.');
      }

      final rows = await _client
          .from('assignments')
          .select(
            'id, school_id, title, description, subject, assigned_class, '
            'assigned_section, assigned_date, start_date, due_date, status, '
            'work_type, audience, created_by, created_at, updated_at',
          )
          .eq('school_id', schoolId)
          .eq('work_type', widget.workType)
          .order('start_date', ascending: false)
          .order('created_at', ascending: false);

      List<Map<String, dynamic>> students = const [];
      try {
        final result = await _client
            .from('students')
            .select('id, full_name, admission_number, class_name, section_name, is_active')
            .eq('school_id', schoolId)
            .eq('is_active', true)
            .order('full_name');
        students = List<Map<String, dynamic>>.from(result);
      } catch (_) {}

      List<Map<String, dynamic>> classes = const [];
      try {
        final result = await _client
            .from('classes')
            .select('id, name, section_name')
            .eq('school_id', schoolId)
            .order('name');
        classes = List<Map<String, dynamic>>.from(result);
      } catch (_) {}

      final teacherClass = profile?['assigned_class']?.toString().trim() ?? '';
      final teacherSection = profile?['assigned_section']?.toString().trim() ?? '';
      if (teacherClass.isNotEmpty &&
          !classes.any((row) =>
              row['name']?.toString().trim().toLowerCase() == teacherClass.toLowerCase() &&
              (row['section_name']?.toString().trim() ?? '').toLowerCase() == teacherSection.toLowerCase())) {
        classes = [
          ...classes,
          {'id': null, 'name': teacherClass, 'section_name': teacherSection.isEmpty ? null : teacherSection},
        ];
      }

      for (final student in students) {
        final className = student['class_name']?.toString().trim() ?? '';
        final section = student['section_name']?.toString().trim() ?? '';
        if (className.isEmpty) continue;
        final exists = classes.any((row) =>
            row['name']?.toString().trim().toLowerCase() == className.toLowerCase() &&
            (row['section_name']?.toString().trim() ?? '').toLowerCase() == section.toLowerCase());
        if (!exists) {
          classes = [
            ...classes,
            {'id': null, 'name': className, 'section_name': section.isEmpty ? null : section},
          ];
        }
      }

      List<Map<String, dynamic>> subjects = const [];
      try {
        final result = await _client
            .from('subjects')
            .select('id, name, code')
            .eq('school_id', schoolId)
            .order('name');
        subjects = List<Map<String, dynamic>>.from(result);
      } catch (_) {}

      final teacherSubject = profile?['subject']?.toString().trim() ?? '';
      if (teacherSubject.isNotEmpty &&
          !subjects.any((row) => row['name']?.toString().trim().toLowerCase() == teacherSubject.toLowerCase())) {
        subjects = [
          ...subjects,
          {'id': null, 'name': teacherSubject, 'code': null},
        ];
      }

      if (!mounted) return;
      setState(() {
        _schoolId = schoolId;
        _role = role;
        _records = List<Map<String, dynamic>>.from(rows);
        _students = students;
        _classes = classes;
        _subjects = subjects;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = _friendlyError(e);
        _loading = false;
      });
    }
  }

  String _friendlyError(Object error) {
    if (error is PostgrestException) return error.message;
    if (error is AuthException) return error.message;
    return error.toString().replaceFirst('Exception: ', '');
  }

  DateTime? _date(dynamic value) => DateTime.tryParse(value?.toString() ?? '');

  DateTime _day(DateTime value) => DateTime(value.year, value.month, value.day);

  String _formatDate(DateTime value) {
    String two(int n) => n.toString().padLeft(2, '0');
    return '${value.year}-${two(value.month)}-${two(value.day)}';
  }

  String _displayDate(dynamic value) {
    final d = _date(value);
    if (d == null) return '—';
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return '${d.day} ${months[d.month - 1]} ${d.year}';
  }

  String _recordState(Map<String, dynamic> row) {
    final status = row['status']?.toString().trim().toLowerCase() ?? 'active';
    if (status == 'completed' || status == 'cancelled') return 'history';
    final now = _day(DateTime.now());
    final start = _date(row['start_date'] ?? row['assigned_date']);
    final due = _date(row['due_date']);
    if (start != null && _day(start).isAfter(now)) return 'scheduled';
    if (due != null && _day(due).isBefore(now)) return 'history';
    return 'current';
  }

  List<Map<String, dynamic>> get _visibleRecords {
    final query = _search.trim().toLowerCase();
    return _records.where((row) {
      if (_recordState(row) != _view) return false;
      if (query.isEmpty) return true;
      final haystack = [
        row['title'],
        row['description'],
        row['subject'],
        row['assigned_class'],
        row['assigned_section'],
      ].map((e) => e?.toString().toLowerCase() ?? '').join(' ');
      return haystack.contains(query);
    }).toList();
  }

  List<String> get _classNames {
    final values = <String>{};
    for (final row in _classes) {
      final value = row['name']?.toString().trim() ?? '';
      if (value.isNotEmpty) values.add(value);
    }
    final result = values.toList()..sort();
    return result;
  }

  List<String> _sectionsFor(String className) {
    final values = <String>{};
    for (final row in _classes) {
      if ((row['name']?.toString().trim().toLowerCase() ?? '') != className.toLowerCase()) continue;
      final section = row['section_name']?.toString().trim() ?? '';
      if (section.isNotEmpty) values.add(section);
    }
    for (final student in _students) {
      if ((student['class_name']?.toString().trim().toLowerCase() ?? '') != className.toLowerCase()) continue;
      final section = student['section_name']?.toString().trim() ?? '';
      if (section.isNotEmpty) values.add(section);
    }
    final result = values.toList()..sort();
    return result;
  }

  List<Map<String, dynamic>> _studentsFor(String className, String section) {
    return _students.where((student) {
      final sameClass = (student['class_name']?.toString().trim().toLowerCase() ?? '') == className.toLowerCase();
      final sameSection = section.trim().isEmpty ||
          (student['section_name']?.toString().trim().toLowerCase() ?? '') == section.toLowerCase();
      return sameClass && sameSection;
    }).toList();
  }

  Future<Set<int>> _loadSelectedStudentIds(int assignmentId) async {
    try {
      final rows = await _client
          .from('assignment_students')
          .select('student_id')
          .eq('assignment_id', assignmentId);
      return List<Map<String, dynamic>>.from(rows)
          .map((row) => int.tryParse(row['student_id'].toString()))
          .whereType<int>()
          .toSet();
    } catch (_) {
      return <int>{};
    }
  }

  Future<Set<int>?> _pickStudents({
    required String className,
    required String section,
    required Set<int> selected,
  }) async {
    final options = _studentsFor(className, section);
    final working = <int>{...selected};

    return showDialog<Set<int>>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text('Select students • $className${section.isEmpty ? '' : ' - $section'}'),
          content: SizedBox(
            width: 520,
            height: 420,
            child: options.isEmpty
                ? const Center(child: Text('No active students found for this class/section.'))
                : ListView.builder(
                    itemCount: options.length,
                    itemBuilder: (context, index) {
                      final student = options[index];
                      final id = int.tryParse(student['id'].toString());
                      if (id == null) return const SizedBox.shrink();
                      return CheckboxListTile(
                        value: working.contains(id),
                        onChanged: (checked) {
                          setDialogState(() {
                            if (checked == true) {
                              working.add(id);
                            } else {
                              working.remove(id);
                            }
                          });
                        },
                        title: Text(student['full_name']?.toString() ?? 'Student'),
                        subtitle: Text('Admission: ${student['admission_number'] ?? '—'}'),
                      );
                    },
                  ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, working),
              child: Text('Use ${working.length} students'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openEditor([Map<String, dynamic>? existing]) async {
    if (!_canManage) return;

    final titleController = TextEditingController(text: existing?['title']?.toString() ?? '');
    final descriptionController = TextEditingController(text: existing?['description']?.toString() ?? '');
    final subjectController = TextEditingController(text: existing?['subject']?.toString() ?? '');

    String selectedClass = existing?['assigned_class']?.toString().trim() ?? '';
    String selectedSection = existing?['assigned_section']?.toString().trim() ?? '';
    String selectedSubject = existing?['subject']?.toString().trim() ?? '';
    String audience = existing?['audience']?.toString() == 'students' ? 'students' : 'class';
    String status = existing?['status']?.toString().trim().toLowerCase() ?? 'active';
    if (!const ['active', 'completed', 'cancelled'].contains(status)) status = 'active';

    DateTime startDate = _date(existing?['start_date'] ?? existing?['assigned_date']) ?? DateTime.now();
    DateTime dueDate = _date(existing?['due_date']) ?? startDate.add(const Duration(days: 1));
    Set<int> selectedStudentIds = <int>{};
    if (existing != null && audience == 'students') {
      final id = int.tryParse(existing['id'].toString());
      if (id != null) selectedStudentIds = await _loadSelectedStudentIds(id);
    }
    if (!mounted) return;

    bool saving = false;
    String? dialogError;

    final saved = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) {
          final sections = _sectionsFor(selectedClass);
          if (selectedSection.isNotEmpty && !sections.contains(selectedSection)) {
            sections.insert(0, selectedSection);
          }
          final subjectNames = _subjects
              .map((row) => row['name']?.toString().trim() ?? '')
              .where((name) => name.isNotEmpty)
              .toSet()
              .toList()
            ..sort();
          if (selectedSubject.isNotEmpty && !subjectNames.contains(selectedSubject)) {
            subjectNames.insert(0, selectedSubject);
          }

          return AlertDialog(
            title: Text(existing == null ? 'Add ${widget.singularLabel}' : 'Edit ${widget.singularLabel}'),
            content: SizedBox(
              width: 600,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: titleController,
                      autofocus: true,
                      textCapitalization: TextCapitalization.sentences,
                      decoration: InputDecoration(
                        labelText: '${widget.singularLabel} title *',
                        prefixIcon: Icon(widget.icon),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: descriptionController,
                      minLines: 3,
                      maxLines: 5,
                      textCapitalization: TextCapitalization.sentences,
                      decoration: const InputDecoration(
                        labelText: 'Instructions / description',
                        prefixIcon: Icon(Icons.description_outlined),
                        alignLabelWithHint: true,
                      ),
                    ),
                    const SizedBox(height: 12),
                    if (subjectNames.isNotEmpty)
                      DropdownButtonFormField<String>(
                        initialValue: selectedSubject.isEmpty ? null : selectedSubject,
                        decoration: const InputDecoration(
                          labelText: 'Subject *',
                          prefixIcon: Icon(Icons.menu_book_outlined),
                        ),
                        items: subjectNames
                            .map((subject) => DropdownMenuItem(value: subject, child: Text(subject)))
                            .toList(),
                        onChanged: saving
                            ? null
                            : (value) => setDialogState(() {
                                  selectedSubject = value ?? '';
                                  subjectController.text = selectedSubject;
                                }),
                      )
                    else
                      TextField(
                        controller: subjectController,
                        decoration: const InputDecoration(
                          labelText: 'Subject *',
                          prefixIcon: Icon(Icons.menu_book_outlined),
                        ),
                      ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            initialValue: selectedClass.isEmpty ? null : selectedClass,
                            decoration: const InputDecoration(
                              labelText: 'Class *',
                              prefixIcon: Icon(Icons.class_outlined),
                            ),
                            items: _classNames
                                .map((name) => DropdownMenuItem(value: name, child: Text(name)))
                                .toList(),
                            onChanged: saving
                                ? null
                                : (value) => setDialogState(() {
                                      selectedClass = value ?? '';
                                      selectedSection = '';
                                      selectedStudentIds.clear();
                                    }),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            initialValue: selectedSection.isEmpty ? null : selectedSection,
                            decoration: const InputDecoration(
                              labelText: 'Section',
                              prefixIcon: Icon(Icons.segment_rounded),
                            ),
                            items: sections
                                .map((section) => DropdownMenuItem(value: section, child: Text(section)))
                                .toList(),
                            onChanged: saving
                                ? null
                                : (value) => setDialogState(() {
                                      selectedSection = value ?? '';
                                      selectedStudentIds.clear();
                                    }),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      initialValue: audience,
                      decoration: const InputDecoration(
                        labelText: 'Give to',
                        prefixIcon: Icon(Icons.groups_2_outlined),
                      ),
                      items: const [
                        DropdownMenuItem(value: 'class', child: Text('Whole class / section')),
                        DropdownMenuItem(value: 'students', child: Text('Selected students only')),
                      ],
                      onChanged: saving
                          ? null
                          : (value) => setDialogState(() {
                                audience = value ?? 'class';
                                if (audience == 'class') selectedStudentIds.clear();
                              }),
                    ),
                    if (audience == 'students') ...[
                      const SizedBox(height: 12),
                      OutlinedButton.icon(
                        onPressed: selectedClass.isEmpty || saving
                            ? null
                            : () async {
                                final result = await _pickStudents(
                                  className: selectedClass,
                                  section: selectedSection,
                                  selected: selectedStudentIds,
                                );
                                if (result != null) {
                                  setDialogState(() => selectedStudentIds = result);
                                }
                              },
                        icon: const Icon(Icons.person_search_outlined),
                        label: Text(
                          selectedStudentIds.isEmpty
                              ? 'Select students *'
                              : '${selectedStudentIds.length} students selected',
                        ),
                      ),
                    ],
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: _DateField(
                            label: 'Start date *',
                            value: startDate,
                            onTap: saving
                                ? null
                                : () async {
                                    final selected = await showDatePicker(
                                      context: dialogContext,
                                      initialDate: startDate,
                                      firstDate: DateTime(2020),
                                      lastDate: DateTime(2100),
                                    );
                                    if (selected != null) {
                                      setDialogState(() {
                                        startDate = selected;
                                        if (dueDate.isBefore(startDate)) dueDate = startDate;
                                      });
                                    }
                                  },
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _DateField(
                            label: 'Due date *',
                            value: dueDate,
                            onTap: saving
                                ? null
                                : () async {
                                    final selected = await showDatePicker(
                                      context: dialogContext,
                                      initialDate: dueDate.isBefore(startDate) ? startDate : dueDate,
                                      firstDate: startDate,
                                      lastDate: DateTime(2100),
                                    );
                                    if (selected != null) setDialogState(() => dueDate = selected);
                                  },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      initialValue: status,
                      decoration: const InputDecoration(
                        labelText: 'Status',
                        prefixIcon: Icon(Icons.flag_outlined),
                      ),
                      items: const [
                        DropdownMenuItem(value: 'active', child: Text('Active')),
                        DropdownMenuItem(value: 'completed', child: Text('Completed')),
                        DropdownMenuItem(value: 'cancelled', child: Text('Cancelled')),
                      ],
                      onChanged: saving ? null : (value) => setDialogState(() => status = value ?? 'active'),
                    ),
                    if (dialogError != null) ...[
                      const SizedBox(height: 12),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          dialogError!,
                          style: TextStyle(color: Theme.of(context).colorScheme.error),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: saving ? null : () => Navigator.pop(dialogContext, false),
                child: const Text('Cancel'),
              ),
              FilledButton.icon(
                onPressed: saving
                    ? null
                    : () async {
                        final title = titleController.text.trim();
                        final subject = subjectNames.isEmpty
                            ? subjectController.text.trim()
                            : selectedSubject.trim();
                        String? validation;
                        if (title.isEmpty) {
                          validation = '${widget.singularLabel} title is required.';
                        } else if (subject.isEmpty) {
                          validation = 'Subject is required.';
                        } else if (selectedClass.isEmpty) {
                          validation = 'Class is required.';
                        } else if (dueDate.isBefore(startDate)) {
                          validation = 'Due date cannot be before the start date.';
                        } else if (audience == 'students' && selectedStudentIds.isEmpty) {
                          validation = 'Select at least one student.';
                        }
                        if (validation != null) {
                          setDialogState(() => dialogError = validation);
                          return;
                        }

                        setDialogState(() {
                          saving = true;
                          dialogError = null;
                        });

                        try {
                          await _saveRecord(
                            existing: existing,
                            title: title,
                            description: descriptionController.text.trim(),
                            subject: subject,
                            className: selectedClass,
                            section: selectedSection,
                            startDate: startDate,
                            dueDate: dueDate,
                            audience: audience,
                            status: status,
                            studentIds: selectedStudentIds,
                          );
                          if (dialogContext.mounted) Navigator.pop(dialogContext, true);
                        } catch (e) {
                          setDialogState(() {
                            saving = false;
                            dialogError = _friendlyError(e);
                          });
                        }
                      },
                icon: saving
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.save_outlined),
                label: Text(existing == null ? 'Create' : 'Save'),
              ),
            ],
          );
        },
      ),
    );

    titleController.dispose();
    descriptionController.dispose();
    subjectController.dispose();

    if (saved == true) {
      await _load();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${widget.singularLabel} saved. Parents linked to affected students were notified.')),
        );
      }
    }
  }

  Future<void> _saveRecord({
    required Map<String, dynamic>? existing,
    required String title,
    required String description,
    required String subject,
    required String className,
    required String section,
    required DateTime startDate,
    required DateTime dueDate,
    required String audience,
    required String status,
    required Set<int> studentIds,
  }) async {
    final schoolId = _schoolId;
    final user = _client.auth.currentUser;
    if (schoolId == null || user == null) throw Exception('School or user session is missing.');

    final payload = <String, dynamic>{
      'school_id': schoolId,
      'title': title,
      'description': description.isEmpty ? null : description,
      'subject': subject,
      'assigned_class': className,
      'assigned_section': section.isEmpty ? null : section,
      'assigned_date': _formatDate(startDate),
      'start_date': _formatDate(startDate),
      'due_date': _formatDate(dueDate),
      'status': status,
      'work_type': widget.workType,
      'audience': audience,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    };

    int assignmentId;
    if (existing == null) {
      payload['created_by'] = user.id;
      final inserted = await _client
          .from('assignments')
          .insert(payload)
          .select('id')
          .single();
      assignmentId = int.parse(inserted['id'].toString());
    } else {
      assignmentId = int.parse(existing['id'].toString());
      await _client
          .from('assignments')
          .update(payload)
          .eq('id', assignmentId)
          .eq('school_id', schoolId);
    }

    await _client
        .from('assignment_students')
        .delete()
        .eq('assignment_id', assignmentId)
        .eq('school_id', schoolId);

    if (audience == 'students' && studentIds.isNotEmpty) {
      await _client.from('assignment_students').insert(
            studentIds
                .map((studentId) => {
                      'school_id': schoolId,
                      'assignment_id': assignmentId,
                      'student_id': studentId,
                    })
                .toList(),
          );
    }

    await _client.rpc(
      'refresh_school_work_parent_notifications',
      params: {'p_assignment_id': assignmentId},
    );
  }

  Future<void> _deleteRecord(Map<String, dynamic> record) async {
    if (!_canManage) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Delete ${widget.singularLabel}?'),
        content: Text('Delete "${record['title'] ?? widget.singularLabel}"? This cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(backgroundColor: Theme.of(context).colorScheme.error),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      await _client
          .from('assignments')
          .delete()
          .eq('id', record['id'])
          .eq('school_id', _schoolId!);
      await _load();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${widget.singularLabel} deleted.')),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(_friendlyError(e))));
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentCount = _records.where((row) => _recordState(row) == 'current').length;
    final scheduledCount = _records.where((row) => _recordState(row) == 'scheduled').length;
    final historyCount = _records.where((row) => _recordState(row) == 'history').length;
    final visible = _visibleRecords;

    return MainWrapper(
      child: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(20),
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(widget.icon, color: Colors.white, size: 24),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(widget.title, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900)),
                      const SizedBox(height: 3),
                      const Text(
                        'Class/section targeting, student selection, start and due dates.',
                        style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
                      ),
                    ],
                  ),
                ),
                FilledButton.icon(
                  onPressed: _loading || !_canManage || _schoolId == null ? null : () => _openEditor(),
                  icon: const Icon(Icons.add_rounded),
                  label: Text('Add ${widget.singularLabel}'),
                ),
              ],
            ),
            const SizedBox(height: 18),
            TextField(
              decoration: const InputDecoration(
                hintText: 'Search by title, subject, class or section',
                prefixIcon: Icon(Icons.search_rounded),
              ),
              onChanged: (value) => setState(() => _search = value),
            ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _ViewChip(
                  label: 'Current ($currentCount)',
                  selected: _view == 'current',
                  onTap: () => setState(() => _view = 'current'),
                ),
                _ViewChip(
                  label: 'Scheduled ($scheduledCount)',
                  selected: _view == 'scheduled',
                  onTap: () => setState(() => _view = 'scheduled'),
                ),
                _ViewChip(
                  label: 'History ($historyCount)',
                  selected: _view == 'history',
                  onTap: () => setState(() => _view = 'history'),
                ),
              ],
            ),
            const SizedBox(height: 18),
            if (_loading)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 72),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_error != null)
              _ErrorCard(message: _error!, onRetry: _load)
            else if (visible.isEmpty)
              _EmptyCard(
                label: widget.singularLabel,
                view: _view,
                canManage: _canManage,
                onAdd: () => _openEditor(),
              )
            else
              Card(
                clipBehavior: Clip.antiAlias,
                child: Column(
                  children: [
                    for (var i = 0; i < visible.length; i++) ...[
                      _WorkTile(
                        row: visible[i],
                        label: widget.singularLabel,
                        icon: widget.icon,
                        startLabel: _displayDate(visible[i]['start_date'] ?? visible[i]['assigned_date']),
                        dueLabel: _displayDate(visible[i]['due_date']),
                        canManage: _canManage,
                        onEdit: () => _openEditor(visible[i]),
                        onDelete: () => _deleteRecord(visible[i]),
                      ),
                      if (i != visible.length - 1) const Divider(height: 1),
                    ],
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _DateField extends StatelessWidget {
  const _DateField({required this.label, required this.value, required this.onTap});
  final String label;
  final DateTime value;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    String two(int n) => n.toString().padLeft(2, '0');
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: InputDecorator(
        decoration: InputDecoration(labelText: label, prefixIcon: const Icon(Icons.calendar_month_outlined)),
        child: Text('${two(value.day)}/${two(value.month)}/${value.year}'),
      ),
    );
  }
}

class _ViewChip extends StatelessWidget {
  const _ViewChip({required this.label, required this.selected, required this.onTap});
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => ChoiceChip(
        label: Text(label),
        selected: selected,
        onSelected: (_) => onTap(),
      );
}

class _WorkTile extends StatelessWidget {
  const _WorkTile({
    required this.row,
    required this.label,
    required this.icon,
    required this.startLabel,
    required this.dueLabel,
    required this.canManage,
    required this.onEdit,
    required this.onDelete,
  });

  final Map<String, dynamic> row;
  final String label;
  final IconData icon;
  final String startLabel;
  final String dueLabel;
  final bool canManage;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final className = row['assigned_class']?.toString().trim() ?? '';
    final section = row['assigned_section']?.toString().trim() ?? '';
    final subject = row['subject']?.toString().trim() ?? '';
    final audience = row['audience']?.toString() == 'students' ? 'Selected students' : 'Whole class';
    final status = row['status']?.toString().trim() ?? 'active';

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      leading: CircleAvatar(
        backgroundColor: AppColors.primary.withValues(alpha: 0.10),
        foregroundColor: AppColors.primary,
        child: Icon(icon),
      ),
      title: Text(row['title']?.toString() ?? label, style: const TextStyle(fontWeight: FontWeight.w800)),
      subtitle: Padding(
        padding: const EdgeInsets.only(top: 5),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('$subject • $className${section.isEmpty ? '' : ' - $section'}'),
            const SizedBox(height: 2),
            Text('From $startLabel to $dueLabel • $audience'),
            const SizedBox(height: 2),
            Text('Status: ${status.isEmpty ? 'active' : status}'),
          ],
        ),
      ),
      trailing: canManage
          ? PopupMenuButton<String>(
              onSelected: (value) {
                if (value == 'edit') onEdit();
                if (value == 'delete') onDelete();
              },
              itemBuilder: (context) => const [
                PopupMenuItem(value: 'edit', child: Text('Edit')),
                PopupMenuItem(value: 'delete', child: Text('Delete')),
              ],
            )
          : null,
    );
  }
}

class _EmptyCard extends StatelessWidget {
  const _EmptyCard({
    required this.label,
    required this.view,
    required this.canManage,
    required this.onAdd,
  });
  final String label;
  final String view;
  final bool canManage;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) => Card(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 48),
          child: Column(
            children: [
              const Icon(Icons.event_note_outlined, size: 46, color: AppColors.textMuted),
              const SizedBox(height: 12),
              Text('No $view ${label.toLowerCase()} found', style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
              if (canManage && view == 'current') ...[
                const SizedBox(height: 16),
                FilledButton.icon(onPressed: onAdd, icon: const Icon(Icons.add_rounded), label: Text('Add $label')),
              ],
            ],
          ),
        ),
      );
}

class _ErrorCard extends StatelessWidget {
  const _ErrorCard({required this.message, required this.onRetry});
  final String message;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) => Card(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              Icon(Icons.error_outline, color: Theme.of(context).colorScheme.error, size: 40),
              const SizedBox(height: 12),
              Text(message, textAlign: TextAlign.center),
              const SizedBox(height: 16),
              OutlinedButton.icon(onPressed: onRetry, icon: const Icon(Icons.refresh_rounded), label: const Text('Retry')),
            ],
          ),
        ),
      );
}
