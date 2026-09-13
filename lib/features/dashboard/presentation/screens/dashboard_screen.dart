import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:fl_chart/fl_chart.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/network/supabase_client.dart';
import '../../../../core/widgets/main_wrapper.dart';

/// ===============================================================
/// DASHBOARD DATA
/// Riverpod-based replacement for the old StatefulWidget dashboard.
/// It keeps the existing Supabase tables used by the project:
/// students, profiles, classes, attendance, activity_logs,
/// fee_payments and student_fees.
/// ===============================================================

class DashboardData {
  final int students;
  final int teachers;
  final int staff;
  final int classes;

  final double attendanceRate;
  final List<FlSpot> attendanceSpots;

  final double? monthlyCollection;
  final double? pendingFees;

  final List<Map<String, dynamic>> recentActivities;

  const DashboardData({
    required this.students,
    required this.teachers,
    required this.staff,
    required this.classes,
    required this.attendanceRate,
    required this.attendanceSpots,
    required this.monthlyCollection,
    required this.pendingFees,
    required this.recentActivities,
  });
}

final dashboardDataProvider =
    FutureProvider.autoDispose<DashboardData>((ref) async {
  final client = SupabaseConfig.client;
  final schoolId = await ref.watch(schoolIdProvider.future);

  if (schoolId == null) {
    throw Exception('Your account is not linked to a school.');
  }

  int students = 0;
  int teachers = 0;
  int staff = 0;
  int classes = 0;

  double attendanceRate = 0;
  List<FlSpot> attendanceSpots = [];

  double? monthlyCollection;
  double? pendingFees;

  List<Map<String, dynamic>> recentActivities = [];

  // ---------------------------------------------------------------
  // STUDENTS
  // ---------------------------------------------------------------
  try {
    final response = await client
        .from('students')
        .select('id')
        .eq('school_id', schoolId)
        .eq('is_active', true);

    students = (response as List).length;
  } catch (_) {}

  // ---------------------------------------------------------------
  // TEACHERS
  // ---------------------------------------------------------------
  try {
    final response = await client
        .from('profiles')
        .select('id')
        .eq('school_id', schoolId)
        .eq('role', 'teacher')
        .eq('is_active', true);

    teachers = (response as List).length;
  } catch (_) {}

  // ---------------------------------------------------------------
  // STAFF
  // ---------------------------------------------------------------
  try {
    final response = await client
        .from('profiles')
        .select('id')
        .eq('school_id', schoolId)
        .eq('role', 'staff')
        .eq('is_active', true);

    staff = (response as List).length;
  } catch (_) {}

  // ---------------------------------------------------------------
  // CLASSES
  // ---------------------------------------------------------------
  try {
    final response = await client
        .from('classes')
        .select('id')
        .eq('school_id', schoolId);

    classes = (response as List).length;
  } catch (_) {}

  // ---------------------------------------------------------------
  // ATTENDANCE - LAST 7 DAYS
  // ---------------------------------------------------------------
  try {
    final start = DateTime.now().subtract(
      const Duration(days: 6),
    );

    final response = await client
        .from('attendance')
        .select('status, attendance_date')
        .eq('school_id', schoolId)
        .gte('attendance_date', _formatDate(start))
        .order('attendance_date');

    final rows =
        List<Map<String, dynamic>>.from(response);

    if (rows.isNotEmpty) {
      final present = rows.where((row) {
        final status =
            row['status']?.toString().toLowerCase();

        return status == 'present' || status == 'late';
      }).length;

      attendanceRate =
          present / rows.length * 100;

      final byDate = <String, List<String>>{};

      for (final row in rows) {
        final date =
            row['attendance_date']?.toString();

        final status =
            row['status']?.toString();

        if (date == null || status == null) {
          continue;
        }

        byDate
            .putIfAbsent(date, () => [])
            .add(status);
      }

      final dates =
          byDate.keys.toList()..sort();

      for (int i = 0; i < dates.length; i++) {
        final statuses =
            byDate[dates[i]] ?? [];

        if (statuses.isEmpty) continue;

        final good = statuses.where((status) {
          final value =
              status.toLowerCase();

          return value == 'present' ||
              value == 'late';
        }).length;

        attendanceSpots.add(
          FlSpot(
            i.toDouble(),
            good / statuses.length * 100,
          ),
        );
      }
    }
  } catch (_) {}

  // ---------------------------------------------------------------
  // MONTHLY COLLECTION
  // ---------------------------------------------------------------
  try {
    final now = DateTime.now();

    final firstDay =
        DateTime(now.year, now.month, 1);

    final nextMonth =
        DateTime(now.year, now.month + 1, 1);

    final response = await client
        .from('fee_payments')
        .select('amount, payment_date, status')
        .eq('school_id', schoolId)
        .gte(
          'payment_date',
          _formatDate(firstDay),
        )
        .lt(
          'payment_date',
          _formatDate(nextMonth),
        );

    final rows =
        List<Map<String, dynamic>>.from(response);

    double total = 0;

    for (final row in rows) {
      final status =
          row['status']?.toString().toLowerCase();

      if (status == null ||
          status == 'paid' ||
          status == 'completed' ||
          status == 'success') {
        final amount =
            double.tryParse(
                  row['amount']?.toString() ?? '',
                ) ??
                0;

        total += amount;
      }
    }

    monthlyCollection = total;
  } catch (_) {}

  // ---------------------------------------------------------------
  // PENDING FEES
  // ---------------------------------------------------------------
  try {
    final response = await client
        .from('student_fees')
        .select('amount, status')
        .eq('school_id', schoolId);

    final rows =
        List<Map<String, dynamic>>.from(response);

    double total = 0;

    for (final row in rows) {
      final status =
          row['status']?.toString().toLowerCase();

      if (status == 'pending' ||
          status == 'unpaid' ||
          status == 'due' ||
          status == 'overdue') {
        total +=
            double.tryParse(
                  row['amount']?.toString() ?? '',
                ) ??
                0;
      }
    }

    pendingFees = total;
  } catch (_) {}

  // ---------------------------------------------------------------
  // RECENT ACTIVITIES
  // ---------------------------------------------------------------
  try {
    final response = await client
        .from('activity_logs')
        .select(
          'id, action, title, description, '
          'created_at, icon, entity_type',
        )
        .eq('school_id', schoolId)
        .order(
          'created_at',
          ascending: false,
        )
        .limit(8);

    recentActivities =
        List<Map<String, dynamic>>.from(response);
  } catch (_) {}

  return DashboardData(
    students: students,
    teachers: teachers,
    staff: staff,
    classes: classes,
    attendanceRate: attendanceRate,
    attendanceSpots: attendanceSpots,
    monthlyCollection: monthlyCollection,
    pendingFees: pendingFees,
    recentActivities: recentActivities,
  );
});

