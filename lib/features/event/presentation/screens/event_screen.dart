import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/network/supabase_client.dart';

class EventsScreen extends StatefulWidget {
  const EventsScreen({super.key});

  @override
  State<EventsScreen> createState() => _EventsScreenState();
}

class _EventsScreenState extends State<EventsScreen> {
  final SupabaseClient _client = SupabaseConfig.client;

  List<Map<String, dynamic>> _events = [];
  bool _loading = true;
  bool _saving = false;
  String _search = '';

  int? _schoolId;

  @override
  void initState() {
    super.initState();
    _loadEvents();
  }

  // ------------------------------------------------------------
  // SCHOOL ID
  // ------------------------------------------------------------

  Future<int?> _getSchoolId() async {
    try {
      final result = await _client.rpc('get_my_school_id');

      if (result is int) return result;
      if (result is num) return result.toInt();

      return int.tryParse(result?.toString() ?? '');
    } catch (e) {
      debugPrint('get_my_school_id error: $e');
      return null;
    }
  }

  // ------------------------------------------------------------
  // LOAD EVENTS
  // ------------------------------------------------------------

  Future<void> _loadEvents() async {
    if (mounted) {
      setState(() => _loading = true);
    }

    try {
      final schoolId = await _getSchoolId();

      if (schoolId == null) {
        throw Exception(
          'Your account is not linked to a school.',
        );
      }

      final response = await _client
          .from('events')
          .select(
        'id, school_id, title, description, event_date, '
            'start_time, end_time, location, status, created_by, created_at',
      )
          .eq('school_id', schoolId)
          .order('event_date', ascending: false)
          .order('start_time', ascending: true);

      if (!mounted) return;

      setState(() {
        _schoolId = schoolId;
        _events = List<Map<String, dynamic>>.from(response);
        _loading = false;
      });
    } on PostgrestException catch (e) {
      debugPrint('Events database error: ${e.message}');

      if (!mounted) return;

      setState(() => _loading = false);

      _showError(e.message);
    } catch (e) {
      debugPrint('Events load error: $e');

      if (!mounted) return;

      setState(() => _loading = false);

      _showError(
        e.toString().replaceFirst('Exception: ', ''),
      );
    }
  }

  // ------------------------------------------------------------
  // ADD / EDIT EVENT
  // ------------------------------------------------------------

