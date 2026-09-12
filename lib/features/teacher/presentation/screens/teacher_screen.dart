import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shimmer/shimmer.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/network/supabase_client.dart';
import '../../../../core/widgets/main_wrapper.dart';

/// ===============================================================
/// TEACHER DATA
/// ===============================================================

class TeacherData {
  final List<Map<String, dynamic>> teachers;
  final List<Map<String, dynamic>> classes;

  const TeacherData({
    required this.teachers,
    required this.classes,
  });
}

/// ===============================================================
/// TEACHER PROVIDER
/// ===============================================================

final teacherProvider =
FutureProvider.autoDispose<TeacherData>((ref) async {
  final client = SupabaseConfig.client;

  final schoolId = await ref.watch(
    schoolIdProvider.future,
  );

  if (schoolId == null) {
    throw Exception(
      'Your account is not linked to a school.',
    );
  }

  final teacherResponse = await client
      .from('profiles')
      .select(
    'id, full_name, email, phone, avatar_url, is_active, '
        'gender, subject, assigned_class, assigned_section, cnic',
  )
      .eq('school_id', schoolId)
      .eq('role', 'teacher')
      .order('full_name');

  List<Map<String, dynamic>> classRows = [];

  try {
    final classResponse = await client
        .from('classes')
        .select('id, name, section_name')
        .eq('school_id', schoolId)
        .order('name');

    classRows = List<Map<String, dynamic>>.from(
      classResponse,
    );
  } catch (_) {
    // Manual class/section entry will remain available.
  }

  return TeacherData(
    teachers: List<Map<String, dynamic>>.from(
      teacherResponse,
    ),
    classes: classRows,
  );
});

/// ===============================================================
/// SEARCH PROVIDER
/// ===============================================================

final teacherSearchProvider =
StateProvider.autoDispose<String>(
      (ref) => '',
);

/// ===============================================================
/// TEACHER SCREEN
/// ===============================================================

class TeacherScreen extends ConsumerStatefulWidget {
  const TeacherScreen({
    super.key,
  });

  @override
  ConsumerState<TeacherScreen> createState() =>
      _TeacherScreenState();
}