String _formatDate(DateTime date) {
  return '${date.year}-'
      '${date.month.toString().padLeft(2, '0')}-'
      '${date.day.toString().padLeft(2, '0')}';
}

/// ===============================================================
/// DASHBOARD SCREEN
/// ===============================================================

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  String _greeting() {
    final hour = DateTime.now().hour;

    if (hour < 12) return 'Good Morning';
    if (hour < 17) return 'Good Afternoon';
    return 'Good Evening';
  }

  @override
  Widget build(
    BuildContext context,
    WidgetRef ref,
  ) {
    final dashboard =
        ref.watch(dashboardDataProvider);

    final user =
        SupabaseConfig.client.auth.currentUser;

    final rawName =
        user?.userMetadata?['full_name'];

    final name =
        rawName is String &&
                rawName.trim().isNotEmpty
            ? rawName.trim()
            : 'Principal';

    return MainWrapper(
      child: dashboard.when(
        loading: () => const _DashboardLoading(),

        error: (error, stack) => _DashboardError(
          message: error.toString()
              .replaceFirst('Exception: ', ''),
          onRetry: () {
            ref.invalidate(
              dashboardDataProvider,
            );
          },
        ),

        data: (data) {
          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(
                dashboardDataProvider,
              );

              await ref.read(
                dashboardDataProvider.future,
              );
            },

            child: ListView(
              physics:
                  const AlwaysScrollableScrollPhysics(),

              padding:
                  const EdgeInsets.fromLTRB(
                18,
                18,
                18,
                32,
              ),

              children: [
                _WelcomeHeader(
                  name: name,
                  greeting: _greeting(),
                ),

                const SizedBox(height: 16),

                _WelcomeBanner(
                  name: name,
                ),

                const SizedBox(height: 25),

                const _SectionTitle(
                  title: 'School Overview',
                  subtitle:
                      'Live information from your school',
                ),

                const SizedBox(height: 12),

                _StatsGrid(
                  data: data,
                ),

                const SizedBox(height: 22),

                LayoutBuilder(
                  builder: (context, constraints) {
                    if (constraints.maxWidth < 850) {
                      return Column(
                        children: [
                          _AttendanceCard(
                            data: data,
                          ),
                          const SizedBox(height: 16),
                          _FinanceCard(
                            data: data,
                          ),
                        ],
                      );
                    }

                    return Row(
                      crossAxisAlignment:
                          CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          flex: 3,
                          child: _AttendanceCard(
                            data: data,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          flex: 2,
                          child: _FinanceCard(
                            data: data,
                          ),
                        ),
                      ],
                    );
                  },
                ),

                const SizedBox(height: 22),

                const _SectionTitle(
                  title: 'Quick Access',
                  subtitle:
                      'Only the most important modules',
                ),

                const SizedBox(height: 12),

                const _QuickAccessGrid(),

                const SizedBox(height: 22),

                _AcademicOverview(
                  data: data,
                ),

                const SizedBox(height: 22),

                _RecentActivity(
                  activities:
                      data.recentActivities,
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

/// ===============================================================
/// HEADER
/// ===============================================================

class _WelcomeHeader extends StatelessWidget {
  final String name;
  final String greeting;

  const _WelcomeHeader({
    required this.name,
    required this.greeting,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment:
                CrossAxisAlignment.start,
            children: [
              Text(
                greeting,
                style: const TextStyle(
                  color:
                      AppColors.textSecondary,
                  fontSize: 12,
                  fontWeight:
                      FontWeight.w600,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                name,
                maxLines: 1,
                overflow:
                    TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 25,
                  fontWeight:
                      FontWeight.w900,
                  letterSpacing: -.7,
                ),
              ),
            ],
          ),
        ),

        _SmallHeaderButton(
          icon:
              Icons.notifications_none_rounded,
          onTap: () {
            context.push(
              '/notification',
            );
          },
        ),

        const SizedBox(width: 8),

        _SmallHeaderButton(
          icon:
              Icons.person_outline_rounded,
          onTap: () {
            context.push(
              '/profile',
            );
          },
        ),
      ],
    );
  }
}

class _SmallHeaderButton
    extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _SmallHeaderButton({
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius:
          BorderRadius.circular(13),

      child: InkWell(
        onTap: onTap,
        borderRadius:
            BorderRadius.circular(13),

        child: Container(
          width: 43,
          height: 43,

          decoration: BoxDecoration(
            borderRadius:
                BorderRadius.circular(13),

            border: Border.all(
              color:
                  AppColors.border,
            ),
          ),

          child: Icon(
            icon,
            size: 20,
            color:
                AppColors.textPrimary,
          ),
        ),
      ),
    );
  }
}

/// ===============================================================
/// WELCOME BANNER
/// ===============================================================

class _WelcomeBanner
    extends StatelessWidget {
  final String name;

  const _WelcomeBanner({
    required this.name,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding:
          const EdgeInsets.all(19),

      decoration:
          BoxDecoration(
        gradient:
            const LinearGradient(
          begin:
              Alignment.topLeft,
          end:
              Alignment.bottomRight,
          colors: [
            AppColors.primary,
            Color(0xFF7C5CFF),
          ],
        ),

        borderRadius:
            BorderRadius.circular(22),

        boxShadow: [
          BoxShadow(
            color:
                AppColors.primary
                    .withValues(alpha: .18),
            blurRadius: 20,
            offset:
                const Offset(0, 8),
          ),
        ],
      ),

      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                const Text(
                  'School Dashboard',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight:
                        FontWeight.w900,
                  ),
                ),

                const SizedBox(height: 6),

                Text(
                  'Welcome back, $name. Here is your school overview for today.',
                  maxLines: 2,
                  overflow:
                      TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.white
                        .withValues(alpha: .82),
                    fontSize: 11.5,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(width: 12),

          Container(
            width: 54,
            height: 54,

            decoration:
                BoxDecoration(
              color: Colors.white
                  .withValues(alpha: .13),
              shape:
                  BoxShape.circle,
            ),

            child: const Icon(
              Icons.auto_awesome_rounded,
              color: Colors.white,
              size: 26,
            ),
          ),
        ],
      ),
    );
  }
}