  Future<void> _openEventDialog({
    Map<String, dynamic>? event,
  }) async {
    final titleController = TextEditingController(
      text: event?['title']?.toString() ?? '',
    );

    final descriptionController = TextEditingController(
      text: event?['description']?.toString() ?? '',
    );

    final locationController = TextEditingController(
      text: event?['location']?.toString() ?? '',
    );

    DateTime selectedDate = event?['event_date'] != null
        ? DateTime.tryParse(
      event!['event_date'].toString(),
    ) ??
        DateTime.now()
        : DateTime.now();

    TimeOfDay? startTime = _parseTime(
      event?['start_time']?.toString(),
    );

    TimeOfDay? endTime = _parseTime(
      event?['end_time']?.toString(),
    );

    String status =
        event?['status']?.toString() ?? 'active';

    final isEditing = event != null;

    await showDialog(
      context: context,
      barrierDismissible: !_saving,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text(
                isEditing ? 'Edit Event' : 'Add New Event',
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                ),
              ),
              content: SizedBox(
                width: 500,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextField(
                        controller: titleController,
                        textCapitalization:
                        TextCapitalization.sentences,
                        decoration: const InputDecoration(
                          labelText: 'Event Title',
                          prefixIcon:
                          Icon(Icons.event_outlined),
                        ),
                      ),
                      const SizedBox(height: 14),

                      TextField(
                        controller: descriptionController,
                        maxLines: 3,
                        textCapitalization:
                        TextCapitalization.sentences,
                        decoration: const InputDecoration(
                          labelText: 'Description',
                          prefixIcon:
                          Icon(Icons.description_outlined),
                        ),
                      ),
                      const SizedBox(height: 14),

                      InkWell(
                        onTap: () async {
                          final picked =
                          await showDatePicker(
                            context: context,
                            initialDate: selectedDate,
                            firstDate: DateTime(2020),
                            lastDate: DateTime(2100),
                          );

                          if (picked != null) {
                            setDialogState(() {
                              selectedDate = picked;
                            });
                          }
                        },
                        child: InputDecorator(
                          decoration:
                          const InputDecoration(
                            labelText: 'Event Date',
                            prefixIcon:
                            Icon(Icons.calendar_month),
                          ),
                          child: Text(
                            _formatDate(selectedDate),
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),

                      Row(
                        children: [
                          Expanded(
                            child: InkWell(
                              onTap: () async {
                                final picked =
                                await showTimePicker(
                                  context: context,
                                  initialTime:
                                  startTime ??
                                      TimeOfDay.now(),
                                );

                                if (picked != null) {
                                  setDialogState(() {
                                    startTime = picked;
                                  });
                                }
                              },
                              child: InputDecorator(
                                decoration:
                                const InputDecoration(
                                  labelText: 'Start Time',
                                  prefixIcon:
                                  Icon(Icons.access_time),
                                ),
                                child: Text(
                                  startTime == null
                                      ? 'Select'
                                      : startTime!
                                      .format(context),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: InkWell(
                              onTap: () async {
                                final picked =
                                await showTimePicker(
                                  context: context,
                                  initialTime:
                                  endTime ??
                                      TimeOfDay.now(),
                                );

                                if (picked != null) {
                                  setDialogState(() {
                                    endTime = picked;
                                  });
                                }
                              },
                              child: InputDecorator(
                                decoration:
                                const InputDecoration(
                                  labelText: 'End Time',
                                  prefixIcon:
                                  Icon(Icons.access_time),
                                ),
                                child: Text(
                                  endTime == null
                                      ? 'Select'
                                      : endTime!
                                      .format(context),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),

                      TextField(
                        controller: locationController,
                        textCapitalization:
                        TextCapitalization.words,
                        decoration: const InputDecoration(
                          labelText: 'Location',
                          prefixIcon:
                          Icon(Icons.location_on_outlined),
                        ),
                      ),
                      const SizedBox(height: 14),

                      DropdownButtonFormField<String>(
                        value: status,
                        decoration:
                        const InputDecoration(
                          labelText: 'Status',
                          prefixIcon:
                          Icon(Icons.flag_outlined),
                        ),
                        items: const [
                          DropdownMenuItem(
                            value: 'active',
                            child: Text('Active'),
                          ),
                          DropdownMenuItem(
                            value: 'completed',
                            child: Text('Completed'),
                          ),
                          DropdownMenuItem(
                            value: 'cancelled',
                            child: Text('Cancelled'),
                          ),
                        ],
                        onChanged: (value) {
                          if (value == null) return;

                          setDialogState(() {
                            status = value;
                          });
                        },
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
                    Navigator.pop(dialogContext);
                  },
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: _saving
                      ? null
                      : () async {
                    final title =
                    titleController.text.trim();

                    if (title.isEmpty) {
                      _showError(
                        'Event title is required.',
                      );
                      return;
                    }

                    setDialogState(() {
                      _saving = true;
                    });

                    try {
                      await _saveEvent(
                        event: event,
                        title: title,
                        description:
                        descriptionController
                            .text
                            .trim(),
                        location:
                        locationController.text
                            .trim(),
                        date: selectedDate,
                        startTime: startTime,
                        endTime: endTime,
                        status: status,
                      );

                      if (!mounted) return;

                      Navigator.pop(dialogContext);
                    } catch (e) {
                      if (!mounted) return;

                      setDialogState(() {
                        _saving = false;
                      });

                      _showError(
                        e.toString().replaceFirst(
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
                      color: Colors.white,
                    ),
                  )
                      : Text(
                    isEditing ? 'Update' : 'Save',
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
    locationController.dispose();
  }

  // ------------------------------------------------------------
  // SAVE EVENT
  // ------------------------------------------------------------

  Future<void> _saveEvent({
    Map<String, dynamic>? event,
    required String title,
    required String description,
    required String location,
    required DateTime date,
    required TimeOfDay? startTime,
    required TimeOfDay? endTime,
    required String status,
  }) async {
    final schoolId = _schoolId ?? await _getSchoolId();

    if (schoolId == null) {
      throw Exception(
        'Your account is not linked to a school.',
      );
    }

    final start = startTime == null
        ? null
        : _timeToString(startTime);

    final end = endTime == null
        ? null
        : _timeToString(endTime);

    final data = <String, dynamic>{
      'school_id': schoolId,
      'title': title,
      'description':
      description.isEmpty ? null : description,
      'event_date': _dateToString(date),
      'start_time': start,
      'end_time': end,
      'location': location.isEmpty ? null : location,
      'status': status,
    };

    if (event == null) {
      data['created_by'] =
          _client.auth.currentUser?.id;

      await _client
          .from('events')
          .insert(data);
    } else {
      await _client
          .from('events')
          .update(data)
          .eq('id', event['id'])
          .eq('school_id', schoolId);
    }

    if (!mounted) return;

    setState(() {
      _saving = false;
    });

    await _loadEvents();

    if (!mounted) return;

    _showSuccess(
      event == null
          ? 'Event added successfully.'
          : 'Event updated successfully.',
    );
  }

  // ------------------------------------------------------------
  // DELETE
  // ------------------------------------------------------------

  Future<void> _deleteEvent(
      Map<String, dynamic> event,
      ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text(
            'Delete Event?',
            style: TextStyle(
              fontWeight: FontWeight.w800,
            ),
          ),
          content: Text(
            'Are you sure you want to delete '
                '"${event['title']}"?',
          ),
          actions: [
            TextButton(
              onPressed: () =>
                  Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.error,
              ),
              onPressed: () =>
                  Navigator.pop(context, true),
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );

    if (confirmed != true) return;

    try {
      final schoolId =
          _schoolId ?? await _getSchoolId();

      if (schoolId == null) {
        throw Exception(
          'Your account is not linked to a school.',
        );
      }

      await _client
          .from('events')
          .delete()
          .eq('id', event['id'])
          .eq('school_id', schoolId);

      await _loadEvents();

      if (!mounted) return;

      _showSuccess(
        'Event deleted successfully.',
      );
    } on PostgrestException catch (e) {
      _showError(e.message);
    } catch (e) {
      _showError(
        e.toString().replaceFirst(
          'Exception: ',
          '',
        ),
      );
    }
  }

  // ------------------------------------------------------------
  // SEARCH
  // ------------------------------------------------------------

  List<Map<String, dynamic>> get _filteredEvents {
    final query = _search.trim().toLowerCase();

    if (query.isEmpty) {
      return _events;
    }

    return _events.where((event) {
      final title =
          event['title']?.toString().toLowerCase() ?? '';

      final description =
          event['description']?.toString().toLowerCase() ??
              '';

      final location =
          event['location']?.toString().toLowerCase() ?? '';

      return title.contains(query) ||
          description.contains(query) ||
          location.contains(query);
    }).toList();
  }

  // ------------------------------------------------------------
  // HELPERS
  // ------------------------------------------------------------

  TimeOfDay? _parseTime(String? value) {
    if (value == null || value.isEmpty) {
      return null;
    }

    final parts = value.split(':');

    if (parts.length < 2) {
      return null;
    }

    final hour = int.tryParse(parts[0]);
    final minute = int.tryParse(parts[1]);

    if (hour == null || minute == null) {
      return null;
    }

    return TimeOfDay(
      hour: hour,
      minute: minute,
    );
  }

  String _timeToString(TimeOfDay time) {
    final hour =
    time.hour.toString().padLeft(2, '0');

    final minute =
    time.minute.toString().padLeft(2, '0');

    return '$hour:$minute:00';
  }

  String _dateToString(DateTime date) {
    final year = date.year.toString().padLeft(4, '0');
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');

    return '$year-$month-$day';
  }

  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}/'
        '${date.month.toString().padLeft(2, '0')}/'
        '${date.year}';
  }

  String _displayDate(dynamic value) {
    if (value == null) return '-';

    final date = DateTime.tryParse(
      value.toString(),
    );

    if (date == null) {
      return value.toString();
    }

    return _formatDate(date);
  }

  String _displayTime(
      dynamic start,
      dynamic end,
      ) {
    final s = _parseTime(start?.toString());
    final e = _parseTime(end?.toString());

    if (s == null && e == null) {
      return 'Time not set';
    }

    if (s != null && e != null) {
      return '${s.format(context)} - ${e.format(context)}';
    }

    return s?.format(context) ??
        e?.format(context) ??
        'Time not set';
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'completed':
        return AppColors.success;

      case 'cancelled':
        return AppColors.error;

      default:
        return AppColors.primary;
    }
  }

  String _statusLabel(String status) {
    switch (status) {
      case 'completed':
        return 'COMPLETED';

      case 'cancelled':
        return 'CANCELLED';

      default:
        return 'ACTIVE';
    }
  }

  void _showSuccess(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: AppColors.success,
        ),
      );
  }

  void _showError(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: AppColors.error,
        ),
      );
  }

  // ------------------------------------------------------------
  // UI
  // ------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final events = _filteredEvents;

    final activeCount = _events
        .where(
          (e) => e['status'] == 'active',
    )
        .length;

    final completedCount = _events
        .where(
          (e) => e['status'] == 'completed',
    )
        .length;

    final cancelledCount = _events
        .where(
          (e) => e['status'] == 'cancelled',
    )
        .length;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: RefreshIndicator(
        onRefresh: _loadEvents,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(
                24,
                28,
                24,
                10,
              ),
              sliver: SliverToBoxAdapter(
                child: _buildHeader(),
              ),
            ),

            SliverPadding(
              padding: const EdgeInsets.symmetric(
                horizontal: 24,
              ),
              sliver: SliverToBoxAdapter(
                child: _buildMetrics(
                  activeCount,
                  completedCount,
                  cancelledCount,
                ),
              ),
            ),

            SliverPadding(
              padding: const EdgeInsets.fromLTRB(
                24,
                24,
                24,
                10,
              ),
              sliver: SliverToBoxAdapter(
                child: _buildSearch(),
              ),
            ),

            if (_loading)
              const SliverFillRemaining(
                hasScrollBody: false,
                child: Center(
                  child: CircularProgressIndicator(),
                ),
              )
            else if (events.isEmpty)
              SliverFillRemaining(
                hasScrollBody: false,
                child: _buildEmptyState(),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(
                  24,
                  12,
                  24,
                  40,
                ),
                sliver: SliverList.builder(
                  itemCount: events.length,
                  itemBuilder: (context, index) {
                    return _buildEventCard(
                      events[index],
                    );
                  },
                ),
              ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _loading
            ? null
            : () => _openEventDialog(),
        icon: const Icon(Icons.add_rounded),
        label: const Text('Add Event'),
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Expanded(
          child: Column(
            crossAxisAlignment:
            CrossAxisAlignment.start,
            children: [
              Text(
                'Events',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.7,
                ),
              ),
              SizedBox(height: 6),
              Text(
                'Plan school events, activities and important dates.',
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
        IconButton(
          tooltip: 'Refresh',
          onPressed: _loadEvents,
          icon: const Icon(
            Icons.refresh_rounded,
          ),
        ),
      ],
    );
  }

  Widget _buildMetrics(
      int active,
      int completed,
      int cancelled,
      ) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 800;

        final cards = [
          _metricCard(
            'Total',
            _events.length.toString(),
            'All events',
            Icons.event_rounded,
            AppColors.primary,
          ),
          _metricCard(
            'Active',
            active.toString(),
            'Upcoming / active',
            Icons.check_circle_outline_rounded,
            AppColors.success,
          ),
          _metricCard(
            'Completed',
            completed.toString(),
            'Finished',
            Icons.task_alt_rounded,
            const Color(0xFF2563EB),
          ),
          _metricCard(
            'Cancelled',
            cancelled.toString(),
            'Cancelled events',
            Icons.cancel_outlined,
            AppColors.error,
          ),
        ];

        if (wide) {
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
          spacing: 14,
          runSpacing: 14,
          children: cards
              .map(
                (card) => SizedBox(
              width:
              (constraints.maxWidth - 14) / 2,
              child: card,
            ),
          )
              .toList(),
        );
      },
    );
  }

  Widget _metricCard(
      String title,
      String value,
      String subtitle,
      IconData icon,
      Color color,
      ) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Row(
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: color.withOpacity(.10),
                borderRadius:
                BorderRadius.circular(14),
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
                  const SizedBox(height: 2),
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

  Widget _buildSearch() {
    return TextField(
      onChanged: (value) {
        setState(() {
          _search = value;
        });
      },
      decoration: InputDecoration(
        hintText:
        'Search events, location or description...',
        prefixIcon:
        const Icon(Icons.search_rounded),
        suffixIcon: _search.isNotEmpty
            ? IconButton(
          onPressed: () {
            setState(() {
              _search = '';
            });
          },
          icon: const Icon(
            Icons.clear_rounded,
          ),
        )
            : null,
      ),
    );
  }

  Widget _buildEventCard(
      Map<String, dynamic> event,
      ) {
    final status =
        event['status']?.toString() ?? 'active';

    final statusColor = _statusColor(status);

    return Card(
      margin: const EdgeInsets.only(bottom: 14),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Row(
          crossAxisAlignment:
          CrossAxisAlignment.start,
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: AppColors.primary
                    .withOpacity(.10),
                borderRadius:
                BorderRadius.circular(16),
              ),
              child: const Icon(
                Icons.event_rounded,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment:
                CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          event['title']
                              ?.toString() ??
                              'Untitled Event',
                          style:
                          const TextStyle(
                            fontSize: 16,
                            fontWeight:
                            FontWeight.w800,
                          ),
                        ),
                      ),
                      Container(
                        padding:
                        const EdgeInsets
                            .symmetric(
                          horizontal: 8,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: statusColor
                              .withOpacity(.10),
                          borderRadius:
                          BorderRadius
                              .circular(20),
                        ),
                        child: Text(
                          _statusLabel(status),
                          style: TextStyle(
                            color: statusColor,
                            fontSize: 9,
                            fontWeight:
                            FontWeight.w900,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  if (event['description'] != null &&
                      event['description']
                          .toString()
                          .trim()
                          .isNotEmpty)
                    Padding(
                      padding:
                      const EdgeInsets.only(
                        bottom: 8,
                      ),
                      child: Text(
                        event['description']
                            .toString(),
                        maxLines: 2,
                        overflow:
                        TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: AppColors
                              .textSecondary,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  Wrap(
                    spacing: 16,
                    runSpacing: 8,
                    children: [
                      _eventInfo(
                        Icons.calendar_today_outlined,
                        _displayDate(
                          event['event_date'],
                        ),
                      ),
                      _eventInfo(
                        Icons.access_time_rounded,
                        _displayTime(
                          event['start_time'],
                          event['end_time'],
                        ),
                      ),
                      if (event['location'] != null &&
                          event['location']
                              .toString()
                              .trim()
                              .isNotEmpty)
                        _eventInfo(
                          Icons.location_on_outlined,
                          event['location']
                              .toString(),
                        ),
                    ],
                  ),
                ],
              ),
            ),
            PopupMenuButton<String>(
              onSelected: (value) {
                if (value == 'edit') {
                  _openEventDialog(
                    event: event,
                  );
                } else if (value == 'delete') {
                  _deleteEvent(event);
                }
              },
              itemBuilder: (context) => const [
                PopupMenuItem(
                  value: 'edit',
                  child: ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading:
                    Icon(Icons.edit_outlined),
                    title: Text('Edit'),
                  ),
                ),
                PopupMenuItem(
                  value: 'delete',
                  child: ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading:
                    Icon(Icons.delete_outline),
                    title: Text('Delete'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _eventInfo(
      IconData icon,
      String text,
      ) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          icon,
          size: 14,
          color: AppColors.textSecondary,
        ),
        const SizedBox(width: 5),
        Text(
          text,
          style: TextStyle(
            fontSize: 11,
            color: AppColors.textSecondary,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyState() {
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
                Icons.event_busy_rounded,
                size: 38,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(height: 18),
            Text(
              _search.isEmpty
                  ? 'No events yet'
                  : 'No matching events',
              style: const TextStyle(
                fontSize: 19,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 7),
            Text(
              _search.isEmpty
                  ? 'Create your first school event.'
                  : 'Try another search term.',
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 12,
              ),
            ),
            if (_search.isEmpty) ...[
              const SizedBox(height: 18),
              FilledButton.icon(
                onPressed: () =>
                    _openEventDialog(),
                icon: const Icon(
                  Icons.add_rounded,
                ),
                label: const Text(
                  'Create Event',
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}