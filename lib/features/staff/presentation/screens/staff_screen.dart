import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/network/supabase_client.dart';
import '../../../../core/widgets/main_wrapper.dart';

/// ===============================================================
/// STAFF MODEL
/// ===============================================================

class StaffData {
  final List<Map<String, dynamic>> staff;

  const StaffData({
    required this.staff,
  });
}

/// ===============================================================
/// STAFF PROVIDER
/// ===============================================================

final staffProvider = FutureProvider.autoDispose<StaffData>((ref) async {
  final client = SupabaseConfig.client;

  final schoolId = await ref.watch(schoolIdProvider.future);

  if (schoolId == null) {
    throw Exception('Your account is not linked to a school.');
  }

  final response = await client
      .from('profiles')
      .select(
    'id, full_name, email, phone, role, staff_role, '
        'school_id, is_active, cnic, avatar_url, gender, created_at',
  )
      .eq('school_id', schoolId)
      .eq('role', 'staff')
      .order('created_at', ascending: false);

  return StaffData(
    staff: List<Map<String, dynamic>>.from(response),
  );
});

/// ===============================================================
/// SEARCH PROVIDER
/// ===============================================================

final staffSearchProvider =
StateProvider.autoDispose<String>((ref) => '');

/// ===============================================================
/// STAFF ROLES
/// ===============================================================

