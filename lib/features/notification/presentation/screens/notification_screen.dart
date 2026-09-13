import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/network/supabase_client.dart';
import '../../../../core/widgets/main_wrapper.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() =>
      _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  final _client = SupabaseConfig.client;

  bool _loading = true;
  bool _saving = false;
  String? _error;

  List<Map<String, dynamic>> _notifications = [];

  @override
  void initState() {
    super.initState();
    _loadNotifications();
  }

  Future<int?> _getSchoolId() async {
    final userId = _client.auth.currentUser?.id;

    if (userId == null) {
      return null;
    }

    try {
      final profile = await _client
          .from('profiles')
          .select('school_id')
          .eq('id', userId)
          .maybeSingle();

      final value = profile?['school_id'];

      final profileSchoolId = value is int
          ? value
          : int.tryParse(value?.toString() ?? '');

      if (profileSchoolId != null) {
        return profileSchoolId;
      }
    } catch (_) {}

    try {
      final school = await _client
          .from('schools')
          .select('id')
          .eq('principal_id', userId)
          .maybeSingle();

      final value = school?['id'];

      final schoolId = value is int
          ? value
          : int.tryParse(value?.toString() ?? '');

      if (schoolId == null) {
        return null;
      }

      try {
        await _client
            .from('profiles')
            .update({
          'school_id': schoolId,
        }).eq(
          'id',
          userId,
        );
      } catch (_) {}

      return schoolId;
    } catch (_) {
      return null;
    }
  }

  Future<void> _loadNotifications() async {
    if (!mounted) return;

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final schoolId = await _getSchoolId();

      if (schoolId == null) {
        throw Exception(
          'Your account is not linked to a school.',
        );
      }

      await _removeExpiredNotifications(schoolId);

      final now =
      DateTime.now().toUtc().toIso8601String();

      final response = await _client
          .from('notifications')
          .select(
        'id, school_id, title, description, category, '
            'message, type, is_active, is_read, created_by, '
            'created_at, updated_at, starts_at, expires_at',
      )
          .eq(
        'school_id',
        schoolId,
      )
          .eq(
        'is_active',
        true,
      )
          .lte(
        'starts_at',
        now,
      )
          .or(
        'expires_at.is.null,expires_at.gt.$now',
      )
          .order(
        'created_at',
        ascending: false,
      );

      if (!mounted) return;

      setState(() {
        _notifications =
        List<Map<String, dynamic>>.from(
          response,
        );

        _loading = false;
      });
    } on PostgrestException catch (e) {
      if (!mounted) return;

      setState(() {
        _error =
        '${e.message}\n\nCode: ${e.code ?? 'unknown'}';
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

  Future<void> _removeExpiredNotifications(
      int schoolId,
      ) async {
    try {
      final now =
      DateTime.now().toUtc().toIso8601String();

      await _client
          .from('notifications')
          .delete()
          .eq(
        'school_id',
        schoolId,
      )
          .not(
        'expires_at',
        'is',
        null,
      )
          .lte(
        'expires_at',
        now,
      );
    } catch (_) {}
  }

  Future<void> _addNotification() async {
    final titleController =
    TextEditingController();

    final messageController =
    TextEditingController();

    String type = 'general';
    String duration = '1 Day';

    DateTime? customExpiry;

    try {
      final saved =
      await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) {
          return StatefulBuilder(
            builder: (
                context,
                setDialogState,
                ) {
              return AlertDialog(
                title: const Text(
                  'Add Notification',
                ),
                content: SizedBox(
                  width: 480,
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize:
                      MainAxisSize.min,
                      children: [
                        TextField(
                          controller:
                          titleController,
                          textCapitalization:
                          TextCapitalization
                              .sentences,
                          decoration:
                          const InputDecoration(
                            labelText:
                            'Title',
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
                        TextField(
                          controller:
                          messageController,
                          maxLines: 4,
                          textCapitalization:
                          TextCapitalization
                              .sentences,
                          decoration:
                          const InputDecoration(
                            labelText:
                            'Message',
                            alignLabelWithHint:
                            true,
                            prefixIcon:
                            Icon(
                              Icons
                                  .message_outlined,
                            ),
                          ),
                        ),
                        const SizedBox(
                          height: 14,
                        ),
                        DropdownButtonFormField<
                            String>(
                          initialValue: type,
                          decoration:
                          const InputDecoration(
                            labelText:
                            'Notification Type',
                            prefixIcon:
                            Icon(
                              Icons
                                  .category_outlined,
                            ),
                          ),
                          items: const [
                            DropdownMenuItem(
                              value:
                              'general',
                              child:
                              Text(
                                'General',
                              ),
                            ),
                            DropdownMenuItem(
                              value:
                              'fee',
                              child:
                              Text(
                                'Fee',
                              ),
                            ),
                            DropdownMenuItem(
                              value:
                              'attendance',
                              child:
                              Text(
                                'Attendance',
                              ),
                            ),
                            DropdownMenuItem(
                              value:
                              'academic',
                              child:
                              Text(
                                'Academic',
                              ),
                            ),
                            DropdownMenuItem(
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
                            if (value == null) {
                              return;
                            }

                            setDialogState(() {
                              type = value;
                            });
                          },
                        ),
                        const SizedBox(
                          height: 14,
                        ),
                        DropdownButtonFormField<
                            String>(
                          initialValue: duration,
                          decoration:
                          const InputDecoration(
                            labelText:
                            'Show Notification For',
                            prefixIcon:
                            Icon(
                              Icons
                                  .schedule_outlined,
                            ),
                          ),
                          items: const [
                            DropdownMenuItem(
                              value:
                              '1 Hour',
                              child:
                              Text(
                                '1 Hour',
                              ),
                            ),
                            DropdownMenuItem(
                              value:
                              '6 Hours',
                              child:
                              Text(
                                '6 Hours',
                              ),
                            ),
                            DropdownMenuItem(
                              value:
                              '1 Day',
                              child:
                              Text(
                                '1 Day',
                              ),
                            ),
                            DropdownMenuItem(
                              value:
                              '3 Days',
                              child:
                              Text(
                                '3 Days',
                              ),
                            ),
                            DropdownMenuItem(
                              value:
                              '7 Days',
                              child:
                              Text(
                                '7 Days',
                              ),
                            ),
                            DropdownMenuItem(
                              value:
                              '30 Days',
                              child:
                              Text(
                                '30 Days',
                              ),
                            ),
                            DropdownMenuItem(
                              value:
                              'Custom',
                              child:
                              Text(
                                'Custom Date & Time',
                              ),
                            ),
                          ],
                          onChanged:
                              (value) async {
                            if (value == null) {
                              return;
                            }

                            setDialogState(() {
                              duration = value;
                            });

                            if (value !=
                                'Custom') {
                              return;
                            }

                            final selectedDate =
                            await showDatePicker(
                              context:
                              dialogContext,
                              initialDate:
                              DateTime.now()
                                  .add(
                                const Duration(
                                  days: 1,
                                ),
                              ),
                              firstDate:
                              DateTime.now(),
                              lastDate:
                              DateTime.now()
                                  .add(
                                const Duration(
                                  days: 3650,
                                ),
                              ),
                            );

                            if (selectedDate ==
                                null) {
                              setDialogState(() {
                                duration =
                                '1 Day';
                                customExpiry =
                                null;
                              });
                              return;
                            }

                            if (!dialogContext
                                .mounted) {
                              return;
                            }

                            final selectedTime =
                            await showTimePicker(
                              context:
                              dialogContext,
                              initialTime:
                              TimeOfDay.now(),
                            );

                            if (selectedTime ==
                                null) {
                              setDialogState(() {
                                duration =
                                '1 Day';
                                customExpiry =
                                null;
                              });
                              return;
                            }

                            final selected =
                            DateTime(
                              selectedDate.year,
                              selectedDate.month,
                              selectedDate.day,
                              selectedTime.hour,
                              selectedTime.minute,
                            );

                            if (selected
                                .isBefore(
                              DateTime.now(),
                            )) {
                              setDialogState(() {
                                duration =
                                '1 Day';
                                customExpiry =
                                null;
                              });

                              if (!dialogContext
                                  .mounted) {
                                return;
                              }

                              ScaffoldMessenger
                                  .of(
                                dialogContext,
                              ).showSnackBar(
                                const SnackBar(
                                  content:
                                  Text(
                                    'Expiry time must be in the future.',
                                  ),
                                ),
                              );

                              return;
                            }

                            setDialogState(() {
                              customExpiry =
                                  selected;
                            });
                          },
                        ),
                        if (duration ==
                            'Custom' &&
                            customExpiry !=
                                null) ...[
                          const SizedBox(
                            height: 10,
                          ),
                          Align(
                            alignment:
                            Alignment.centerLeft,
                            child: Text(
                              'Expires: ${_formatDateTime(customExpiry!)}',
                              style:
                              const TextStyle(
                                color:
                                AppColors
                                    .primary,
                                fontWeight:
                                FontWeight.w700,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ],
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
                        false,
                      );
                    },
                    child:
                    const Text(
                      'Cancel',
                    ),
                  ),
                  FilledButton(
                    onPressed: _saving
                        ? null
                        : () async {
                      final title =
                      titleController
                          .text
                          .trim();

                      final message =
                      messageController
                          .text
                          .trim();

                      if (title.isEmpty ||
                          message.isEmpty) {
                        ScaffoldMessenger
                            .of(
                          dialogContext,
                        ).showSnackBar(
                          const SnackBar(
                            content:
                            Text(
                              'Title and message are required.',
                            ),
                          ),
                        );
                        return;
                      }

                      setDialogState(() {
                        _saving = true;
                      });

                      try {
                        final schoolId =
                        await _getSchoolId();

                        if (schoolId ==
                            null) {
                          throw Exception(
                            'Your account is not linked to a school.',
                          );
                        }

                        final userId =
                            _client
                                .auth
                                .currentUser
                                ?.id;

                        if (userId == null) {
                          throw Exception(
                            'No authenticated user found.',
                          );
                        }

                        final startsAt =
                        DateTime.now()
                            .toUtc();

                        late DateTime
                        expiresAt;

                        switch (duration) {
                          case '1 Hour':
                            expiresAt =
                                startsAt.add(
                                  const Duration(
                                    hours: 1,
                                  ),
                                );
                            break;

                          case '6 Hours':
                            expiresAt =
                                startsAt.add(
                                  const Duration(
                                    hours: 6,
                                  ),
                                );
                            break;

                          case '3 Days':
                            expiresAt =
                                startsAt.add(
                                  const Duration(
                                    days: 3,
                                  ),
                                );
                            break;

                          case '7 Days':
                            expiresAt =
                                startsAt.add(
                                  const Duration(
                                    days: 7,
                                  ),
                                );
                            break;

                          case '30 Days':
                            expiresAt =
                                startsAt.add(
                                  const Duration(
                                    days: 30,
                                  ),
                                );
                            break;

                          case 'Custom':
                            if (customExpiry ==
                                null) {
                              throw Exception(
                                'Please select an expiry date and time.',
                              );
                            }

                            expiresAt =
                                customExpiry!
                                    .toUtc();
                            break;

                          case '1 Day':
                          default:
                            expiresAt =
                                startsAt.add(
                                  const Duration(
                                    days: 1,
                                  ),
                                );
                            break;
                        }

                        await _client
                            .from(
                          'notifications',
                        )
                            .insert({
                          'school_id':
                          schoolId,
                          'title':
                          title,
                          'description':
                          message,
                          'category':
                          type,
                          'message':
                          message,
                          'type':
                          type,
                          'is_active':
                          true,
                          'is_read':
                          false,
                          'created_by':
                          userId,
                          'starts_at':
                          startsAt
                              .toIso8601String(),
                          'expires_at':
                          expiresAt
                              .toIso8601String(),
                        });

                        if (!dialogContext
                            .mounted) {
                          return;
                        }

                        Navigator.pop(
                          dialogContext,
                          true,
                        );
                      } on PostgrestException
                      catch (e) {
                        if (!dialogContext
                            .mounted) {
                          return;
                        }

                        setDialogState(() {
                          _saving = false;
                        });

                        ScaffoldMessenger
                            .of(
                          dialogContext,
                        ).showSnackBar(
                          SnackBar(
                            content:
                            Text(
                              '${e.message}\nCode: ${e.code ?? 'unknown'}',
                            ),
                            backgroundColor:
                            AppColors
                                .error,
                          ),
                        );
                      } catch (e) {
                        if (!dialogContext
                            .mounted) {
                          return;
                        }

                        setDialogState(() {
                          _saving = false;
                        });

                        ScaffoldMessenger
                            .of(
                          dialogContext,
                        ).showSnackBar(
                          SnackBar(
                            content:
                            Text(
                              e.toString()
                                  .replaceFirst(
                                'Exception: ',
                                '',
                              ),
                            ),
                            backgroundColor:
                            AppColors
                                .error,
                          ),
                        );
                      }
                    },
                    child: _saving
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
                        : const Text(
                      'Send Notification',
                    ),
                  ),
                ],
              );
            },
          );
        },
      );

      if (saved == true) {
        await _loadNotifications();

        if (!mounted) return;

        ScaffoldMessenger.of(
          context,
        ).showSnackBar(
          const SnackBar(
            content: Text(
              'Notification added successfully.',
            ),
            backgroundColor:
            AppColors.success,
          ),
        );
      }
    } finally {
      titleController.dispose();
      messageController.dispose();

      if (mounted) {
        setState(() {
          _saving = false;
        });
      }
    }
  }

  Future<void> _markAsRead(
      Map<String, dynamic> notification,
      ) async {
    final isRead =
        notification['is_read'] as bool? ??
            false;

    if (isRead) {
      return;
    }

    try {
      await _client
          .from('notifications')
          .update({
        'is_read': true,
      }).eq(
        'id',
        notification['id'],
      );

      if (!mounted) return;

      setState(() {
        notification['is_read'] = true;
      });
    } on PostgrestException catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(
        SnackBar(
          content: Text(
            '${e.message}\nCode: ${e.code ?? 'unknown'}',
          ),
          backgroundColor:
          AppColors.error,
        ),
      );
    }
  }

  Future<void> _deleteNotification(
      Map<String, dynamic> notification,
      ) async {
    final confirmed =
    await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text(
            'Delete Notification?',
          ),
          content: const Text(
            'This notification will be permanently removed.',
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
      await _client
          .from('notifications')
          .delete()
          .eq(
        'id',
        notification['id'],
      );

      await _loadNotifications();

      if (!mounted) return;

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(
        const SnackBar(
          content: Text(
            'Notification deleted.',
          ),
        ),
      );
    } on PostgrestException catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(
        SnackBar(
          content: Text(
            '${e.message}\nCode: ${e.code ?? 'unknown'}',
          ),
          backgroundColor:
          AppColors.error,
        ),
      );
    }
  }

  int get _unreadCount {
    return _notifications.where(
          (notification) {
        final isRead =
            notification['is_read'] as bool? ??
                false;

        return !isRead;
      },
    ).length;
  }

  String _formatDateTime(
      DateTime date,
      ) {
    final local = date.toLocal();

    final dateText =
    MaterialLocalizations
        .of(context)
        .formatMediumDate(local);

    final timeText =
    MaterialLocalizations
        .of(context)
        .formatTimeOfDay(
      TimeOfDay.fromDateTime(local),
    );

    return '$dateText at $timeText';
  }

  IconData _notificationIcon(
      String? type,
      ) {
    switch (type) {
      case 'fee':
        return Icons.payments_outlined;

      case 'attendance':
        return Icons.event_available_outlined;

      case 'academic':
        return Icons.school_outlined;

      case 'urgent':
        return Icons.priority_high_rounded;

      default:
        return Icons.notifications_rounded;
    }
  }

  @override
  Widget build(
      BuildContext context,
      ) {
    return MainWrapper(
      child: Column(
        children: [
          _buildHeader(),
          Expanded(
            child: RefreshIndicator(
              onRefresh:
              _loadNotifications,
              child: _buildBody(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        24,
        24,
        24,
        16,
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment:
              CrossAxisAlignment.start,
              children: [
                const Text(
                  'Notifications',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight:
                    FontWeight.w900,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(
                  height: 4,
                ),
                const Text(
                  'Stay updated with school alerts.',
                  style: TextStyle(
                    color:
                    AppColors
                        .textSecondary,
                    fontSize: 13,
                  ),
                ),
                if (!_loading &&
                    _unreadCount > 0) ...[
                  const SizedBox(
                    height: 6,
                  ),
                  Text(
                    '$_unreadCount unread',
                    style: const TextStyle(
                      color:
                      AppColors.primary,
                      fontWeight:
                      FontWeight.w700,
                      fontSize: 12,
                    ),
                  ),
                ],
              ],
            ),
          ),
          FilledButton.icon(
            onPressed:
            _loading
                ? null
                : _addNotification,
            icon: const Icon(
              Icons.add_rounded,
              size: 20,
            ),
            label: const Text(
              'Add Notification',
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(
        child:
        CircularProgressIndicator(),
      );
    }

    if (_error != null) {
      return ListView(
        physics:
        const AlwaysScrollableScrollPhysics(),
        children: [
          const SizedBox(
            height: 140,
          ),
          const Icon(
            Icons.error_outline_rounded,
            color: AppColors.error,
            size: 48,
          ),
          const SizedBox(
            height: 16,
          ),
          Center(
            child: Padding(
              padding:
              const EdgeInsets.symmetric(
                horizontal: 24,
              ),
              child: Text(
                _error!,
                textAlign:
                TextAlign.center,
              ),
            ),
          ),
          const SizedBox(
            height: 24,
          ),
          Center(
            child:
            FilledButton.tonal(
              onPressed:
              _loadNotifications,
              child:
              const Text('Retry'),
            ),
          ),
        ],
      );
    }

    if (_notifications.isEmpty) {
      return ListView(
        physics:
        const AlwaysScrollableScrollPhysics(),
        children: const [
          SizedBox(
            height: 150,
          ),
          Icon(
            Icons
                .notifications_none_rounded,
            size: 64,
            color: AppColors.border,
          ),
          SizedBox(
            height: 16,
          ),
          Center(
            child: Text(
              'No notifications',
              style: TextStyle(
                fontSize: 18,
                fontWeight:
                FontWeight.bold,
              ),
            ),
          ),
          SizedBox(
            height: 8,
          ),
          Center(
            child: Text(
              'Add your first school notification.',
              style: TextStyle(
                color:
                AppColors
                    .textSecondary,
              ),
            ),
          ),
        ],
      );
    }

    return ListView.separated(
      physics:
      const AlwaysScrollableScrollPhysics(),
      padding:
      const EdgeInsets.all(24),
      itemCount:
      _notifications.length,
      separatorBuilder:
          (_, __) =>
      const SizedBox(height: 12),
      itemBuilder:
          (context, index) {
        return _buildNotificationCard(
          _notifications[index],
        );
      },
    );
  }

  Widget _buildNotificationCard(
      Map<String, dynamic> notification,
      ) {
    final isRead =
        notification['is_read'] as bool? ??
            false;

    final unread = !isRead;

    final title =
        notification['title']
            ?.toString() ??
            'Notification';

    final message =
    notification['message']
        ?.toString()
        .trim()
        .isNotEmpty ==
        true
        ? notification['message']
        .toString()
        : notification['description']
        ?.toString() ??
        '';

    final rawType =
    notification['type']
        ?.toString();

    final type =
    rawType == null ||
        rawType.isEmpty
        ? notification['category']
        ?.toString()
        : rawType;

    DateTime? expiresAt;

    final expiresAtRaw =
    notification['expires_at'];

    if (expiresAtRaw != null) {
      expiresAt =
          DateTime.tryParse(
            expiresAtRaw.toString(),
          );
    }

    return Card(
      color: unread
          ? AppColors.primary
          .withValues(alpha: 0.02)
          : Colors.white,
      child: InkWell(
        onTap: () {
          _markAsRead(
            notification,
          );
        },
        borderRadius:
        BorderRadius.circular(20),
        child: Padding(
          padding:
          const EdgeInsets.all(16),
          child: Row(
            children: [
              CircleAvatar(
                backgroundColor:
                unread
                    ? AppColors.primary
                    : AppColors
                    .background,
                child: Icon(
                  _notificationIcon(
                    type,
                  ),
                  color: unread
                      ? Colors.white
                      : AppColors
                      .textMuted,
                  size: 20,
                ),
              ),
              const SizedBox(
                width: 14,
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment:
                  CrossAxisAlignment
                      .start,
                  children: [
                    Text(
                      title,
                      style:
                      TextStyle(
                        fontWeight:
                        unread
                            ? FontWeight
                            .w800
                            : FontWeight
                            .w600,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(
                      height: 4,
                    ),
                    Text(
                      message,
                      style:
                      const TextStyle(
                        fontSize: 13,
                        color:
                        AppColors
                            .textSecondary,
                      ),
                    ),
                    if (expiresAt !=
                        null) ...[
                      const SizedBox(
                        height: 6,
                      ),
                      Text(
                        'Expires: ${_formatDateTime(expiresAt)}',
                        style:
                        const TextStyle(
                          fontSize: 11,
                          color:
                          AppColors
                              .textMuted,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              Column(
                children: [
                  if (unread)
                    Container(
                      width: 8,
                      height: 8,
                      decoration:
                      const BoxDecoration(
                        color:
                        AppColors
                            .primary,
                        shape:
                        BoxShape
                            .circle,
                      ),
                    ),
                  PopupMenuButton<
                      String>(
                    onSelected:
                        (value) {
                      if (value ==
                          'read') {
                        _markAsRead(
                          notification,
                        );
                      }

                      if (value ==
                          'delete') {
                        _deleteNotification(
                          notification,
                        );
                      }
                    },
                    itemBuilder:
                        (_) => const [
                      PopupMenuItem(
                        value: 'read',
                        child:
                        Text(
                          'Mark as read',
                        ),
                      ),
                      PopupMenuItem(
                        value: 'delete',
                        child:
                        Text(
                          'Delete',
                        ),
                      ),
                    ],
                    child:
                    const Icon(
                      Icons
                          .more_vert_rounded,
                      color:
                      AppColors
                          .textMuted,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}