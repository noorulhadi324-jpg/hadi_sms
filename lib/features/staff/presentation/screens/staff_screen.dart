import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/network/supabase_client.dart';
import '../../../../core/widgets/main_wrapper.dart';

const List<String> staffRoles = <String>[
  'Management',
  'Fee Collection',
  'Accountant',
  'Admission',
  'Office Administration',
  'Receptionist',
  'Coordinator',
  'Librarian',
  'IT / Computer Operator',
  'HR / Admin',
  'Exam Coordinator',
  'Transport Incharge',
  'Store Keeper',
  'Peon / Support Staff',
  'Security',
  'Other',
];

final staffProvider =
FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final schoolId = await ref.watch(schoolIdProvider.future);

  if (schoolId == null) {
    throw Exception('Your account is not linked to a school.');
  }

  final rows = await SupabaseConfig.client
      .from('profiles')
      .select(
    'id,full_name,email,phone,role,staff_role,is_active,cnic,gender,created_at',
  )
      .eq('school_id', schoolId)
      .eq('role', 'staff')
      .order('created_at', ascending: false);

  return List<Map<String, dynamic>>.from(rows);
});

class StaffScreen extends ConsumerWidget {
  const StaffScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final staffAsync = ref.watch(staffProvider);

    return MainWrapper(
      child: staffAsync.when(
        loading: () => const Center(
          child: CircularProgressIndicator(),
        ),
        error: (error, stackTrace) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.error_outline_rounded,
                  size: 48,
                  color: Colors.redAccent,
                ),
                const SizedBox(height: 12),
                Text(
                  error.toString().replaceFirst('Exception: ', ''),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                FilledButton.icon(
                  onPressed: () {
                    ref.invalidate(staffProvider);
                  },
                  icon: const Icon(Icons.refresh_rounded),
                  label: const Text('Retry'),
                ),
              ],
            ),
          ),
        ),
        data: (list) => _StaffPage(list: list),
      ),
    );
  }
}

class _StaffPage extends ConsumerStatefulWidget {
  final List<Map<String, dynamic>> list;

  const _StaffPage({
    required this.list,
  });

  @override
  ConsumerState<_StaffPage> createState() => _StaffPageState();
}

class _StaffPageState extends ConsumerState<_StaffPage> {
  String search = '';

  List<String> _parseRoles(dynamic value) {
    if (value == null) {
      return [];
    }

    final text = value.toString().trim();

    if (text.isEmpty) {
      return [];
    }

    return text
        .replaceAll('[', '')
        .replaceAll(']', '')
        .replaceAll('"', '')
        .split(',')
        .map((item) => item.trim())
        .where((item) => item.isNotEmpty)
        .toList();
  }