const List<String> staffRoles = [
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

/// ===============================================================
/// STAFF SCREEN
/// ===============================================================

class StaffScreen extends ConsumerWidget {
  const StaffScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final staffAsync = ref.watch(staffProvider);

    return MainWrapper(
      child: staffAsync.when(
        loading: () => const Center(
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
        error: (error, stack) => _StaffErrorView(
          message: error.toString().replaceFirst('Exception: ', ''),
          onRetry: () => ref.invalidate(staffProvider),
        ),
        data: (data) => _StaffContent(data: data),
      ),
    );
  }
}

/// ===============================================================
/// STAFF CONTENT
/// ===============================================================

class _StaffContent extends ConsumerWidget {
  final StaffData data;

  const _StaffContent({
    required this.data,
  });

  List<String> _parseRoles(dynamic value) {
    if (value == null) return [];

    if (value is List) {
      return value
          .map((e) => e.toString().trim())
          .where((e) => e.isNotEmpty)
          .toList();
    }

    final text = value.toString().trim();

    if (text.isEmpty) return [];

    if (text.startsWith('[') && text.endsWith(']')) {
      try {
        final decoded = jsonDecode(text);

        if (decoded is List) {
          return decoded
              .map((e) => e.toString().trim())
              .where((e) => e.isNotEmpty)
              .toList();
        }
      } catch (_) {}
    }

    return text
        .split(',')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();
  }

  String _rolesToJson(List<String> roles) {
    return jsonEncode(roles);
  }

  String _generateTemporaryPassword() {
    final now = DateTime.now();

    final month = now.month.toString().padLeft(2, '0');
    final day = now.day.toString().padLeft(2, '0');

    return 'Hadi@${now.year}$month$day';
  }

  Future<int?> _getSchoolId() async {
    try {
      final result = await SupabaseConfig.client.rpc(
        'get_my_school_id',
      );

      if (result is int) return result;
      if (result is num) return result.toInt();

      return int.tryParse(result?.toString() ?? '');
    } catch (e) {
      debugPrint('get_my_school_id error: $e');
      return null;
    }
  }

  /// =============================================================
  /// ADD / EDIT DIALOG
  /// =============================================================

  Future<void> _openStaffDialog(
      BuildContext context,
      WidgetRef ref, {
        Map<String, dynamic>? staff,
      }) async {
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

    final passwordController = TextEditingController(
      text: _generateTemporaryPassword(),
    );

    String gender = staff?['gender']?.toString() ?? 'male';

    if (!['male', 'female', 'other'].contains(gender)) {
      gender = 'male';
    }

    bool isActive = staff?['is_active'] != false;

    final isEditing = staff != null;

    List<String> selectedRoles = _parseRoles(
      staff?['staff_role'],
    )
        .where(staffRoles.contains)
        .toSet()
        .toList();

    bool saving = false;

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text(
                isEditing ? 'Edit Staff' : 'Add Staff',
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                ),
              ),
              content: SizedBox(
                width: 560,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _field(
                        controller: nameController,
                        label: 'Full Name',
                        icon: Icons.person_outline_rounded,
                        textCapitalization: TextCapitalization.words,
                      ),
                      const SizedBox(height: 14),

                      _field(
                        controller: emailController,
                        label: 'Email',
                        icon: Icons.email_outlined,
                        keyboardType: TextInputType.emailAddress,
                      ),
                      const SizedBox(height: 14),

                      _field(
                        controller: phoneController,
                        label: 'Phone',
                        icon: Icons.phone_outlined,
                        keyboardType: TextInputType.phone,
                      ),

                      if (!isEditing) ...[
                        const SizedBox(height: 14),
                        _field(
                          controller: passwordController,
                          label: 'Temporary Password',
                          icon: Icons.lock_outline_rounded,
                          obscureText: true,
                          helperText:
                          'Staff will use this password to login.',
                        ),
                      ],

                      const SizedBox(height: 20),

                      const Text(
                        'Staff Roles',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                        ),
                      ),

                      const SizedBox(height: 5),

                      const Text(
                        'Select all responsibilities this person handles.',
                        style: TextStyle(
                          fontSize: 11,
                          color: AppColors.textSecondary,
                        ),
                      ),

                      const SizedBox(height: 12),

                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          border: Border.all(
                            color: Colors.grey.withOpacity(.25),
                          ),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: staffRoles.map((role) {
                            final selected =
                            selectedRoles.contains(role);

                            return FilterChip(
                              selected: selected,
                              label: Text(role),
                              avatar: Icon(
                                selected
                                    ? Icons.check_rounded
                                    : Icons.work_outline_rounded,
                                size: 17,
                              ),
                              onSelected: saving
                                  ? null
                                  : (value) {
                                setDialogState(() {
                                  if (value) {
                                    if (!selectedRoles.contains(role)) {
                                      selectedRoles.add(role);
                                    }
                                  } else {
                                    selectedRoles.remove(role);
                                  }
                                });
                              },
                            );
                          }).toList(),
                        ),
                      ),

                      if (selectedRoles.isNotEmpty) ...[
                        const SizedBox(height: 10),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withOpacity(.06),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Wrap(
                            spacing: 6,
                            runSpacing: 6,
                            children: selectedRoles.map((role) {
                              return Chip(
                                label: Text(
                                  role,
                                  style: const TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                deleteIcon: const Icon(
                                  Icons.close_rounded,
                                  size: 15,
                                ),
                                onDeleted: saving
                                    ? null
                                    : () {
                                  setDialogState(() {
                                    selectedRoles.remove(role);
                                  });
                                },
                              );
                            }).toList(),
                          ),
                        ),
                      ],

                      const SizedBox(height: 14),

                      _field(
                        controller: cnicController,
                        label: 'CNIC',
                        icon: Icons.badge_outlined,
                        keyboardType: TextInputType.number,
                      ),

                      const SizedBox(height: 14),

                      DropdownButtonFormField<String>(
                        value: gender,
                        decoration: const InputDecoration(
                          labelText: 'Gender',
                          prefixIcon:
                          Icon(Icons.person_search_outlined),
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
                          if (value == null) return;

                          setDialogState(() {
                            gender = value;
                          });
                        },
                      ),

                      const SizedBox(height: 10),

                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text(
                          'Active Staff',
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        subtitle: const Text(
                          'Allow this staff member to remain active.',
                        ),
                        value: isActive,
                        onChanged: saving
                            ? null
                            : (value) {
                          setDialogState(() {
                            isActive = value;
                          });
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
                      : () => Navigator.pop(dialogContext),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: saving
                      ? null
                      : () async {
                    final name =
                    nameController.text.trim();
                    final email =
                    emailController.text.trim();
                    final password =
                    passwordController.text.trim();

                    if (name.isEmpty) {
                      _showError(
                        context,
                        'Full name is required.',
                      );
                      return;
                    }

                    if (!isEditing && email.isEmpty) {
                      _showError(
                        context,
                        'Email is required.',
                      );
                      return;
                    }

                    if (!isEditing &&
                        !email.contains('@')) {
                      _showError(
                        context,
                        'Please enter a valid email.',
                      );
                      return;
                    }

                    if (!isEditing &&
                        password.length < 6) {
                      _showError(
                        context,
                        'Password must be at least 6 characters.',
                      );
                      return;
                    }

                    if (selectedRoles.isEmpty) {
                      _showError(
                        context,
                        'Please select at least one staff role.',
                      );
                      return;
                    }

                    setDialogState(() {
                      saving = true;
                    });

                    try {
                      await _saveStaff(
                        staff: staff,
                        fullName: name,
                        email: email,
                        phone:
                        phoneController.text.trim(),
                        cnic:
                        cnicController.text.trim(),
                        selectedRoles: selectedRoles,
                        gender: gender,
                        isActive: isActive,
                        password: password,
                      );

                      ref.invalidate(staffProvider);

                      if (!context.mounted) return;

                      Navigator.pop(dialogContext);

                      _showSuccess(
                        context,
                        isEditing
                            ? 'Staff updated successfully.'
                            : 'Staff added successfully.',
                      );
                    } catch (e) {
                      setDialogState(() {
                        saving = false;
                      });

                      if (!context.mounted) return;

                      _showError(
                        context,
                        e.toString().replaceFirst(
                          'Exception: ',
                          '',
                        ),
                      );
                    }
                  },
                  child: saving
                      ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                      : Text(
                    isEditing ? 'Update' : 'Add Staff',
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
    passwordController.dispose();
  }

  /// =============================================================
  /// INPUT FIELD
  /// =============================================================

  Widget _field({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType? keyboardType,
    bool obscureText = false,
    String? helperText,
    TextCapitalization textCapitalization =
        TextCapitalization.none,
  }) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      obscureText: obscureText,
      textCapitalization: textCapitalization,
      decoration: InputDecoration(
        labelText: label,
        helperText: helperText,
        prefixIcon: Icon(icon),
      ),
    );
  }

  /// =============================================================
  /// SAVE STAFF
  /// =============================================================

  Future<void> _saveStaff({
    Map<String, dynamic>? staff,
    required String fullName,
    required String email,
    required String phone,
    required String cnic,
    required List<String> selectedRoles,
    required String gender,
    required bool isActive,
    required String password,
  }) async {
    final client = SupabaseConfig.client;

    final schoolId = await _getSchoolId();

    if (schoolId == null) {
      throw Exception(
        'Your account is not linked to a school.',
      );
    }

    /// UPDATE
    if (staff != null) {
      final staffId = staff['id']?.toString();

      if (staffId == null || staffId.isEmpty) {
        throw Exception('Staff ID is missing.');
      }

      await client
          .from('profiles')
          .update({
        'full_name': fullName,
        'email': email.isEmpty ? null : email,
        'phone': phone.isEmpty ? null : phone,
        'cnic': cnic.isEmpty ? null : cnic,
        'gender': gender,
        'staff_role': _rolesToJson(selectedRoles),
        'is_active': isActive,
        'role': 'staff',
      })
          .eq('id', staffId)
          .eq('school_id', schoolId);

      return;
    }

    /// CREATE
    final response = await client.functions.invoke(
      'create-staff',
      body: {
        'full_name': fullName,
        'email': email,
        'phone': phone,
        'cnic': cnic,
        'gender': gender,
        'staff_roles': selectedRoles,
        'is_active': isActive,
        'password': password,
      },
    );

    final responseData = response.data;

    if (responseData is Map) {
      if (responseData['success'] == true) {
        return;
      }

      throw Exception(
        responseData['error']?.toString() ??
            'Unable to create staff account.',
      );
    }

    throw Exception(
      'Invalid response from create-staff service.',
    );
  }

  /// =============================================================
  /// DELETE STAFF
  /// =============================================================

  Future<void> _deleteStaff(
      BuildContext context,
      WidgetRef ref,
      Map<String, dynamic> staff,
      ) async {
    final name =
    staff['full_name']?.toString().trim().isNotEmpty == true
        ? staff['full_name'].toString()
        : 'this staff member';

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text(
            'Delete Staff?',
            style: TextStyle(
              fontWeight: FontWeight.w800,
            ),
          ),
          content: Text(
            'Are you sure you want to remove "$name"?',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext, false);
              },
              child: const Text('Cancel'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.error,
              ),
              onPressed: () {
                Navigator.pop(dialogContext, true);
              },
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );

    if (confirmed != true) return;

    if (!context.mounted) return;

    final loadingDialog = showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) {
        return const AlertDialog(
          content: Row(
            children: [
              SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                ),
              ),
              SizedBox(width: 16),
              Expanded(
                child: Text(
                  'Deleting staff...',
                ),
              ),
            ],
          ),
        );
      },
    );

    try {
      final client = SupabaseConfig.client;

      final schoolId = await _getSchoolId();

      if (schoolId == null) {
        throw Exception(
          'Your account is not linked to a school.',
        );
      }

      final staffId = staff['id']?.toString();

      if (staffId == null || staffId.isEmpty) {
        throw Exception('Staff ID is missing.');
      }

      await client
          .from('profiles')
          .delete()
          .eq('id', staffId)
          .eq('school_id', schoolId);

      ref.invalidate(staffProvider);

      if (context.mounted) {
        Navigator.of(context, rootNavigator: true).pop();

        _showSuccess(
          context,
          'Staff profile deleted successfully.',
        );
      }
    } on PostgrestException catch (e) {
      if (context.mounted) {
        Navigator.of(context, rootNavigator: true).pop();

        _showError(
          context,
          e.message,
        );
      }
    } catch (e) {
      if (context.mounted) {
        Navigator.of(context, rootNavigator: true).pop();

        _showError(
          context,
          e.toString().replaceFirst(
            'Exception: ',
            '',
          ),
        );
      }
    }
  }

  /// =============================================================
  /// FILTER
  /// =============================================================

  List<Map<String, dynamic>> _filteredStaff(
      String search,
      ) {
    final query = search.trim().toLowerCase();

    if (query.isEmpty) {
      return data.staff;
    }

    return data.staff.where((person) {
      final name =
          person['full_name']?.toString().toLowerCase() ?? '';

      final email =
          person['email']?.toString().toLowerCase() ?? '';

      final phone =
          person['phone']?.toString().toLowerCase() ?? '';

      final roles = _parseRoles(person['staff_role'])
          .join(' ')
          .toLowerCase();

      return name.contains(query) ||
          email.contains(query) ||
          phone.contains(query) ||
          roles.contains(query);
    }).toList();
  }

  /// =============================================================
  /// BUILD
  /// =============================================================

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final search = ref.watch(staffSearchProvider);
    final filtered = _filteredStaff(search);

    final activeCount = data.staff.where(
          (staff) => staff['is_active'] != false,
    ).length;

    final inactiveCount =
        data.staff.length - activeCount;

    return LayoutBuilder(
      builder: (context, constraints) {
        final isDesktop = constraints.maxWidth >= 1100;
        final isTablet = constraints.maxWidth >= 700 &&
            constraints.maxWidth < 1100;

        return Scaffold(
          backgroundColor: AppColors.background,
          body: RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(staffProvider);
              await ref.read(staffProvider.future);
            },
            child: CustomScrollView(
              physics:
              const AlwaysScrollableScrollPhysics(),
              slivers: [
                SliverToBoxAdapter(
                  child: Center(
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        maxWidth:
                        isDesktop ? 1350 : double.infinity,
                      ),
                      child: Padding(
                        padding: EdgeInsets.fromLTRB(
                          isDesktop
                              ? 32
                              : isTablet
                              ? 24
                              : 16,
                          isDesktop ? 30 : 22,
                          isDesktop
                              ? 32
                              : isTablet
                              ? 24
                              : 16,
                          10,
                        ),
                        child: _buildHeader(
                          context,
                          ref,
                          isDesktop,
                        ),
                      ),
                    ),
                  ),
                ),

                SliverToBoxAdapter(
                  child: Center(
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        maxWidth:
                        isDesktop ? 1350 : double.infinity,
                      ),
                      child: Padding(
                        padding: EdgeInsets.symmetric(
                          horizontal:
                          isDesktop
                              ? 32
                              : isTablet
                              ? 24
                              : 16,
                        ),
                        child: _buildMetrics(
                          activeCount,
                          inactiveCount,
                        ),
                      ),
                    ),
                  ),
                ),

                SliverToBoxAdapter(
                  child: Center(
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        maxWidth:
                        isDesktop ? 1350 : double.infinity,
                      ),
                      child: Padding(
                        padding: EdgeInsets.fromLTRB(
                          isDesktop
                              ? 32
                              : isTablet
                              ? 24
                              : 16,
                          22,
                          isDesktop
                              ? 32
                              : isTablet
                              ? 24
                              : 16,
                          8,
                        ),
                        child: _buildSearch(
                          ref,
                          search,
                        ),
                      ),
                    ),
                  ),
                ),

                if (filtered.isEmpty)
                  SliverFillRemaining(
                    hasScrollBody: false,
                    child: _buildEmptyState(
                      context,
                      ref,
                      search,
                    ),
                  )
                else
                  SliverToBoxAdapter(
                    child: Center(
                      child: ConstrainedBox(
                        constraints: BoxConstraints(
                          maxWidth:
                          isDesktop ? 1350 : double.infinity,
                        ),
                        child: Padding(
                          padding: EdgeInsets.fromLTRB(
                            isDesktop
                                ? 32
                                : isTablet
                                ? 24
                                : 16,
                            12,
                            isDesktop
                                ? 32
                                : isTablet
                                ? 24
                                : 16,
                            40,
                          ),
                          child: isDesktop
                              ? _buildDesktopStaffList(
                            context,
                            ref,
                            filtered,
                          )
                              : _buildMobileStaffList(
                            context,
                            ref,
                            filtered,
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          floatingActionButton:
          FloatingActionButton.extended(
            onPressed: () {
              _openStaffDialog(context, ref);
            },
            icon: const Icon(
              Icons.person_add_rounded,
            ),
            label: const Text(
              'Add Staff',
            ),
          ),
        );
      },
    );
  }

  /// =============================================================
  /// HEADER
  /// =============================================================

  Widget _buildHeader(
      BuildContext context,
      WidgetRef ref,
      bool desktop,
      ) {
    return Container(
      padding: EdgeInsets.all(
        desktop ? 26 : 20,
      ),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.primary,
            AppColors.primary.withOpacity(.82),
          ],
        ),
        borderRadius: BorderRadius.circular(
          desktop ? 22 : 18,
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withOpacity(.16),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: desktop ? 58 : 50,
            height: desktop ? 58 : 50,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(.16),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(
              Icons.groups_rounded,
              color: Colors.white,
              size: 28,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment:
              CrossAxisAlignment.start,
              children: [
                Text(
                  'School Staff',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: desktop ? 26 : 22,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  'Manage staff members and their responsibilities.',
                  style: TextStyle(
                    color: Colors.white.withOpacity(.82),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Refresh',
            onPressed: () {
              ref.invalidate(staffProvider);
            },
            style: IconButton.styleFrom(
              backgroundColor:
              Colors.white.withOpacity(.12),
              foregroundColor: Colors.white,
            ),
            icon: const Icon(
              Icons.refresh_rounded,
            ),
          ),
        ],
      ),
    );
  }

  /// =============================================================
  /// METRICS
  /// =============================================================

  Widget _buildMetrics(
      int active,
      int inactive,
      ) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final cards = [
          _metricCard(
            'Total',
            data.staff.length.toString(),
            'All staff',
            Icons.groups_rounded,
            AppColors.primary,
          ),
          _metricCard(
            'Active',
            active.toString(),
            'Currently active',
            Icons.check_circle_outline_rounded,
            AppColors.success,
          ),
          _metricCard(
            'Inactive',
            inactive.toString(),
            'Not active',
            Icons.pause_circle_outline_rounded,
            AppColors.error,
          ),
          _metricCard(
            'Roles',
            staffRoles.length.toString(),
            'Available roles',
            Icons.work_outline_rounded,
            const Color(0xFF2563EB),
          ),
        ];

        if (constraints.maxWidth >= 900) {
          return Row(
            children: [
              for (int i = 0; i < cards.length; i++) ...[
                Expanded(child: cards[i]),
                if (i != cards.length - 1)
                  const SizedBox(width: 14),
              ],
            ],
          );
        }

        return Wrap(
          spacing: 12,
          runSpacing: 12,
          children: cards.map((card) {
            return SizedBox(
              width:
              (constraints.maxWidth - 12) / 2,
              child: card,
            );
          }).toList(),
        );
      },
    );
  }

  /// =============================================================
  /// METRIC CARD
  /// =============================================================

  Widget _metricCard(
      String title,
      String value,
      String subtitle,
      IconData icon,
      Color color,
      ) {
    return Card(
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Row(
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: color.withOpacity(.10),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(
                icon,
                color: color,
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
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Text(
                    value,
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontSize: 10,
                      color:
                      AppColors.textSecondary,
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

  /// =============================================================
  /// SEARCH
  /// =============================================================

  Widget _buildSearch(
      WidgetRef ref,
      String search,
      ) {
    return TextField(
      onChanged: (value) {
        ref.read(
          staffSearchProvider.notifier,
        ).state = value;
      },
      decoration: InputDecoration(
        hintText:
        'Search staff by name, email or role...',
        prefixIcon: const Icon(
          Icons.search_rounded,
        ),
        suffixIcon: search.isNotEmpty
            ? IconButton(
          onPressed: () {
            ref.read(
              staffSearchProvider.notifier,
            ).state = '';
          },
          icon: const Icon(
            Icons.clear_rounded,
          ),
        )
            : null,
      ),
    );
  }

  /// =============================================================
  /// MOBILE STAFF LIST
  /// =============================================================

  Widget _buildMobileStaffList(
      BuildContext context,
      WidgetRef ref,
      List<Map<String, dynamic>> staff,
      ) {
    return Column(
      children: staff.map((person) {
        return _buildStaffCard(
          context,
          ref,
          person,
        );
      }).toList(),
    );
  }

  /// =============================================================
  /// DESKTOP STAFF LIST
  /// =============================================================

  Widget _buildDesktopStaffList(
      BuildContext context,
      WidgetRef ref,
      List<Map<String, dynamic>> staff,
      ) {
    return Card(
      elevation: 0,
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: 20,
              vertical: 16,
            ),
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(.05),
              border: Border(
                bottom: BorderSide(
                  color: Colors.grey.withOpacity(.18),
                ),
              ),
            ),
            child: const Row(
              children: [
                SizedBox(
                  width: 360,
                  child: Text(
                    'STAFF',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                Expanded(
                  child: Text(
                    'RESPONSIBILITIES',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                SizedBox(
                  width: 150,
                  child: Text(
                    'CONTACT',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                SizedBox(
                  width: 100,
                  child: Text(
                    'STATUS',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                SizedBox(width: 48),
              ],
            ),
          ),
          ...staff.map(
                (person) => _buildDesktopStaffRow(
              context,
              ref,
              person,
            ),
          ),
        ],
      ),
    );
  }

  /// =============================================================
  /// DESKTOP ROW
  /// =============================================================

  Widget _buildDesktopStaffRow(
      BuildContext context,
      WidgetRef ref,
      Map<String, dynamic> person,
      ) {
    final name =
        person['full_name']?.toString().trim() ?? '';

    final displayName =
    name.isEmpty ? 'Unnamed Staff' : name;

    final email =
        person['email']?.toString() ?? '';

    final phone =
        person['phone']?.toString() ?? '';

    final roles = _parseRoles(
      person['staff_role'],
    );

    final isActive =
        person['is_active'] != false;

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 20,
        vertical: 15,
      ),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: Colors.grey.withOpacity(.12),
          ),
        ),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 360,
            child: Row(
              children: [
                _buildAvatar(
                  displayName,
                  person['avatar_url']?.toString(),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment:
                    CrossAxisAlignment.start,
                    children: [
                      Text(
                        displayName,
                        maxLines: 1,
                        overflow:
                        TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      if (email.isNotEmpty)
                        Text(
                          email,
                          maxLines: 1,
                          overflow:
                          TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 11,
                            color:
                            AppColors.textSecondary,
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: roles.isEmpty
                ? const Text(
              'No role',
              style: TextStyle(
                fontSize: 11,
                color:
                AppColors.textSecondary,
              ),
            )
                : Wrap(
              spacing: 5,
              runSpacing: 5,
              children: roles.map(
                    (role) {
                  return _roleBadge(role);
                },
              ).toList(),
            ),
          ),
          SizedBox(
            width: 150,
            child: Text(
              phone.isEmpty ? '—' : phone,
              style: const TextStyle(
                fontSize: 11,
                color:
                AppColors.textSecondary,
              ),
            ),
          ),
          SizedBox(
            width: 100,
            child: _statusBadge(isActive),
          ),
          SizedBox(
            width: 48,
            child: PopupMenuButton<String>(
              onSelected: (value) {
                if (value == 'edit') {
                  _openStaffDialog(
                    context,
                    ref,
                    staff: person,
                  );
                }

                if (value == 'delete') {
                  _deleteStaff(
                    context,
                    ref,
                    person,
                  );
                }
              },
              itemBuilder: (context) =>
              const [
                PopupMenuItem(
                  value: 'edit',
                  child: Row(
                    children: [
                      Icon(
                        Icons.edit_outlined,
                      ),
                      SizedBox(width: 10),
                      Text('Edit'),
                    ],
                  ),
                ),
                PopupMenuItem(
                  value: 'delete',
                  child: Row(
                    children: [
                      Icon(
                        Icons.delete_outline,
                      ),
                      SizedBox(width: 10),
                      Text('Delete'),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// =============================================================
  /// STAFF CARD
  /// =============================================================

  Widget _buildStaffCard(
      BuildContext context,
      WidgetRef ref,
      Map<String, dynamic> person,
      ) {
    final name =
        person['full_name']?.toString().trim() ?? '';

    final displayName =
    name.isEmpty ? 'Unnamed Staff' : name;

    final email =
        person['email']?.toString() ?? '';

    final phone =
        person['phone']?.toString() ?? '';

    final roles = _parseRoles(
      person['staff_role'],
    );

    final isActive =
        person['is_active'] != false;

    return Card(
      margin: const EdgeInsets.only(
        bottom: 12,
      ),
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(15),
        child: Row(
          crossAxisAlignment:
          CrossAxisAlignment.start,
          children: [
            _buildAvatar(
              displayName,
              person['avatar_url']?.toString(),
            ),
            const SizedBox(width: 13),
            Expanded(
              child: Column(
                crossAxisAlignment:
                CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          displayName,
                          maxLines: 1,
                          overflow:
                          TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      _statusBadge(isActive),
                    ],
                  ),

                  if (roles.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 5,
                      runSpacing: 5,
                      children: roles.map(
                            (role) {
                          return _roleBadge(role);
                        },
                      ).toList(),
                    ),
                  ],

                  if (email.isNotEmpty)
                    Padding(
                      padding:
                      const EdgeInsets.only(
                        top: 8,
                      ),
                      child: Text(
                        email,
                        maxLines: 1,
                        overflow:
                        TextOverflow.ellipsis,
                        style: const TextStyle(
                          color:
                          AppColors.textSecondary,
                          fontSize: 11,
                        ),
                      ),
                    ),

                  if (phone.isNotEmpty)
                    Padding(
                      padding:
                      const EdgeInsets.only(
                        top: 3,
                      ),
                      child: Text(
                        phone,
                        style: const TextStyle(
                          color:
                          AppColors.textSecondary,
                          fontSize: 11,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            PopupMenuButton<String>(
              padding: EdgeInsets.zero,
              onSelected: (value) {
                if (value == 'edit') {
                  _openStaffDialog(
                    context,
                    ref,
                    staff: person,
                  );
                }

                if (value == 'delete') {
                  _deleteStaff(
                    context,
                    ref,
                    person,
                  );
                }
              },
              itemBuilder: (context) =>
              const [
                PopupMenuItem(
                  value: 'edit',
                  child: Row(
                    children: [
                      Icon(
                        Icons.edit_outlined,
                      ),
                      SizedBox(width: 10),
                      Text('Edit'),
                    ],
                  ),
                ),
                PopupMenuItem(
                  value: 'delete',
                  child: Row(
                    children: [
                      Icon(
                        Icons.delete_outline,
                      ),
                      SizedBox(width: 10),
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

  /// =============================================================
  /// ROLE BADGE
  /// =============================================================

  Widget _roleBadge(String role) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 8,
        vertical: 5,
      ),
      decoration: BoxDecoration(
        color: AppColors.primary.withOpacity(.08),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        role,
        style: const TextStyle(
          color: AppColors.primary,
          fontSize: 9,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }

  /// =============================================================
  /// STATUS BADGE
  /// =============================================================

  Widget _statusBadge(bool active) {
    final color =
    active ? AppColors.success : AppColors.error;

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 8,
        vertical: 5,
      ),
      decoration: BoxDecoration(
        color: color.withOpacity(.10),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        active ? 'ACTIVE' : 'INACTIVE',
        textAlign: TextAlign.center,
        style: TextStyle(
          color: color,
          fontSize: 9,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }

  /// =============================================================
  /// AVATAR
  /// =============================================================

  Widget _buildAvatar(
      String name,
      String? avatarUrl,
      ) {
    if (avatarUrl != null &&
        avatarUrl.trim().isNotEmpty) {
      return CircleAvatar(
        radius: 25,
        backgroundImage: NetworkImage(
          avatarUrl,
        ),
      );
    }

    final letter = name.isNotEmpty
        ? name[0].toUpperCase()
        : 'S';

    return CircleAvatar(
      radius: 25,
      backgroundColor:
      AppColors.primary.withOpacity(.10),
      child: Text(
        letter,
        style: const TextStyle(
          color: AppColors.primary,
          fontWeight: FontWeight.w900,
          fontSize: 18,
        ),
      ),
    );
  }

  /// =============================================================
  /// EMPTY
  /// =============================================================

  Widget _buildEmptyState(
      BuildContext context,
      WidgetRef ref,
      String search,
      ) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(30),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color:
                AppColors.primary.withOpacity(.08),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.groups_outlined,
                size: 38,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(height: 18),
            Text(
              search.isEmpty
                  ? 'No staff found'
                  : 'No matching staff',
              style: const TextStyle(
                fontSize: 19,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 7),
            Text(
              search.isEmpty
                  ? 'Add your first staff member.'
                  : 'Try another search term.',
              textAlign: TextAlign.center,
              style: const TextStyle(
                color:
                AppColors.textSecondary,
                fontSize: 12,
              ),
            ),
            if (search.isEmpty) ...[
              const SizedBox(height: 18),
              FilledButton.icon(
                onPressed: () {
                  _openStaffDialog(
                    context,
                    ref,
                  );
                },
                icon: const Icon(
                  Icons.person_add_rounded,
                ),
                label: const Text(
                  'Add Staff',
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// ===============================================================
/// ERROR VIEW
/// ===============================================================

class _StaffErrorView extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _StaffErrorView({
    required this.message,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.cloud_off_rounded,
              size: 48,
              color: AppColors.error,
            ),
            const SizedBox(height: 12),
            const Text(
              'Unable to load staff',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 11,
                color:
                AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: onRetry,
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}

/// ===============================================================
/// SUCCESS MESSAGE
/// ===============================================================

void _showSuccess(
    BuildContext context,
    String message,
    ) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppColors.success,
      ),
    );
}

/// ===============================================================
/// ERROR MESSAGE
/// ===============================================================

void _showError(
    BuildContext context,
    String message,
    ) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppColors.error,
      ),
    );
}