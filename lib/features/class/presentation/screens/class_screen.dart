import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/network/supabase_client.dart';
import '../../../../core/widgets/main_wrapper.dart';

class ClassesScreen extends StatefulWidget {
  const ClassesScreen({super.key});

  @override
  State<ClassesScreen> createState() => _ClassesScreenState();
}

class _ClassesScreenState extends State<ClassesScreen> {
  final SupabaseClient _client = SupabaseConfig.client;

  final TextEditingController _searchController =
  TextEditingController();

  List<Map<String, dynamic>> _classes = [];

  bool _loading = true;
  final bool _saving = false;

  String? _error;
  int? _schoolId;

  @override
  void initState() {
    super.initState();
    _loadClasses();

    _searchController.addListener(() {
      if (mounted) {
        setState(() {});
      }
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // ============================================================
  // GET SCHOOL ID
  // ============================================================

  Future<int?> _getSchoolId() async {
    try {
      final result = await _client.rpc('get_my_school_id');

      if (result is int) {
        return result;
      }

      if (result is num) {
        return result.toInt();
      }

      final parsed = int.tryParse(
        result?.toString() ?? '',
      );

      if (parsed != null) {
        return parsed;
      }
    } catch (e) {
      debugPrint(
        'get_my_school_id error: $e',
      );
    }

    // Fallback: profiles table
    try {
      final userId =
          _client.auth.currentUser?.id;

      if (userId == null) {
        return null;
      }

      final profile = await _client
          .from('profiles')
          .select('school_id')
          .eq('id', userId)
          .maybeSingle();

      final value =
      profile?['school_id'];

      if (value is int) {
        return value;
      }

      return int.tryParse(
        value?.toString() ?? '',
      );
    } catch (e) {
      debugPrint(
        'Profile school lookup error: $e',
      );
    }

    return null;
  }

  // ============================================================
  // LOAD CLASSES
  // ============================================================

  Future<void> _loadClasses() async {
    if (!mounted) return;

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final schoolId =
      await _getSchoolId();

      if (schoolId == null) {
        throw Exception(
          'Your account is not linked to a school.',
        );
      }

      _schoolId = schoolId;

      // IMPORTANT:
      // Do NOT create classes from students here.
      // This prevents deleted classes from coming back.

      final response = await _client
          .from('classes')
          .select(
        'id, school_id, name, section_name, '
            'created_by, created_at, updated_at',
      )
          .eq(
        'school_id',
        schoolId,
      )
          .order(
        'name',
        ascending: true,
      );

      if (!mounted) return;

      setState(() {
        _classes =
        List<Map<String, dynamic>>.from(
          response,
        );
        _loading = false;
      });
    } on PostgrestException catch (e) {
      debugPrint(
        'Classes DB error: ${e.message}',
      );

      if (!mounted) return;

      setState(() {
        _error =
        '${e.message}\n\nCode: ${e.code ?? 'unknown'}';
        _loading = false;
      });
    } catch (e) {
      debugPrint(
        'Classes load error: $e',
      );

      if (!mounted) return;

      setState(() {
        _error = e
            .toString()
            .replaceFirst(
          'Exception: ',
          '',
        );
        _loading = false;
      });
    }
  }

  // ============================================================
  // ENSURE CLASS EXISTS
  // Only called when adding/editing a student.
  // ============================================================

  Future<void> _ensureClassExists({
    required int schoolId,
    required String className,
    String? sectionName,
  }) async {
    final cleanClass =
    className.trim();

    final cleanSection =
        sectionName?.trim() ?? '';

    if (cleanClass.isEmpty) {
      return;
    }

    final rows = await _client
        .from('classes')
        .select('id, name, section_name')
        .eq(
      'school_id',
      schoolId,
    )
        .ilike(
      'name',
      cleanClass,
    );

    final existing =
    List<Map<String, dynamic>>.from(
      rows,
    );

    for (final row in existing) {
      final rowSection =
          row['section_name']
              ?.toString()
              .trim() ??
              '';

      if (rowSection.toLowerCase() ==
          cleanSection.toLowerCase()) {
        return;
      }
    }

    try {
      await _client.from('classes').insert({
        'school_id': schoolId,
        'name': cleanClass,
        'section_name':
        cleanSection.isEmpty
            ? null
            : cleanSection,
      });
    } on PostgrestException catch (e) {
      // If unique index exists and another request
      // created it at the same time, ignore duplicate.
      if (e.code != '23505') {
        rethrow;
      }
    }
  }

  // ============================================================
  // SEARCH
  // ============================================================

  List<Map<String, dynamic>>
  get _visibleClasses {
    final query =
    _searchController.text
        .trim()
        .toLowerCase();

    if (query.isEmpty) {
      return _classes;
    }

    return _classes.where((item) {
      final name =
          item['name']
              ?.toString()
              .toLowerCase() ??
              '';

      final section =
          item['section_name']
              ?.toString()
              .toLowerCase() ??
              '';

      return name.contains(query) ||
          section.contains(query);
    }).toList();
  }

  // ============================================================
  // CLASS ADD / EDIT
  // ============================================================

  Future<void> _openClassDialog({
    Map<String, dynamic>? existing,
  }) async {
    final nameController =
    TextEditingController(
      text:
      existing?['name']
          ?.toString() ??
          '',
    );

    final sectionController =
    TextEditingController(
      text:
      existing?['section_name']
          ?.toString() ??
          '',
    );

    final isEditing =
        existing != null;

    try {
      final result =
      await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) {
          bool saving = false;

          return StatefulBuilder(
            builder: (
                context,
                setDialogState,
                ) {
              Future<void> save() async {
                final name =
                nameController.text
                    .trim();

                final section =
                sectionController.text
                    .trim();

                if (name.isEmpty) {
                  ScaffoldMessenger.of(
                    dialogContext,
                  ).showSnackBar(
                    const SnackBar(
                      content: Text(
                        'Class name is required.',
                      ),
                    ),
                  );
                  return;
                }

                if (_schoolId == null) {
                  return;
                }

                setDialogState(() {
                  saving = true;
                });

                try {
                  if (isEditing) {
                    // Check duplicate before rename.
                    final duplicate =
                    await _client
                        .from('classes')
                        .select('id')
                        .eq(
                      'school_id',
                      _schoolId!,
                    )
                        .ilike(
                      'name',
                      name,
                    );

                    final duplicateRows =
                    List<Map<String, dynamic>>
                        .from(
                      duplicate,
                    );

                    bool duplicateFound =
                    false;

                    for (final row
                    in duplicateRows) {
                      if (row['id'] !=
                          existing['id']) {
                        final existingSection =
                            row['section_name']
                                ?.toString()
                                .trim() ??
                                '';

                        if (existingSection
                            .toLowerCase() ==
                            section
                                .toLowerCase()) {
                          duplicateFound =
                          true;
                          break;
                        }
                      }
                    }

                    if (duplicateFound) {
                      throw Exception(
                        'This class and section already exists.',
                      );
                    }

                    await _client
                        .from('classes')
                        .update({
                      'name': name,
                      'section_name':
                      section.isEmpty
                          ? null
                          : section,
                      'updated_at':
                      DateTime.now()
                          .toUtc()
                          .toIso8601String(),
                    })
                        .eq(
                      'id',
                      existing['id'],
                    )
                        .eq(
                      'school_id',
                      _schoolId!,
                    );

                    // Move only students that belonged
                    // to the old class + old section.
                    final oldName =
                        existing['name']
                            ?.toString()
                            .trim() ??
                            '';

                    final oldSection =
                        existing['section_name']
                            ?.toString()
                            .trim() ??
                            '';

                    var query =
                    _client
                        .from('students')
                        .update({
                      'class_name':
                      name,
                      'section_name':
                      section.isEmpty
                          ? null
                          : section,
                      'updated_at':
                      DateTime.now()
                          .toUtc()
                          .toIso8601String(),
                    })
                        .eq(
                      'school_id',
                      _schoolId!,
                    )
                        .ilike(
                      'class_name',
                      oldName,
                    );

                    if (oldSection.isEmpty) {
                      query = query.isFilter(
                        'section_name',
                        null,
                      );
                    } else {
                      query = query.ilike(
                        'section_name',
                        oldSection,
                      );
                    }

                    await query;
                  } else {
                    await _ensureClassExists(
                      schoolId: _schoolId!,
                      className: name,
                      sectionName: section,
                    );
                  }

                  if (!dialogContext.mounted) {
                    return;
                  }

                  Navigator.of(
                    dialogContext,
                  ).pop(true);
                } catch (e) {
                  if (!dialogContext.mounted) {
                    return;
                  }

                  setDialogState(() {
                    saving = false;
                  });

                  ScaffoldMessenger.of(
                    dialogContext,
                  ).showSnackBar(
                    SnackBar(
                      content: Text(
                        e.toString()
                            .replaceFirst(
                          'Exception: ',
                          '',
                        ),
                      ),
                    ),
                  );
                }
              }

              return AlertDialog(
                title: Text(
                  isEditing
                      ? 'Edit Class'
                      : 'Add Class',
                  style:
                  const TextStyle(
                    fontWeight:
                    FontWeight.w800,
                  ),
                ),
                content: SizedBox(
                  width: 450,
                  child: Column(
                    mainAxisSize:
                    MainAxisSize.min,
                    children: [
                      TextField(
                        controller:
                        nameController,
                        enabled: !saving,
                        decoration:
                        const InputDecoration(
                          labelText:
                          'Class Name',
                          prefixIcon:
                          Icon(
                            Icons
                                .class_outlined,
                          ),
                        ),
                      ),
                      const SizedBox(
                        height: 14,
                      ),
                      TextField(
                        controller:
                        sectionController,
                        enabled: !saving,
                        decoration:
                        const InputDecoration(
                          labelText:
                          'Section',
                          hintText: 'A',
                          prefixIcon:
                          Icon(
                            Icons
                                .segment_rounded,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: saving
                        ? null
                        : () {
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
                    onPressed:
                    saving ? null : save,
                    child: saving
                        ? const SizedBox(
                      width: 18,
                      height: 18,
                      child:
                      CircularProgressIndicator(
                        strokeWidth: 2,
                      ),
                    )
                        : Text(
                      isEditing
                          ? 'Save Changes'
                          : 'Add Class',
                    ),
                  ),
                ],
              );
            },
          );
        },
      );

      if (result == true) {
        await _loadClasses();

        if (!mounted) return;

        ScaffoldMessenger.of(
          context,
        ).showSnackBar(
          SnackBar(
            content: Text(
              isEditing
                  ? 'Class updated successfully.'
                  : 'Class added successfully.',
            ),
          ),
        );
      }
    } finally {
      nameController.dispose();
      sectionController.dispose();
    }
  }

  // ============================================================
  // DELETE CLASS
  // ============================================================

  Future<void> _deleteClass(
      Map<String, dynamic> item,
      ) async {
    final confirmed =
    await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        final name =
            item['name']
                ?.toString() ??
                'this class';

        final section =
            item['section_name']
                ?.toString() ??
                '';

        return AlertDialog(
          title:
          const Text(
            'Delete Class?',
          ),
          content: Text(
            'Delete $name'
                '${section.isNotEmpty ? ' - $section' : ''}?\n\n'
                'Students will NOT be deleted.',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(
                  dialogContext,
                ).pop(false);
              },
              child:
              const Text('Cancel'),
            ),
            FilledButton(
              style:
              FilledButton.styleFrom(
                backgroundColor:
                AppColors.error,
              ),
              onPressed: () {
                Navigator.of(
                  dialogContext,
                ).pop(true);
              },
              child:
              const Text('Delete'),
            ),
          ],
        );
      },
    );

    if (confirmed != true ||
        _schoolId == null) {
      return;
    }

    try {
      await _client
          .from('classes')
          .delete()
          .eq(
        'id',
        item['id'],
      )
          .eq(
        'school_id',
        _schoolId!,
      );

      await _loadClasses();

      if (!mounted) return;

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(
        const SnackBar(
          content: Text(
            'Class deleted successfully.',
          ),
        ),
      );
    } on PostgrestException catch (e) {
      _showMessage(
        '${e.message}\nCode: ${e.code ?? 'unknown'}',
      );
    }
  }

  // ============================================================
  // LOAD CLASS STUDENTS
  // ============================================================

  Future<List<Map<String, dynamic>>>
  _loadClassStudents(
      Map<String, dynamic> classItem,
      ) async {
    if (_schoolId == null) {
      return [];
    }

    final className =
        classItem['name']
            ?.toString()
            .trim() ??
            '';

    final section =
        classItem['section_name']
            ?.toString()
            .trim() ??
            '';

    if (className.isEmpty) {
      return [];
    }

    final response = await _client
        .from('students')
        .select(
      'id, school_id, admission_number, '
          'full_name, father_name, parent_email, '
          'mobile_number, class_name, section_name, '
          'date_of_birth, is_active, created_at, updated_at',
    )
        .eq(
      'school_id',
      _schoolId!,
    )
        .ilike(
      'class_name',
      className,
    )
        .order(
      'full_name',
      ascending: true,
    );

    final students =
    List<Map<String, dynamic>>.from(
      response,
    );

    if (section.isEmpty) {
      return students.where((student) {
        final studentSection =
            student['section_name']
                ?.toString()
                .trim() ??
                '';

        return studentSection.isEmpty;
      }).toList();
    }

    return students.where((student) {
      final studentSection =
          student['section_name']
              ?.toString()
              .trim() ??
              '';

      return studentSection.toLowerCase() ==
          section.toLowerCase();
    }).toList();
  }

  // ============================================================
  // OPEN CLASS
  // ============================================================

  Future<void> _openClassStudents(
      Map<String, dynamic> classItem,
      ) async {
    if (_schoolId == null) {
      return;
    }

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor:
      Colors.transparent,
      builder: (_) {
        return _ClassStudentsSheet(
          classItem: classItem,
          loadStudents:
          _loadClassStudents,
          onAddStudent: () async {
            return await _openStudentDialog(
              classItem: classItem,
            );
          },
          onEditStudent: (student) async {
            return await _openStudentDialog(
              classItem: classItem,
              existing: student,
            );
          },
          onDeleteStudent: (student) async {
            return await _deleteStudent(
              student,
            );
          },
        );
      },
    );

    await _loadClasses();
  }