/// ===============================================================
/// SECTION TITLE
/// ===============================================================

class _SectionTitle
    extends StatelessWidget {
  final String title;
  final String subtitle;

  const _SectionTitle({
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment:
          CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 18,
            fontWeight:
                FontWeight.w900,
          ),
        ),

        const SizedBox(height: 3),

        Text(
          subtitle,
          style: const TextStyle(
            color:
                AppColors.textSecondary,
            fontSize: 10.5,
          ),
        ),
      ],
    );
  }
}

/// ===============================================================
/// STATS
/// ===============================================================

class _StatsGrid
    extends StatelessWidget {
  final DashboardData data;

  const _StatsGrid({
    required this.data,
  });

  @override
  Widget build(BuildContext context) {
    final items = [
      _Stat(
        'Students',
        '${data.students}',
        Icons.people_alt_rounded,
        AppColors.primary,
      ),
      _Stat(
        'Teachers',
        '${data.teachers}',
        Icons.school_rounded,
        AppColors.info,
      ),
      _Stat(
        'Staff',
        '${data.staff}',
        Icons.badge_rounded,
        AppColors.success,
      ),
      _Stat(
        'Classes',
        '${data.classes}',
        Icons.class_rounded,
        AppColors.warning,
      ),
    ];

    return LayoutBuilder(
      builder: (_, constraints) {
        final columns =
            constraints.maxWidth >= 850
                ? 4
                : 2;

        return GridView.builder(
          shrinkWrap: true,
          physics:
              const NeverScrollableScrollPhysics(),

          itemCount:
              items.length,

          gridDelegate:
              SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount:
                columns,
            crossAxisSpacing:
                10,
            mainAxisSpacing:
                10,
            mainAxisExtent:
                108,
          ),

          itemBuilder: (_, index) {
            return _StatCard(
              item: items[index],
            );
          },
        );
      },
    );
  }
}

