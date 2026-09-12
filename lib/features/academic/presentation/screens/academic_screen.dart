import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/network/supabase_client.dart';
import '../../../../core/widgets/main_wrapper.dart';

class AcademicScreen extends StatefulWidget {
  const AcademicScreen({super.key});

  @override
  State<AcademicScreen> createState() => _AcademicScreenState();
}

class _AcademicScreenState extends State<AcademicScreen> {
  final _client = SupabaseConfig.client;
  bool _loading = true;
  String? _error;

  List<Map<String, dynamic>> _classes = [];
  List<Map<String, dynamic>> _sessions = [];

  @override
  void initState() {
    super.initState();
    _loadAcademicData();
  }

  Future<int?> _getSchoolId() async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return null;
    final profile = await _client
        .from('profiles')
        .select('school_id')
        .eq('id', userId)
        .maybeSingle();
    final value = profile?['school_id'];
    return value is int ? value : int.tryParse(value?.toString() ?? '');
  }

  Future<void> _loadAcademicData() async {
    if (mounted) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }

    try {
      final schoolId = await _getSchoolId();
      if (schoolId == null) {
        throw Exception('Account not linked to school.');
      }

      final results = await Future.wait([
        _client
            .from('classes')
            .select('id, class_name, numeric_level')
            .eq('school_id', schoolId)
            .order('numeric_level'),
        _client
            .from('academic_sessions')
            .select()
            .eq('school_id', schoolId)
            .order('start_date', ascending: false),
      ]);

      if (!mounted) return;
      setState(() {
        _classes = List<Map<String, dynamic>>.from(results[0] as List);
        _sessions = List<Map<String, dynamic>>.from(results[1] as List);
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return MainWrapper(
      child: RefreshIndicator(
        onRefresh: _loadAcademicData,
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            _buildHeader(context),
            const SizedBox(height: 24),
            _buildActiveSession(context),
            const SizedBox(height: 32),
            _buildSectionHeader(
              context,
              'School Hierarchy',
              'Manage your classes and sections.',
            ),
            const SizedBox(height: 16),
            _buildClassGrid(context),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 620;
        final title = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Academic Hub',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.5,
                  ),
            ),
            const SizedBox(height: 4),
            Text(
              'Configure your classes, subjects, and sessions.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.textSecondary,
                  ),
            ),
          ],
        );

        final addButton = FilledButton.tonalIcon(
          onPressed: () {},
          icon: const Icon(Icons.add_rounded, size: 20),
          label: const Text('Add Class'),
        );

        if (compact) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              title,
              const SizedBox(height: 14),
              SizedBox(width: double.infinity, child: addButton),
            ],
          );
        }

        return Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(child: title),
            const SizedBox(width: 16),
            addButton,
          ],
        );
      },
    );
  }

  Widget _buildActiveSession(BuildContext context) {
    final current = _sessions.where((s) => s['is_current'] == true).firstOrNull;

    return Card(
      color: AppColors.primary.withOpacity(0.04),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final compact = constraints.maxWidth < 520;
            final content = Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(
                    Icons.calendar_today_rounded,
                    color: Colors.white,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Active Academic Session',
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                      ),
                      Text(
                        current?['session_name']?.toString() ?? 'No current session',
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
                if (!compact)
                  TextButton(
                    onPressed: () {},
                    child: const Text('Manage Sessions'),
                  ),
              ],
            );

            if (!compact) return content;

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                content,
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: () {},
                    child: const Text('Manage Sessions'),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildSectionHeader(BuildContext context, String title, String sub) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w800,
              ),
        ),
        const SizedBox(height: 3),
        Text(
          sub,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: AppColors.textSecondary,
              ),
        ),
      ],
    );
  }

  Widget _buildClassGrid(BuildContext context) {
    if (_loading) return _shimmerGrid();
    if (_error != null) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              const Icon(Icons.error_outline_rounded, size: 36),
              const SizedBox(height: 10),
              const Text('Unable to load academic data.'),
              const SizedBox(height: 10),
              TextButton.icon(
                onPressed: _loadAcademicData,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }
    if (_classes.isEmpty) return _buildEmptyState();

    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 1000
            ? 4
            : constraints.maxWidth >= 620
                ? 3
                : constraints.maxWidth >= 360
                    ? 2
                    : 1;

        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: _classes.length,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: columns,
            mainAxisSpacing: 16,
            crossAxisSpacing: 16,
            childAspectRatio: columns == 1 ? 2.7 : 1.3,
          ),
          itemBuilder: (context, index) {
            final c = _classes[index];
            final className = c['class_name']?.toString() ?? 'Unnamed Class';
            final level = c['numeric_level']?.toString() ?? '?';

            return Card(
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                onTap: () {},
                borderRadius: BorderRadius.circular(20),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              className,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontWeight: FontWeight.w900,
                                fontSize: 18,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          const Icon(
                            Icons.arrow_forward_rounded,
                            size: 16,
                            color: AppColors.border,
                          ),
                        ],
                      ),
                      const Spacer(),
                      Row(
                        children: [
                          const Icon(
                            Icons.people_outline_rounded,
                            size: 14,
                            color: AppColors.textSecondary,
                          ),
                          const SizedBox(width: 4),
                          const Expanded(
                            child: Text(
                              '— students',
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: AppColors.textSecondary,
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.background,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              'Level $level',
                              style: const TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _shimmerGrid() {
    return Shimmer.fromColors(
      baseColor: Colors.grey.shade100,
      highlightColor: Colors.white,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final columns = constraints.maxWidth >= 1000
              ? 4
              : constraints.maxWidth >= 620
                  ? 3
                  : constraints.maxWidth >= 360
                      ? 2
                      : 1;
          return GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: columns,
            mainAxisSpacing: 16,
            crossAxisSpacing: 16,
            childAspectRatio: columns == 1 ? 2.7 : 1.3,
            children: List.generate(
              4,
              (i) => Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildEmptyState() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 48),
      alignment: Alignment.center,
      child: const Text(
        'No classes registered yet.',
        style: TextStyle(color: AppColors.textSecondary),
      ),
    );
  }
}
