import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/network/supabase_client.dart';
import '../../../../core/widgets/main_wrapper.dart';

class ClassroomsScreen extends StatefulWidget {
  const ClassroomsScreen({super.key});

  @override
  State<ClassroomsScreen> createState() => _ClassroomsScreenState();
}

class _ClassroomsScreenState extends State<ClassroomsScreen> {
  final SupabaseClient _client = SupabaseConfig.client;

  bool _loading = true;
  String? _error;
  int? _schoolId;
  List<Map<String, dynamic>> _classes = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<int?> _getSchoolId() async {
    try {
      final result = await _client.rpc('get_my_school_id');
      if (result is int) return result;
      if (result is num) return result.toInt();
      final parsed = int.tryParse(result?.toString() ?? '');
      if (parsed != null) return parsed;
    } catch (e) {
      debugPrint('get_my_school_id failed: $e');
    }

    final userId = _client.auth.currentUser?.id;
    if (userId == null) return null;

    try {
      final profile = await _client
          .from('profiles')
          .select('school_id')
          .eq('id', userId)
          .maybeSingle();
      final value = profile?['school_id'];
      if (value is int) return value;
      return int.tryParse(value?.toString() ?? '');
    } catch (e) {
      debugPrint('Profile school lookup failed: $e');
      return null;
    }
  }