  // ============================================================
  // ADD / EDIT STUDENT
  // ============================================================

  Future<bool> _openStudentDialog({
    required Map<String, dynamic> classItem,
    Map<String, dynamic>? existing,
  }) async {
    if (_schoolId == null) {
      return false;
    }

    final isEditing =
        existing != null;

    final nameController =
    TextEditingController(
      text:
      existing?['full_name']
          ?.toString() ??
          '',
    );

    final admissionController =
    TextEditingController(
      text:
      existing?['admission_number']
          ?.toString() ??
          '',
    );

    final fatherController =
    TextEditingController(
      text:
      existing?['father_name']
          ?.toString() ??
          '',
    );

    final emailController =
    TextEditingController(
      text:
      existing?['parent_email']
          ?.toString() ??
          '',
    );

    final mobileController =
    TextEditingController(
      text:
      existing?['mobile_number']
          ?.toString() ??
          '',
    );

    final dobController =
    TextEditingController(
      text:
      existing?['date_of_birth']
          ?.toString() ??
          '',
    );

    final classController =
    TextEditingController(
      text:
      classItem['name']
          ?.toString() ??
          '',
    );

    final sectionController =
    TextEditingController(
      text:
      classItem['section_name']
          ?.toString() ??
          '',
    );

    bool active =
        existing?['is_active'] != false;

    try {
      final result =
      await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) {
          bool saving = false;

          return StatefulBuilder(
            builder: (
                context,
                setDialogState,
                ) {
              Future<void> saveStudent() async {
                final name =
                nameController.text
                    .trim();

                final admission =
                admissionController
                    .text
                    .trim();

                final father =
                fatherController.text
                    .trim();

                final email =
                emailController.text
                    .trim();

                final mobile =
                mobileController.text
                    .trim();

                final className =
                classController.text
                    .trim();

                final section =
                sectionController.text
                    .trim();

                final dob =
                dobController.text
                    .trim();

                if (name.isEmpty) {
                  _dialogError(
                    dialogContext,
                    'Student name is required.',
                  );
                  return;
                }

                if (admission.isEmpty) {
                  _dialogError(
                    dialogContext,
                    'Admission number is required.',
                  );
                  return;
                }

                if (className.isEmpty) {
                  _dialogError(
                    dialogContext,
                    'Class is required.',
                  );
                  return;
                }

                setDialogState(() {
                  saving = true;
                });

                try {
                  // Create class ONLY when a student
                  // is actually being added/moved.
                  await _ensureClassExists(
                    schoolId: _schoolId!,
                    className: className,
                    sectionName: section,
                  );

                  final data = {
                    'admission_number':
                    admission,
                    'full_name':
                    name,
                    'father_name':
                    father.isEmpty
                        ? null
                        : father,
                    'parent_email':
                    email.isEmpty
                        ? null
                        : email,
                    'mobile_number':
                    mobile.isEmpty
                        ? null
                        : mobile,
                    'class_name':
                    className,
                    'section_name':
                    section.isEmpty
                        ? null
                        : section,
                    'date_of_birth':
                    dob.isEmpty
                        ? null
                        : dob,
                    'is_active':
                    active,
                    'updated_at':
                    DateTime.now()
                        .toUtc()
                        .toIso8601String(),
                  };

                  if (isEditing) {
                    await _client
                        .from('students')
                        .update(data)
                        .eq(
                      'id',
                      existing['id'],
                    )
                        .eq(
                      'school_id',
                      _schoolId!,
                    );
                  } else {
                    await _client
                        .from('students')
                        .insert({
                      'school_id':
                      _schoolId!,
                      ...data,
                    });
                  }

                  if (!dialogContext.mounted) {
                    return;
                  }

                  Navigator.of(
                    dialogContext,
                  ).pop(true);
                } on PostgrestException catch (e) {
                  if (!dialogContext.mounted) {
                    return;
                  }

                  setDialogState(() {
                    saving = false;
                  });

                  _dialogError(
                    dialogContext,
                    '${e.message}\nCode: ${e.code ?? 'unknown'}',
                  );
                } catch (e) {
                  if (!dialogContext.mounted) {
                    return;
                  }

                  setDialogState(() {
                    saving = false;
                  });

                  _dialogError(
                    dialogContext,
                    e.toString()
                        .replaceFirst(
                      'Exception: ',
                      '',
                    ),
                  );
                }
              }

              return AlertDialog(
                title: Text(
                  isEditing
                      ? 'Edit Student'
                      : 'Add Student',
                  style:
                  const TextStyle(
                    fontWeight:
                    FontWeight.w800,
                  ),
                ),
                content: SizedBox(
                  width: 540,
                  child:
                  SingleChildScrollView(
                    child: Column(
                      mainAxisSize:
                      MainAxisSize.min,
                      children: [
                        TextField(
                          controller:
                          nameController,
                          enabled: !saving,
                          decoration:
                          const InputDecoration(
                            labelText:
                            'Student Name *',
                            prefixIcon:
                            Icon(
                              Icons
                                  .person_outline_rounded,
                            ),
                          ),
                        ),
                        const SizedBox(
                          height: 12,
                        ),
                        TextField(
                          controller:
                          admissionController,
                          enabled: !saving,
                          decoration:
                          const InputDecoration(
                            labelText:
                            'Admission Number *',
                            prefixIcon:
                            Icon(
                              Icons
                                  .badge_outlined,
                            ),
                          ),
                        ),
                        const SizedBox(
                          height: 12,
                        ),
                        TextField(
                          controller:
                          fatherController,
                          enabled: !saving,
                          decoration:
                          const InputDecoration(
                            labelText:
                            'Father Name',
                            prefixIcon:
                            Icon(
                              Icons
                                  .family_restroom_rounded,
                            ),
                          ),
                        ),
                        const SizedBox(
                          height: 12,
                        ),
                        TextField(
                          controller:
                          emailController,
                          enabled: !saving,
                          keyboardType:
                          TextInputType
                              .emailAddress,
                          decoration:
                          const InputDecoration(
                            labelText:
                            'Parent Email',
                            prefixIcon:
                            Icon(
                              Icons
                                  .email_outlined,
                            ),
                          ),
                        ),
                        const SizedBox(
                          height: 12,
                        ),
                        TextField(
                          controller:
                          mobileController,
                          enabled: !saving,
                          keyboardType:
                          TextInputType.phone,
                          decoration:
                          const InputDecoration(
                            labelText:
                            'Mobile Number',
                            prefixIcon:
                            Icon(
                              Icons
                                  .phone_outlined,
                            ),
                          ),
                        ),
                        const SizedBox(
                          height: 12,
                        ),
                        TextField(
                          controller:
                          dobController,
                          enabled: !saving,
                          readOnly: true,
                          decoration:
                          const InputDecoration(
                            labelText:
                            'Date of Birth',
                            hintText:
                            'YYYY-MM-DD',
                            prefixIcon:
                            Icon(
                              Icons
                                  .calendar_today_outlined,
                            ),
                          ),
                          onTap: saving
                              ? null
                              : () async {
                            final picked =
                            await showDatePicker(
                              context:
                              dialogContext,
                              initialDate:
                              DateTime(
                                2012,
                              ),
                              firstDate:
                              DateTime(
                                1990,
                              ),
                              lastDate:
                              DateTime.now(),
                            );

                            if (picked !=
                                null &&
                                dialogContext
                                    .mounted) {
                              dobController
                                  .text =
                              '${picked.year}-'
                                  '${picked.month.toString().padLeft(2, '0')}-'
                                  '${picked.day.toString().padLeft(2, '0')}';
                            }
                          },
                        ),
                        const SizedBox(
                          height: 12,
                        ),

                        // Class is automatically
                        // selected from the class card.
                        TextField(
                          controller:
                          classController,
                          enabled: false,
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

                        const SizedBox(
                          height: 12,
                        ),

                        TextField(
                          controller:
                          sectionController,
                          enabled: false,
                          decoration:
                          const InputDecoration(
                            labelText:
                            'Section',
                            prefixIcon:
                            Icon(
                              Icons
                                  .segment_rounded,
                            ),
                          ),
                        ),

                        const SizedBox(
                          height: 8,
                        ),

                        SwitchListTile(
                          contentPadding:
                          EdgeInsets.zero,
                          title:
                          const Text(
                            'Active Student',
                            style:
                            TextStyle(
                              fontWeight:
                              FontWeight.w700,
                            ),
                          ),
                          value: active,
                          onChanged:
                          saving
                              ? null
                              : (value) {
                            setDialogState(
                                  () {
                                active =
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
                  TextButton(
                    onPressed: saving
                        ? null
                        : () {
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
                    onPressed:
                    saving
                        ? null
                        : saveStudent,
                    child: saving
                        ? const SizedBox(
                      width: 18,
                      height: 18,
                      child:
                      CircularProgressIndicator(
                        strokeWidth: 2,
                      ),
                    )
                        : Text(
                      isEditing
                          ? 'Save Changes'
                          : 'Add Student',
                    ),
                  ),
                ],
              );
            },
          );
        },
      );

      return result == true;
    } finally {
      nameController.dispose();
      admissionController.dispose();
      fatherController.dispose();
      emailController.dispose();
      mobileController.dispose();
      dobController.dispose();
      classController.dispose();
      sectionController.dispose();
    }
  }

  // ============================================================
  // DELETE STUDENT
  // ============================================================

  Future<bool> _deleteStudent(
      Map<String, dynamic> student,
      ) async {
    final name =
        student['full_name']
            ?.toString() ??
            'this student';

    final confirmed =
    await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title:
          const Text(
            'Delete Student?',
          ),
          content: Text(
            'Are you sure you want to delete $name?',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(
                  dialogContext,
                ).pop(false);
              },
              child:
              const Text('Cancel'),
            ),
            FilledButton(
              style:
              FilledButton.styleFrom(
                backgroundColor:
                AppColors.error,
              ),
              onPressed: () {
                Navigator.of(
                  dialogContext,
                ).pop(true);
              },
              child:
              const Text('Delete'),
            ),
          ],
        );
      },
    );

    if (confirmed != true ||
        _schoolId == null) {
      return false;
    }

    try {
      await _client
          .from('students')
          .delete()
          .eq(
        'id',
        student['id'],
      )
          .eq(
        'school_id',
        _schoolId!,
      );

      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(
          const SnackBar(
            content: Text(
              'Student deleted successfully.',
            ),
          ),
        );
      }

      return true;
    } on PostgrestException catch (e) {
      _showMessage(
        '${e.message}\nCode: ${e.code ?? 'unknown'}',
      );
      return false;
    } catch (e) {
      _showMessage(
        e.toString().replaceFirst(
          'Exception: ',
          '',
        ),
      );
      return false;
    }
  }

  // ============================================================
  // DIALOG ERROR
  // ============================================================

  void _dialogError(
      BuildContext context,
      String message,
      ) {
    if (!context.mounted) return;

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(
      SnackBar(
        content: Text(message),
      ),
    );
  }

  // ============================================================
  // MESSAGE
  // ============================================================

  void _showMessage(
      String message,
      ) {
    if (!mounted) return;

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(
      SnackBar(
        content: Text(message),
      ),
    );
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(
      BuildContext context,
      ) {
    return MainWrapper(
      child: Column(
        children: [
          _buildHeader(),
          _buildSearch(),
          Expanded(
            child:
            _buildBody(
              _visibleClasses,
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // HEADER
  // ============================================================

  Widget _buildHeader() {
    return Padding(
      padding:
      const EdgeInsets.fromLTRB(
        24,
        24,
        24,
        12,
      ),
      child: Row(
        children: [
          const Expanded(
            child: Column(
              crossAxisAlignment:
              CrossAxisAlignment.start,
              children: [
                Text(
                  'Classes',
                  style: TextStyle(
                    fontSize: 26,
                    fontWeight:
                    FontWeight.w900,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'Manage classes and students class-wise.',
                  style: TextStyle(
                    color:
                    AppColors
                        .textSecondary,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
          FilledButton.icon(
            onPressed: _saving
                ? null
                : () =>
                _openClassDialog(),
            icon:
            const Icon(
              Icons.add_rounded,
            ),
            label:
            const Text(
              'Add Class',
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // SEARCH
  // ============================================================

  Widget _buildSearch() {
    return Padding(
      padding:
      const EdgeInsets.fromLTRB(
        24,
        0,
        24,
        16,
      ),
      child: TextField(
        controller:
        _searchController,
        decoration:
        InputDecoration(
          hintText:
          'Search class or section...',
          prefixIcon:
          const Icon(
            Icons.search_rounded,
          ),
          suffixIcon:
          _searchController
              .text
              .isEmpty
              ? null
              : IconButton(
            onPressed: () {
              _searchController
                  .clear();
            },
            icon:
            const Icon(
              Icons
                  .clear_rounded,
            ),
          ),
        ),
      ),
    );
  }

  // ============================================================
  // BODY
  // ============================================================

  Widget _buildBody(
      List<Map<String, dynamic>>
      classes,
      ) {
    if (_loading) {
      return const Center(
        child:
        CircularProgressIndicator(),
      );
    }

    if (_error != null) {
      return Center(
        child: Padding(
          padding:
          const EdgeInsets.all(24),
          child: Column(
            mainAxisSize:
            MainAxisSize.min,
            children: [
              const Icon(
                Icons
                    .cloud_off_rounded,
                size: 60,
                color:
                AppColors
                    .textMuted,
              ),
              const SizedBox(
                height: 16,
              ),
              Text(
                _error!,
                textAlign:
                TextAlign.center,
              ),
              const SizedBox(
                height: 16,
              ),
              OutlinedButton(
                onPressed:
                _loadClasses,
                child:
                const Text(
                  'Retry',
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (classes.isEmpty) {
      return RefreshIndicator(
        onRefresh:
        _loadClasses,
        child: ListView(
          physics:
          const AlwaysScrollableScrollPhysics(),
          children: const [
            SizedBox(
              height: 120,
            ),
            Icon(
              Icons
                  .class_outlined,
              size: 70,
              color:
              AppColors
                  .textMuted,
            ),
            SizedBox(
              height: 16,
            ),
            Center(
              child: Text(
                'No classes found.',
                style:
                TextStyle(
                  fontSize: 17,
                  fontWeight:
                  FontWeight.w700,
                ),
              ),
            ),
            SizedBox(
              height: 6,
            ),
            Center(
              child: Text(
                'Add a class to get started.',
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh:
      _loadClasses,
      child:
      ListView.separated(
        physics:
        const AlwaysScrollableScrollPhysics(),
        padding:
        const EdgeInsets.fromLTRB(
          24,
          4,
          24,
          30,
        ),
        itemCount:
        classes.length,
        separatorBuilder:
            (_, __) =>
        const SizedBox(
          height: 12,
        ),
        itemBuilder:
            (_, index) {
          return _buildClassCard(
            classes[index],
          );
        },
      ),
    );
  }

  // ============================================================
  // CLASS CARD
  // ============================================================

  Widget _buildClassCard(
      Map<String, dynamic> item,
      ) {
    final name =
        item['name']
            ?.toString() ??
            'Class';

    final section =
        item['section_name']
            ?.toString() ??
            '';

    return Card(
      margin: EdgeInsets.zero,
      child: InkWell(
        onTap: () =>
            _openClassStudents(
              item,
            ),
        borderRadius:
        BorderRadius.circular(
          20,
        ),
        child: Padding(
          padding:
          const EdgeInsets.all(
            18,
          ),
          child: Row(
            children: [
              Container(
                width: 58,
                height: 58,
                decoration:
                BoxDecoration(
                  color: AppColors
                      .primary
                      .withValues(alpha: 
                    .10,
                  ),
                  borderRadius:
                  BorderRadius.circular(
                    16,
                  ),
                ),
                child:
                const Icon(
                  Icons
                      .class_rounded,
                  color:
                  AppColors
                      .primary,
                  size: 29,
                ),
              ),
              const SizedBox(
                width: 16,
              ),
              Expanded(
                child:
                Column(
                  crossAxisAlignment:
                  CrossAxisAlignment
                      .start,
                  children: [
                    Text(
                      name,
                      style:
                      const TextStyle(
                        fontSize: 18,
                        fontWeight:
                        FontWeight
                            .w900,
                      ),
                    ),
                    const SizedBox(
                      height: 5,
                    ),
                    Text(
                      section.isEmpty
                          ? 'All sections'
                          : 'Section $section',
                      style:
                      const TextStyle(
                        color:
                        AppColors
                            .textSecondary,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(
                      height: 8,
                    ),
                    const Text(
                      'Tap to view students',
                      style:
                      TextStyle(
                        color:
                        AppColors
                            .primary,
                        fontSize: 12,
                        fontWeight:
                        FontWeight
                            .w700,
                      ),
                    ),
                  ],
                ),
              ),
              PopupMenuButton<
                  String>(
                onSelected:
                    (value) {
                  if (value ==
                      'edit') {
                    _openClassDialog(
                      existing:
                      item,
                    );
                  }

                  if (value ==
                      'delete') {
                    _deleteClass(
                      item,
                    );
                  }
                },
                itemBuilder:
                    (_) =>
                const [
                  PopupMenuItem(
                    value: 'edit',
                    child:
                    Text(
                      'Edit Class',
                    ),
                  ),
                  PopupMenuItem(
                    value:
                    'delete',
                    child:
                    Text(
                      'Delete Class',
                    ),
                  ),
                ],
              ),
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
      ),
    );
  }
}

// ============================================================================
// CLASS STUDENTS SHEET
// ============================================================================

class _ClassStudentsSheet
    extends StatefulWidget {
  final Map<String, dynamic>
  classItem;

  final Future<
      List<Map<String, dynamic>>>
  Function(
      Map<String, dynamic>,
      ) loadStudents;

  final Future<bool> Function()
  onAddStudent;

  final Future<bool> Function(
      Map<String, dynamic>,
      ) onEditStudent;

  final Future<bool> Function(
      Map<String, dynamic>,
      ) onDeleteStudent;

  const _ClassStudentsSheet({
    required this.classItem,
    required this.loadStudents,
    required this.onAddStudent,
    required this.onEditStudent,
    required this.onDeleteStudent,
  });

  @override
  State<_ClassStudentsSheet>
  createState() =>
      _ClassStudentsSheetState();
}

class _ClassStudentsSheetState
    extends State<
        _ClassStudentsSheet> {
  bool _loading = true;

  String? _error;

  List<Map<String, dynamic>>
  _students = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (!mounted) return;

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final rows =
      await widget
          .loadStudents(
        widget.classItem,
      );

      if (!mounted) return;

      setState(() {
        _students = rows;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _error = e
            .toString()
            .replaceFirst(
          'Exception: ',
          '',
        );
        _loading = false;
      });
    }
  }

  String _initial(
      Map<String, dynamic>
      student,
      ) {
    final name =
        student['full_name']
            ?.toString()
            .trim() ??
            '';

    if (name.isEmpty) {
      return '?';
    }

    return name
        .substring(0, 1)
        .toUpperCase();
  }

  @override
  Widget build(
      BuildContext context,
      ) {
    final className =
        widget.classItem['name']
            ?.toString() ??
            'Class';

    final section =
        widget.classItem[
        'section_name']
            ?.toString() ??
            '';

    return Container(
      height:
      MediaQuery.of(context)
          .size
          .height *
          .88,
      decoration:
      const BoxDecoration(
        color: Colors.white,
        borderRadius:
        BorderRadius.vertical(
          top: Radius.circular(
            26,
          ),
        ),
      ),
      child: Column(
        children: [
          // ------------------------------------------------------
          // HEADER
          // ------------------------------------------------------

          Padding(
            padding:
            const EdgeInsets
                .fromLTRB(
              20,
              16,
              12,
              12,
            ),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration:
                  BoxDecoration(
                    color: AppColors
                        .primary
                        .withValues(alpha: 
                      .10,
                    ),
                    borderRadius:
                    BorderRadius
                        .circular(
                      14,
                    ),
                  ),
                  child:
                  const Icon(
                    Icons
                        .class_rounded,
                    color:
                    AppColors
                        .primary,
                  ),
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
                        className,
                        style:
                        const TextStyle(
                          fontSize: 20,
                          fontWeight:
                          FontWeight
                              .w900,
                        ),
                      ),
                      Text(
                        section.isEmpty
                            ? 'All sections'
                            : 'Section $section',
                        style:
                        const TextStyle(
                          color:
                          AppColors
                              .textSecondary,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed:
                      () async {
                    final added =
                    await widget
                        .onAddStudent();

                    if (added &&
                        mounted) {
                      await _load();
                    }
                  },
                  icon:
                  const Icon(
                    Icons
                        .person_add_alt_1_rounded,
                    color:
                    AppColors
                        .primary,
                  ),
                ),
                IconButton(
                  onPressed: () {
                    Navigator.of(
                      context,
                    ).pop();
                  },
                  icon:
                  const Icon(
                    Icons
                        .close_rounded,
                  ),
                ),
              ],
            ),
          ),

          const Divider(
            height: 1,
          ),

          // ------------------------------------------------------
          // ADD STUDENT BUTTON
          // ------------------------------------------------------

          Padding(
            padding:
            const EdgeInsets
                .fromLTRB(
              20,
              14,
              20,
              8,
            ),
            child:
            SizedBox(
              width:
              double.infinity,
              child:
              FilledButton.icon(
                onPressed:
                    () async {
                  final added =
                  await widget
                      .onAddStudent();

                  if (added &&
                      mounted) {
                    await _load();
                  }
                },
                icon:
                const Icon(
                  Icons
                      .person_add_alt_1_rounded,
                ),
                label:
                const Text(
                  'Add Student to This Class',
                ),
              ),
            ),
          ),

          // ------------------------------------------------------
          // COUNT
          // ------------------------------------------------------

          Padding(
            padding:
            const EdgeInsets
                .fromLTRB(
              20,
              8,
              20,
              10,
            ),
            child: Row(
              children: [
                Text(
                  '${_students.length} Students',
                  style:
                  const TextStyle(
                    fontSize: 14,
                    fontWeight:
                    FontWeight
                        .w800,
                  ),
                ),
                const Spacer(),
                IconButton(
                  onPressed:
                  _load,
                  icon:
                  const Icon(
                    Icons
                        .refresh_rounded,
                    size: 20,
                  ),
                ),
              ],
            ),
          ),

          // ------------------------------------------------------
          // STUDENTS
          // ------------------------------------------------------

          Expanded(
            child: _loading
                ? const Center(
              child:
              CircularProgressIndicator(),
            )
                : _error != null
                ? Center(
              child:
              Padding(
                padding:
                const EdgeInsets
                    .all(
                  24,
                ),
                child:
                Column(
                  mainAxisSize:
                  MainAxisSize
                      .min,
                  children: [
                    const Icon(
                      Icons
                          .cloud_off_rounded,
                      size: 50,
                      color:
                      AppColors
                          .textMuted,
                    ),
                    const SizedBox(
                      height: 12,
                    ),
                    Text(
                      _error!,
                      textAlign:
                      TextAlign
                          .center,
                    ),
                    const SizedBox(
                      height: 12,
                    ),
                    OutlinedButton(
                      onPressed:
                      _load,
                      child:
                      const Text(
                        'Retry',
                      ),
                    ),
                  ],
                ),
              ),
            )
                : _students
                .isEmpty
                ? ListView(
              children: const [
                SizedBox(
                  height: 80,
                ),
                Icon(
                  Icons
                      .people_outline_rounded,
                  size: 64,
                  color:
                  AppColors
                      .textMuted,
                ),
                SizedBox(
                  height: 14,
                ),
                Center(
                  child:
                  Text(
                    'No students in this class.',
                    style:
                    TextStyle(
                      fontWeight:
                      FontWeight
                          .w700,
                    ),
                  ),
                ),
                SizedBox(
                  height: 6,
                ),
                Center(
                  child:
                  Text(
                    'Use "Add Student to This Class".',
                  ),
                ),
              ],
            )
                : RefreshIndicator(
              onRefresh:
              _load,
              child:
              ListView.separated(
                padding:
                const EdgeInsets
                    .fromLTRB(
                  20,
                  4,
                  20,
                  30,
                ),
                itemCount:
                _students
                    .length,
                separatorBuilder:
                    (_, __) =>
                const SizedBox(
                  height: 8,
                ),
                itemBuilder:
                    (_, index) {
                  final student =
                  _students[
                  index];

                  final name =
                      student[
                      'full_name']
                          ?.toString() ??
                          'Student';

                  final admission =
                      student[
                      'admission_number']
                          ?.toString() ??
                          '-';

                  final father =
                      student[
                      'father_name']
                          ?.toString() ??
                          '-';

                  final active =
                      student[
                      'is_active'] ==
                          true;

                  return Card(
                    margin:
                    EdgeInsets
                        .zero,
                    child:
                    ListTile(
                      leading:
                      CircleAvatar(
                        backgroundColor:
                        AppColors
                            .primary
                            .withValues(alpha: 
                          .10,
                        ),
                        child:
                        Text(
                          _initial(
                            student,
                          ),
                          style:
                          const TextStyle(
                            color:
                            AppColors
                                .primary,
                            fontWeight:
                            FontWeight
                                .w900,
                          ),
                        ),
                      ),
                      title:
                      Text(
                        name,
                        style:
                        const TextStyle(
                          fontWeight:
                          FontWeight
                              .w800,
                        ),
                      ),
                      subtitle:
                      Text(
                        'Admission: $admission'
                            '  •  Father: $father',
                      ),
                      trailing:
                      Row(
                        mainAxisSize:
                        MainAxisSize
                            .min,
                        children: [
                          Container(
                            padding:
                            const EdgeInsets
                                .symmetric(
                              horizontal:
                              8,
                              vertical:
                              4,
                            ),
                            decoration:
                            BoxDecoration(
                              color: active
                                  ? AppColors
                                  .success
                                  .withValues(alpha: 
                                .10,
                              )
                                  : AppColors
                                  .error
                                  .withValues(alpha: 
                                .10,
                              ),
                              borderRadius:
                              BorderRadius
                                  .circular(
                                20,
                              ),
                            ),
                            child:
                            Text(
                              active
                                  ? 'Active'
                                  : 'Inactive',
                              style:
                              TextStyle(
                                color: active
                                    ? AppColors
                                    .success
                                    : AppColors
                                    .error,
                                fontSize:
                                10,
                                fontWeight:
                                FontWeight
                                    .w800,
                              ),
                            ),
                          ),
                          PopupMenuButton<
                              String>(
                            onSelected:
                                (value) async {
                              if (value ==
                                  'edit') {
                                final result =
                                await widget
                                    .onEditStudent(
                                  student,
                                );

                                if (result &&
                                    mounted) {
                                  await _load();
                                }
                              }

                              if (value ==
                                  'delete') {
                                final result =
                                await widget
                                    .onDeleteStudent(
                                  student,
                                );

                                if (result &&
                                    mounted) {
                                  await _load();
                                }
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
                                  'Edit Student',
                                ),
                              ),
                              PopupMenuItem(
                                value:
                                'delete',
                                child:
                                Text(
                                  'Delete Student',
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}