import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/network/supabase_client.dart';
import '../../../../core/widgets/main_wrapper.dart';

// ============================================================
// MODEL
// ============================================================

class SchoolSettings {
  final int id;
  final int schoolId;
  final bool notificationsEnabled;
  final bool darkMode;
  final bool autoBackup;

  const SchoolSettings({
    required this.id,
    required this.schoolId,
    required this.notificationsEnabled,
    required this.darkMode,
    required this.autoBackup,
  });

  factory SchoolSettings.fromMap(
      Map<String, dynamic> map,
      ) {
    return SchoolSettings(
      id: (map['id'] as num?)?.toInt() ?? 0,
      schoolId: (map['school_id'] as num?)?.toInt() ?? 0,
      notificationsEnabled:
      map['notifications_enabled'] == true,
      darkMode: map['dark_mode'] == true,
      autoBackup: map['auto_backup'] == true,
    );
  }
}

// ============================================================
// REPOSITORY
// ============================================================

class SettingsRepository {
  final SupabaseClient client;

  SettingsRepository(this.client);

  // ----------------------------------------------------------
  // SCHOOL ID
  // ----------------------------------------------------------

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
  // GET SETTINGS
  // ----------------------------------------------------------

  Future<SchoolSettings> getSettings() async {
    final schoolId = await getSchoolId();

    final row = await client
        .from('school_settings')
        .select(
      'id, school_id, notifications_enabled, dark_mode, auto_backup',
    )
        .eq('school_id', schoolId)
        .maybeSingle()
        .timeout(
      const Duration(seconds: 10),
    );

    if (row != null) {
      return SchoolSettings.fromMap(
        Map<String, dynamic>.from(row),
      );
    }

    final created = await client
        .from('school_settings')
        .insert({
      'school_id': schoolId,
      'notifications_enabled': true,
      'dark_mode': false,
      'auto_backup': true,
    })
        .select(
      'id, school_id, notifications_enabled, dark_mode, auto_backup',
    )
        .single()
        .timeout(
      const Duration(seconds: 10),
    );

    return SchoolSettings.fromMap(
      Map<String, dynamic>.from(created),
    );
  }

  // ----------------------------------------------------------
  // UPDATE SETTINGS
  // ----------------------------------------------------------

  Future<void> updateSettings({
    bool? notificationsEnabled,
    bool? darkMode,
    bool? autoBackup,
  }) async {
    final schoolId = await getSchoolId();

    final data = <String, dynamic>{};

    if (notificationsEnabled != null) {
      data['notifications_enabled'] =
          notificationsEnabled;
    }

    if (darkMode != null) {
      data['dark_mode'] = darkMode;
    }

    if (autoBackup != null) {
      data['auto_backup'] = autoBackup;
    }

    if (data.isEmpty) {
      return;
    }

    await client
        .from('school_settings')
        .update(data)
        .eq('school_id', schoolId)
        .timeout(
      const Duration(seconds: 10),
    );
  }

  // ----------------------------------------------------------
  // REALTIME
  // ----------------------------------------------------------

  Stream<SchoolSettings> watchSettings() async* {
    final schoolId = await getSchoolId();

    // Initial settings
    yield await getSettings();

    final controller =
    StreamController<SchoolSettings>();

    final channel = client.channel(
      'school-settings-realtime-$schoolId',
    );

    channel.onPostgresChanges(
      event: PostgresChangeEvent.all,
      schema: 'public',
      table: 'school_settings',
      filter: PostgresChangeFilter(
        type: PostgresChangeFilterType.eq,
        column: 'school_id',
        value: schoolId,
      ),
      callback: (payload) {
        final record = payload.newRecord;

        if (record.isEmpty) {
          return;
        }

        try {
          final settings =
          SchoolSettings.fromMap(
            Map<String, dynamic>.from(record),
          );

          if (!controller.isClosed) {
            controller.add(settings);
          }
        } catch (_) {}
      },
    );

    channel.subscribe();

    try {
      await for (final settings
      in controller.stream) {
        yield settings;
      }
    } finally {
      if (!controller.isClosed) {
        await controller.close();
      }

      await client.removeChannel(channel);
    }
  }

  // ----------------------------------------------------------
  // SCHOOL
  // ----------------------------------------------------------

