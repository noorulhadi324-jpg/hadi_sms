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
  int? _schoolId;

  @override
  void initState() {
    super.initState();
    _loadAcademicData();
  }

  Future<int?> _getSchoolId() async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return null;
    final profile = await _client.from('profiles').select('school_id').eq('id', userId).maybeSingle();
    final value = profile?['school_id'];
    return value is int ? value : int.tryParse(value?.toString() ?? '');
  }

  Future<void> _loadAcademicData() async {
    setState(() { _loading = true; _error = null; });
    try {
      final schoolId = await _getSchoolId();
      if (schoolId == null) throw Exception('Account not linked to school.');
      
      final results = await Future.wait([
        _client.from('classes').select('id, class_name, numeric_level').eq('school_id', schoolId).order('numeric_level'),
        _client.from('academic_sessions').select().eq('school_id', schoolId).order('start_date', ascending: false),
      ]);

      if (!mounted) return;
      setState(() {
        _schoolId = schoolId;
        _classes = List<Map<String, dynamic>>.from(results[0] as List);
        _sessions = List<Map<String, dynamic>>.from(results[1] as List);
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() { _error = e.toString(); _loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return MainWrapper(
      child: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          _buildHeader(),
          const SizedBox(height: 24),
          _buildActiveSession(),
          const SizedBox(height: 32),
          _buildSectionHeader('School Hierarchy', 'Manage your classes and sections.'),
          const SizedBox(height: 16),
          _buildClassGrid(),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      children: [
        const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Academic Hub', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900, letterSpacing: -0.5)),
            Text('Configure your classes, subjects, and sessions.', style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
          ],
        ),
        const Spacer(),
        FilledButton.tonalIcon(
          onPressed: () {},
          icon: const Icon(Icons.add_rounded, size: 20),
          label: const Text('Add Class'),
        ),
      ],
    );
  }

  Widget _buildActiveSession() {
    final current = _sessions.where((s) => s['is_current'] == true).firstOrNull;
    return Card(
      color: AppColors.primary.withOpacity(0.04),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: AppColors.primary, borderRadius: BorderRadius.circular(14)),
              child: const Icon(Icons.calendar_today_rounded, color: Colors.white, size: 22),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Active Academic Session', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                  Text(current?['session_name'] ?? 'No current session', style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
                ],
              ),
            ),
            TextButton(onPressed: () {}, child: const Text('Manage Sessions')),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title, String sub) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
        Text(sub, style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
      ],
    );
  }

  Widget _buildClassGrid() {
    if (_loading) return _shimmerGrid();
    if (_classes.isEmpty) return _buildEmptyState();

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: _classes.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 16,
        crossAxisSpacing: 16,
        childAspectRatio: 1.3,
      ),
      itemBuilder: (context, index) {
        final c = _classes[index];
        return Card(
          child: InkWell(
            onTap: () {},
            borderRadius: BorderRadius.circular(20),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(c['class_name'], style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18)),
                      const Icon(Icons.arrow_forward_rounded, size: 16, color: AppColors.border),
                    ],
                  ),
                  const Spacer(),
                  Row(
                    children: [
                      const Icon(Icons.people_outline_rounded, size: 14, color: AppColors.textSecondary),
                      const SizedBox(width: 4),
                      const Text('— students', style: TextStyle(color: AppColors.textSecondary, fontSize: 11, fontWeight: FontWeight.w600)),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(color: AppColors.background, borderRadius: BorderRadius.circular(6)),
                        child: Text('Level ${c['numeric_level'] ?? '?' }', style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w800)),
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
  }

  Widget _shimmerGrid() {
    return Shimmer.fromColors(
      baseColor: Colors.grey.shade100, highlightColor: Colors.white,
      child: GridView.count(
        shrinkWrap: true, crossAxisCount: 2, mainAxisSpacing: 16, crossAxisSpacing: 16,
        children: List.generate(4, (i) => Container(decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20)))),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 48),
      alignment: Alignment.center,
      child: const Text('No classes registered yet.', style: TextStyle(color: AppColors.textSecondary)),
    );
  }
}