  Future<void> _load() async {
    if (!mounted) return;
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final schoolId = await _getSchoolId();
      if (schoolId == null) {
        throw Exception('Your account is not linked to a school.');
      }

      final rows = await _client
          .from('classes')
          .select('id, school_id, name, section_name, created_at, updated_at')
          .eq('school_id', schoolId)
          .order('name')
          .order('section_name');

      if (!mounted) return;
      setState(() {
        _schoolId = schoolId;
        _classes = List<Map<String, dynamic>>.from(rows);
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = _friendlyError(e);
        _loading = false;
      });
    }
  }

  String _friendlyError(Object error) {
    if (error is PostgrestException) return error.message;
    return error.toString().replaceFirst('Exception: ', '');
  }

  Future<void> _showEditor([Map<String, dynamic>? existing]) async {
    final nameController = TextEditingController(
      text: existing?['name']?.toString() ?? '',
    );
    final sectionController = TextEditingController(
      text: existing?['section_name']?.toString() ?? '',
    );
    String? dialogError;
    bool saving = false;

    final saved = await showDialog<bool>(
      context: context,
      barrierDismissible: !saving,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(existing == null ? 'Add class' : 'Edit class'),
          content: SizedBox(
            width: 420,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController,
                  autofocus: true,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(
                    labelText: 'Class name',
                    hintText: 'e.g. Grade 8',
                    prefixIcon: Icon(Icons.school_outlined),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: sectionController,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(
                    labelText: 'Section',
                    hintText: 'e.g. A (optional)',
                    prefixIcon: Icon(Icons.segment_rounded),
                  ),
                ),
                if (dialogError != null) ...[
                  const SizedBox(height: 14),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      dialogError!,
                      style: TextStyle(color: Theme.of(context).colorScheme.error),
                    ),
                  ),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: saving ? null : () => Navigator.pop(dialogContext, false),
              child: const Text('Cancel'),
            ),
            FilledButton.icon(
              onPressed: saving
                  ? null
                  : () async {
                      final name = nameController.text.trim();
                      final section = sectionController.text.trim();
                      if (name.isEmpty) {
                        setDialogState(() => dialogError = 'Class name is required.');
                        return;
                      }
                      final schoolId = _schoolId;
                      if (schoolId == null) {
                        setDialogState(() => dialogError = 'School link is missing.');
                        return;
                      }

                      setDialogState(() {
                        saving = true;
                        dialogError = null;
                      });

                      try {
                        final payload = <String, dynamic>{
                          'school_id': schoolId,
                          'name': name,
                          'section_name': section.isEmpty ? null : section,
                        };

                        if (existing == null) {
                          await _client.from('classes').insert(payload);
                        } else {
                          await _client
                              .from('classes')
                              .update(payload)
                              .eq('id', existing['id']);
                        }

                        if (dialogContext.mounted) {
                          Navigator.pop(dialogContext, true);
                        }
                      } catch (e) {
                        setDialogState(() {
                          saving = false;
                          dialogError = _friendlyError(e);
                        });
                      }
                    },
              icon: saving
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.save_outlined),
              label: Text(existing == null ? 'Create' : 'Save'),
            ),
          ],
        ),
      ),
    );

    nameController.dispose();
    sectionController.dispose();
    if (saved == true) await _load();
  }

  Future<void> _delete(Map<String, dynamic> item) async {
    final label = _classLabel(item);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete class?'),
        content: Text(
          'Delete $label? This is only allowed when no protected school records depend on it.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      await _client.from('classes').delete().eq('id', item['id']);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$label deleted.')),
      );
      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_friendlyError(e))),
      );
    }
  }

  String _classLabel(Map<String, dynamic> item) {
    final name = item['name']?.toString().trim() ?? 'Class';
    final section = item['section_name']?.toString().trim() ?? '';
    return section.isEmpty ? name : '$name — $section';
  }

  @override
  Widget build(BuildContext context) {
    return MainWrapper(
      child: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(24),
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(
                    Icons.meeting_room_rounded,
                    color: Colors.white,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 16),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Classrooms',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                          letterSpacing: -0.5,
                        ),
                      ),
                      Text(
                        'Manage your school classes and sections.',
                        style: TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
                FilledButton.icon(
                  onPressed: _loading || _schoolId == null ? null : () => _showEditor(),
                  icon: const Icon(Icons.add_rounded),
                  label: const Text('Add class'),
                ),
              ],
            ),
            const SizedBox(height: 24),
            if (_loading)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 80),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_error != null)
              _ErrorCard(message: _error!, onRetry: _load)
            else if (_classes.isEmpty)
              _EmptyCard(onAdd: () => _showEditor())
            else ...[
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  _SummaryChip(
                    icon: Icons.school_outlined,
                    label: '${_classes.length} ${_classes.length == 1 ? 'class' : 'classes'}',
                  ),
                  _SummaryChip(
                    icon: Icons.segment_rounded,
                    label: '${_classes.where((e) => (e['section_name']?.toString().trim() ?? '').isNotEmpty).length} sections',
                  ),
                ],
              ),
              const SizedBox(height: 18),
              Card(
                child: Column(
                  children: [
                    for (var i = 0; i < _classes.length; i++) ...[
                      ListTile(
                        leading: CircleAvatar(
                          backgroundColor: AppColors.primary.withValues(alpha: 0.10),
                          foregroundColor: AppColors.primary,
                          child: const Icon(Icons.class_outlined),
                        ),
                        title: Text(
                          _classes[i]['name']?.toString() ?? 'Unnamed class',
                          style: const TextStyle(fontWeight: FontWeight.w800),
                        ),
                        subtitle: Text(
                          (_classes[i]['section_name']?.toString().trim() ?? '').isEmpty
                              ? 'No section'
                              : 'Section ${_classes[i]['section_name']}',
                        ),
                        trailing: PopupMenuButton<String>(
                          onSelected: (value) {
                            if (value == 'edit') _showEditor(_classes[i]);
                            if (value == 'delete') _delete(_classes[i]);
                          },
                          itemBuilder: (context) => const [
                            PopupMenuItem(
                              value: 'edit',
                              child: ListTile(
                                leading: Icon(Icons.edit_outlined),
                                title: Text('Edit'),
                                contentPadding: EdgeInsets.zero,
                              ),
                            ),
                            PopupMenuItem(
                              value: 'delete',
                              child: ListTile(
                                leading: Icon(Icons.delete_outline),
                                title: Text('Delete'),
                                contentPadding: EdgeInsets.zero,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (i != _classes.length - 1) const Divider(height: 1),
                    ],
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _SummaryChip extends StatelessWidget {
  const _SummaryChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: AppColors.primary.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 18, color: AppColors.primary),
            const SizedBox(width: 8),
            Text(label, style: const TextStyle(fontWeight: FontWeight.w700)),
          ],
        ),
      );
}

class _EmptyCard extends StatelessWidget {
  const _EmptyCard({required this.onAdd});

  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) => Card(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 56),
          child: Column(
            children: [
              const Icon(Icons.meeting_room_outlined, size: 48, color: AppColors.textMuted),
              const SizedBox(height: 14),
              const Text(
                'No classes yet',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 6),
              const Text(
                'Create the first class or section for this school.',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.textSecondary),
              ),
              const SizedBox(height: 18),
              FilledButton.icon(
                onPressed: onAdd,
                icon: const Icon(Icons.add_rounded),
                label: const Text('Add class'),
              ),
            ],
          ),
        ),
      );
}

class _ErrorCard extends StatelessWidget {
  const _ErrorCard({required this.message, required this.onRetry});

  final String message;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) => Card(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              Icon(Icons.error_outline, color: Theme.of(context).colorScheme.error, size: 40),
              const SizedBox(height: 12),
              Text(message, textAlign: TextAlign.center),
              const SizedBox(height: 16),
              OutlinedButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
}