class _Stat {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _Stat(
    this.label,
    this.value,
    this.icon,
    this.color,
  );
}

class _StatCard
    extends StatelessWidget {
  final _Stat item;

  const _StatCard({
    required this.item,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding:
          const EdgeInsets.all(14),

      decoration:
          BoxDecoration(
        color: Colors.white,
        borderRadius:
            BorderRadius.circular(18),

        border: Border.all(
          color:
              AppColors.border,
        ),

        boxShadow: [
          BoxShadow(
            color:
                Colors.black.withValues(alpha: .025),
            blurRadius: 14,
            offset:
                const Offset(0, 5),
          ),
        ],
      ),

      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,

        mainAxisAlignment:
            MainAxisAlignment.spaceBetween,

        children: [
          Container(
            width: 38,
            height: 38,

            decoration:
                BoxDecoration(
              color:
                  item.color
                      .withValues(alpha: .10),
              borderRadius:
                  BorderRadius.circular(11),
            ),

            child: Icon(
              item.icon,
              color:
                  item.color,
              size: 20,
            ),
          ),

          Row(
            children: [
              Text(
                item.value,
                style: const TextStyle(
                  fontSize: 21,
                  fontWeight:
                      FontWeight.w900,
                ),
              ),

              const Spacer(),

              Text(
                item.label,
                style: const TextStyle(
                  color:
                      AppColors.textSecondary,
                  fontSize: 9.5,
                  fontWeight:
                      FontWeight.w700,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// ===============================================================
/// ATTENDANCE
/// ===============================================================

class _AttendanceCard
    extends StatelessWidget {
  final DashboardData data;

  const _AttendanceCard({
    required this.data,
  });

  @override
  Widget build(BuildContext context) {
    return _Panel(
      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          const _PanelHeader(
            title:
                'Attendance Analytics',
            subtitle:
                'Last 7 days',
            icon:
                Icons.bar_chart_rounded,
            color:
                AppColors.primary,
          ),

          const SizedBox(height: 12),

          Row(
            crossAxisAlignment:
                CrossAxisAlignment.end,
            children: [
              Text(
                '${data.attendanceRate.toStringAsFixed(1)}%',
                style: const TextStyle(
                  fontSize: 28,
                  fontWeight:
                      FontWeight.w900,
                ),
              ),

              const SizedBox(width: 8),

              const Padding(
                padding:
                    EdgeInsets.only(bottom: 4),
                child: Text(
                  'overall attendance',
                  style: TextStyle(
                    color:
                        AppColors.textSecondary,
                    fontSize: 10.5,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          SizedBox(
            height: 175,
            child:
                data.attendanceSpots.isEmpty
                    ? const _EmptyChart()
                    : LineChart(
                        LineChartData(
                          minY: 0,
                          maxY: 100,

                          gridData:
                              const FlGridData(
                            show: true,
                            drawVerticalLine:
                                false,
                            horizontalInterval:
                                25,
                          ),

                          titlesData:
                              FlTitlesData(
                            topTitles:
                                const AxisTitles(
                              sideTitles:
                                  SideTitles(
                                showTitles:
                                    false,
                              ),
                            ),
                            rightTitles:
                                const AxisTitles(
                              sideTitles:
                                  SideTitles(
                                showTitles:
                                    false,
                              ),
                            ),
                            bottomTitles:
                                const AxisTitles(
                              sideTitles:
                                  SideTitles(
                                showTitles:
                                    false,
                              ),
                            ),
                            leftTitles:
                                AxisTitles(
                              sideTitles:
                                  SideTitles(
                                showTitles:
                                    true,
                                interval:
                                    25,
                                reservedSize:
                                    31,
                                getTitlesWidget:
                                    (value, _) {
                                  return Text(
                                    '${value.toInt()}%',
                                    style:
                                        const TextStyle(
                                      fontSize:
                                          8.5,
                                      color:
                                          AppColors.textSecondary,
                                    ),
                                  );
                                },
                              ),
                            ),
                          ),

                          borderData:
                              FlBorderData(
                            show: false,
                          ),

                          lineBarsData: [
                            LineChartBarData(
                              spots:
                                  data.attendanceSpots,
                              isCurved:
                                  true,
                              color:
                                  AppColors.primary,
                              barWidth:
                                  3,
                              isStrokeCapRound:
                                  true,
                              dotData:
                                  const FlDotData(
                                show: false,
                              ),
                              belowBarData:
                                  BarAreaData(
                                show: true,
                                color: AppColors
                                    .primary
                                    .withValues(
                                  alpha: .08,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
          ),
        ],
      ),
    );
  }
}

class _EmptyChart
    extends StatelessWidget {
  const _EmptyChart();

  @override
  Widget build(BuildContext context) {
    return Container(
      alignment:
          Alignment.center,

      decoration:
          BoxDecoration(
        color:
            AppColors.background,
        borderRadius:
            BorderRadius.circular(14),
      ),

      child: const Text(
        'No attendance data available yet',
        style: TextStyle(
          color:
              AppColors.textSecondary,
          fontSize: 11,
        ),
      ),
    );
  }
}

/// ===============================================================
/// FINANCE
/// ===============================================================

class _FinanceCard
    extends StatelessWidget {
  final DashboardData data;

  const _FinanceCard({
    required this.data,
  });

  String _money(double? value) {
    if (value == null) return '--';

    return 'PKR ${value.toStringAsFixed(0)}';
  }

  @override
  Widget build(BuildContext context) {
    return _Panel(
      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          const _PanelHeader(
            title:
                'Finance',
            subtitle:
                'Fee collection overview',
            icon:
                Icons.account_balance_wallet_rounded,
            color:
                AppColors.success,
          ),

          const SizedBox(height: 14),

          _FinanceRow(
            label:
                'Monthly Collection',
            value:
                _money(
                  data.monthlyCollection,
                ),
            color:
                AppColors.success,
          ),

          const SizedBox(height: 10),

          _FinanceRow(
            label:
                'Pending Fees',
            value:
                _money(
                  data.pendingFees,
                ),
            color:
                AppColors.warning,
          ),

          const SizedBox(height: 14),

          SizedBox(
            width:
                double.infinity,
            height: 42,

            child:
                FilledButton.tonal(
              onPressed: () {
                context.push(
                  '/finance',
                );
              },
              child:
                  const Text(
                'Open Finance',
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FinanceRow
    extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _FinanceRow({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding:
          const EdgeInsets.all(11),

      decoration:
          BoxDecoration(
        color:
            AppColors.background,
        borderRadius:
            BorderRadius.circular(13),
      ),

      child: Row(
        children: [
          Container(
            width: 5,
            height: 34,

            decoration:
                BoxDecoration(
              color: color,
              borderRadius:
                  BorderRadius.circular(4),
            ),
          ),

          const SizedBox(width: 9),

          Expanded(
            child: Text(
              label,
              maxLines: 1,
              overflow:
                  TextOverflow.ellipsis,
              style: const TextStyle(
                color:
                    AppColors.textSecondary,
                fontSize: 10.5,
                fontWeight:
                    FontWeight.w600,
              ),
            ),
          ),

          Text(
            value,
            style: const TextStyle(
              fontSize: 13,
              fontWeight:
                  FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

/// ===============================================================
/// QUICK ACCESS
/// Only essential dashboard buttons.
/// Everything else remains in AppDrawer.
/// ===============================================================

class _QuickAccessGrid
    extends StatelessWidget {
  const _QuickAccessGrid();

  @override
  Widget build(BuildContext context) {
    final actions = [
      const _QuickAction(
        'Students',
        Icons.people_alt_rounded,
        AppColors.primary,
        '/student',
      ),
      const _QuickAction(
        'Attendance',
        Icons.fact_check_rounded,
        AppColors.success,
        '/attendance',
      ),
      const _QuickAction(
        'Finance',
        Icons.account_balance_wallet_rounded,
        AppColors.warning,
        '/finance',
      ),
      const _QuickAction(
        'Examinations',
        Icons.quiz_rounded,
        Color(0xFFEC4899),
        '/examination',
      ),
      const _QuickAction(
        'Notices',
        Icons.notifications_rounded,
        Color(0xFF7C3AED),
        '/notification',
      ),
      const _QuickAction(
        'Teachers',
        Icons.school_rounded,
        AppColors.info,
        '/teacher',
      ),
    ];

    return LayoutBuilder(
      builder: (_, constraints) {
        final columns =
            constraints.maxWidth >= 850
                ? 3
                : 2;

        return GridView.builder(
          shrinkWrap: true,
          physics:
              const NeverScrollableScrollPhysics(),

          itemCount:
              actions.length,

          gridDelegate:
              SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount:
                columns,
            crossAxisSpacing:
                10,
            mainAxisSpacing:
                10,
            mainAxisExtent:
                98,
          ),

          itemBuilder: (_, index) {
            return _QuickActionCard(
              action:
                  actions[index],
            );
          },
        );
      },
    );
  }
}

class _QuickAction {
  final String title;
  final IconData icon;
  final Color color;
  final String route;

  const _QuickAction(
    this.title,
    this.icon,
    this.color,
    this.route,
  );
}

class _QuickActionCard
    extends StatelessWidget {
  final _QuickAction action;

  const _QuickActionCard({
    required this.action,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius:
          BorderRadius.circular(17),

      child: InkWell(
        onTap: () {
          context.push(
            action.route,
          );
        },

        borderRadius:
            BorderRadius.circular(17),

        child: Container(
          padding:
              const EdgeInsets.all(13),

          decoration:
              BoxDecoration(
            borderRadius:
                BorderRadius.circular(17),

            border: Border.all(
              color:
                  AppColors.border,
            ),

            boxShadow: [
              BoxShadow(
                color:
                    Colors.black
                        .withValues(alpha: .02),
                blurRadius: 10,
                offset:
                    const Offset(0, 4),
              ),
            ],
          ),

          child: Row(
            children: [
              Container(
                width: 43,
                height: 43,

                decoration:
                    BoxDecoration(
                  color: action.color
                      .withValues(alpha: .10),
                  borderRadius:
                      BorderRadius.circular(13),
                ),

                child: Icon(
                  action.icon,
                  color:
                      action.color,
                  size: 21,
                ),
              ),

              const SizedBox(width: 10),

              Expanded(
                child: Text(
                  action.title,
                  maxLines: 2,
                  overflow:
                      TextOverflow.ellipsis,
                  style:
                      const TextStyle(
                    fontSize: 11,
                    fontWeight:
                        FontWeight.w900,
                  ),
                ),
              ),

              const Icon(
                Icons.chevron_right_rounded,
                color:
                    AppColors.textSecondary,
                size: 18,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// ===============================================================
/// ACADEMIC OVERVIEW
/// These are information cards, not extra navigation buttons.
/// ===============================================================

class _AcademicOverview
    extends StatelessWidget {
  final DashboardData data;

  const _AcademicOverview({
    required this.data,
  });

  @override
  Widget build(BuildContext context) {
    return _Panel(
      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          const _PanelHeader(
            title:
                'Academic Overview',
            subtitle:
                'Quick school management snapshot',
            icon:
                Icons.auto_stories_rounded,
            color:
                Color(0xFF7C3AED),
          ),

          const SizedBox(height: 14),

          Row(
            children: [
              Expanded(
                child:
                    _MiniInfo(
                  title:
                      'Students / Class',
                  value:
                      data.classes == 0
                          ? '--'
                          : (data.students /
                                  data.classes)
                              .toStringAsFixed(1),
                  icon:
                      Icons.groups_rounded,
                ),
              ),

              const SizedBox(width: 10),

              Expanded(
                child:
                    _MiniInfo(
                  title:
                      'Teacher / Class',
                  value:
                      data.classes == 0
                          ? '--'
                          : (data.teachers /
                                  data.classes)
                              .toStringAsFixed(1),
                  icon:
                      Icons.supervisor_account_rounded,
                ),
              ),

              const SizedBox(width: 10),

              Expanded(
                child:
                    _MiniInfo(
                  title:
                      'Attendance',
                  value:
                      '${data.attendanceRate.toStringAsFixed(0)}%',
                  icon:
                      Icons.trending_up_rounded,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MiniInfo
    extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;

  const _MiniInfo({
    required this.title,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding:
          const EdgeInsets.all(11),

      decoration:
          BoxDecoration(
        color:
            AppColors.background,
        borderRadius:
            BorderRadius.circular(14),
      ),

      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          Icon(
            icon,
            color:
                AppColors.primary,
            size: 19,
          ),

          const SizedBox(height: 8),

          Text(
            value,
            maxLines: 1,
            overflow:
                TextOverflow.ellipsis,
            style:
                const TextStyle(
              fontSize: 17,
              fontWeight:
                  FontWeight.w900,
            ),
          ),

          const SizedBox(height: 2),

          Text(
            title,
            maxLines: 2,
            overflow:
                TextOverflow.ellipsis,
            style:
                const TextStyle(
              color:
                  AppColors.textSecondary,
              fontSize: 8.5,
            ),
          ),
        ],
      ),
    );
  }
}

/// ===============================================================
/// RECENT ACTIVITY
/// ===============================================================

class _RecentActivity
    extends StatelessWidget {
  final List<Map<String, dynamic>>
      activities;

  const _RecentActivity({
    required this.activities,
  });

  String _time(dynamic value) {
    if (value == null) return '';

    final date =
        DateTime.tryParse(
      value.toString(),
    );

    if (date == null) return '';

    final diff =
        DateTime.now()
            .difference(
              date.toLocal(),
            );

    if (diff.inSeconds < 60) {
      return 'Just now';
    }

    if (diff.inMinutes < 60) {
      return '${diff.inMinutes}m ago';
    }

    if (diff.inHours < 24) {
      return '${diff.inHours}h ago';
    }

    if (diff.inDays < 7) {
      return '${diff.inDays}d ago';
    }

    return '${date.day.toString().padLeft(2, '0')}/'
        '${date.month.toString().padLeft(2, '0')}';
  }

  IconData _icon(
    Map<String, dynamic> item,
  ) {
    final icon =
        item['icon']
                ?.toString()
                .toLowerCase() ??
            '';

    final type =
        item['entity_type']
                ?.toString()
                .toLowerCase() ??
            '';

    final action =
        item['action']
                ?.toString()
                .toLowerCase() ??
            '';

    if (icon.contains('student') ||
        type.contains('student')) {
      return Icons.person_add_alt_1_rounded;
    }

    if (icon.contains('teacher') ||
        type.contains('teacher')) {
      return Icons.school_rounded;
    }

    if (icon.contains('fee') ||
        icon.contains('finance') ||
        type.contains('fee') ||
        type.contains('finance')) {
      return Icons.account_balance_wallet_rounded;
    }

    if (icon.contains('attendance') ||
        type.contains('attendance')) {
      return Icons.fact_check_rounded;
    }

    if (icon.contains('exam') ||
        type.contains('exam')) {
      return Icons.assignment_rounded;
    }

    if (action.contains('delete') ||
        action.contains('deactivate')) {
      return Icons.delete_outline_rounded;
    }

    if (action.contains('update') ||
        action.contains('edit')) {
      return Icons.edit_rounded;
    }

    return Icons.history_rounded;
  }

  Color _color(
    Map<String, dynamic> item,
  ) {
    final type =
        item['entity_type']
                ?.toString()
                .toLowerCase() ??
            '';

    if (type.contains('student')) {
      return AppColors.primary;
    }

    if (type.contains('teacher')) {
      return AppColors.info;
    }

    if (type.contains('fee') ||
        type.contains('finance')) {
      return AppColors.success;
    }

    if (type.contains('attendance')) {
      return AppColors.warning;
    }

    return AppColors.primary;
  }

  @override
  Widget build(BuildContext context) {
    return _Panel(
      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          const _PanelHeader(
            title:
                'Recent Activity',
            subtitle:
                'Latest school actions',
            icon:
                Icons.history_rounded,
            color:
                AppColors.primary,
          ),

          const SizedBox(height: 12),

          if (activities.isEmpty)
            const Padding(
              padding:
                  EdgeInsets.symmetric(
                vertical: 22,
              ),
              child: Center(
                child: Text(
                  'No recent activity yet.',
                  style: TextStyle(
                    color:
                        AppColors.textSecondary,
                    fontSize: 11,
                  ),
                ),
              ),
            )
          else
            ...activities.map(
              (item) {
                final color =
                    _color(item);

                final title =
                    item['title']
                                ?.toString()
                                .trim()
                                .isNotEmpty ==
                            true
                        ? item['title']
                            .toString()
                        : item['action']
                                ?.toString() ??
                            'Activity';

                final description =
                    item['description']
                            ?.toString() ??
                        '';

                return Padding(
                  padding:
                      const EdgeInsets.only(
                    bottom: 8,
                  ),

                  child: Container(
                    padding:
                        const EdgeInsets.all(
                      10,
                    ),

                    decoration:
                        BoxDecoration(
                      color:
                          AppColors.background,
                      borderRadius:
                          BorderRadius.circular(
                        13,
                      ),
                    ),

                    child: Row(
                      children: [
                        Container(
                          width: 39,
                          height: 39,

                          decoration:
                              BoxDecoration(
                            color: color
                                .withValues(
                              alpha: .10,
                            ),
                            borderRadius:
                                BorderRadius.circular(
                              11,
                            ),
                          ),

                          child: Icon(
                            _icon(item),
                            color:
                                color,
                            size: 18,
                          ),
                        ),

                        const SizedBox(
                          width: 10,
                        ),

                        Expanded(
                          child: Column(
                            crossAxisAlignment:
                                CrossAxisAlignment
                                    .start,
                            children: [
                              Text(
                                title,
                                maxLines: 1,
                                overflow:
                                    TextOverflow
                                        .ellipsis,
                                style:
                                    const TextStyle(
                                  fontSize: 11.5,
                                  fontWeight:
                                      FontWeight.w800,
                                ),
                              ),

                              if (description
                                  .trim()
                                  .isNotEmpty)
                                Padding(
                                  padding:
                                      const EdgeInsets
                                          .only(
                                    top: 2,
                                  ),
                                  child: Text(
                                    description,
                                    maxLines: 1,
                                    overflow:
                                        TextOverflow
                                            .ellipsis,
                                    style:
                                        const TextStyle(
                                      color:
                                          AppColors
                                              .textSecondary,
                                      fontSize: 9,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),

                        const SizedBox(
                          width: 7,
                        ),

                        Text(
                          _time(
                            item['created_at'],
                          ),
                          style:
                              const TextStyle(
                            color:
                                AppColors
                                    .textSecondary,
                            fontSize: 8.5,
                            fontWeight:
                                FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
        ],
      ),
    );
  }
}

/// ===============================================================
/// COMMON PANEL
/// ===============================================================

class _Panel
    extends StatelessWidget {
  final Widget child;

  const _Panel({
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width:
          double.infinity,

      padding:
          const EdgeInsets.all(16),

      decoration:
          BoxDecoration(
        color:
            Colors.white,

        borderRadius:
            BorderRadius.circular(20),

        border:
            Border.all(
          color:
              AppColors.border,
        ),

        boxShadow: [
          BoxShadow(
            color:
                Colors.black.withValues(alpha: .025),
            blurRadius: 15,
            offset:
                const Offset(0, 5),
          ),
        ],
      ),

      child: child,
    );
  }
}

class _PanelHeader
    extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;

  const _PanelHeader({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 40,
          height: 40,

          decoration:
              BoxDecoration(
            color:
                color.withValues(alpha: .10),
            borderRadius:
                BorderRadius.circular(11),
          ),

          child: Icon(
            icon,
            color:
                color,
            size: 20,
          ),
        ),

        const SizedBox(width: 10),

        Expanded(
          child: Column(
            crossAxisAlignment:
                CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style:
                    const TextStyle(
                  fontSize: 14,
                  fontWeight:
                      FontWeight.w900,
                ),
              ),

              const SizedBox(height: 2),

              Text(
                subtitle,
                style:
                    const TextStyle(
                  color:
                      AppColors.textSecondary,
                  fontSize: 9,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// ===============================================================
/// LOADING / ERROR
/// ===============================================================

class _DashboardLoading
    extends StatelessWidget {
  const _DashboardLoading();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child:
          CircularProgressIndicator(
        strokeWidth: 2,
      ),
    );
  }
}

class _DashboardError
    extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _DashboardError({
    required this.message,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding:
            const EdgeInsets.all(24),
        child: Container(
          padding:
              const EdgeInsets.all(18),
          decoration:
              BoxDecoration(
            color:
                Colors.white,
            borderRadius:
                BorderRadius.circular(18),
            border:
                Border.all(
              color:
                  AppColors.error
                      .withValues(alpha: .18),
            ),
          ),
          child: Column(
            mainAxisSize:
                MainAxisSize.min,
            children: [
              const Icon(
                Icons.error_outline_rounded,
                color:
                    AppColors.error,
                size: 42,
              ),

              const SizedBox(height: 10),

              const Text(
                'Unable to load dashboard',
                style:
                    TextStyle(
                  fontSize: 15,
                  fontWeight:
                      FontWeight.w900,
                ),
              ),

              const SizedBox(height: 7),

              Text(
                message,
                textAlign:
                    TextAlign.center,
                style:
                    const TextStyle(
                  color:
                      AppColors.textSecondary,
                  fontSize: 10,
                ),
              ),

              const SizedBox(height: 14),

              FilledButton(
                onPressed:
                    onRetry,
                child:
                    const Text(
                  'Retry',
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