  Future<Map<String, dynamic>> getSchool() async {
    final schoolId = await getSchoolId();

    final data = await client
        .from('schools')
        .select(
      'id, school_name, logo_url',
    )
        .eq('id', schoolId)
        .maybeSingle()
        .timeout(
      const Duration(seconds: 10),
    );

    if (data == null) {
      return {};
    }

    return Map<String, dynamic>.from(data);
  }

  Future<void> updateSchool({
    required String schoolName,
  }) async {
    final schoolId = await getSchoolId();

    await client
        .from('schools')
        .update({
      'school_name': schoolName.trim(),
    })
        .eq('id', schoolId)
        .timeout(
      const Duration(seconds: 10),
    );
  }

  // ----------------------------------------------------------
  // USERS
  // ----------------------------------------------------------

  Future<List<Map<String, dynamic>>> getUsers() async {
    final schoolId = await getSchoolId();

    final data = await client
        .from('profiles')
        .select(
      'id,email,full_name,role,staff_role,is_active,phone',
    )
        .eq('school_id', schoolId)
        .order('full_name')
        .timeout(
      const Duration(seconds: 10),
    );

    return (data as List)
        .map(
          (item) => Map<String, dynamic>.from(
        item as Map,
      ),
    )
        .toList();
  }

  // ----------------------------------------------------------
  // PASSWORD
  // ----------------------------------------------------------

  Future<void> changePassword(
      String password,
      ) async {
    if (password.length < 6) {
      throw Exception(
        'Password must contain at least 6 characters.',
      );
    }

    await client.auth.updateUser(
      UserAttributes(
        password: password,
      ),
    );
  }
}

// ============================================================
// PROVIDERS
// ============================================================

final settingsRepositoryProvider =
Provider<SettingsRepository>((ref) {
  return SettingsRepository(
    SupabaseConfig.client,
  );
});

final schoolSettingsProvider =
StreamProvider<SchoolSettings>((ref) {
  final repository =
  ref.read(settingsRepositoryProvider);

  return repository.watchSettings();
});

final schoolProfileProvider =
FutureProvider<Map<String, dynamic>>((ref) {
  return ref
      .read(settingsRepositoryProvider)
      .getSchool();
});

final settingsUsersProvider =
FutureProvider<List<Map<String, dynamic>>>((ref) {
  return ref
      .read(settingsRepositoryProvider)
      .getUsers();
});

final languageProvider =
StateProvider<String>((ref) {
  return 'English';
});

final dateFormatProvider =
StateProvider<String>((ref) {
  return 'DD/MM/YYYY';
});

// ============================================================
// MAIN SCREEN
// ============================================================

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({
    super.key,
  });

  @override
  Widget build(
      BuildContext context,
      WidgetRef ref,
      ) {
    final settingsAsync =
    ref.watch(schoolSettingsProvider);

    return MainWrapper(
      child: settingsAsync.when(
        loading: () => const Center(
          child: CircularProgressIndicator(),
        ),
        error: (error, stack) {
          return _ErrorView(
            error: error.toString(),
            retry: () {
              ref.invalidate(
                schoolSettingsProvider,
              );
            },
          );
        },
        data: (settings) {
          return _SettingsHome(
            settings: settings,
          );
        },
      ),
    );
  }
}

// ============================================================
// SETTINGS HOME
// ============================================================

class _SettingsHome extends ConsumerWidget {
  final SchoolSettings settings;

  const _SettingsHome({
    required this.settings,
  });

  @override
  Widget build(
      BuildContext context,
      WidgetRef ref,
      ) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final mobile =
            constraints.maxWidth < 650;