  Future<void> _openStaffDialog({
    Map<String, dynamic>? staff,
  }) async {
    final bool editing = staff != null;

    final nameController = TextEditingController(
      text: staff?['full_name']?.toString() ?? '',
    );

    final emailController = TextEditingController(
      text: staff?['email']?.toString() ?? '',
    );

    final phoneController = TextEditingController(
      text: staff?['phone']?.toString() ?? '',
    );

    final cnicController = TextEditingController(
      text: staff?['cnic']?.toString() ?? '',
    );

    final Set<String> selectedRoles = _parseRoles(
      staff?['staff_role'],
    ).toSet();

    String gender = 'male';

    final storedGender = staff?['gender']?.toString().toLowerCase();

    if (storedGender == 'male' ||
        storedGender == 'female' ||
        storedGender == 'other') {
      gender = storedGender!;
    }

    bool active = staff?['is_active'] != false;
    bool saving = false;

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (dialogContext, setDialogState) {
            return AlertDialog(
              title: Text(
                editing ? 'Edit Staff' : 'Add Staff',
                style: const TextStyle(
                  fontWeight: FontWeight.w900,
                ),
              ),
              content: SizedBox(
                width: 560,
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildField(
                        controller: nameController,
                        label: 'Full Name',
                        icon: Icons.person_outline_rounded,
                        capitalization: TextCapitalization.words,
                        enabled: !saving,
                      ),

                      const SizedBox(height: 12),

                      _buildField(
                        controller: emailController,
                        label: 'Email',
                        icon: Icons.email_outlined,
                        capitalization: TextCapitalization.none,
                        keyboardType: TextInputType.emailAddress,
                        enabled: !editing && !saving,
                      ),

                      const SizedBox(height: 12),

                      _buildField(
                        controller: phoneController,
                        label: 'Phone',
                        icon: Icons.phone_outlined,
                        capitalization: TextCapitalization.none,
                        keyboardType: TextInputType.phone,
                        enabled: !saving,
                      ),

                      const SizedBox(height: 12),

                      _buildField(
                        controller: cnicController,
                        label: 'CNIC',
                        icon: Icons.badge_outlined,
                        capitalization: TextCapitalization.none,
                        keyboardType: TextInputType.number,
                        enabled: !saving,
                      ),

                      const SizedBox(height: 14),

                      DropdownButtonFormField<String>(
                        initialValue: gender,
                        decoration: const InputDecoration(
                          labelText: 'Gender',
                          prefixIcon: Icon(
                            Icons.wc_rounded,
                          ),
                        ),
                        items: const [
                          DropdownMenuItem(
                            value: 'male',
                            child: Text('Male'),
                          ),
                          DropdownMenuItem(
                            value: 'female',
                            child: Text('Female'),
                          ),
                          DropdownMenuItem(
                            value: 'other',
                            child: Text('Other'),
                          ),
                        ],
                        onChanged: saving
                            ? null
                            : (value) {
                          if (value == null) {
                            return;
                          }

                          setDialogState(() {
                            gender = value;
                          });
                        },
                      ),

                      const SizedBox(height: 18),

                      const Text(
                        'Responsibilities',
                        style: TextStyle(
                          fontWeight: FontWeight.w900,
                        ),
                      ),

                      const SizedBox(height: 8),

                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: staffRoles.map(
                              (role) {
                            final bool selected =
                            selectedRoles.contains(role);

                            return FilterChip(
                              label: Text(role),
                              selected: selected,
                              onSelected: saving
                                  ? null
                                  : (isSelected) {
                                setDialogState(() {
                                  if (isSelected) {
                                    selectedRoles.add(role);
                                  } else {
                                    selectedRoles.remove(role);
                                  }
                                });
                              },
                            );
                          },
                        ).toList(),
                      ),

                      const SizedBox(height: 12),

                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        value: active,
                        title: const Text(
                          'Active account',
                        ),
                        subtitle: const Text(
                          'Allow this staff member to use the system.',
                        ),
                        onChanged: saving
                            ? null
                            : (value) {
                          setDialogState(() {
                            active = value;
                          });
                        },
                      ),

                      if (!editing) ...[
                        const SizedBox(height: 6),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(10),
                            color: AppColors.primary.withValues(
                              alpha: 0.06,
                            ),
                          ),
                          child: const Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Icon(
                                Icons.info_outline_rounded,
                                size: 18,
                              ),
                              SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Staff کو invitation email ملے گی۔ '
                                      'Temporary password یہاں دکھایا نہیں جائے گا۔',
                                  style: TextStyle(
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: saving
                      ? null
                      : () {
                    Navigator.of(dialogContext).pop();
                  },
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: saving
                      ? null
                      : () async {
                    final String name =
                    nameController.text.trim();

                    final String email =
                    emailController.text.trim().toLowerCase();

                    final String phone =
                    phoneController.text.trim();

                    final String cnic =
                    cnicController.text.trim();

                    if (name.isEmpty) {
                      _showError(
                        'Full name is required.',
                      );
                      return;
                    }

                    if (!editing) {
                      if (email.isEmpty || !email.contains('@')) {
                        _showError(
                          'Valid email is required.',
                        );
                        return;
                      }
                    }

                    if (selectedRoles.isEmpty) {
                      _showError(
                        'Select at least one responsibility.',
                      );
                      return;
                    }

                    setDialogState(() {
                      saving = true;
                    });

                    try {
                      if (editing) {
                        await SupabaseConfig.client
                            .from('profiles')
                            .update({
                          'full_name': name,
                          'phone': phone.isEmpty ? null : phone,
                          'cnic': cnic.isEmpty ? null : cnic,
                          'gender': gender,
                          'staff_role':
                          selectedRoles.join(', '),
                          'is_active': active,
                        }).eq(
                          'id',
                          staff!['id'],
                        );

                        ref.invalidate(
                          staffProvider,
                        );

                        if (dialogContext.mounted) {
                          Navigator.of(dialogContext).pop();
                        }

                        _showSuccess(
                          'Staff updated successfully.',
                        );
                      } else {
                        final response =
                        await SupabaseConfig.client.functions
                            .invoke(
                          'create-staff-account',
                          body: {
                            'full_name': name,
                            'email': email,
                            'phone': phone,
                            'cnic': cnic,
                            'gender': gender,
                            'staff_role':
                            selectedRoles.join(', '),
                          },
                        );

                        final dynamic rawData = response.data;

                        if (rawData is! Map) {
                          throw Exception(
                            'Invalid response from server.',
                          );
                        }

                        final Map<String, dynamic> data =
                        Map<String, dynamic>.from(
                          rawData,
                        );

                        if (data['success'] != true) {
                          throw Exception(
                            data['error']?.toString() ??
                                'Unable to create staff account.',
                          );
                        }

                        ref.invalidate(
                          staffProvider,
                        );

                        if (dialogContext.mounted) {
                          Navigator.of(dialogContext).pop();
                        }

                        _showSuccess(
                          'Invitation sent to staff.',
                        );
                      }
                    } catch (error) {
                      setDialogState(() {
                        saving = false;
                      });

                      _showError(
                        error
                            .toString()
                            .replaceFirst(
                          'Exception: ',
                          '',
                        ),
                      );
                    }
                  },
                  child: saving
                      ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                      : Text(
                    editing
                        ? 'Save Changes'
                        : 'Create & Invite',
                  ),
                ),
              ],
            );
          },
        );
      },
    );

    nameController.dispose();
    emailController.dispose();
    phoneController.dispose();
    cnicController.dispose();
  }

  Future<void> _performAction(
      Map<String, dynamic> staff,
      String action,
      ) async {
    try {
      final response = await SupabaseConfig.client.functions.invoke(
        'manage-role-account',
        body: {
          'action': action,
          'user_id': staff['id'],
        },
      );

      final dynamic rawData = response.data;

      if (rawData is! Map) {
        throw Exception(
          'Invalid response from server.',
        );
      }

      final Map<String, dynamic> data =
      Map<String, dynamic>.from(rawData);

      if (data['success'] != true) {
        throw Exception(
          data['error']?.toString() ??
              'Operation failed.',
        );
      }

      ref.invalidate(
        staffProvider,
      );

      _showSuccess(
        data['message']?.toString() ?? 'Operation completed.',
      );
    } catch (error) {
      _showError(
        error.toString().replaceFirst(
          'Exception: ',
          '',
        ),
      );
    }
  }

  Future<void> _deleteStaff(
      Map<String, dynamic> staff,
      ) async {
    final String staffName =
        staff['full_name']?.toString() ?? 'this account';

    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text(
            'Delete Staff?',
          ),
          content: Text(
            'Delete $staffName permanently?',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop(false);
              },
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.of(dialogContext).pop(true);
              },
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );

    if (confirmed == true) {
      await _performAction(
        staff,
        'delete',
      );
    }
  }

  Widget _buildField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    required TextCapitalization capitalization,
    TextInputType? keyboardType,
    bool enabled = true,
  }) {
    return TextField(
      controller: controller,
      enabled: enabled,
      keyboardType: keyboardType,
      textCapitalization: capitalization,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon),
      ),
    );
  }

  void _showError(String message) {
    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.redAccent,
      ),
    );
  }

  void _showSuccess(String message) {
    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppColors.success,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final String query = search.trim().toLowerCase();

    final List<Map<String, dynamic>> filteredList =
    widget.list.where((staff) {
      if (query.isEmpty) {
        return true;
      }

      final String searchableText = [
        staff['full_name'],
        staff['email'],
        staff['phone'],
        staff['staff_role'],
      ].map((value) => value?.toString() ?? '').join(' ').toLowerCase();

      return searchableText.contains(query);
    }).toList();

    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Staff Management',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  SizedBox(height: 5),
                  Text(
                    'Manage team staff and responsibilities.',
                    style: TextStyle(
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            FilledButton.icon(
              onPressed: () {
                _openStaffDialog();
              },
              icon: const Icon(
                Icons.person_add_alt_1_rounded,
              ),
              label: const Text(
                'Add Staff',
              ),
            ),
          ],
        ),

        const SizedBox(height: 20),

        TextField(
          onChanged: (value) {
            setState(() {
              search = value;
            });
          },
          decoration: const InputDecoration(
            prefixIcon: Icon(
              Icons.search_rounded,
            ),
            hintText: 'Search staff...',
          ),
        ),

        const SizedBox(height: 18),

        if (filteredList.isEmpty)
          Card(
            elevation: 0,
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                children: [
                  Icon(
                    Icons.people_outline_rounded,
                    size: 52,
                    color: AppColors.primary.withValues(
                      alpha: 0.5,
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'No staff found.',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    query.isEmpty
                        ? 'Add your first staff member.'
                        : 'Try another search.',
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          )
        else
          ...filteredList.map(
                (staff) {
              final bool isActive =
                  staff['is_active'] != false;

              final String staffName =
                  staff['full_name']?.toString() ??
                      'Unnamed Staff';

              final String email =
                  staff['email']?.toString() ?? '';

              final String responsibilities =
                  staff['staff_role']?.toString() ??
                      'Staff';

              return Card(
                elevation: 0,
                margin: const EdgeInsets.only(
                  bottom: 10,
                ),
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 6,
                  ),
                  leading: CircleAvatar(
                    backgroundColor:
                    AppColors.primary.withValues(
                      alpha: 0.08,
                    ),
                    child: const Icon(
                      Icons.badge_rounded,
                      color: AppColors.primary,
                    ),
                  ),
                  title: Row(
                    children: [
                      Flexible(
                        child: Text(
                          staffName,
                          style: const TextStyle(
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(20),
                          color: isActive
                              ? AppColors.success.withValues(
                            alpha: 0.10,
                          )
                              : Colors.grey.withValues(
                            alpha: 0.12,
                          ),
                        ),
                        child: Text(
                          isActive ? 'Active' : 'Inactive',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: isActive
                                ? AppColors.success
                                : Colors.grey.shade700,
                          ),
                        ),
                      ),
                    ],
                  ),
                  subtitle: Padding(
                    padding: const EdgeInsets.only(
                      top: 4,
                    ),
                    child: Text(
                      '$email\n$responsibilities',
                    ),
                  ),
                  isThreeLine: true,
                  trailing: PopupMenuButton<String>(
                    onSelected: (value) {
                      if (value == 'edit') {
                        _openStaffDialog(
                          staff: staff,
                        );
                      } else if (value == 'delete') {
                        _deleteStaff(
                          staff,
                        );
                      } else if (value == 'activate' ||
                          value == 'deactivate') {
                        _performAction(
                          staff,
                          value,
                        );
                      }
                    },
                    itemBuilder: (context) {
                      return [
                        const PopupMenuItem<String>(
                          value: 'edit',
                          child: Text(
                            'Edit',
                          ),
                        ),
                        PopupMenuItem<String>(
                          value: isActive
                              ? 'deactivate'
                              : 'activate',
                          child: Text(
                            isActive
                                ? 'Deactivate'
                                : 'Activate',
                          ),
                        ),
                        const PopupMenuDivider(),
                        const PopupMenuItem<String>(
                          value: 'delete',
                          child: Text(
                            'Delete',
                          ),
                        ),
                      ];
                    },
                  ),
                ),
              );
            },
          ),
      ],
    );
  }
}