class _TeacherScreenState
    extends ConsumerState<TeacherScreen> {
  final ImagePicker _picker = ImagePicker();

  bool _saving = false;

  /// =============================================================
  /// SCHOOL ID
  /// =============================================================

  Future<int?> _getSchoolId() async {
    try {
      return await ref.read(
        schoolIdProvider.future,
      );
    } catch (_) {
      return null;
    }
  }

  /// =============================================================
  /// REFRESH
  /// =============================================================

  Future<void> _refresh() async {
    ref.invalidate(
      teacherProvider,
    );

    try {
      await ref.read(
        teacherProvider.future,
      );
    } catch (_) {}
  }

  /// =============================================================
  /// SEARCH FILTER
  /// =============================================================

  List<Map<String, dynamic>> _filteredTeachers(
      List<Map<String, dynamic>> teachers,
      String search,
      ) {
    final query =
    search.trim().toLowerCase();

    if (query.isEmpty) {
      return teachers;
    }

    return teachers.where(
          (teacher) {
        final text = [
          teacher['full_name'],
          teacher['email'],
          teacher['phone'],
          teacher['subject'],
          teacher['assigned_class'],
          teacher['assigned_section'],
          teacher['gender'],
          teacher['cnic'],
        ]
            .where(
              (value) => value != null,
        )
            .join(' ')
            .toLowerCase();

        return text.contains(query);
      },
    ).toList();
  }

  /// =============================================================
  /// CLASS NAMES
  /// =============================================================

  List<String> _classNames(
      List<Map<String, dynamic>> classes,
      ) {
    final result = <String>{};

    for (final row in classes) {
      final name =
          row['name']
              ?.toString()
              .trim() ??
              '';

      if (name.isNotEmpty) {
        result.add(name);
      }
    }

    final list = result.toList();
    list.sort();

    return list;
  }

  /// =============================================================
  /// SECTIONS
  /// =============================================================

  List<String> _sectionsForClass(
      List<Map<String, dynamic>> classes,
      String className,
      ) {
    final result = <String>{};

    for (final row in classes) {
      final name =
          row['name']
              ?.toString()
              .trim() ??
              '';

      final section =
          row['section_name']
              ?.toString()
              .trim() ??
              '';

      if (name == className &&
          section.isNotEmpty) {
        result.add(section);
      }
    }

    final list = result.toList();
    list.sort();

    return list;
  }

  /// =============================================================
  /// ADD / EDIT TEACHER
  /// =============================================================

  Future<void> _openTeacherDialog({
    Map<String, dynamic>? teacher,
  }) async {
    final data =
        ref.read(teacherProvider).valueOrNull;

    final classes =
        data?.classes ?? [];

    final nameController =
    TextEditingController(
      text:
      teacher?['full_name']
          ?.toString() ??
          '',
    );

    final emailController =
    TextEditingController(
      text:
      teacher?['email']
          ?.toString() ??
          '',
    );

    final phoneController =
    TextEditingController(
      text:
      teacher?['phone']
          ?.toString() ??
          '',
    );

    final cnicController =
    TextEditingController(
      text:
      teacher?['cnic']
          ?.toString() ??
          '',
    );

    final subjectController =
    TextEditingController(
      text:
      teacher?['subject']
          ?.toString() ??
          '',
    );

    final passwordController =
    TextEditingController();

    final classController =
    TextEditingController(
      text:
      teacher?['assigned_class']
          ?.toString() ??
          '',
    );

    final sectionController =
    TextEditingController(
      text:
      teacher?['assigned_section']
          ?.toString() ??
          '',
    );

    String gender =
    teacher?['gender']
        ?.toString()
        .toLowerCase() ==
        'female'
        ? 'Female'
        : 'Male';

    bool active =
        teacher?['is_active'] != false;

    final isEditing =
        teacher != null;

    final classNames =
    _classNames(classes);

    try {
      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) {
          return StatefulBuilder(
            builder: (
                context,
                setDialogState,
                ) {
              final sections =
              _sectionsForClass(
                classes,
                classController.text.trim(),
              );

              return AlertDialog(
                title: Text(
                  isEditing
                      ? 'Edit Teacher'
                      : 'Add Teacher',
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
                        /// NAME
                        TextField(
                          controller:
                          nameController,
                          textCapitalization:
                          TextCapitalization
                              .words,
                          decoration:
                          const InputDecoration(
                            labelText:
                            'Teacher Name *',
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

                        /// GENDER
                        DropdownButtonFormField<
                            String>(
                          initialValue: gender,
                          decoration:
                          const InputDecoration(
                            labelText:
                            'Gender *',
                            prefixIcon:
                            Icon(
                              Icons
                                  .wc_outlined,
                            ),
                          ),
                          items:
                          const [
                            DropdownMenuItem(
                              value: 'Male',
                              child:
                              Text(
                                'Male',
                              ),
                            ),
                            DropdownMenuItem(
                              value: 'Female',
                              child:
                              Text(
                                'Female',
                              ),
                            ),
                          ],
                          onChanged:
                              (value) {
                            if (value ==
                                null) {
                              return;
                            }

                            setDialogState(
                                  () {
                                gender =
                                    value;
                              },
                            );
                          },
                        ),

                        const SizedBox(
                          height: 12,
                        ),

                        /// EMAIL
                        TextField(
                          controller:
                          emailController,
                          keyboardType:
                          TextInputType
                              .emailAddress,
                          decoration:
                          const InputDecoration(
                            labelText:
                            'Email *',
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

                        /// PHONE
                        TextField(
                          controller:
                          phoneController,
                          keyboardType:
                          TextInputType.phone,
                          decoration:
                          const InputDecoration(
                            labelText:
                            'Phone *',
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

                        /// CNIC
                        TextField(
                          controller:
                          cnicController,
                          keyboardType:
                          TextInputType.number,
                          decoration:
                          const InputDecoration(
                            labelText:
                            'CNIC',
                            hintText:
                            '35202-1234567-1',
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

                        /// PASSWORD
                        if (!isEditing) ...[
                          TextField(
                            controller:
                            passwordController,
                            obscureText:
                            true,
                            decoration:
                            const InputDecoration(
                              labelText:
                              'Temporary Password *',
                              helperText:
                              'Minimum 6 characters.',
                              prefixIcon:
                              Icon(
                                Icons
                                    .lock_outline_rounded,
                              ),
                            ),
                          ),
                          const SizedBox(
                            height: 12,
                          ),
                        ],

                        /// SUBJECT
                        TextField(
                          controller:
                          subjectController,
                          textCapitalization:
                          TextCapitalization
                              .words,
                          decoration:
                          const InputDecoration(
                            labelText:
                            'Subject *',
                            prefixIcon:
                            Icon(
                              Icons
                                  .menu_book_outlined,
                            ),
                          ),
                        ),

                        const SizedBox(
                          height: 12,
                        ),

                        /// CLASS
                        if (classNames
                            .isNotEmpty)
                          DropdownButtonFormField<
                              String>(
                            initialValue:
                            classNames.contains(
                              classController
                                  .text
                                  .trim(),
                            )
                                ? classController
                                .text
                                .trim()
                                : null,
                            decoration:
                            const InputDecoration(
                              labelText:
                              'Class *',
                              prefixIcon:
                              Icon(
                                Icons
                                    .school_outlined,
                              ),
                            ),
                            items:
                            classNames.map(
                                  (name) {
                                return DropdownMenuItem<
                                    String>(
                                  value: name,
                                  child:
                                  Text(
                                    name,
                                  ),
                                );
                              },
                            ).toList(),
                            onChanged:
                                (value) {
                              if (value ==
                                  null) {
                                return;
                              }

                              classController
                                  .text = value;

                              sectionController
                                  .clear();

                              setDialogState(
                                    () {},
                              );
                            },
                          )
                        else
                          TextField(
                            controller:
                            classController,
                            decoration:
                            const InputDecoration(
                              labelText:
                              'Class *',
                              hintText:
                              'e.g. Class 5',
                              prefixIcon:
                              Icon(
                                Icons
                                    .school_outlined,
                              ),
                            ),
                          ),

                        const SizedBox(
                          height: 12,
                        ),

                        /// SECTION
                        if (sections
                            .isNotEmpty)
                          DropdownButtonFormField<
                              String>(
                            initialValue:
                            sections.contains(
                              sectionController
                                  .text
                                  .trim(),
                            )
                                ? sectionController
                                .text
                                .trim()
                                : null,
                            decoration:
                            const InputDecoration(
                              labelText:
                              'Section',
                              prefixIcon:
                              Icon(
                                Icons
                                    .class_outlined,
                              ),
                            ),
                            items:
                            sections.map(
                                  (section) {
                                return DropdownMenuItem<
                                    String>(
                                  value:
                                  section,
                                  child:
                                  Text(
                                    section,
                                  ),
                                );
                              },
                            ).toList(),
                            onChanged:
                                (value) {
                              sectionController
                                  .text =
                                  value ?? '';

                              setDialogState(
                                    () {},
                              );
                            },
                          )
                        else
                          TextField(
                            controller:
                            sectionController,
                            decoration:
                            const InputDecoration(
                              labelText:
                              'Section',
                              hintText:
                              'e.g. A',
                              prefixIcon:
                              Icon(
                                Icons
                                    .class_outlined,
                              ),
                            ),
                          ),

                        const SizedBox(
                          height: 8,
                        ),

                        /// ACTIVE
                        SwitchListTile(
                          contentPadding:
                          EdgeInsets.zero,
                          title:
                          const Text(
                            'Active Teacher',
                            style:
                            TextStyle(
                              fontWeight:
                              FontWeight.w800,
                            ),
                          ),
                          subtitle:
                          const Text(
                            'Allow teacher to remain active in the system.',
                          ),
                          value: active,
                          onChanged:
                              (value) {
                            setDialogState(
                                  () {
                                active =
                                    value;
                              },
                            );
                          },
                        ),

                        const SizedBox(
                          height: 4,
                        ),

                        Align(
                          alignment:
                          Alignment
                              .centerLeft,
                          child:
                          Text(
                            isEditing
                                ? 'Photo and documents can be managed from the teacher card.'
                                : 'Photo and documents can be added after saving.',
                            style:
                            const TextStyle(
                              color: AppColors
                                  .textSecondary,
                              fontSize: 11,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                actions: [
                  TextButton(
                    onPressed: _saving
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

                  FilledButton.icon(
                    onPressed: _saving
                        ? null
                        : () async {
                      await _saveTeacher(
                        dialogContext:
                        dialogContext,
                        existing:
                        teacher,
                        name:
                        nameController
                            .text
                            .trim(),
                        email:
                        emailController
                            .text
                            .trim(),
                        phone:
                        phoneController
                            .text
                            .trim(),
                        cnic:
                        cnicController
                            .text
                            .trim(),
                        gender:
                        gender,
                        password:
                        passwordController
                            .text,
                        subject:
                        subjectController
                            .text
                            .trim(),
                        className:
                        classController
                            .text
                            .trim(),
                        section:
                        sectionController
                            .text
                            .trim(),
                        active:
                        active,
                      );
                    },
                    icon:
                    const Icon(
                      Icons
                          .save_rounded,
                    ),
                    label: Text(
                      isEditing
                          ? 'Save Changes'
                          : 'Add Teacher',
                    ),
                  ),
                ],
              );
            },
          );
        },
      );
    } finally {
      nameController.dispose();
      emailController.dispose();
      phoneController.dispose();
      cnicController.dispose();
      subjectController.dispose();
      passwordController.dispose();
      classController.dispose();
      sectionController.dispose();
    }
  }

  /// =============================================================
  /// SAVE TEACHER
  /// =============================================================

  Future<void> _saveTeacher({
    required BuildContext dialogContext,
    required Map<String, dynamic>? existing,
    required String name,
    required String email,
    required String phone,
    required String cnic,
    required String gender,
    required String password,
    required String subject,
    required String className,
    required String section,
    required bool active,
  }) async {
    if (_saving) return;

    if (name.isEmpty ||
        email.isEmpty ||
        phone.isEmpty ||
        subject.isEmpty ||
        className.isEmpty) {
      _showSnack(
        'Name, Email, Phone, Subject and Class are required.',
      );
      return;
    }

    if (existing == null &&
        password.length < 6) {
      _showSnack(
        'Password must be at least 6 characters.',
      );
      return;
    }

    setState(() {
      _saving = true;
    });

    try {
      final client =
          SupabaseConfig.client;

      final schoolId =
      await _getSchoolId();

      if (schoolId == null) {
        throw Exception(
          'Your account is not linked to a school.',
        );
      }

      final data = {
        'full_name': name,
        'email': email,
        'phone': phone,
        'cnic': cnic.isEmpty
            ? null
            : cnic,
        'gender': gender,
        'subject': subject,
        'assigned_class': className,
        'assigned_section':
        section.isEmpty
            ? null
            : section,
        'is_active': active,
      };

      /// =========================================================
      /// EDIT
      /// =========================================================

      if (existing != null) {
        await client
            .from('profiles')
            .update(data)
            .eq(
          'id',
          existing['id'],
        )
            .eq(
          'school_id',
          schoolId,
        );

        ref.invalidate(
          teacherProvider,
        );

        if (dialogContext.mounted) {
          Navigator.pop(
            dialogContext,
          );
        }

        _showSnack(
          'Teacher updated successfully.',
        );

        return;
      }

      /// =========================================================
      /// CREATE AUTH USER
      ///
      /// IMPORTANT:
      /// Do NOT insert into profiles here.
      ///
      /// Your Supabase auth trigger:
      /// on_auth_user_created
      /// -> handle_new_user()
      ///
      /// creates/upserts the profile automatically.
      /// =========================================================

      final currentSession =
          client.auth.currentSession;

      final adminRefreshToken =
          currentSession?.refreshToken;

      if (adminRefreshToken ==
          null) {
        throw Exception(
          'Admin session is missing. Please login again.',
        );
      }

      User? teacherUser;

      try {
        final authResponse =
        await client.auth.signUp(
          email:
          email.toLowerCase(),
          password:
          password,
          data: {
            'full_name':
            name,
            'role':
            'teacher',
            'school_id':
            schoolId,
            'gender':
            gender,
          },
        );

        teacherUser =
            authResponse.user;

        if (teacherUser ==
            null) {
          throw Exception(
            'Teacher account could not be created.',
          );
        }
      } finally {
        /// Restore administrator session.
        try {
          await client.auth
              .setSession(
            adminRefreshToken,
          );
        } catch (_) {}
      }

      /// =========================================================
      /// UPDATE PROFILE CREATED BY TRIGGER
      /// =========================================================

      bool profileUpdated =
      false;

      for (int attempt = 0;
      attempt < 5;
      attempt++) {
        try {
          await Future.delayed(
            const Duration(
              milliseconds: 300,
            ),
          );

          await client
              .from('profiles')
              .update({
            ...data,
            'role':
            'teacher',
            'school_id':
            schoolId,
          })
              .eq(
            'id',
            teacherUser.id,
          )
              .eq(
            'school_id',
            schoolId,
          );

          final profile =
          await client
              .from('profiles')
              .select('id')
              .eq(
            'id',
            teacherUser.id,
          )
              .eq(
            'school_id',
            schoolId,
          )
              .maybeSingle();

          if (profile !=
              null) {
            profileUpdated =
            true;
            break;
          }
        } catch (_) {
          await Future.delayed(
            const Duration(
              milliseconds: 400,
            ),
          );
        }
      }

      if (!profileUpdated) {
        throw Exception(
          'Teacher account was created, but teacher profile could not be completed.',
        );
      }

      ref.invalidate(
        teacherProvider,
      );

      if (dialogContext.mounted) {
        Navigator.pop(
          dialogContext,
        );
      }

      _showSnack(
        'Teacher added successfully.',
      );
    } on AuthException catch (e) {
      _showSnack(
        'Teacher account error: ${e.message}',
      );
    } on PostgrestException catch (e) {
      _showSnack(
        '${e.message} (${e.code})',
      );
    } catch (e) {
      _showSnack(
        e.toString().replaceFirst(
          'Exception: ',
          '',
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _saving = false;
        });
      }
    }
  }

  /// =============================================================
  /// MANAGE TEACHER
  /// =============================================================

  Future<void> _manageTeacher(
      Map<String, dynamic> teacher,
      ) async {
    final choice =
    await showDialog<String>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text(
            teacher['full_name']
                ?.toString() ??
                'Teacher',
            style:
            const TextStyle(
              fontWeight:
              FontWeight.w900,
            ),
          ),
          content:
          const Text(
            'Choose an action.',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(
                  dialogContext,
                  'cancel',
                );
              },
              child:
              const Text(
                'Cancel',
              ),
            ),
            OutlinedButton(
              onPressed: () {
                Navigator.pop(
                  dialogContext,
                  'edit',
                );
              },
              child:
              const Text(
                'Edit',
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
                  'deactivate',
                );
              },
              child:
              const Text(
                'Deactivate',
              ),
            ),
          ],
        );
      },
    );

    if (choice == 'edit') {
      await _openTeacherDialog(
        teacher: teacher,
      );
      return;
    }

    if (choice != 'deactivate') {
      return;
    }

    if (!mounted) return;

    final confirmed =
    await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title:
          const Text(
            'Deactivate Teacher?',
          ),
          content: Text(
            'Are you sure you want to deactivate ${teacher['full_name'] ?? 'this teacher'}?',
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
                'Deactivate',
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
      await _getSchoolId();

      if (schoolId == null) {
        throw Exception(
          'School not found.',
        );
      }

      await SupabaseConfig.client
          .from('profiles')
          .update({
        'is_active': false,
      })
          .eq(
        'id',
        teacher['id'],
      )
          .eq(
        'school_id',
        schoolId,
      );

      ref.invalidate(
        teacherProvider,
      );

      _showSnack(
        'Teacher deactivated successfully.',
      );
    } on PostgrestException catch (e) {
      _showSnack(
        e.message,
      );
    } catch (e) {
      _showSnack(
        e.toString().replaceFirst(
          'Exception: ',
          '',
        ),
      );
    }
  }

  /// =============================================================
  /// TEACHER PHOTO
  /// =============================================================

  Future<void> _pickTeacherPhoto(
      Map<String, dynamic> teacher,
      ) async {
    final teacherId =
    teacher['id']?.toString();

    if (teacherId == null ||
        teacherId.isEmpty) {
      return;
    }

    try {
      final image =
      await _picker.pickImage(
        source:
        ImageSource.gallery,
        imageQuality: 70,
        maxWidth: 1000,
      );

      if (image == null) {
        return;
      }

      final bytes =
      await File(
        image.path,
      ).readAsBytes();

      final path =
          'teacher_${teacherId}_${DateTime.now().millisecondsSinceEpoch}.jpg';

      await SupabaseConfig
          .client.storage
          .from(
        'teacher-avatars',
      )
          .uploadBinary(
        path,
        bytes,
        fileOptions:
        const FileOptions(
          contentType:
          'image/jpeg',
          upsert: true,
        ),
      );

      final url =
      SupabaseConfig
          .client.storage
          .from(
        'teacher-avatars',
      )
          .getPublicUrl(
        path,
      );

      final schoolId =
      await _getSchoolId();

      if (schoolId == null) {
        throw Exception(
          'School not found.',
        );
      }

      await SupabaseConfig
          .client
          .from('profiles')
          .update({
        'avatar_url':
        url,
      })
          .eq(
        'id',
        teacherId,
      )
          .eq(
        'school_id',
        schoolId,
      );

      ref.invalidate(
        teacherProvider,
      );

      _showSnack(
        'Teacher photo updated successfully.',
      );
    } on PostgrestException catch (e) {
      _showSnack(
        e.message,
      );
    } catch (e) {
      _showSnack(
        e.toString().replaceFirst(
          'Exception: ',
          '',
        ),
      );
    }
  }

  /// =============================================================
  /// DOCUMENTS
  /// =============================================================

  Future<void> _manageDocuments(
      Map<String, dynamic> teacher,
      ) async {
    final teacherId =
    teacher['id']?.toString();

    if (teacherId == null ||
        teacherId.isEmpty) {
      return;
    }

    try {
      final rows =
      await SupabaseConfig
          .client
          .from('teacher_documents')
          .select(
        'id, document_type, file_name, file_url, created_at',
      )
          .eq(
        'teacher_id',
        teacherId,
      )
          .order(
        'created_at',
        ascending: false,
      );

      final documents =
      List<Map<String, dynamic>>.from(
        rows,
      );

      if (!mounted) {
        return;
      }

      await showDialog<void>(
        context: context,
        builder: (dialogContext) {
          return AlertDialog(
            title: Text(
              '${teacher['full_name'] ?? 'Teacher'} Documents',
              style:
              const TextStyle(
                fontWeight:
                FontWeight.w900,
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
                    const Align(
                      alignment:
                      Alignment
                          .centerLeft,
                      child: Text(
                        'Documents uploaded to Supabase Storage.',
                        style:
                        TextStyle(
                          color:
                          AppColors
                              .textSecondary,
                          fontSize:
                          12,
                        ),
                      ),
                    ),

                    const SizedBox(
                      height: 12,
                    ),

                    if (documents
                        .isEmpty)
                      const Padding(
                        padding:
                        EdgeInsets.all(
                          20,
                        ),
                        child: Text(
                          'No documents uploaded yet.',
                        ),
                      ),

                    ...documents.map(
                          (doc) {
                        return ListTile(
                          contentPadding:
                          EdgeInsets.zero,
                          leading:
                          Container(
                            width: 40,
                            height: 40,
                            decoration:
                            BoxDecoration(
                              color: AppColors
                                  .primary
                                  .withValues(
                                alpha: .08,
                              ),
                              borderRadius:
                              BorderRadius
                                  .circular(
                                11,
                              ),
                            ),
                            child:
                            const Icon(
                              Icons
                                  .description_outlined,
                              color:
                              AppColors
                                  .primary,
                            ),
                          ),
                          title:
                          Text(
                            doc['document_type']
                                ?.toString() ??
                                'Document',
                            style:
                            const TextStyle(
                              fontWeight:
                              FontWeight
                                  .w700,
                            ),
                          ),
                          subtitle:
                          Text(
                            doc['file_name']
                                ?.toString() ??
                                '',
                          ),
                          trailing:
                          IconButton(
                            tooltip:
                            'Delete',
                            onPressed:
                                () async {
                              final id =
                              doc['id'];

                              if (id ==
                                  null) {
                                return;
                              }

                              try {
                                await SupabaseConfig
                                    .client
                                    .from(
                                  'teacher_documents',
                                )
                                    .delete()
                                    .eq(
                                  'id',
                                  id,
                                )
                                    .eq(
                                  'teacher_id',
                                  teacherId,
                                );

                                if (dialogContext
                                    .mounted) {
                                  Navigator.pop(
                                    dialogContext,
                                  );
                                }

                                _showSnack(
                                  'Document deleted.',
                                );
                              } on PostgrestException catch (e) {
                                _showSnack(
                                  e.message,
                                );
                              } catch (e) {
                                _showSnack(
                                  e.toString().replaceFirst(
                                    'Exception: ',
                                    '',
                                  ),
                                );
                              }
                            },
                            icon:
                            const Icon(
                              Icons
                                  .delete_outline_rounded,
                              color:
                              AppColors
                                  .error,
                            ),
                          ),
                        );
                      },
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
                const Text(
                  'Close',
                ),
              ),
            ],
          );
        },
      );
    } on PostgrestException catch (e) {
      _showSnack(
        'Documents table error: ${e.message}',
      );
    } catch (e) {
      _showSnack(
        e.toString().replaceFirst(
          'Exception: ',
          '',
        ),
      );
    }
  }

  /// =============================================================
  /// SNACKBAR
  /// =============================================================

  void _showSnack(
      String message,
      ) {
    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content:
          Text(message),
          behavior:
          SnackBarBehavior
              .floating,
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
    final teacherAsync =
    ref.watch(
      teacherProvider,
    );

    final search =
    ref.watch(
      teacherSearchProvider,
    );

    return MainWrapper(
      child: teacherAsync.when(
        loading:
            () => const _TeacherLoading(),

        error:
            (error, stack) =>
            _TeacherError(
              message:
              error.toString().replaceFirst(
                'Exception: ',
                '',
              ),
              onRetry:
              _refresh,
            ),

        data:
            (data) {
          final teachers =
          _filteredTeachers(
            data.teachers,
            search,
          );

          return _TeacherContent(
            teachers:
            teachers,
            totalTeachers:
            data.teachers.length,
            search:
            search,
            onSearch:
                (value) {
              ref
                  .read(
                teacherSearchProvider
                    .notifier,
              )
                  .state = value;
            },
            onClearSearch:
                () {
              ref
                  .read(
                teacherSearchProvider
                    .notifier,
              )
                  .state = '';
            },
            onRefresh:
            _refresh,
            onAdd:
                () =>
                _openTeacherDialog(),
            onEdit:
                (teacher) =>
                _openTeacherDialog(
                  teacher: teacher,
                ),
            onManage:
            _manageTeacher,
            onPhoto:
            _pickTeacherPhoto,
            onDocuments:
            _manageDocuments,
          );
        },
      ),
    );
  }
}

/// ===============================================================
/// TEACHER CONTENT
/// ===============================================================

class _TeacherContent
    extends StatelessWidget {
  final List<Map<String, dynamic>> teachers;
  final int totalTeachers;
  final String search;
  final ValueChanged<String> onSearch;
  final VoidCallback onClearSearch;
  final Future<void> Function() onRefresh;
  final VoidCallback onAdd;
  final Future<void> Function(
      Map<String, dynamic>,
      ) onEdit;
  final Future<void> Function(
      Map<String, dynamic>,
      ) onManage;
  final Future<void> Function(
      Map<String, dynamic>,
      ) onPhoto;
  final Future<void> Function(
      Map<String, dynamic>,
      ) onDocuments;

  const _TeacherContent({
    required this.teachers,
    required this.totalTeachers,
    required this.search,
    required this.onSearch,
    required this.onClearSearch,
    required this.onRefresh,
    required this.onAdd,
    required this.onEdit,
    required this.onManage,
    required this.onPhoto,
    required this.onDocuments,
  });

  @override
  Widget build(
      BuildContext context,
      ) {
    return LayoutBuilder(
      builder:
          (
          context,
          constraints,
          ) {
        final desktop =
            constraints.maxWidth >=
                1100;

        final tablet =
            constraints.maxWidth >=
                650;

        return Column(
          children: [
            /// HEADER
            _header(
              context,
              desktop,
            ),

            /// SEARCH
            _searchBox(
              context,
            ),

            /// BODY
            Expanded(
              child:
              RefreshIndicator(
                onRefresh:
                onRefresh,
                child:
                teachers.isEmpty
                    ? _empty(
                  context,
                )
                    : GridView.builder(
                  physics:
                  const AlwaysScrollableScrollPhysics(),
                  padding:
                  EdgeInsets.fromLTRB(
                    desktop
                        ? 28
                        : tablet
                        ? 22
                        : 16,
                    8,
                    desktop
                        ? 28
                        : tablet
                        ? 22
                        : 16,
                    30,
                  ),
                  gridDelegate:
                  SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount:
                    desktop
                        ? 3
                        : tablet
                        ? 2
                        : 1,
                    crossAxisSpacing:
                    16,
                    mainAxisSpacing:
                    16,
                    childAspectRatio:
                    desktop
                        ? 1.28
                        : tablet
                        ? 1.18
                        : 1.55,
                  ),
                  itemCount:
                  teachers.length,
                  itemBuilder:
                      (
                      context,
                      index,
                      ) {
                    return _teacherCard(
                      context,
                      teachers[index],
                    );
                  },
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  /// =============================================================
  /// HEADER
  /// =============================================================

  Widget _header(
      BuildContext context,
      bool desktop,
      ) {
    return Padding(
      padding:
      EdgeInsets.fromLTRB(
        desktop ? 28 : 18,
        desktop ? 24 : 16,
        desktop ? 28 : 18,
        10,
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
                  .withValues(alpha: .10),
              borderRadius:
              BorderRadius.circular(
                14,
              ),
            ),
            child:
            const Icon(
              Icons
                  .school_rounded,
              color:
              AppColors.primary,
            ),
          ),

          const SizedBox(
            width: 12,
          ),

          Expanded(
            child: Column(
              crossAxisAlignment:
              CrossAxisAlignment
                  .start,
              children: [
                const Text(
                  'Faculty Directory',
                  style:
                  TextStyle(
                    fontSize: 23,
                    fontWeight:
                    FontWeight.w900,
                    letterSpacing:
                    -.5,
                  ),
                ),
                const SizedBox(
                  height: 3,
                ),
                Text(
                  '$totalTeachers teacher${totalTeachers == 1 ? '' : 's'} • Manage faculty and classes',
                  style:
                  const TextStyle(
                    color: AppColors
                        .textSecondary,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),

          IconButton(
            tooltip:
            'Refresh',
            onPressed:
            onRefresh,
            icon:
            const Icon(
              Icons
                  .refresh_rounded,
            ),
          ),

          const SizedBox(
            width: 4,
          ),

          FilledButton.icon(
            onPressed:
            onAdd,
            icon:
            const Icon(
              Icons
                  .person_add_rounded,
            ),
            label:
            const Text(
              'Add Teacher',
            ),
          ),
        ],
      ),
    );
  }

  /// =============================================================
  /// SEARCH
  /// =============================================================

  Widget _searchBox(
      BuildContext context,
      ) {
    return Padding(
      padding:
      const EdgeInsets
          .fromLTRB(
        18,
        4,
        18,
        8,
      ),
      child: TextField(
        onChanged:
        onSearch,
        decoration:
        InputDecoration(
          hintText:
          'Search teacher, subject, class or email...',
          prefixIcon:
          const Icon(
            Icons
                .search_rounded,
          ),
          suffixIcon:
          search.isEmpty
              ? null
              : IconButton(
            onPressed:
            onClearSearch,
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

  /// =============================================================
  /// TEACHER CARD
  /// =============================================================

  Widget _teacherCard(
    BuildContext context,
    Map<String, dynamic> teacher,
  ) {
    final rawName = teacher['full_name']?.toString().trim();
    final name = rawName == null || rawName.isEmpty ? 'Teacher' : rawName;
    final avatar = teacher['avatar_url']?.toString();
    final active = teacher['is_active'] != false;
    final subject = teacher['subject']?.toString().trim().isNotEmpty == true
        ? teacher['subject'].toString()
        : '-';
    final className =
        teacher['assigned_class']?.toString().trim().isNotEmpty == true
            ? teacher['assigned_class'].toString()
            : '-';
    final section = teacher['assigned_section']?.toString().trim() ?? '';
    final gender = teacher['gender']?.toString() ?? '-';
    final email = teacher['email']?.toString() ?? '';
    final phone = teacher['phone']?.toString() ?? '';

    return Card(
      elevation: 0,
      margin: EdgeInsets.zero,
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: () => onEdit(teacher),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              /// TOP
              Row(
                children: [
                  GestureDetector(
                    onTap: () => onPhoto(teacher),
                    child: Stack(
                      children: [
                        CircleAvatar(
                          radius: 31,
                          backgroundColor:
                              AppColors.primary.withValues(alpha: .10),
                          backgroundImage: avatar != null && avatar.isNotEmpty
                              ? NetworkImage(avatar)
                              : null,
                          child: avatar == null || avatar.isEmpty
                              ? Text(
                                  name[0].toUpperCase(),
                                  style: const TextStyle(
                                    color: AppColors.primary,
                                    fontSize: 20,
                                    fontWeight: FontWeight.w900,
                                  ),
                                )
                              : null,
                        ),
                        Positioned(
                          right: 0,
                          bottom: 0,
                          child: Container(
                            width: 20,
                            height: 20,
                            decoration: BoxDecoration(
                              color: AppColors.primary,
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white, width: 2),
                            ),
                            child: const Icon(Icons.camera_alt_rounded,
                                color: Colors.white, size: 10),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontSize: 15, fontWeight: FontWeight.w900),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '$gender • $subject',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              color: AppColors.textSecondary, fontSize: 10),
                        ),
                      ],
                    ),
                  ),
                  _status(active),
                  PopupMenuButton<String>(
                    onSelected: (value) {
                      if (value == 'edit') {
                        onEdit(teacher);
                      } else if (value == 'documents') {
                        onDocuments(teacher);
                      } else if (value == 'manage') {
                        onManage(teacher);
                      }
                    },
                    itemBuilder: (context) => const [
                      PopupMenuItem(value: 'edit', child: Text('Edit')),
                      PopupMenuItem(
                          value: 'documents', child: Text('Documents')),
                      PopupMenuItem(
                          value: 'manage', child: Text('Manage / Deactivate')),
                    ],
                  ),
                ],
              ),

              const SizedBox(height: 14),

              /// CLASS
              Container(
                width: double.infinity,
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: AppColors.background,
                  borderRadius: BorderRadius.circular(13),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 34,
                      height: 34,
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: .09),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.school_outlined,
                          size: 18, color: AppColors.primary),
                    ),
                    const SizedBox(width: 9),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Assigned Class',
                            style: TextStyle(
                                fontSize: 9, color: AppColors.textSecondary),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            section.isEmpty
                                ? className
                                : '$className - $section',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                fontSize: 12, fontWeight: FontWeight.w800),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 12),

              /// CONTACT
              if (email.isNotEmpty)
                Row(
                  children: [
                    const Icon(Icons.email_outlined,
                        size: 15, color: AppColors.textSecondary),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        email,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontSize: 10, color: AppColors.textSecondary),
                      ),
                    ),
                  ],
                ),

              if (phone.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 5),
                  child: Row(
                    children: [
                      const Icon(Icons.phone_outlined,
                          size: 15, color: AppColors.textSecondary),
                      const SizedBox(width: 6),
                      Text(
                        phone,
                        style: const TextStyle(
                            fontSize: 10, color: AppColors.textSecondary),
                      ),
                    ],
                  ),
                ),

              const Spacer(),

              /// DOCUMENT BUTTON
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () => onDocuments(teacher),
                  icon: const Icon(Icons.description_outlined, size: 17),
                  label: const Text('Documents'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// =============================================================
  /// STATUS
  /// =============================================================

  Widget _status(
    bool active,
  ) {
    final color = active ? AppColors.success : AppColors.error;

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 8,
        vertical: 5,
      ),
      decoration: BoxDecoration(
        color: color.withValues(
          alpha: .10,
        ),
        borderRadius: BorderRadius.circular(
          20,
        ),
      ),
      child: Text(
        active ? 'ACTIVE' : 'INACTIVE',
        style: TextStyle(
          color: color,
          fontSize: 8,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }

  /// =============================================================
  /// EMPTY
  /// =============================================================

  Widget _empty(
    BuildContext context,
  ) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        SizedBox(
          height: MediaQuery.of(
                context,
              ).size.height *
              .50,
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(
                      alpha: .08,
                    ),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.school_outlined,
                    size: 40,
                    color: AppColors.primary,
                  ),
                ),
                const SizedBox(
                  height: 16,
                ),
                Text(
                  search.isEmpty
                      ? 'No faculty members found.'
                      : 'No matching teachers found.',
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(
                  height: 12,
                ),
                if (search.isEmpty)
                  FilledButton.icon(
                    onPressed: onAdd,
                    icon: const Icon(
                      Icons.person_add_rounded,
                    ),
                    label: const Text(
                      'Add Teacher',
                    ),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// ===============================================================
/// LOADING
/// ===============================================================

class _TeacherLoading
    extends StatelessWidget {
  const _TeacherLoading();

  @override
  Widget build(
      BuildContext context,
      ) {
    return Padding(
      padding:
      const EdgeInsets.all(
        20,
      ),
      child:
      Shimmer.fromColors(
        baseColor:
        Colors.grey.shade200,
        highlightColor:
        Colors.white,
        child:
        GridView.count(
          crossAxisCount:
          MediaQuery.of(
            context,
          ).size.width >=
              900
              ? 3
              : MediaQuery.of(
            context,
          ).size.width >=
              600
              ? 2
              : 1,
          crossAxisSpacing:
          16,
          mainAxisSpacing:
          16,
          children:
          List.generate(
            6,
                (_) =>
                Card(
                  child:
                  Container(),
                ),
          ),
        ),
      ),
    );
  }
}

/// ===============================================================
/// ERROR
/// ===============================================================

class _TeacherError
    extends StatelessWidget {
  final String message;
  final Future<void> Function()
  onRetry;

  const _TeacherError({
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
        Column(
          mainAxisSize:
          MainAxisSize.min,
          children: [
            Container(
              width: 70,
              height: 70,
              decoration:
              BoxDecoration(
                color: AppColors
                    .error
                    .withValues(
                  alpha: .08,
                ),
                shape:
                BoxShape.circle,
              ),
              child:
              const Icon(
                Icons
                    .cloud_off_rounded,
                size: 35,
                color:
                AppColors.error,
              ),
            ),

            const SizedBox(
              height: 14,
            ),

            const Text(
              'Unable to load teachers',
              style:
              TextStyle(
                fontSize: 17,
                fontWeight:
                FontWeight.w900,
              ),
            ),

            const SizedBox(
              height: 8,
            ),

            Text(
              message,
              textAlign:
              TextAlign.center,
              style:
              const TextStyle(
                fontSize: 11,
                color: AppColors
                    .textSecondary,
              ),
            ),

            const SizedBox(
              height: 16,
            ),

            FilledButton.icon(
              onPressed:
              onRetry,
              icon:
              const Icon(
                Icons
                    .refresh_rounded,
              ),
              label:
              const Text(
                'Retry',
              ),
            ),
          ],
        ),
      ),
    );
  }
}