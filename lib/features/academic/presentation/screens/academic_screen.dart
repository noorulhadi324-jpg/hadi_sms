import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
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
    if (mounted) setState(() { _loading = true; _error = null; });
    try {
      final schoolId = await _getSchoolId();
      if (schoolId == null) throw Exception('Account not linked to school.');
      final results = await Future.wait([
        _client.from('classes').select('id, name, section_name').eq('school_id', schoolId).order('name'),
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
      child: RefreshIndicator(
        onRefresh: _loadAcademicData,
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            _buildHeader(context),
            const SizedBox(height: 24),
            _buildActiveSession(context),
            const SizedBox(height: 32),
            _buildSectionHeader(context, 'School Hierarchy', 'Manage your classes and sections.'),
            const SizedBox(height: 16),
            _buildClassGrid(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      final compact = constraints.maxWidth < 620;
      final title = Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Academic Hub', style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w900, letterSpacing: -0.5)),
        const SizedBox(height: 4),
        Text('Configure your classes, subjects, and sessions.', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary)),
      ]);
      final addButton = FilledButton.tonalIcon(onPressed: () => context.go('/student'), icon: const Icon(Icons.add_rounded, size: 20), label: const Text('Add Class'));
      if (compact) return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [title, const SizedBox(height: 14), SizedBox(width: double.infinity, child: addButton)]);
      return Row(children: [Expanded(child: title), const SizedBox(width: 16), addButton]);
    });
  }

  Widget _buildActiveSession(BuildContext context) {
    final current = _sessions.where((s) => s['is_current'] == true).firstOrNull;
    return Card(
      color: AppColors.primary.withValues(alpha: 0.04),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: LayoutBuilder(builder: (context, constraints) {
          final compact = constraints.maxWidth < 520;
          final content = Row(children: [
            Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: AppColors.primary, borderRadius: BorderRadius.circular(14)), child: const Icon(Icons.calendar_today_rounded, color: Colors.white, size: 22)),
            const SizedBox(width: 16),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Active Academic Session', overflow: TextOverflow.ellipsis, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
              Text(current?['name']?.toString() ?? 'No current session', overflow: TextOverflow.ellipsis, style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
            ])),
            if (!compact) TextButton(onPressed: _manageSessions, child: const Text('Manage Sessions')),
          ]);
          if (!compact) return content;
          return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [content, const SizedBox(height: 8), SizedBox(width: double.infinity, child: OutlinedButton(onPressed: _manageSessions, child: const Text('Manage Sessions')))]);
        }),
      ),
    );
  }

  Future<void> _manageSessions() async {
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Academic sessions'),
        content: SizedBox(
          width: 480,
          child: _sessions.isEmpty
              ? const Text('No sessions have been created.')
              : ListView(
                  shrinkWrap: true,
                  children: _sessions.map((session) {
                    final current = session['is_current'] == true;
                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(session['name']?.toString() ?? 'Session'),
                      subtitle: Text('${session['start_date']} to ${session['end_date']}'),
                      trailing: current
                          ? const Chip(label: Text('Current'))
                          : TextButton(
                              onPressed: () async {
                                try {
                                  await _client.rpc('set_current_academic_session', params: {'p_session_id': session['id']});
                                  if (dialogContext.mounted) Navigator.pop(dialogContext);
                                  await _loadAcademicData();
                                } catch (error) {
                                  if (dialogContext.mounted) {
                                    ScaffoldMessenger.of(dialogContext).showSnackBar(SnackBar(content: Text('Could not change session: $error')));
                                  }
                                }
                              },
                              child: const Text('Set current'),
                            ),
                    );
                  }).toList(),
                ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Close')),
          FilledButton.icon(
            onPressed: () async {
              Navigator.pop(dialogContext);
              await _createSession();
            },
            icon: const Icon(Icons.add_rounded),
            label: const Text('Add session'),
          ),
        ],
      ),
    );
  }

  Future<void> _createSession() async {
    final name = TextEditingController();
    final start = TextEditingController(text: '${DateTime.now().year}-04-01');
    final end = TextEditingController(text: '${DateTime.now().year + 1}-03-31');
    final saved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Add academic session'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: name, decoration: const InputDecoration(labelText: 'Session name', hintText: '2026-2027')),
            TextField(controller: start, decoration: const InputDecoration(labelText: 'Start date (YYYY-MM-DD)')),
            TextField(controller: end, decoration: const InputDecoration(labelText: 'End date (YYYY-MM-DD)')),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Cancel')),
          FilledButton(
            onPressed: () async {
              final schoolId = _schoolId;
              final startDate = DateTime.tryParse(start.text.trim());
              final endDate = DateTime.tryParse(end.text.trim());
              if (schoolId == null || name.text.trim().isEmpty || startDate == null || endDate == null || endDate.isBefore(startDate)) {
                ScaffoldMessenger.of(dialogContext).showSnackBar(const SnackBar(content: Text('Enter a session name and valid date range.')));
                return;
              }
              try {
                await _client.from('academic_sessions').insert({
                  'school_id': schoolId,
                  'name': name.text.trim(),
                  'start_date': start.text.trim(),
                  'end_date': end.text.trim(),
                  'is_current': false,
                });
                if (dialogContext.mounted) Navigator.pop(dialogContext, true);
              } catch (error) {
                if (dialogContext.mounted) ScaffoldMessenger.of(dialogContext).showSnackBar(SnackBar(content: Text('Could not save session: $error')));
              }
            },
            child: const Text('Save session'),
          ),
        ],
      ),
    );
    name.dispose();
    start.dispose();
    end.dispose();
    if (saved == true) await _loadAcademicData();
  }

  Widget _buildSectionHeader(BuildContext context, String title, String sub) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(title, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
      const SizedBox(height: 3),
      Text(sub, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary)),
    ]);
  }

  Widget _buildClassGrid() {
    if (_loading) return _shimmerGrid();
    if (_error != null) return Card(child: Padding(padding: const EdgeInsets.all(24), child: Column(children: [const Icon(Icons.error_outline_rounded, size: 36), const SizedBox(height: 10), const Text('Unable to load academic data.'), const SizedBox(height: 10), TextButton.icon(onPressed: _loadAcademicData, icon: const Icon(Icons.refresh_rounded), label: const Text('Retry'))])));
    if (_classes.isEmpty) return _buildEmptyState();
    return LayoutBuilder(builder: (context, constraints) {
      final columns = constraints.maxWidth >= 1000 ? 4 : constraints.maxWidth >= 620 ? 3 : constraints.maxWidth >= 360 ? 2 : 1;
      return GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: _classes.length,
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: columns, mainAxisSpacing: 16, crossAxisSpacing: 16, childAspectRatio: columns == 1 ? 2.7 : 1.3),
        itemBuilder: (context, index) {
          final c = _classes[index];
          final className = c['name']?.toString() ?? 'Unnamed Class';
          final sectionName = c['section_name']?.toString().trim() ?? '';
          return Card(clipBehavior: Clip.antiAlias, child: InkWell(onTap: () => context.go('/student'), borderRadius: BorderRadius.circular(20), child: Padding(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [Expanded(child: Text(className, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18))), const SizedBox(width: 8), const Icon(Icons.arrow_forward_rounded, size: 16, color: AppColors.border)]),
            const Spacer(),
            Row(children: [const Icon(Icons.segment_rounded, size: 14, color: AppColors.textSecondary), const SizedBox(width: 4), Expanded(child: Text(sectionName.isEmpty ? 'Manage class and students' : sectionName, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: AppColors.textSecondary, fontSize: 11, fontWeight: FontWeight.w600))), const Icon(Icons.arrow_forward_rounded, size: 15, color: AppColors.textSecondary)]),
          ]))));
        },
      );
    });
  }

  Widget _shimmerGrid() {
    return Shimmer.fromColors(baseColor: Colors.grey.shade100, highlightColor: Colors.white, child: LayoutBuilder(builder: (context, constraints) {
      final columns = constraints.maxWidth >= 1000 ? 4 : constraints.maxWidth >= 620 ? 3 : constraints.maxWidth >= 360 ? 2 : 1;
      return GridView.count(shrinkWrap: true, physics: const NeverScrollableScrollPhysics(), crossAxisCount: columns, mainAxisSpacing: 16, crossAxisSpacing: 16, childAspectRatio: columns == 1 ? 2.7 : 1.3, children: List.generate(4, (i) => Container(decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20)))));
    }));
  }

  Widget _buildEmptyState() => Container(padding: const EdgeInsets.symmetric(vertical: 48), alignment: Alignment.center, child: const Text('No classes registered yet.', style: TextStyle(color: AppColors.textSecondary)));
}
