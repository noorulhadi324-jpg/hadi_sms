import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/network/supabase_client.dart';
import '../../../../core/widgets/main_wrapper.dart';
import '../controllers/communication_controller.dart';

class CommunicationCenterScreen extends ConsumerStatefulWidget {
  const CommunicationCenterScreen({super.key});

  @override
  ConsumerState<CommunicationCenterScreen> createState() =>
      _CommunicationCenterScreenState();
}

class _CommunicationCenterScreenState
    extends ConsumerState<CommunicationCenterScreen> {
  final TextEditingController _searchController =
  TextEditingController();

  int? _schoolId;
  String? _userId;
  String _role = '';

  bool _loading = true;
  String? _error;

  int _tab = 0;

  List<Map<String, dynamic>> _announcements = [];
  List<Map<String, dynamic>> _users = [];
  List<Map<String, dynamic>> _threads = [];
  List<Map<String, dynamic>> _messages = [];

  int? _selectedThreadId;
  bool _messagesLoading = false;

  String _search = '';

  SupabaseClient get _client => SupabaseConfig.client;

  bool get _canManageAnnouncements =>
      _role == 'principal' || _role == 'staff';

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // ============================================================
  // LOAD MAIN DATA
  // ============================================================

  Future<void> _load() async {
    if (mounted) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }

    try {
      final currentUser = _client.auth.currentUser;

      if (currentUser == null) {
        throw Exception('آپ لاگ اِن نہیں ہیں۔');
      }

      final profile = await _client
          .from('profiles')
          .select('school_id,role,is_active')
          .eq('id', currentUser.id)
          .maybeSingle();

      final dynamic schoolValue = profile?['school_id'];

      final int? schoolId = schoolValue is num
          ? schoolValue.toInt()
          : int.tryParse(
        schoolValue?.toString() ?? '',
      );

      if (schoolId == null) {
        throw Exception(
          'آپ کے اکاؤنٹ کے ساتھ اسکول منسلک نہیں ہے۔',
        );
      }

      if (profile?['is_active'] == false) {
        throw Exception(
          'آپ کا اکاؤنٹ غیر فعال ہے۔',
        );
      }

      _schoolId = schoolId;
      _userId = currentUser.id;
      _role = profile?['role']?.toString() ?? '';

      final repository =
      ref.read(communicationRepositoryProvider);

      final announcements =
      await repository.getSchoolNotifications(
        schoolId,
      );

      final users =
      await repository.getSchoolUsers(
        schoolId,
      );

      final threads =
      await repository.getThreads(
        schoolId,
      );

      if (!mounted) return;

      setState(() {
        _announcements = announcements
            .map(
              (notification) => notification.toMap(),
        )
            .toList();

        // IMPORTANT:
        // "user" is a Map, therefore we use userData['id']
        // instead of user.id.
        _users = users
            .where(
              (userData) =>
          userData['id']?.toString() !=
              currentUser.id,
        )
            .toList();

        _threads = threads.map(
              (thread) {
            return {
              'id': thread.id,
              'school_id': thread.schoolId,
              'title': thread.title,
              'thread_type': thread.threadType,
              'created_by': thread.createdBy,
              'created_at':
              thread.createdAt.toIso8601String(),
              'updated_at':
              thread.updatedAt.toIso8601String(),
              'is_archived': thread.isArchived,
            };
          },
        ).toList();

        _loading = false;
      });

      if (_selectedThreadId != null &&
          !_threads.any(
                (thread) =>
            thread['id'] ==
                _selectedThreadId,
          )) {
        setState(() {
          _selectedThreadId = null;
          _messages = [];
        });
      }
    } catch (error) {
      if (!mounted) return;

      setState(() {
        _loading = false;
        _error = error
            .toString()
            .replaceFirst(
          'Exception: ',
          '',
        );
      });
    }
  }

  // ============================================================
  // LOAD MESSAGES
  // ============================================================

  Future<void> _loadMessages(
      int threadId,
      ) async {
    if (mounted) {
      setState(() {
        _messagesLoading = true;
        _error = null;
      });
    }

    try {
      final rows = await _client
          .from('communication_messages')
          .select(
        'id,thread_id,sender_id,body,created_at,is_deleted',
      )
          .eq(
        'thread_id',
        threadId,
      )
          .order(
        'created_at',
      );

      final List<String> senderIds = rows
          .map(
            (row) =>
        row['sender_id']?.toString() ??
            '',
      )
          .where(
            (id) => id.isNotEmpty,
      )
          .toSet()
          .toList();

      final Map<String, String> names = {};

      if (senderIds.isNotEmpty) {
        final profiles = await _client
            .from('profiles')
            .select(
          'id,full_name,role',
        )
            .inFilter(
          'id',
          senderIds,
        );

        for (final profile in profiles) {
          final id =
          profile['id']?.toString();

          if (id == null || id.isEmpty) {
            continue;
          }

          final fullName =
          profile['full_name']
              ?.toString()
              .trim();

          names[id] =
          fullName != null &&
              fullName.isNotEmpty
              ? fullName
              : 'User';
        }
      }

      if (!mounted) return;

      setState(() {
        _messages = rows.map(
              (row) {
            final map =
            Map<String, dynamic>.from(
              row,
            );

            final senderId =
                row['sender_id']
                    ?.toString() ??
                    '';

            map['sender_name'] =
                names[senderId] ?? 'User';

            return map;
          },
        ).toList();

        _messagesLoading = false;
      });
    } catch (error) {
      if (!mounted) return;

      setState(() {
        _messagesLoading = false;
        _error = error
            .toString()
            .replaceFirst(
          'Exception: ',
          '',
        );
      });
    }
  }

  // ============================================================
  // SEND MESSAGE
  // ============================================================

  Future<void> _sendMessage(
      String text,
      ) async {
    final threadId =
        _selectedThreadId;

    final userId = _userId;

    if (threadId == null ||
        userId == null ||
        text.trim().isEmpty) {
      return;
    }

    try {
      await ref
          .read(
        communicationRepositoryProvider,
      )
          .sendMessage(
        threadId: threadId,
        senderId: userId,
        body: text.trim(),
      );

      await _loadMessages(
        threadId,
      );

      await _load();
    } catch (error) {
      _showError(
        error.toString().replaceFirst(
          'Exception: ',
          '',
        ),
      );
    }
  }

  // ============================================================
  // CREATE THREAD
  // ============================================================

  Future<void> _createThread() async {
    final schoolId = _schoolId;
    final userId = _userId;

    if (schoolId == null ||
        userId == null) {
      return;
    }

    final titleController =
    TextEditingController();

    final Set<String> selected =
    <String>{};

    String type = 'direct';

    final created =
    await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (
              dialogContext,
              setDialogState,
              ) {
            final query =
            _search.trim().toLowerCase();

            final visibleUsers =
            _users.where(
                  (userData) {
                if (query.isEmpty) {
                  return true;
                }

                final searchable =
                '${userData['full_name'] ?? ''} '
                    '${userData['email'] ?? ''} '
                    '${userData['role'] ?? ''}'
                    .toLowerCase();

                return searchable.contains(
                  query,
                );
              },
            ).toList();

            return AlertDialog(
              title: const Text(
                'نئی گفتگو',
              ),
              content: SizedBox(
                width: 520,
                child: SingleChildScrollView(
                  child: Column(
                    children: [
                      TextField(
                        controller:
                        titleController,
                        decoration:
                        const InputDecoration(
                          labelText:
                          'گفتگو کا عنوان (اختیاری)',
                          prefixIcon:
                          Icon(
                            Icons
                                .title_rounded,
                          ),
                        ),
                      ),

                      const SizedBox(
                        height: 14,
                      ),

                      SegmentedButton<
                          String>(
                        segments: const [
                          ButtonSegment<
                              String>(
                            value: 'direct',
                            label:
                            Text(
                              'Direct',
                            ),
                            icon:
                            Icon(
                              Icons
                                  .person_rounded,
                            ),
                          ),
                          ButtonSegment<
                              String>(
                            value: 'group',
                            label:
                            Text(
                              'Group',
                            ),
                            icon:
                            Icon(
                              Icons
                                  .groups_rounded,
                            ),
                          ),
                        ],
                        selected: {
                          type,
                        },
                        onSelectionChanged:
                            (selection) {
                          if (selection
                              .isEmpty) {
                            return;
                          }

                          setDialogState(
                                () {
                              type =
                                  selection
                                      .first;

                              if (type ==
                                  'direct' &&
                                  selected
                                      .length >
                                      1) {
                                final first =
                                    selected
                                        .first;

                                selected
                                  ..clear()
                                  ..add(
                                    first,
                                  );
                              }
                            },
                          );
                        },
                      ),

                      const SizedBox(
                        height: 16,
                      ),

                      Align(
                        alignment:
                        Alignment
                            .centerLeft,
                        child: Text(
                          type == 'direct'
                              ? 'شخص منتخب کریں'
                              : 'ٹیم کے اراکین منتخب کریں',
                          style:
                          const TextStyle(
                            fontWeight:
                            FontWeight
                                .w800,
                          ),
                        ),
                      ),

                      const SizedBox(
                        height: 8,
                      ),

                      if (visibleUsers
                          .isEmpty)
                        const Padding(
                          padding:
                          EdgeInsets
                              .all(
                            20,
                          ),
                          child: Text(
                            'کوئی user موجود نہیں۔',
                          ),
                        )
                      else
                        ...visibleUsers.map(
                              (
                              userData,
                              ) {
                            final id =
                                userData[
                                'id']
                                    ?.toString() ??
                                    '';

                            final fullName =
                            userData[
                            'full_name']
                                ?.toString()
                                .trim();

                            final email =
                            userData[
                            'email']
                                ?.toString()
                                .trim();

                            final name =
                            fullName !=
                                null &&
                                fullName
                                    .isNotEmpty
                                ? fullName
                                : email !=
                                null &&
                                email
                                    .isNotEmpty
                                ? email
                                : 'User';

                            final role =
                                userData[
                                'role']
                                    ?.toString() ??
                                    '';

                            return CheckboxListTile(
                              dense: true,
                              value:
                              selected
                                  .contains(
                                id,
                              ),
                              title:
                              Text(
                                name,
                              ),
                              subtitle:
                              Text(
                                role
                                    .toUpperCase(),
                              ),
                              onChanged:
                                  (value) {
                                setDialogState(
                                      () {
                                    if (type ==
                                        'direct') {
                                      selected
                                          .clear();
                                    }

                                    if (value ==
                                        true) {
                                      selected
                                          .add(
                                        id,
                                      );
                                    } else {
                                      selected
                                          .remove(
                                        id,
                                      );
                                    }
                                  },
                                );
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
                  onPressed:
                  selected.isEmpty
                      ? null
                      : () {
                    Navigator.pop(
                      dialogContext,
                      true,
                    );
                  },
                  child:
                  const Text(
                    'Create',
                  ),
                ),
              ],
            );
          },
        );
      },
    );

    if (created != true ||
        selected.isEmpty) {
      titleController.dispose();
      return;
    }

    try {
      final id = await ref
          .read(
        communicationRepositoryProvider,
      )
          .createThread(
        schoolId: schoolId,
        createdBy: userId,
        title:
        titleController.text.trim(),
        threadType: type,
        memberIds:
        selected.toList(),
      );

      titleController.dispose();

      await _load();

      if (!mounted) return;

      setState(() {
        _tab = 1;
        _selectedThreadId = id;
      });

      await _loadMessages(id);
    } catch (error) {
      titleController.dispose();

      _showError(
        error.toString().replaceFirst(
          'Exception: ',
          '',
        ),
      );
    }
  }

  // ============================================================
  // CREATE ANNOUNCEMENT
  // ============================================================

  Future<void> _createAnnouncement() async {
    final schoolId = _schoolId;

    if (schoolId == null ||
        !_canManageAnnouncements) {
      return;
    }

    final titleController =
    TextEditingController();

    final bodyController =
    TextEditingController();

    String target = 'all';
    String category = 'general';

    final created =
    await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (
              dialogContext,
              setDialogState,
              ) {
            return AlertDialog(
              title: const Text(
                'نیا اعلان',
              ),
              content: SizedBox(
                width: 520,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize:
                    MainAxisSize.min,
                    children: [
                      TextField(
                        controller:
                        titleController,
                        decoration:
                        const InputDecoration(
                          labelText:
                          'عنوان',
                        ),
                      ),

                      const SizedBox(
                        height: 12,
                      ),

                      TextField(
                        controller:
                        bodyController,
                        minLines: 4,
                        maxLines: 7,
                        decoration:
                        const InputDecoration(
                          labelText:
                          'پیغام',
                        ),
                      ),

                      const SizedBox(
                        height: 12,
                      ),

                      DropdownButtonFormField<
                          String>(
                        initialValue:
                        target,
                        decoration:
                        const InputDecoration(
                          labelText:
                          'کس کو دکھانا ہے؟',
                        ),
                        items: const [
                          DropdownMenuItem<
                              String>(
                            value: 'all',
                            child:
                            Text(
                              'سب',
                            ),
                          ),
                          DropdownMenuItem<
                              String>(
                            value:
                            'teacher',
                            child:
                            Text(
                              'Teachers',
                            ),
                          ),
                          DropdownMenuItem<
                              String>(
                            value:
                            'parent',
                            child:
                            Text(
                              'Parents',
                            ),
                          ),
                          DropdownMenuItem<
                              String>(
                            value:
                            'staff',
                            child:
                            Text(
                              'Staff',
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
                              target =
                                  value;
                            },
                          );
                        },
                      ),

                      const SizedBox(
                        height: 12,
                      ),

                      DropdownButtonFormField<
                          String>(
                        initialValue:
                        category,
                        decoration:
                        const InputDecoration(
                          labelText:
                          'Category',
                        ),
                        items: const [
                          DropdownMenuItem<
                              String>(
                            value:
                            'general',
                            child:
                            Text(
                              'General',
                            ),
                          ),
                          DropdownMenuItem<
                              String>(
                            value:
                            'academic',
                            child:
                            Text(
                              'Academic',
                            ),
                          ),
                          DropdownMenuItem<
                              String>(
                            value:
                            'attendance',
                            child:
                            Text(
                              'Attendance',
                            ),
                          ),
                          DropdownMenuItem<
                              String>(
                            value:
                            'fee',
                            child:
                            Text(
                              'Fee',
                            ),
                          ),
                          DropdownMenuItem<
                              String>(
                            value:
                            'urgent',
                            child:
                            Text(
                              'Urgent',
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
                              category =
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
                  onPressed: () {
                    Navigator.pop(
                      dialogContext,
                      true,
                    );
                  },
                  child:
                  const Text(
                    'Publish',
                  ),
                ),
              ],
            );
          },
        );
      },
    );

    if (created != true) {
      titleController.dispose();
      bodyController.dispose();
      return;
    }

    final title =
    titleController.text.trim();

    final body =
    bodyController.text.trim();

    if (title.isEmpty ||
        body.isEmpty) {
      titleController.dispose();
      bodyController.dispose();

      _showError(
        'عنوان اور پیغام دونوں ضروری ہیں۔',
      );

      return;
    }

    try {
      await _client
          .from('notifications')
          .insert({
        'school_id': schoolId,
        'title': title,
        'description': body,
        'message': body,
        'category': category,
        'type': 'announcement',
        'target_role':
        target == 'all'
            ? null
            : target,
        'is_active': true,
        'is_read': false,
        'created_by': _userId,
      });

      titleController.dispose();
      bodyController.dispose();

      await _load();
    } catch (error) {
      titleController.dispose();
      bodyController.dispose();

      _showError(
        error.toString().replaceFirst(
          'Exception: ',
          '',
        ),
      );
    }
  }

  // ============================================================
  // DELETE ANNOUNCEMENT
  // ============================================================

  Future<void> _deleteAnnouncement(
      int id,
      ) async {
    if (!_canManageAnnouncements ||
        _schoolId == null) {
      return;
    }

    try {
      await _client
          .from('notifications')
          .delete()
          .eq(
        'id',
        id,
      )
          .eq(
        'school_id',
        _schoolId!,
      );

      await _load();
    } catch (error) {
      _showError(
        error.toString().replaceFirst(
          'Exception: ',
          '',
        ),
      );
    }
  }

  // ============================================================
  // ERROR
  // ============================================================

  void _showError(
      String message,
      ) {
    if (!mounted) return;

    ScaffoldMessenger.of(context)
        .showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor:
        Colors.redAccent,
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
      child: _loading
          ? const Center(
        child:
        CircularProgressIndicator(),
      )
          : _error != null
          ? _errorView()
          : LayoutBuilder(
        builder:
            (
            context,
            constraints,
            ) {
          final mobile =
              constraints
                  .maxWidth <
                  850;

          return Column(
            children: [
              _header(
                mobile,
              ),
              Expanded(
                child: _tab == 0
                    ? _announcementsView(
                  mobile,
                )
                    : _chatView(
                  mobile,
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  // ============================================================
  // HEADER
  // ============================================================

  Widget _header(
      bool mobile,
      ) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        mobile ? 16 : 28,
        18,
        mobile ? 16 : 28,
        14,
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration:
                BoxDecoration(
                  color: AppColors
                      .primary
                      .withValues(
                    alpha: 0.1,
                  ),
                  borderRadius:
                  BorderRadius
                      .circular(
                    14,
                  ),
                ),
                child: const Icon(
                  Icons
                      .forum_rounded,
                  color:
                  AppColors
                      .primary,
                ),
              ),

              const SizedBox(
                width: 12,
              ),

              const Expanded(
                child: Column(
                  crossAxisAlignment:
                  CrossAxisAlignment
                      .start,
                  children: [
                    Text(
                      'Communication',
                      style:
                      TextStyle(
                        fontSize: 23,
                        fontWeight:
                        FontWeight
                            .w900,
                      ),
                    ),
                    SizedBox(
                      height: 3,
                    ),
                    Text(
                      'Announcements, team chat and school communication',
                      style:
                      TextStyle(
                        color: AppColors
                            .textSecondary,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),

              IconButton(
                onPressed: _load,
                tooltip: 'Refresh',
                icon: const Icon(
                  Icons
                      .refresh_rounded,
                ),
              ),

              if (_tab == 1)
                IconButton(
                  onPressed:
                  _createThread,
                  tooltip:
                  'New chat',
                  icon: const Icon(
                    Icons
                        .add_comment_rounded,
                  ),
                ),

              if (_tab == 0 &&
                  _canManageAnnouncements)
                FilledButton.icon(
                  onPressed:
                  _createAnnouncement,
                  icon: const Icon(
                    Icons
                        .campaign_rounded,
                    size: 17,
                  ),
                  label: Text(
                    mobile
                        ? 'New'
                        : 'New Announcement',
                  ),
                ),
            ],
          ),

          const SizedBox(
            height: 14,
          ),

          Align(
            alignment:
            Alignment.centerLeft,
            child:
            SegmentedButton<int>(
              segments: const [
                ButtonSegment<int>(
                  value: 0,
                  label: Text(
                    'Announcements',
                  ),
                  icon: Icon(
                    Icons
                        .campaign_rounded,
                  ),
                ),
                ButtonSegment<int>(
                  value: 1,
                  label: Text(
                    'Team Chat',
                  ),
                  icon: Icon(
                    Icons
                        .chat_rounded,
                  ),
                ),
              ],
              selected: {_tab},
              onSelectionChanged:
                  (value) {
                if (value.isEmpty) {
                  return;
                }

                setState(() {
                  _tab =
                      value.first;
                });
              },
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // ANNOUNCEMENTS
  // ============================================================

  Widget _announcementsView(
      bool mobile,
      ) {
    final visible =
    _announcements.where(
          (notification) {
        final target =
        notification[
        'target_role']
            ?.toString();

        final allowed =
            target == null ||
                target.isEmpty ||
                target == 'all' ||
                target == _role ||
                _canManageAnnouncements;

        final query =
        _search
            .trim()
            .toLowerCase();

        final text =
        '${notification['title'] ?? ''} '
            '${notification['description'] ?? ''} '
            '${notification['message'] ?? ''}'
            .toLowerCase();

        return allowed &&
            (
                query.isEmpty ||
                    text.contains(query)
            );
      },
    ).toList();

    return Column(
      children: [
        Padding(
          padding:
          EdgeInsets.symmetric(
            horizontal:
            mobile ? 16 : 28,
            vertical: 8,
          ),
          child: TextField(
            controller:
            _searchController,
            onChanged: (value) {
              setState(() {
                _search = value;
              });
            },
            decoration:
            InputDecoration(
              prefixIcon:
              const Icon(
                Icons
                    .search_rounded,
              ),
              hintText:
              'Search announcements...',
              suffixIcon:
              _search.isEmpty
                  ? null
                  : IconButton(
                onPressed:
                    () {
                  _searchController
                      .clear();

                  setState(
                        () {
                      _search =
                      '';
                    },
                  );
                },
                icon:
                const Icon(
                  Icons
                      .clear_rounded,
                ),
              ),
            ),
          ),
        ),

        Expanded(
          child: visible.isEmpty
              ? _empty(
            Icons
                .campaign_outlined,
            'کوئی اعلان موجود نہیں',
          )
              : ListView
              .separated(
            padding:
            EdgeInsets.all(
              mobile
                  ? 12
                  : 24,
            ),
            itemCount:
            visible.length,
            separatorBuilder:
                (
                _,
                __,
                ) =>
            const SizedBox(
              height: 10,
            ),
            itemBuilder:
                (
                _,
                index,
                ) =>
                _announcementCard(
                  visible[index],
                ),
          ),
        ),
      ],
    );
  }

  Widget _announcementCard(
      Map<String, dynamic>
      notification,
      ) {
    final title =
    notification['title']
        ?.toString()
        .trim()
        .isNotEmpty ==
        true
        ? notification[
    'title']
        .toString()
        : 'School Announcement';

    final message =
    notification['message']
        ?.toString()
        .trim()
        .isNotEmpty ==
        true
        ? notification[
    'message']
        .toString()
        : notification[
    'description']
        ?.toString() ??
        '';

    final target =
    notification[
    'target_role']
        ?.toString();

    final category =
        notification[
        'category']
            ?.toString() ??
            'general';

    final dynamic rawId =
    notification['id'];

    final int? id =
    rawId is num
        ? rawId.toInt()
        : int.tryParse(
      rawId?.toString() ??
          '',
    );

    return Card(
      elevation: 0,
      child: InkWell(
        borderRadius:
        BorderRadius.circular(
          16,
        ),
        onTap: () =>
            _showAnnouncement(
              notification,
            ),
        child: Padding(
          padding:
          const EdgeInsets.all(
            16,
          ),
          child: Row(
            crossAxisAlignment:
            CrossAxisAlignment
                .start,
            children: [
              Container(
                width: 46,
                height: 46,
                decoration:
                BoxDecoration(
                  color: AppColors
                      .primary
                      .withValues(
                    alpha: 0.1,
                  ),
                  borderRadius:
                  BorderRadius
                      .circular(
                    13,
                  ),
                ),
                child: const Icon(
                  Icons
                      .campaign_rounded,
                  color:
                  AppColors
                      .primary,
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
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            title,
                            style:
                            const TextStyle(
                              fontWeight:
                              FontWeight
                                  .w900,
                              fontSize: 15,
                            ),
                          ),
                        ),
                        if (target !=
                            null)
                          _chip(
                            target,
                          ),
                      ],
                    ),

                    const SizedBox(
                      height: 5,
                    ),

                    Text(
                      message,
                      maxLines: 3,
                      overflow:
                      TextOverflow
                          .ellipsis,
                      style:
                      const TextStyle(
                        color: AppColors
                            .textSecondary,
                        height: 1.4,
                      ),
                    ),

                    const SizedBox(
                      height: 8,
                    ),

                    Row(
                      children: [
                        _chip(
                          category,
                        ),

                        const Spacer(),

                        Text(
                          _formatDate(
                            notification[
                            'created_at'],
                          ),
                          style:
                          const TextStyle(
                            color: AppColors
                                .textMuted,
                            fontSize: 10,
                          ),
                        ),

                        if (_canManageAnnouncements &&
                            id != null)
                          IconButton(
                            onPressed:
                                () =>
                                _deleteAnnouncement(
                                  id,
                                ),
                            icon:
                            const Icon(
                              Icons
                                  .delete_outline_rounded,
                              size: 19,
                              color: Colors
                                  .redAccent,
                            ),
                          ),
                      ],
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

  // ============================================================
  // CHAT
  // ============================================================

  Widget _chatView(
      bool mobile,
      ) {
    if (_selectedThreadId ==
        null) {
      return _threadList(
        mobile,
      );
    }

    return _chatDetail(
      mobile,
    );
  }

  Widget _threadList(
      bool mobile,
      ) {
    final visible =
    _threads.where(
          (thread) {
        final query =
        _search
            .trim()
            .toLowerCase();

        final title =
        _threadTitle(
          thread,
        ).toLowerCase();

        return query.isEmpty ||
            title.contains(query);
      },
    ).toList();

    return Column(
      children: [
        Padding(
          padding:
          EdgeInsets.fromLTRB(
            mobile ? 16 : 28,
            8,
            mobile ? 16 : 28,
            4,
          ),
          child: TextField(
            onChanged: (value) {
              setState(() {
                _search = value;
              });
            },
            decoration:
            const InputDecoration(
              prefixIcon:
              Icon(
                Icons
                    .search_rounded,
              ),
              hintText:
              'Search conversations...',
            ),
          ),
        ),

        Expanded(
          child: visible.isEmpty
              ? _empty(
            Icons
                .chat_bubble_outline_rounded,
            'ابھی کوئی گفتگو نہیں۔ نئی گفتگو شروع کریں۔',
          )
              : ListView
              .separated(
            padding:
            EdgeInsets.all(
              mobile
                  ? 12
                  : 24,
            ),
            itemCount:
            visible.length,
            separatorBuilder:
                (
                _,
                __,
                ) =>
            const SizedBox(
              height: 8,
            ),
            itemBuilder:
                (
                _,
                index,
                ) =>
                _threadCard(
                  visible[index],
                ),
          ),
        ),
      ],
    );
  }

  Widget _threadCard(
      Map<String, dynamic>
      thread,
      ) {
    final dynamic rawId =
    thread['id'];

    final int? id =
    rawId is num
        ? rawId.toInt()
        : int.tryParse(
      rawId?.toString() ??
          '',
    );

    if (id == null) {
      return const SizedBox
          .shrink();
    }

    final title =
    _threadTitle(thread);

    final isGroup =
        thread['thread_type']
            ?.toString() ==
            'group';

    return Card(
      elevation: 0,
      child: ListTile(
        leading:
        CircleAvatar(
          backgroundColor:
          AppColors.primary
              .withValues(
            alpha: 0.1,
          ),
          child: Icon(
            isGroup
                ? Icons
                .groups_rounded
                : Icons
                .person_rounded,
            color:
            AppColors.primary,
          ),
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
          isGroup
              ? 'Team conversation'
              : 'Direct conversation',
        ),
        trailing:
        const Icon(
          Icons
              .chevron_right_rounded,
        ),
        onTap: () async {
          setState(() {
            _selectedThreadId =
                id;
          });

          await _loadMessages(
            id,
          );
        },
      ),
    );
  }

  // ============================================================
  // CHAT DETAIL
  // ============================================================

  Widget _chatDetail(
      bool mobile,
      ) {
    final thread =
    _threads.firstWhere(
          (item) =>
      item['id'] ==
          _selectedThreadId,
      orElse: () => {},
    );

    final title =
    _threadTitle(thread);

    final isGroup =
        thread['thread_type']
            ?.toString() ==
            'group';

    return Column(
      children: [
        Container(
          padding:
          const EdgeInsets
              .symmetric(
            horizontal: 12,
            vertical: 8,
          ),
          decoration:
          const BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color:
                AppColors.border,
              ),
            ),
          ),
          child: Row(
            children: [
              IconButton(
                onPressed: () {
                  setState(() {
                    _selectedThreadId =
                    null;
                    _messages = [];
                  });
                },
                icon: const Icon(
                  Icons
                      .arrow_back_rounded,
                ),
              ),

              CircleAvatar(
                backgroundColor:
                AppColors.primary
                    .withValues(
                  alpha: 0.1,
                ),
                child: Icon(
                  isGroup
                      ? Icons
                      .groups_rounded
                      : Icons
                      .person_rounded,
                  color:
                  AppColors
                      .primary,
                ),
              ),

              const SizedBox(
                width: 10,
              ),

              Expanded(
                child: Text(
                  title,
                  style:
                  const TextStyle(
                    fontWeight:
                    FontWeight
                        .w900,
                    fontSize: 16,
                  ),
                ),
              ),

              IconButton(
                onPressed:
                _selectedThreadId ==
                    null
                    ? null
                    : () =>
                    _loadMessages(
                      _selectedThreadId!,
                    ),
                icon: const Icon(
                  Icons
                      .refresh_rounded,
                ),
              ),
            ],
          ),
        ),

        Expanded(
          child:
          _messagesLoading
              ? const Center(
            child:
            CircularProgressIndicator(),
          )
              : _messages.isEmpty
              ? _empty(
            Icons
                .forum_outlined,
            'اس گفتگو میں ابھی کوئی پیغام نہیں۔',
          )
              : ListView.builder(
            padding:
            const EdgeInsets
                .all(
              18,
            ),
            itemCount:
            _messages
                .length,
            itemBuilder:
                (
                _,
                index,
                ) =>
                _messageBubble(
                  _messages[
                  index],
                ),
          ),
        ),

        _Composer(
          onSend:
          _sendMessage,
        ),
      ],
    );
  }

  // ============================================================
  // MESSAGE BUBBLE
  // ============================================================

  Widget _messageBubble(
      Map<String, dynamic>
      message,
      ) {
    final mine =
        message['sender_id']
            ?.toString() ==
            _userId;

    return Align(
      alignment: mine
          ? Alignment.centerRight
          : Alignment.centerLeft,
      child: Container(
        constraints:
        const BoxConstraints(
          maxWidth: 650,
        ),
        margin:
        const EdgeInsets.only(
          bottom: 10,
        ),
        padding:
        const EdgeInsets.fromLTRB(
          14,
          10,
          14,
          9,
        ),
        decoration:
        BoxDecoration(
          color: mine
              ? AppColors.primary
              : Theme.of(context)
              .cardColor,
          borderRadius:
          BorderRadius.circular(
            16,
          ),
          border: mine
              ? null
              : Border.all(
            color:
            AppColors.border,
          ),
        ),
        child: Column(
          crossAxisAlignment:
          mine
              ? CrossAxisAlignment
              .end
              : CrossAxisAlignment
              .start,
          children: [
            if (!mine)
              Text(
                message[
                'sender_name']
                    ?.toString() ??
                    'User',
                style:
                const TextStyle(
                  fontWeight:
                  FontWeight.w800,
                  fontSize: 11,
                ),
              ),

            if (!mine)
              const SizedBox(
                height: 2,
              ),

            Text(
              message['body']
                  ?.toString() ??
                  '',
              style: TextStyle(
                color: mine
                    ? Colors.white
                    : null,
                height: 1.4,
              ),
            ),

            const SizedBox(
              height: 3,
            ),

            Text(
              _formatTime(
                message[
                'created_at'],
              ),
              style:
              TextStyle(
                color: mine
                    ? Colors.white70
                    : AppColors
                    .textMuted,
                fontSize: 9,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // HELPERS
  // ============================================================

  String _threadTitle(
      Map<String, dynamic>
      thread,
      ) {
    final title =
        thread['title']
            ?.toString()
            .trim() ??
            '';

    if (title.isNotEmpty) {
      return title;
    }

    return thread['thread_type']
        ?.toString() ==
        'group'
        ? 'Team Chat'
        : 'Direct Chat';
  }

  Widget _chip(
      String text,
      ) {
    return Container(
      margin:
      const EdgeInsets.only(
        left: 6,
      ),
      padding:
      const EdgeInsets.symmetric(
        horizontal: 8,
        vertical: 4,
      ),
      decoration:
      BoxDecoration(
        color: AppColors.primary
            .withValues(
          alpha: 0.08,
        ),
        borderRadius:
        BorderRadius.circular(
          20,
        ),
      ),
      child: Text(
        text,
        style:
        const TextStyle(
          color:
          AppColors.primary,
          fontSize: 9,
          fontWeight:
          FontWeight.w800,
        ),
      ),
    );
  }

  Widget _empty(
      IconData icon,
      String text,
      ) {
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
            Icon(
              icon,
              size: 54,
              color: AppColors
                  .primary
                  .withValues(
                alpha: 0.35,
              ),
            ),
            const SizedBox(
              height: 12,
            ),
            Text(
              text,
              textAlign:
              TextAlign.center,
              style:
              const TextStyle(
                color: AppColors
                    .textSecondary,
                fontWeight:
                FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _errorView() {
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
            const Icon(
              Icons
                  .error_outline_rounded,
              size: 50,
              color:
              Colors.redAccent,
            ),
            const SizedBox(
              height: 12,
            ),
            Text(
              _error ?? 'Error',
              textAlign:
              TextAlign.center,
            ),
            const SizedBox(
              height: 12,
            ),
            FilledButton.icon(
              onPressed: _load,
              icon: const Icon(
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

  void _showAnnouncement(
      Map<String, dynamic>
      notification,
      ) {
    final title =
        notification['title']
            ?.toString() ??
            'Announcement';

    final message =
    notification['message']
        ?.toString()
        .trim()
        .isNotEmpty ==
        true
        ? notification[
    'message']
        .toString()
        : notification[
    'description']
        ?.toString() ??
        '';

    showDialog<void>(
      context: context,
      builder:
          (dialogContext) {
        return AlertDialog(
          title: Text(title),
          content:
          SingleChildScrollView(
            child: Text(message),
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
  }

  String _formatDate(
      dynamic value,
      ) {
    final date =
    DateTime.tryParse(
      value?.toString() ?? '',
    );

    if (date == null) {
      return '';
    }

    return '${date.day.toString().padLeft(2, '0')}/'
        '${date.month.toString().padLeft(2, '0')}/'
        '${date.year}';
  }

  String _formatTime(
      dynamic value,
      ) {
    final date =
    DateTime.tryParse(
      value?.toString() ?? '',
    )?.toLocal();

    if (date == null) {
      return '';
    }

    final hour = date.hour == 0
        ? 12
        : date.hour > 12
        ? date.hour - 12
        : date.hour;

    final period =
    date.hour >= 12
        ? 'PM'
        : 'AM';

    return '${hour.toString().padLeft(2, '0')}:'
        '${date.minute.toString().padLeft(2, '0')} '
        '$period';
  }
}

// ============================================================
// MESSAGE COMPOSER
// ============================================================

class _Composer extends StatefulWidget {
  final Future<void> Function(
      String,
      ) onSend;

  const _Composer({
    required this.onSend,
  });

  @override
  State<_Composer> createState() =>
      _ComposerState();
}

class _ComposerState
    extends State<_Composer> {
  final TextEditingController
  _controller =
  TextEditingController();

  bool _sending = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final text =
    _controller.text.trim();

    if (text.isEmpty ||
        _sending) {
      return;
    }

    setState(() {
      _sending = true;
    });

    try {
      await widget.onSend(text);

      if (mounted) {
        _controller.clear();
      }
    } finally {
      if (mounted) {
        setState(() {
          _sending = false;
        });
      }
    }
  }

  @override
  Widget build(
      BuildContext context,
      ) {
    return SafeArea(
      child: Container(
        padding:
        const EdgeInsets.fromLTRB(
          12,
          8,
          12,
          12,
        ),
        decoration:
        const BoxDecoration(
          border: Border(
            top: BorderSide(
              color:
              AppColors.border,
            ),
          ),
        ),
        child: Row(
          crossAxisAlignment:
          CrossAxisAlignment.end,
          children: [
            Expanded(
              child: TextField(
                controller:
                _controller,
                minLines: 1,
                maxLines: 5,
                textInputAction:
                TextInputAction
                    .newline,
                decoration:
                const InputDecoration(
                  hintText:
                  'پیغام لکھیں...',
                  prefixIcon:
                  Icon(
                    Icons
                        .message_outlined,
                  ),
                ),
              ),
            ),

            const SizedBox(
              width: 8,
            ),

            IconButton.filled(
              onPressed:
              _sending
                  ? null
                  : _send,
              icon: _sending
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
                  : const Icon(
                Icons
                    .send_rounded,
              ),
            ),
          ],
        ),
      ),
    );
  }
}