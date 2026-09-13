import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shimmer/shimmer.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/network/supabase_client.dart';
import '../../../../core/widgets/main_wrapper.dart';

class AttendanceScreen extends StatefulWidget {
  const AttendanceScreen({super.key});

  @override
  State<AttendanceScreen> createState() => _AttendanceScreenState();
}

class _AttendanceScreenState extends State<AttendanceScreen> {
  final SupabaseClient _client = SupabaseConfig.client;

  bool _loading = true;
  String? _error;

  int? _schoolId;

  List<Map<String, dynamic>> _classes = [];

  // Summary cache:
  // key = class id
  Map<String, Map<String, int>> _summaries = {};

  @override
  void initState() {
    super.initState();
    _loadClasses();
  }

  // ============================================================
  // SCHOOL ID
  // ============================================================

  Future<int?> _getSchoolId() async {
    // First use the secure RPC.
    try {
      final result =
      await _client.rpc('get_my_school_id');

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
        'get_my_school_id RPC error: $e',
      );
    }

    // Fallback to profiles.
    try {
      final userId =
          _client.auth.currentUser?.id;

      if (userId == null) {
        return null;
      }

      final profile = await _client
          .from('profiles')
          .select('school_id')
          .eq(
        'id',
        userId,
      )
          .maybeSingle();

      final value =
      profile?['school_id'];

      if (value is int) {
        return value;
      }

      final parsed = int.tryParse(
        value?.toString() ?? '',
      );

      if (parsed != null) {
        return parsed;
      }
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
      // Classes come ONLY from public.classes.
      // We do NOT create classes from students here.
      final rows = await _client
          .from('classes')
          .select(
        'id, school_id, name, section_name',
      )
          .eq(
        'school_id',
        schoolId,
      )
          .order(
        'name',
        ascending: true,
      )
          .order(
        'section_name',
        ascending: true,
      );

      final classes =
      List<Map<String, dynamic>>.from(
        rows,
      );

      // Remove any duplicate objects from the UI
      // as an additional safety layer.
      final unique = <String, Map<String, dynamic>>{};

      for (final item in classes) {
        final name =
            item['name']
                ?.toString()
                .trim()
                .toLowerCase() ??
                '';

        final section =
            item['section_name']
                ?.toString()
                .trim()
                .toLowerCase() ??
                '';

        final key =
            '$schoolId|$name|$section';

        unique[key] = item;
      }

      final result =
      unique.values.toList();

      result.sort(
            (a, b) {
          final nameA =
              a['name']
                  ?.toString()
                  .trim() ??
                  '';

          final nameB =
              b['name']
                  ?.toString()
                  .trim() ??
                  '';

          final numberA =
          _extractClassNumber(
            nameA,
          );

          final numberB =
          _extractClassNumber(
            nameB,
          );

          if (numberA != null &&
              numberB != null &&
              numberA != numberB) {
            return numberA.compareTo(
              numberB,
            );
          }

          final nameCompare =
          nameA.toLowerCase().compareTo(
            nameB.toLowerCase(),
          );

          if (nameCompare != 0) {
            return nameCompare;
          }

          final sectionA =
              a['section_name']
                  ?.toString()
                  .trim() ??
                  '';

          final sectionB =
              b['section_name']
                  ?.toString()
                  .trim() ??
                  '';

          return sectionA
              .toLowerCase()
              .compareTo(
            sectionB.toLowerCase(),
          );
        },
      );

      if (!mounted) return;

      setState(() {
        _classes = result;
        _loading = false;
        _summaries = {};
      });

      // Load today's summary.
      await _loadAllSummaries();
    } on PostgrestException catch (e) {
      debugPrint(
        'Attendance classes error: ${e.message}',
      );

      if (!mounted) return;

      setState(() {
        _error =
        '${e.message}\n\nCode: ${e.code ?? 'unknown'}';
        _loading = false;
      });
    } catch (e) {
      debugPrint(
        'Attendance classes error: $e',
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
  // CLASS NUMBER
  // ============================================================

  int? _extractClassNumber(
      String value,
      ) {
    final match = RegExp(
      r'\d+',
    ).firstMatch(value);

    if (match == null) {
      return null;
    }

    return int.tryParse(
      match.group(0)!,
    );
  }

  // ============================================================
  // DISPLAY CLASS NAME
  // ============================================================

  String _displayClassName(
      String name,
      ) {
    final clean =
    name.trim();

    if (clean.isEmpty) {
      return 'Class';
    }

    if (clean.toLowerCase().startsWith(
      'class ',
    )) {
      return clean;
    }

    return 'Class $clean';
  }

  // ============================================================
  // TODAY
  // ============================================================

  String _todayKey() {
    final now =
    DateTime.now();

    return '${now.year}-'
        '${now.month.toString().padLeft(2, '0')}-'
        '${now.day.toString().padLeft(2, '0')}';
  }

  // ============================================================
  // LOAD ALL TODAY SUMMARIES
  // ============================================================

  Future<void> _loadAllSummaries() async {
    if (_schoolId == null ||
        _classes.isEmpty) {
      return;
    }

    try {
      final today =
      _todayKey();

      final rows = await _client
          .from('attendance')
          .select(
        'student_id, status',
      )
          .eq(
        'school_id',
        _schoolId!,
      )
          .eq(
        'attendance_date',
        today,
      );

      final attendance =
      List<Map<String, dynamic>>.from(
        rows,
      );

      // Student IDs that have today's attendance.
      final studentIds =
      attendance
          .map(
            (row) =>
            row['student_id']
                .toString(),
      )
          .toSet();

      if (studentIds.isEmpty) {
        if (!mounted) return;

        setState(() {
          _summaries = {};
        });

        return;
      }

      // Load students so we can associate attendance
      // records with their class + section.
      final studentRows =
      await _client
          .from('students')
          .select(
        'id, class_name, section_name',
      )
          .eq(
        'school_id',
        _schoolId!,
      )
          .eq(
        'is_active',
        true,
      );

      final students =
      List<Map<String, dynamic>>.from(
        studentRows,
      );

      final studentMap =
      <String, Map<String, dynamic>>{};

      for (final student in students) {
        studentMap[
        student['id'].toString()] =
            student;
      }

      final summary =
      <String, Map<String, int>>{};

      for (final row in attendance) {
        final studentId =
        row['student_id']
            .toString();

        final student =
        studentMap[studentId];

        if (student == null) {
          continue;
        }

        final className =
            student['class_name']
                ?.toString()
                .trim() ??
                '';

        final section =
            student['section_name']
                ?.toString()
                .trim()
                .toLowerCase() ??
                '';

        final key =
        _classKey(
          className,
          section,
        );

        summary.putIfAbsent(
          key,
              () => {
            'present': 0,
            'absent': 0,
            'late': 0,
            'leave': 0,
          },
        );

        final status =
            row['status']
                ?.toString()
                .toLowerCase() ??
                '';

        if (status == 'present') {
          summary[key]!['present'] =
              summary[key]!['present']! +
                  1;
        } else if (status == 'absent') {
          summary[key]!['absent'] =
              summary[key]!['absent']! +
                  1;
        } else if (status == 'late') {
          summary[key]!['late'] =
              summary[key]!['late']! +
                  1;
        } else if (status == 'leave') {
          summary[key]!['leave'] =
              summary[key]!['leave']! +
                  1;
        }
      }

      if (!mounted) return;

      setState(() {
        _summaries = summary;
      });
    } catch (e) {
      debugPrint(
        'Summary error: $e',
      );
    }
  }

  String _classKey(
      String className,
      String section,
      ) {
    return '${className.trim().toLowerCase()}|'
        '${section.trim().toLowerCase()}';
  }

  // ============================================================
  // CLASS STUDENT COUNT
  // ============================================================

  Future<int> _getStudentCount(
      Map<String, dynamic> classItem,
      ) async {
    if (_schoolId == null) {
      return 0;
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
      return 0;
    }

    try {
      var query = _client
          .from('students')
          .select('id')
          .eq(
        'school_id',
        _schoolId!,
      )
          .eq(
        'is_active',
        true,
      )
          .ilike(
        'class_name',
        className,
      );

      final rows =
      section.isEmpty
          ? await query.isFilter(
        'section_name',
        null,
      )
          : await query.ilike(
        'section_name',
        section,
      );

      return (rows as List).length;
    } catch (e) {
      debugPrint(
        'Student count error: $e',
      );
      return 0;
    }
  }

  // ============================================================
  // OPEN CLASS
  // ============================================================

  Future<void> _openClass(
      Map<String, dynamic> classItem,
      ) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) =>
            ClassAttendanceScreen(
              classItem: classItem,
            ),
      ),
    );

    if (!mounted) return;

    await _loadClasses();
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
          Padding(
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
                        'Attendance',
                        style:
                        TextStyle(
                          fontSize: 26,
                          fontWeight:
                          FontWeight.w900,
                        ),
                      ),
                      SizedBox(
                        height: 4,
                      ),
                      Text(
                        'Select a class to open its attendance register.',
                        style:
                        TextStyle(
                          color:
                          AppColors
                              .textSecondary,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed:
                  _loadClasses,
                  icon:
                  const Icon(
                    Icons
                        .refresh_rounded,
                  ),
                  tooltip:
                  'Refresh',
                ),
              ],
            ),
          ),
          Expanded(
            child: _loading
                ? _buildShimmer()
                : _error != null
                ? _buildError()
                : _classes.isEmpty
                ? _buildEmpty()
                : RefreshIndicator(
              onRefresh:
              _loadClasses,
              child:
              ListView
                  .separated(
                physics:
                const AlwaysScrollableScrollPhysics(),
                padding:
                const EdgeInsets.fromLTRB(
                  24,
                  12,
                  24,
                  24,
                ),
                itemCount:
                _classes.length,
                separatorBuilder:
                    (_, __) =>
                const SizedBox(
                  height: 12,
                ),
                itemBuilder:
                    (
                    context,
                    index,
                    ) {
                  final item =
                  _classes[index];

                  return _ClassCard(
                    classItem:
                    item,
                    summary:
                    _summaries[
                    _classKey(
                      item['name']
                          ?.toString() ??
                          '',
                      item['section_name']
                          ?.toString() ??
                          '',
                    )],
                    getStudentCount:
                        () =>
                        _getStudentCount(
                          item,
                        ),
                    onTap:
                        () =>
                        _openClass(
                          item,
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

  // ============================================================
  // EMPTY
  // ============================================================

  Widget _buildEmpty() {
    return RefreshIndicator(
      onRefresh:
      _loadClasses,
      child: ListView(
        physics:
        const AlwaysScrollableScrollPhysics(),
        children: const [
          SizedBox(
            height: 130,
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
                FontWeight.w800,
              ),
            ),
          ),
          SizedBox(
            height: 6,
          ),
          Center(
            child: Text(
              'Add classes from the Classes screen.',
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // SHIMMER
  // ============================================================

  Widget _buildShimmer() {
    return Shimmer.fromColors(
      baseColor:
      Colors.grey.shade100,
      highlightColor:
      Colors.white,
      child:
      ListView.separated(
        padding:
        const EdgeInsets.all(
          24,
        ),
        itemCount: 6,
        separatorBuilder:
            (_, __) =>
        const SizedBox(
          height: 12,
        ),
        itemBuilder:
            (_, __) =>
            Container(
              height: 150,
              decoration:
              BoxDecoration(
                color:
                Colors.white,
                borderRadius:
                BorderRadius.circular(
                  20,
                ),
              ),
            ),
      ),
    );
  }

  // ============================================================
  // ERROR
  // ============================================================

  Widget _buildError() {
    return Center(
      child: Padding(
        padding:
        const EdgeInsets.all(
          24,
        ),
        child: Column(
          mainAxisAlignment:
          MainAxisAlignment.center,
          children: [
            const Icon(
              Icons
                  .error_outline_rounded,
              color:
              AppColors
                  .error,
              size: 48,
            ),
            const SizedBox(
              height: 16,
            ),
            Text(
              _error ??
                  'An error occurred.',
              textAlign:
              TextAlign.center,
            ),
            const SizedBox(
              height: 20,
            ),
            FilledButton.tonal(
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
}

// ============================================================================
// CLASS CARD
// ============================================================================

class _ClassCard
    extends StatelessWidget {
  final Map<String, dynamic>
  classItem;

  final Map<String, int>?
  summary;

  final Future<int>
  Function() getStudentCount;

  final VoidCallback onTap;

  const _ClassCard({
    required this.classItem,
    required this.summary,
    required this.getStudentCount,
    required this.onTap,
  });

  String _displayName() {
    final name =
        classItem['name']
            ?.toString()
            .trim() ??
            '';

    if (name.isEmpty) {
      return 'Class';
    }

    if (name.toLowerCase().startsWith(
      'class ',
    )) {
      return name;
    }

    return 'Class $name';
  }

  @override
  Widget build(
      BuildContext context,
      ) {
    final section =
        classItem['section_name']
            ?.toString()
            .trim() ??
            '';

    final present =
        summary?['present'] ?? 0;

    final absent =
        summary?['absent'] ?? 0;

    final late =
        summary?['late'] ?? 0;

    final leave =
        summary?['leave'] ?? 0;

    return Card(
      margin:
      EdgeInsets.zero,
      child: InkWell(
        onTap: onTap,
        borderRadius:
        BorderRadius.circular(
          20,
        ),
        child: Padding(
          padding:
          const EdgeInsets.all(
            16,
          ),
          child: Column(
            children: [
              Row(
                children: [
                  Container(
                    width: 52,
                    height: 52,
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
                        15,
                      ),
                    ),
                    child:
                    const Icon(
                      Icons
                          .school_rounded,
                      color:
                      AppColors
                          .primary,
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
                          _displayName(),
                          style:
                          const TextStyle(
                            fontSize:
                            17,
                            fontWeight:
                            FontWeight
                                .w900,
                          ),
                        ),
                        const SizedBox(
                          height: 4,
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
                            fontSize:
                            12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Icon(
                    Icons
                        .arrow_forward_ios_rounded,
                    size: 18,
                    color:
                    AppColors
                        .textSecondary,
                  ),
                ],
              ),
              const SizedBox(
                height: 14,
              ),
              const Divider(
                height: 1,
              ),
              const SizedBox(
                height: 12,
              ),
              FutureBuilder<int>(
                future:
                getStudentCount(),
                builder:
                    (
                    context,
                    snapshot,
                    ) {
                  final count =
                      snapshot.data ??
                          0;

                  return Row(
                    children: [
                      const Icon(
                        Icons
                            .people_alt_outlined,
                        size: 17,
                        color:
                        AppColors
                            .textSecondary,
                      ),
                      const SizedBox(
                        width: 7,
                      ),
                      Text(
                        '$count ${count == 1 ? 'student' : 'students'}',
                        style:
                        const TextStyle(
                          color:
                          AppColors
                              .textSecondary,
                          fontSize:
                          12,
                          fontWeight:
                          FontWeight
                              .w700,
                        ),
                      ),
                    ],
                  );
                },
              ),
              const SizedBox(
                height: 12,
              ),
              const Align(
                alignment:
                Alignment.centerLeft,
                child:
                Text(
                  "Today's Attendance",
                  style:
                  TextStyle(
                    fontSize: 11,
                    fontWeight:
                    FontWeight
                        .w800,
                    color:
                    AppColors
                        .textSecondary,
                  ),
                ),
              ),
              const SizedBox(
                height: 9,
              ),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _badge(
                    'Present',
                    present,
                    AppColors
                        .success,
                  ),
                  _badge(
                    'Absent',
                    absent,
                    AppColors
                        .error,
                  ),
                  _badge(
                    'Late',
                    late,
                    AppColors
                        .warning,
                  ),
                  _badge(
                    'Leave',
                    leave,
                    AppColors
                        .info,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _badge(
      String label,
      int value,
      Color color,
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
        color.withValues(alpha: 
          .07,
        ),
        borderRadius:
        BorderRadius.circular(
          10,
        ),
        border: Border.all(
          color:
          color.withValues(alpha: 
            .14,
          ),
        ),
      ),
      child: Text(
        '$label $value',
        style:
        TextStyle(
          color: color,
          fontSize: 11,
          fontWeight:
          FontWeight.w800,
        ),
      ),
    );
  }
}

// ============================================================================
// CLASS ATTENDANCE SCREEN
// ============================================================================

class ClassAttendanceScreen
    extends StatefulWidget {
  final Map<String, dynamic>
  classItem;

  const ClassAttendanceScreen({
    super.key,
    required this.classItem,
  });

  @override
  State<
      ClassAttendanceScreen>
  createState() =>
      _ClassAttendanceScreenState();
}

class _ClassAttendanceScreenState
    extends State<
        ClassAttendanceScreen> {
  final SupabaseClient _client =
      SupabaseConfig.client;

  DateTime _date =
  DateTime.now();

  bool _loading = true;
  bool _saving = false;

  String? _error;

  int? _schoolId;

  List<Map<String, dynamic>>
  _students = [];

  Map<String, String>
  _statuses = {};

  String get _className {
    return widget.classItem['name']
        ?.toString()
        .trim() ??
        '';
  }

  String get _section {
    return widget.classItem[
    'section_name']
        ?.toString()
        .trim() ??
        '';
  }

  String _displayClassName() {
    if (_className.isEmpty) {
      return 'Class';
    }

    if (_className
        .toLowerCase()
        .startsWith(
      'class ',
    )) {
      return _className;
    }

    return 'Class $_className';
  }

  String _dateKey(
      DateTime date,
      ) {
    return '${date.year}-'
        '${date.month.toString().padLeft(2, '0')}-'
        '${date.day.toString().padLeft(2, '0')}';
  }

  // ============================================================
  // SCHOOL ID
  // ============================================================

  Future<int?> _getSchoolId() async {
    try {
      final result =
      await _client.rpc(
        'get_my_school_id',
      );

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
    } catch (_) {}

    final userId =
        _client.auth.currentUser?.id;

    if (userId == null) {
      return null;
    }

    final profile =
    await _client
        .from('profiles')
        .select(
      'school_id',
    )
        .eq(
      'id',
      userId,
    )
        .maybeSingle();

    final value =
    profile?['school_id'];

    if (value is int) {
      return value;
    }

    return int.tryParse(
      value?.toString() ?? '',
    );
  }

  // ============================================================
  // LOAD DATA
  // ============================================================

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
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

      // --------------------------------------------------------
      // Load students from this exact class + section.
      // --------------------------------------------------------

      var studentQuery =
      _client
          .from('students')
          .select(
        'id, admission_number, full_name, '
            'class_name, section_name',
      )
          .eq(
        'school_id',
        schoolId,
      )
          .eq(
        'is_active',
        true,
      )
          .ilike(
        'class_name',
        _className,
      );

      final rows =
      _section.isEmpty
          ? await studentQuery.isFilter(
        'section_name',
        null,
      )
          : await studentQuery.ilike(
        'section_name',
        _section,
      );

      final students =
      List<Map<String, dynamic>>.from(
        rows,
      );

      final ids =
      students
          .map(
            (student) =>
            student['id'].toString(),
      )
          .toList();

      final statuses =
      <String, String>{};

      // --------------------------------------------------------
      // Load attendance for selected date.
      // --------------------------------------------------------

      if (ids.isNotEmpty) {
        final attendanceRows =
        await _client
            .from('attendance')
            .select(
          'student_id, status',
        )
            .eq(
          'school_id',
          schoolId,
        )
            .eq(
          'attendance_date',
          _dateKey(_date),
        )
            .inFilter(
          'student_id',
          ids,
        );

        for (final row
        in attendanceRows as List) {
          final studentId =
          row['student_id']
              .toString();

          final status =
          row['status']
              ?.toString()
              .toLowerCase();

          if (status != null &&
              status.isNotEmpty) {
            statuses[
            studentId] =
                status;
          }
        }
      }

      // --------------------------------------------------------
      // Sort students by name.
      // --------------------------------------------------------

      students.sort(
            (a, b) {
          final nameA =
              a['full_name']
                  ?.toString()
                  .toLowerCase() ??
                  '';

          final nameB =
              b['full_name']
                  ?.toString()
                  .toLowerCase() ??
                  '';

          return nameA.compareTo(
            nameB,
          );
        },
      );

      if (!mounted) return;

      setState(() {
        _students = students;
        _statuses = statuses;
        _loading = false;
      });
    } on PostgrestException catch (e) {
      debugPrint(
        'Attendance load error: ${e.message}',
      );

      if (!mounted) return;

      setState(() {
        _error =
        '${e.message}\n\nCode: ${e.code ?? 'unknown'}';
        _loading = false;
      });
    } catch (e) {
      debugPrint(
        'Attendance load error: $e',
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
  // MARK ALL
  // ============================================================

  void _markAll(
      String status,
      ) {
    if (_students.isEmpty) {
      return;
    }

    setState(() {
      for (final student
      in _students) {
        final id =
        student['id'].toString();

        _statuses[id] =
            status;
      }
    });
  }

  // ============================================================
  // SAVE
  // ============================================================

  Future<void> _saveAttendance() async {
    if (_saving) {
      return;
    }

    if (_students.isEmpty) {
      return;
    }

    if (_statuses.length <
        _students.length) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(
        const SnackBar(
          content: Text(
            'Please mark attendance for all students before saving.',
          ),
        ),
      );

      return;
    }

    setState(() {
      _saving = true;
    });

    try {
      final schoolId =
          _schoolId ??
              await _getSchoolId();

      final userId =
          _client.auth.currentUser?.id;

      if (schoolId == null) {
        throw Exception(
          'Your account is not linked to a school.',
        );
      }

      if (userId == null) {
        throw Exception(
          'No authenticated user found.',
        );
      }

      final rows =
      <Map<String, dynamic>>[];

      for (final student
      in _students) {
        final studentId =
        student['id'].toString();

        final status =
        _statuses[studentId];

        if (status == null ||
            status.isEmpty) {
          continue;
        }

        rows.add({
          'school_id': schoolId,
          'student_id':
          student['id'],
          'attendance_date':
          _dateKey(_date),
          'status': status,
          'marked_by': userId,
          'updated_at':
          DateTime.now()
              .toUtc()
              .toIso8601String(),
        });
      }

      if (rows.isEmpty) {
        throw Exception(
          'No attendance marked.',
        );
      }

      await _client
          .from('attendance')
          .upsert(
        rows,
        onConflict:
        'student_id,attendance_date',
      );

      if (!mounted) return;

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(
        const SnackBar(
          content: Text(
            'Attendance saved successfully.',
          ),
          backgroundColor:
          AppColors.success,
        ),
      );

      await _loadData();
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
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(
        SnackBar(
          content: Text(
            e.toString()
                .replaceFirst(
              'Exception: ',
              '',
            ),
          ),
          backgroundColor:
          AppColors.error,
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

  // ============================================================
  // DATE PICKER
  // ============================================================

  Future<void> _pickDate() async {
    final selected =
    await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate:
      DateTime(2020),
      lastDate:
      DateTime.now(),
    );

    if (selected == null) {
      return;
    }

    setState(() {
      _date = selected;
    });

    await _loadData();
  }

  // ============================================================
  // DATE CHANGE
  // ============================================================

  Future<void> _changeDate(
      int days,
      ) async {
    final next =
    _date.add(
      Duration(
        days: days,
      ),
    );

    if (next.isAfter(
      DateTime.now(),
    )) {
      return;
    }

    setState(() {
      _date = next;
    });

    await _loadData();
  }

  // ============================================================
  // STATS
  // ============================================================

  int get _present {
    return _statuses.values
        .where(
          (status) =>
      status == 'present',
    )
        .length;
  }

  int get _absent {
    return _statuses.values
        .where(
          (status) =>
      status == 'absent',
    )
        .length;
  }

  int get _late {
    return _statuses.values
        .where(
          (status) =>
      status == 'late',
    )
        .length;
  }

  int get _leave {
    return _statuses.values
        .where(
          (status) =>
      status == 'leave',
    )
        .length;
  }

  double get _rate {
    if (_students.isEmpty) {
      return 0;
    }

    final counted =
        _present +
            _absent +
            _late +
            _leave;

    if (counted == 0) {
      return 0;
    }

    return ((_present +
        _late) /
        counted) *
        100;
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
          _buildDateSelector(),
          _buildQuickActions(),
          _buildStats(),
          Expanded(
            child: _loading
                ? _buildShimmer()
                : _error != null
                ? _buildError()
                : _students.isEmpty
                ? _buildEmpty()
                : RefreshIndicator(
              onRefresh:
              _loadData,
              child:
              _buildStudents(),
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
        16,
        20,
        16,
        12,
      ),
      child: Row(
        children: [
          IconButton(
            onPressed: () =>
                Navigator.of(
                  context,
                ).pop(),
            icon:
            const Icon(
              Icons
                  .arrow_back_rounded,
            ),
            tooltip:
            'Back to Classes',
          ),
          const SizedBox(
            width: 4,
          ),
          Expanded(
            child: Column(
              crossAxisAlignment:
              CrossAxisAlignment
                  .start,
              children: [
                Text(
                  '${_displayClassName()} Attendance',
                  style:
                  const TextStyle(
                    fontSize: 22,
                    fontWeight:
                    FontWeight
                        .w900,
                  ),
                  overflow:
                  TextOverflow
                      .ellipsis,
                ),
                const SizedBox(
                  height: 3,
                ),
                Text(
                  _section.isEmpty
                      ? 'All sections'
                      : 'Section $_section',
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
          const SizedBox(
            width: 8,
          ),
          Flexible(
            child:
            FilledButton.icon(
              onPressed:
              _saving
                  ? null
                  : _saveAttendance,
              icon: _saving
                  ? const SizedBox(
                width: 16,
                height: 16,
                child:
                CircularProgressIndicator(
                  strokeWidth: 2,
                  color:
                  Colors.white,
                ),
              )
                  : const Icon(
                Icons
                    .cloud_done_rounded,
                size: 18,
              ),
              label: Text(
                _saving
                    ? 'Saving...'
                    : 'Save',
                maxLines: 1,
                overflow:
                TextOverflow
                    .ellipsis,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // DATE
  // ============================================================

  Widget _buildDateSelector() {
    final today =
        _dateKey(_date) ==
            _dateKey(
              DateTime.now(),
            );

    return Container(
      margin:
      const EdgeInsets
          .symmetric(
        horizontal: 24,
        vertical: 8,
      ),
      padding:
      const EdgeInsets.all(
        8,
      ),
      decoration:
      BoxDecoration(
        color:
        Colors.white,
        borderRadius:
        BorderRadius.circular(
          16,
        ),
        border:
        Border.all(
          color:
          AppColors.border,
        ),
      ),
      child: Row(
        children: [
          IconButton(
            onPressed: () =>
                _changeDate(-1),
            icon:
            const Icon(
              Icons
                  .chevron_left_rounded,
            ),
          ),
          Expanded(
            child: InkWell(
              onTap:
              _pickDate,
              child: Center(
                child: Row(
                  mainAxisSize:
                  MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons
                          .calendar_today_rounded,
                      size: 16,
                      color:
                      AppColors
                          .primary,
                    ),
                    const SizedBox(
                      width: 10,
                    ),
                    Text(
                      MaterialLocalizations
                          .of(
                        context,
                      )
                          .formatMediumDate(
                        _date,
                      ),
                      style:
                      const TextStyle(
                        fontWeight:
                        FontWeight
                            .w800,
                        fontSize: 15,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          IconButton(
            onPressed: today
                ? null
                : () =>
                _changeDate(1),
            icon:
            Icon(
              Icons
                  .chevron_right_rounded,
              color: today
                  ? AppColors
                  .textMuted
                  : AppColors
                  .textPrimary,
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // QUICK ACTIONS
  // ============================================================

  Widget _buildQuickActions() {
    return Padding(
      padding:
      const EdgeInsets.fromLTRB(
        24,
        8,
        24,
        4,
      ),
      child: Wrap(
        alignment:
        WrapAlignment.end,
        crossAxisAlignment:
        WrapCrossAlignment
            .center,
        spacing: 4,
        children: [
          Text(
            '${_students.length} students',
            style:
            const TextStyle(
              color:
              AppColors
                  .textSecondary,
              fontSize: 12,
              fontWeight:
              FontWeight
                  .w700,
            ),
          ),
          TextButton(
            onPressed:
                () => _markAll(
              'present',
            ),
            child:
            const Text(
              'Present All',
            ),
          ),
          TextButton(
            onPressed:
                () => _markAll(
              'absent',
            ),
            child:
            const Text(
              'Absent All',
            ),
          ),
          TextButton(
            onPressed:
                () => _markAll(
              'late',
            ),
            child:
            const Text(
              'Late All',
            ),
          ),
          TextButton(
            onPressed:
                () => _markAll(
              'leave',
            ),
            child:
            const Text(
              'Leave All',
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // STATS
  // ============================================================

  Widget _buildStats() {
    final cards = [
      _statCard(
        'Total',
        _students.length
            .toString(),
        AppColors.primary,
      ),
      _statCard(
        'Present',
        _present
            .toString(),
        AppColors.success,
      ),
      _statCard(
        'Absent',
        _absent
            .toString(),
        AppColors.error,
      ),
      _statCard(
        'Late',
        _late.toString(),
        AppColors.warning,
      ),
      _statCard(
        'Leave',
        _leave.toString(),
        AppColors.info,
      ),
      _statCard(
        'Rate',
        '${_rate.toStringAsFixed(1)}%',
        AppColors.primary,
      ),
    ];

    return Padding(
      padding:
      const EdgeInsets.fromLTRB(
        24,
        8,
        24,
        12,
      ),
      child: LayoutBuilder(
        builder:
            (
            context,
            constraints,
            ) {
          final width =
          constraints.maxWidth <
              650
              ? (constraints
              .maxWidth -
              10) /
              2
              : null;

          if (width ==
              null) {
            return Row(
              children: [
                for (
                int i = 0;
                i < cards.length;
                i++
                ) ...[
                  Expanded(
                    child:
                    cards[i],
                  ),
                  if (i <
                      cards.length -
                          1)
                    const SizedBox(
                      width: 8,
                    ),
                ],
              ],
            );
          }

          return Wrap(
            spacing: 10,
            runSpacing: 10,
            children:
            cards.map(
                  (card) {
                return SizedBox(
                  width: width,
                  child: card,
                );
              },
            ).toList(),
          );
        },
      ),
    );
  }

  Widget _statCard(
      String label,
      String value,
      Color color,
      ) {
    return Container(
      padding:
      const EdgeInsets
          .symmetric(
        vertical: 13,
        horizontal: 8,
      ),
      decoration:
      BoxDecoration(
        color:
        color.withValues(alpha: 
          .06,
        ),
        borderRadius:
        BorderRadius.circular(
          16,
        ),
        border:
        Border.all(
          color:
          color.withValues(alpha: 
            .12,
          ),
        ),
      ),
      child: Column(
        children: [
          Text(
            value,
            style:
            TextStyle(
              color: color,
              fontWeight:
              FontWeight
                  .w900,
              fontSize: 19,
            ),
          ),
          Text(
            label,
            style:
            TextStyle(
              color:
              color.withValues(alpha: 
                .75,
              ),
              fontWeight:
              FontWeight
                  .w700,
              fontSize: 10,
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // STUDENTS
  // ============================================================

  Widget _buildStudents() {
    return ListView.separated(
      physics:
      const AlwaysScrollableScrollPhysics(),
      padding:
      const EdgeInsets.fromLTRB(
        24,
        8,
        24,
        24,
      ),
      itemCount:
      _students.length,
      separatorBuilder:
          (_, __) =>
      const SizedBox(
        height: 12,
      ),
      itemBuilder:
          (
          context,
          index,
          ) {
        final student =
        _students[index];

        final id =
        student['id'].toString();

        final rawName =
            student['full_name']
                ?.toString()
                .trim() ??
                '';

        final name =
        rawName.isEmpty
            ? 'Unnamed Student'
            : rawName;

        final initial =
        name.substring(
          0,
          1,
        ).toUpperCase();

        final admission =
            student[
            'admission_number']
                ?.toString() ??
                '-';

        final status =
        _statuses[id];

        return Card(
          margin:
          EdgeInsets.zero,
          child:
          Padding(
            padding:
            const EdgeInsets.all(
              14,
            ),
            child: Row(
              children: [
                Container(
                  width: 46,
                  height: 46,
                  decoration:
                  BoxDecoration(
                    color:
                    AppColors
                        .background,
                    borderRadius:
                    BorderRadius
                        .circular(
                      13,
                    ),
                  ),
                  alignment:
                  Alignment
                      .center,
                  child:
                  Text(
                    initial,
                    style:
                    const TextStyle(
                      fontWeight:
                      FontWeight
                          .w900,
                      fontSize: 17,
                    ),
                  ),
                ),
                const SizedBox(
                  width: 14,
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
                          fontWeight:
                          FontWeight
                              .w800,
                          fontSize:
                          15,
                        ),
                      ),
                      const SizedBox(
                        height: 3,
                      ),
                      Text(
                        'Admission: $admission',
                        style:
                        const TextStyle(
                          color:
                          AppColors
                              .textSecondary,
                          fontSize:
                          11,
                        ),
                      ),
                    ],
                  ),
                ),
                _statusButton(
                  label: 'P',
                  code: 'present',
                  color:
                  AppColors.success,
                  active:
                  status ==
                      'present',
                  studentId:
                  id,
                ),
                _statusButton(
                  label: 'A',
                  code: 'absent',
                  color:
                  AppColors.error,
                  active:
                  status ==
                      'absent',
                  studentId:
                  id,
                ),
                _statusButton(
                  label: 'L',
                  code: 'late',
                  color:
                  AppColors.warning,
                  active:
                  status ==
                      'late',
                  studentId:
                  id,
                ),
                _statusButton(
                  label: 'LV',
                  code: 'leave',
                  color:
                  AppColors.info,
                  active:
                  status ==
                      'leave',
                  studentId:
                  id,
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _statusButton({
    required String label,
    required String code,
    required Color color,
    required bool active,
    required String studentId,
  }) {
    return Padding(
      padding:
      const EdgeInsets.only(
        left: 5,
      ),
      child: InkWell(
        onTap: () {
          setState(() {
            _statuses[
            studentId] =
                code;
          });
        },
        borderRadius:
        BorderRadius.circular(
          10,
        ),
        child: Container(
          width: 38,
          height: 38,
          alignment:
          Alignment.center,
          decoration:
          BoxDecoration(
            color: active
                ? color
                : Colors.white,
            borderRadius:
            BorderRadius.circular(
              10,
            ),
            border:
            Border.all(
              color: active
                  ? color
                  : AppColors
                  .border,
            ),
          ),
          child:
          Text(
            label,
            style:
            TextStyle(
              color: active
                  ? Colors.white
                  : AppColors
                  .textSecondary,
              fontWeight:
              FontWeight
                  .w900,
              fontSize:
              10,
            ),
          ),
        ),
      ),
    );
  }

  // ============================================================
  // EMPTY
  // ============================================================

  Widget _buildEmpty() {
    return RefreshIndicator(
      onRefresh:
      _loadData,
      child: ListView(
        physics:
        const AlwaysScrollableScrollPhysics(),
        children: const [
          SizedBox(
            height: 100,
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
            child: Text(
              'No active students found.',
              style:
              TextStyle(
                fontWeight:
                FontWeight
                    .w800,
              ),
            ),
          ),
          SizedBox(
            height: 6,
          ),
          Center(
            child: Text(
              'Students assigned to this class will appear here.',
              textAlign:
              TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // SHIMMER
  // ============================================================

  Widget _buildShimmer() {
    return Shimmer.fromColors(
      baseColor:
      Colors.grey.shade100,
      highlightColor:
      Colors.white,
      child:
      ListView.separated(
        padding:
        const EdgeInsets.all(
          24,
        ),
        itemCount: 6,
        separatorBuilder:
            (_, __) =>
        const SizedBox(
          height: 12,
        ),
        itemBuilder:
            (_, __) =>
            Container(
              height: 76,
              decoration:
              BoxDecoration(
                color:
                Colors.white,
                borderRadius:
                BorderRadius.circular(
                  20,
                ),
              ),
            ),
      ),
    );
  }

  // ============================================================
  // ERROR
  // ============================================================

  Widget _buildError() {
    return Center(
      child: Padding(
        padding:
        const EdgeInsets.all(
          24,
        ),
        child: Column(
          mainAxisAlignment:
          MainAxisAlignment.center,
          children: [
            const Icon(
              Icons
                  .error_outline_rounded,
              color:
              AppColors.error,
              size: 48,
            ),
            const SizedBox(
              height: 16,
            ),
            Text(
              _error ??
                  'An error occurred.',
              textAlign:
              TextAlign.center,
            ),
            const SizedBox(
              height: 20,
            ),
            FilledButton.tonal(
              onPressed:
              _loadData,
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
}