        return ListView(
          padding: EdgeInsets.all(
            mobile ? 16 : 28,
          ),
          children: [
            const _Header(),

            const SizedBox(height: 28),

            _section('Application'),

            _Tile(
              icon:
              Icons.settings_applications_rounded,
              title: 'General Settings',
              subtitle:
              'Application preferences and defaults',
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) =>
                    const GeneralSettingsPage(),
                  ),
                );
              },
            ),

            _Tile(
              icon: Icons.translate_rounded,
              title: 'Language & Region',
              subtitle:
              'Language and date format',
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) =>
                    const LanguageSettingsPage(),
                  ),
                );
              },
            ),

            _Tile(
              icon:
              Icons.notifications_active_rounded,
              title: 'Notifications',
              subtitle:
              settings.notificationsEnabled
                  ? 'Notifications enabled'
                  : 'Notifications disabled',
              trailing: Switch.adaptive(
                value:
                settings.notificationsEnabled,
                onChanged: (value) async {
                  await _update(
                    context,
                    ref,
                    notificationsEnabled:
                    value,
                  );
                },
              ),
            ),

            const SizedBox(height: 24),

            _section('Institutional'),

            _Tile(
              icon:
              Icons.calendar_month_rounded,
              title: 'Academic Sessions',
              subtitle:
              'Academic year configuration',
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) =>
                    const AcademicSessionPage(),
                  ),
                );
              },
            ),

            _Tile(
              icon:
              Icons.account_balance_wallet_rounded,
              title: 'Fee Structures',
              subtitle:
              'Fee configuration and defaults',
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) =>
                    const FeeStructurePage(),
                  ),
                );
              },
            ),

            _Tile(
              icon: Icons.school_rounded,
              title: 'School Profile',
              subtitle:
              'School name and branding',
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) =>
                    const SchoolProfilePage(),
                  ),
                );
              },
            ),

            const SizedBox(height: 24),

            _section('System'),

            _Tile(
              icon: Icons.groups_rounded,
              title: 'Manage Users',
              subtitle:
              'Administrators, teachers and staff',
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) =>
                    const ManageUsersPage(),
                  ),
                );
              },
            ),

            _Tile(
              icon: Icons.security_rounded,
              title: 'Security & Privacy',
              subtitle:
              'Change account password',
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) =>
                    const SecurityPage(),
                  ),
                );
              },
            ),

            _Tile(
              icon: Icons.cloud_done_rounded,
              title: 'Cloud Storage',
              subtitle:
              settings.autoBackup
                  ? 'Automatic backup enabled'
                  : 'Automatic backup disabled',
              trailing: Switch.adaptive(
                value: settings.autoBackup,
                onChanged: (value) async {
                  await _update(
                    context,
                    ref,
                    autoBackup: value,
                  );
                },
              ),
            ),

            const SizedBox(height: 24),

            _section('Appearance'),

            _Tile(
              icon: Icons.dark_mode_rounded,
              title: 'Dark Mode',
              subtitle:
              settings.darkMode
                  ? 'Dark mode enabled'
                  : 'Light mode enabled',
              trailing: Switch.adaptive(
                value: settings.darkMode,
                onChanged: (value) async {
                  await _update(
                    context,
                    ref,
                    darkMode: value,
                  );
                },
              ),
            ),

            const SizedBox(height: 28),

            Container(
              padding:
              const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.success
                    .withValues(alpha: .07),
                borderRadius:
                BorderRadius.circular(16),
                border: Border.all(
                  color: AppColors.success
                      .withValues(alpha: .12),
                ),
              ),
              child: const Row(
                children: [
                  Icon(
                    Icons.cloud_sync_rounded,
                    color:
                    AppColors.success,
                  ),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Settings are synchronized in realtime.',
                      style: TextStyle(
                        color:
                        AppColors.success,
                        fontWeight:
                        FontWeight.w800,
                        fontSize: 12,
                      ),
                    ),
                  ),
                  Icon(
                    Icons.circle,
                    color:
                    AppColors.success,
                    size: 9,
                  ),
                ],
              ),
            ),

            const SizedBox(height: 25),

            const Center(
              child: Text(
                'HADI SMS v1.0.0 Enterprise',
                style: TextStyle(
                  color:
                  AppColors.textMuted,
                  fontSize: 11,
                  fontWeight:
                  FontWeight.w700,
                ),
              ),
            ),

            const SizedBox(height: 25),
          ],
        );
      },
    );
  }

  Future<void> _update(
      BuildContext context,
      WidgetRef ref, {
        bool? notificationsEnabled,
        bool? darkMode,
        bool? autoBackup,
      }) async {
    try {
      await ref
          .read(
        settingsRepositoryProvider,
      )
          .updateSettings(
        notificationsEnabled:
        notificationsEnabled,
        darkMode: darkMode,
        autoBackup: autoBackup,
      );
    } catch (e) {
      if (!context.mounted) return;

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(
        SnackBar(
          content:
          Text('Update failed: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Widget _section(String title) {
    return Padding(
      padding:
      const EdgeInsets.only(
        left: 7,
        bottom: 10,
      ),
      child: Row(
        children: [
          Container(
            width: 4,
            height: 16,
            decoration:
            BoxDecoration(
              color:
              AppColors.primary,
              borderRadius:
              BorderRadius.circular(5),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            title.toUpperCase(),
            style:
            const TextStyle(
              color:
              AppColors.primary,
              fontWeight:
              FontWeight.w900,
              fontSize: 11,
              letterSpacing: 1.1,
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================
// HEADER
// ============================================================

class _Header extends StatelessWidget {
  const _Header();

  @override
  Widget build(
      BuildContext context,
      ) {
    return Container(
      padding:
      const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: AppColors.primary,
        borderRadius:
        BorderRadius.circular(22),
      ),
      child: const Row(
        children: [
          Icon(
            Icons.tune_rounded,
            color: Colors.white,
            size: 32,
          ),
          SizedBox(width: 15),
          Expanded(
            child: Column(
              crossAxisAlignment:
              CrossAxisAlignment.start,
              children: [
                Text(
                  'Settings',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 25,
                    fontWeight:
                    FontWeight.w900,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'Manage your HADI SMS system.',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 12,
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

// ============================================================
// TILE
// ============================================================

class _Tile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;
  final Widget? trailing;

  const _Tile({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.onTap,
    this.trailing,
  });

  @override
  Widget build(
      BuildContext context,
      ) {
    return Card(
      margin:
      const EdgeInsets.only(
        bottom: 10,
      ),
      elevation: 0,
      child: InkWell(
        onTap: onTap,
        borderRadius:
        BorderRadius.circular(15),
        child: Padding(
          padding:
          const EdgeInsets.all(14),
          child: Row(
            children: [
              Container(
                width: 45,
                height: 45,
                decoration:
                BoxDecoration(
                  color: AppColors.primary
                      .withValues(alpha: .08),
                  borderRadius:
                  BorderRadius.circular(13),
                ),
                child: Icon(
                  icon,
                  color:
                  AppColors.primary,
                ),
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment:
                  CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style:
                      const TextStyle(
                        fontWeight:
                        FontWeight.w800,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      maxLines: 2,
                      overflow:
                      TextOverflow.ellipsis,
                      style:
                      const TextStyle(
                        color:
                        AppColors
                            .textSecondary,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
              trailing ??
                  const Icon(
                    Icons.chevron_right_rounded,
                    color:
                    AppColors.border,
                  ),
            ],
          ),
        ),
      ),
    );
  }
}

// ============================================================
// GENERAL SETTINGS PAGE
// ============================================================

class GeneralSettingsPage
    extends ConsumerWidget {
  const GeneralSettingsPage({
    super.key,
  });

  @override
  Widget build(
      BuildContext context,
      WidgetRef ref,
      ) {
    final settings =
        ref.watch(
          schoolSettingsProvider,
        ).valueOrNull;

    return _Page(
      title: 'General Settings',
      icon:
      Icons.settings_applications_rounded,
      child: Column(
        children: [
          _InfoCard(
            icon:
            Icons.notifications_rounded,
            title: 'System Notifications',
            subtitle:
            'Control system notifications.',
            trailing:
            settings == null
                ? const SizedBox()
                : Switch.adaptive(
              value: settings
                  .notificationsEnabled,
              onChanged: (value) {
                ref
                    .read(
                  settingsRepositoryProvider,
                )
                    .updateSettings(
                  notificationsEnabled:
                  value,
                );
              },
            ),
          ),
          _InfoCard(
            icon:
            Icons.cloud_rounded,
            title: 'Automatic Backup',
            subtitle:
            'Keep automatic cloud backup enabled.',
            trailing:
            settings == null
                ? const SizedBox()
                : Switch.adaptive(
              value:
              settings.autoBackup,
              onChanged: (value) {
                ref
                    .read(
                  settingsRepositoryProvider,
                )
                    .updateSettings(
                  autoBackup:
                  value,
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================
// LANGUAGE
// ============================================================

class LanguageSettingsPage
    extends ConsumerWidget {
  const LanguageSettingsPage({
    super.key,
  });

  @override
  Widget build(
      BuildContext context,
      WidgetRef ref,
      ) {
    final language =
    ref.watch(languageProvider);

    final format =
    ref.watch(dateFormatProvider);

    return _Page(
      title: 'Language & Region',
      icon: Icons.translate_rounded,
      child: Column(
        children: [
          _DropdownCard<String>(
            title: 'Language',
            value: language,
            items: const [
              'English',
              'Urdu',
            ],
            onChanged: (value) {
              if (value != null) {
                ref
                    .read(
                  languageProvider
                      .notifier,
                )
                    .state = value;
              }
            },
          ),
          _DropdownCard<String>(
            title: 'Date Format',
            value: format,
            items: const [
              'DD/MM/YYYY',
              'MM/DD/YYYY',
              'YYYY-MM-DD',
            ],
            onChanged: (value) {
              if (value != null) {
                ref
                    .read(
                  dateFormatProvider
                      .notifier,
                )
                    .state = value;
              }
            },
          ),
        ],
      ),
    );
  }
}

// ============================================================
// SCHOOL PROFILE
// ============================================================

class SchoolProfilePage
    extends ConsumerStatefulWidget {
  const SchoolProfilePage({
    super.key,
  });

  @override
  ConsumerState<SchoolProfilePage>
  createState() =>
      _SchoolProfilePageState();
}

class _SchoolProfilePageState
    extends ConsumerState<
        SchoolProfilePage> {
  final controller =
  TextEditingController();

  bool loading = false;

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  Future<void> save() async {
    if (controller.text.trim().isEmpty) {
      return;
    }

    setState(() {
      loading = true;
    });

    try {
      await ref
          .read(
        settingsRepositoryProvider,
      )
          .updateSchool(
        schoolName:
        controller.text,
      );

      ref.invalidate(
        schoolProfileProvider,
      );

      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(
          const SnackBar(
            content:
            Text('School profile updated.'),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(
          SnackBar(
            content: Text('$e'),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          loading = false;
        });
      }
    }
  }

  @override
  Widget build(
      BuildContext context,
      ) {
    final schoolAsync =
    ref.watch(
      schoolProfileProvider,
    );

    return _Page(
      title: 'School Profile',
      icon: Icons.school_rounded,
      child: schoolAsync.when(
        loading: () => const Center(
          child:
          CircularProgressIndicator(),
        ),
        error: (error, _) =>
            Text('$error'),
        data: (school) {
          if (controller.text.isEmpty) {
            controller.text =
                school['school_name']
                    ?.toString() ??
                    '';
          }

          final logo =
              school['logo_url']
                  ?.toString() ??
                  '';

          return Column(
            children: [
              if (logo.isNotEmpty)
                ClipRRect(
                  borderRadius:
                  BorderRadius.circular(
                    18,
                  ),
                  child: Image.network(
                    logo,
                    width: 90,
                    height: 90,
                    fit: BoxFit.cover,
                    errorBuilder:
                        (_, __, ___) {
                      return Container(
                        width: 90,
                        height: 90,
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
                            18,
                          ),
                        ),
                        child: const Icon(
                          Icons.school_rounded,
                          color:
                          AppColors.primary,
                          size: 40,
                        ),
                      );
                    },
                  ),
                ),

              const SizedBox(height: 20),

              TextField(
                controller: controller,
                decoration:
                const InputDecoration(
                  labelText:
                  'School Name',
                  prefixIcon:
                  Icon(Icons.school),
                  border:
                  OutlineInputBorder(),
                ),
              ),

              const SizedBox(height: 15),

              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed:
                  loading ? null : save,
                  icon: loading
                      ? const SizedBox(
                    width: 17,
                    height: 17,
                    child:
                    CircularProgressIndicator(
                      strokeWidth: 2,
                      color:
                      Colors.white,
                    ),
                  )
                      : const Icon(
                    Icons.save_rounded,
                  ),
                  label: Text(
                    loading
                        ? 'Saving...'
                        : 'Save School Profile',
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

// ============================================================
// MANAGE USERS
// ============================================================

class ManageUsersPage
    extends ConsumerWidget {
  const ManageUsersPage({
    super.key,
  });

  @override
  Widget build(
      BuildContext context,
      WidgetRef ref,
      ) {
    final users =
    ref.watch(
      settingsUsersProvider,
    );

    return _Page(
      title: 'Manage Users',
      icon: Icons.groups_rounded,
      child: users.when(
        loading: () => const Center(
          child:
          CircularProgressIndicator(),
        ),
        error: (error, _) =>
            Text('$error'),
        data: (list) {
          if (list.isEmpty) {
            return const _Empty(
              text: 'No users found.',
            );
          }

          return Column(
            children: list.map(
                  (user) {
                final active =
                    user['is_active'] != false;

                final name =
                user['full_name']
                    ?.toString()
                    .trim()
                    .isNotEmpty ==
                    true
                    ? user['full_name']
                    .toString()
                    : 'Unnamed User';

                final email =
                    user['email']
                        ?.toString() ??
                        '';

                final role =
                    user['role']
                        ?.toString() ??
                        'user';

                return Card(
                  margin:
                  const EdgeInsets.only(
                    bottom: 10,
                  ),
                  child: ListTile(
                    leading:
                    CircleAvatar(
                      backgroundColor:
                      AppColors.primary
                          .withValues(
                        alpha: .10,
                      ),
                      child: const Icon(
                        Icons.person,
                        color:
                        AppColors.primary,
                      ),
                    ),
                    title: Text(
                      name,
                      style:
                      const TextStyle(
                        fontWeight:
                        FontWeight.w800,
                      ),
                    ),
                    subtitle: Text(
                      '$email • $role',
                    ),
                    trailing: Icon(
                      active
                          ? Icons
                          .check_circle
                          : Icons
                          .cancel,
                      color: active
                          ? AppColors
                          .success
                          : Colors.red,
                    ),
                  ),
                );
              },
            ).toList(),
          );
        },
      ),
    );
  }
}

// ============================================================
// SECURITY
// ============================================================

class SecurityPage
    extends ConsumerStatefulWidget {
  const SecurityPage({
    super.key,
  });

  @override
  ConsumerState<SecurityPage>
  createState() =>
      _SecurityPageState();
}

class _SecurityPageState
    extends ConsumerState<
        SecurityPage> {
  final password =
  TextEditingController();

  final confirm =
  TextEditingController();

  bool loading = false;

  @override
  void dispose() {
    password.dispose();
    confirm.dispose();
    super.dispose();
  }

  Future<void> changePassword() async {
    if (password.text.length < 6) {
      _message(
        'Password must contain at least 6 characters.',
      );
      return;
    }

    if (password.text != confirm.text) {
      _message(
        'Passwords do not match.',
      );
      return;
    }

    setState(() {
      loading = true;
    });

    try {
      await ref
          .read(
        settingsRepositoryProvider,
      )
          .changePassword(
        password.text,
      );

      password.clear();
      confirm.clear();

      if (mounted) {
        _message(
          'Password changed successfully.',
        );
      }
    } catch (e) {
      if (mounted) {
        _message('$e');
      }
    } finally {
      if (mounted) {
        setState(() {
          loading = false;
        });
      }
    }
  }

  void _message(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(
      SnackBar(
        content: Text(message),
      ),
    );
  }

  @override
  Widget build(
      BuildContext context,
      ) {
    return _Page(
      title: 'Security & Privacy',
      icon: Icons.security_rounded,
      child: Column(
        children: [
          TextField(
            controller: password,
            obscureText: true,
            decoration:
            const InputDecoration(
              labelText:
              'New Password',
              prefixIcon:
              Icon(Icons.lock_outline),
              border:
              OutlineInputBorder(),
            ),
          ),

          const SizedBox(height: 14),

          TextField(
            controller: confirm,
            obscureText: true,
            decoration:
            const InputDecoration(
              labelText:
              'Confirm Password',
              prefixIcon:
              Icon(Icons.lock_reset),
              border:
              OutlineInputBorder(),
            ),
          ),

          const SizedBox(height: 18),

          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed:
              loading
                  ? null
                  : changePassword,
              icon: const Icon(
                Icons.password_rounded,
              ),
              label: Text(
                loading
                    ? 'Updating...'
                    : 'Change Password',
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================
// ACADEMIC SESSION
// ============================================================

class AcademicSessionPage
    extends StatelessWidget {
  const AcademicSessionPage({
    super.key,
  });

  @override
  Widget build(
      BuildContext context,
      ) {
    return const _Page(
      title: 'Academic Sessions',
      icon:
      Icons.calendar_month_rounded,
      child: _Empty(
        text:
        'Academic Sessions module will be connected to the academic sessions database.',
      ),
    );
  }
}

// ============================================================
// FEE STRUCTURE
// ============================================================

class FeeStructurePage
    extends StatelessWidget {
  const FeeStructurePage({
    super.key,
  });

  @override
  Widget build(
      BuildContext context,
      ) {
    return const _Page(
      title: 'Fee Structures',
      icon:
      Icons.account_balance_wallet_rounded,
      child: _Empty(
        text:
        'Fee Structures module will be connected to the fee database.',
      ),
    );
  }
}

// ============================================================
// PAGE
// ============================================================

class _Page extends StatelessWidget {
  final String title;
  final IconData icon;
  final Widget child;

  const _Page({
    required this.title,
    required this.icon,
    required this.child,
  });

  @override
  Widget build(
      BuildContext context,
      ) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Icon(
              icon,
              color:
              AppColors.primary,
            ),
            const SizedBox(width: 10),
            Text(title),
          ],
        ),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints:
          const BoxConstraints(
            maxWidth: 700,
          ),
          child: ListView(
            padding:
            const EdgeInsets.all(20),
            children: [
              child,
            ],
          ),
        ),
      ),
    );
  }
}

// ============================================================
// INFO CARD
// ============================================================

class _InfoCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Widget trailing;

  const _InfoCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.trailing,
  });

  @override
  Widget build(
      BuildContext context,
      ) {
    return Card(
      margin:
      const EdgeInsets.only(
        bottom: 12,
      ),
      child: ListTile(
        leading: Icon(
          icon,
          color:
          AppColors.primary,
        ),
        title: Text(
          title,
          style:
          const TextStyle(
            fontWeight:
            FontWeight.w800,
          ),
        ),
        subtitle: Text(
          subtitle,
        ),
        trailing: trailing,
      ),
    );
  }
}

// ============================================================
// DROPDOWN
// ============================================================

class _DropdownCard<T>
    extends StatelessWidget {
  final String title;
  final T value;
  final List<T> items;
  final ValueChanged<T?> onChanged;

  const _DropdownCard({
    required this.title,
    required this.value,
    required this.items,
    required this.onChanged,
  });

  @override
  Widget build(
      BuildContext context,
      ) {
    return Card(
      margin:
      const EdgeInsets.only(
        bottom: 12,
      ),
      child: Padding(
        padding:
        const EdgeInsets.all(15),
        child:
        DropdownButtonFormField<T>(
          initialValue: value,
          decoration:
          InputDecoration(
            labelText: title,
            border:
            const OutlineInputBorder(),
          ),
          items: items
              .map(
                (item) =>
                DropdownMenuItem<T>(
                  value: item,
                  child:
                  Text(item.toString()),
                ),
          )
              .toList(),
          onChanged: onChanged,
        ),
      ),
    );
  }
}

// ============================================================
// EMPTY
// ============================================================

class _Empty extends StatelessWidget {
  final String text;

  const _Empty({
    required this.text,
  });

  @override
  Widget build(
      BuildContext context,
      ) {
    return Container(
      padding:
      const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius:
        BorderRadius.circular(16),
      ),
      child: Text(
        text,
        textAlign:
        TextAlign.center,
        style:
        const TextStyle(
          color:
          AppColors
              .textSecondary,
        ),
      ),
    );
  }
}

// ============================================================
// ERROR
// ============================================================

class _ErrorView
    extends StatelessWidget {
  final String error;
  final VoidCallback retry;

  const _ErrorView({
    required this.error,
    required this.retry,
  });

  @override
  Widget build(
      BuildContext context,
      ) {
    return Center(
      child: Padding(
        padding:
        const EdgeInsets.all(25),
        child: Column(
          mainAxisSize:
          MainAxisSize.min,
          children: [
            const Icon(
              Icons
                  .error_outline_rounded,
              color: Colors.red,
              size: 50,
            ),

            const SizedBox(height: 12),

            const Text(
              'Unable to load settings',
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
                fontSize: 12,
              ),
            ),

            const SizedBox(height: 18),

            FilledButton.icon(
              onPressed: retry,
              icon: const Icon(
                Icons.refresh_rounded,
              ),
              label:
              const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}