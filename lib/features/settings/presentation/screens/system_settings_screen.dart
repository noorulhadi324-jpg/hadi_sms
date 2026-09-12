import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/network/supabase_client.dart';
import '../../../../core/widgets/main_wrapper.dart';

final systemSettingsDataProvider = FutureProvider.autoDispose<Map<String, dynamic>>((ref) async {
  final client = SupabaseConfig.client;
  final user = client.auth.currentUser;
  if (user == null) throw Exception('No authenticated user.');
  final profile = await client.from('profiles').select('school_id,role,is_active').eq('id', user.id).single();
  final schoolId = (profile['school_id'] as num?)?.toInt();
  if (schoolId == null) throw Exception('No school linked with your account.');
  final school = await client.from('schools').select('id,school_name').eq('id', schoolId).single();
  final settings = await client.from('school_settings').select('notifications_enabled,dark_mode,auto_backup').eq('school_id', schoolId).maybeSingle();
  final sessions = await client.from('academic_sessions').select('id,name,start_date,end_date,is_current').eq('school_id', schoolId).order('start_date', ascending: false);
  final fees = await client.from('fee_categories').select('id,name,amount,description,is_active').eq('school_id', schoolId).order('name');
  return {'school_id': schoolId, 'role': profile['role'], 'school': school, 'settings': settings, 'sessions': sessions, 'fees': fees};
});

class SystemSettingsScreen extends ConsumerWidget {
  const SystemSettingsScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(systemSettingsDataProvider);
    return MainWrapper(child: async.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Column(mainAxisSize: MainAxisSize.min, children: [Text('$e'), const SizedBox(height: 12), FilledButton(onPressed: () => ref.invalidate(systemSettingsDataProvider), child: const Text('Retry'))])),
      data: (data) => _Body(data: data),
    ));
  }
}

class _Body extends ConsumerStatefulWidget {
  final Map<String, dynamic> data;
  const _Body({required this.data});
  @override ConsumerState<_Body> createState() => _BodyState();
}

class _BodyState extends ConsumerState<_Body> {
  int tab = 0;
  late final TextEditingController schoolName;
  late bool notifications;
  late bool darkMode;
  late bool backup;

  int get schoolId => (widget.data['school_id'] as num).toInt();
  bool get canManage => ['principal', 'staff'].contains(widget.data['role']?.toString());

  @override
  void initState() {
    super.initState();
    final school = Map<String, dynamic>.from(widget.data['school'] as Map);
    final s = widget.data['settings'] == null ? <String, dynamic>{} : Map<String, dynamic>.from(widget.data['settings'] as Map);
    schoolName = TextEditingController(text: school['school_name']?.toString() ?? '');
    notifications = s['notifications_enabled'] != false;
    darkMode = s['dark_mode'] == true;
    backup = s['auto_backup'] != false;
  }

  @override void dispose() { schoolName.dispose(); super.dispose(); }

  Future<void> saveGeneral() async {
    try {
      await SupabaseConfig.client.from('school_settings').update({'notifications_enabled': notifications, 'dark_mode': darkMode, 'auto_backup': backup}).eq('school_id', schoolId);
      _ok('General settings saved.');
    } catch (e) { _error('$e'); }
  }

  Future<void> saveSchool() async {
    if (schoolName.text.trim().isEmpty) { _error('School name is required.'); return; }
    try {
      await SupabaseConfig.client.from('schools').update({'school_name': schoolName.text.trim()}).eq('id', schoolId);
      _ok('School profile updated.');
    } catch (e) { _error('$e'); }
  }

  Future<void> addSession() async {
    final name = TextEditingController();
    final result = await showDialog<bool>(context: context, builder: (d) => AlertDialog(title: const Text('Academic Session'), content: TextField(controller: name, decoration: const InputDecoration(labelText: 'Name', hintText: '2026-27')), actions: [TextButton(onPressed: () => Navigator.pop(d, false), child: const Text('Cancel')), FilledButton(onPressed: () => Navigator.pop(d, true), child: const Text('Add'))]));
    if (result != true) { name.dispose(); return; }
    if (name.text.trim().isEmpty) { name.dispose(); _error('Session name is required.'); return; }
    try {
      final now = DateTime.now();
      await SupabaseConfig.client.from('academic_sessions').insert({'school_id': schoolId, 'name': name.text.trim(), 'start_date': '${now.year}-04-01', 'end_date': '${now.year + 1}-03-31'});
      ref.invalidate(systemSettingsDataProvider);
    } catch (e) { _error('$e'); }
    name.dispose();
  }

  Future<void> currentSession(int id) async {
    try { await SupabaseConfig.client.rpc('set_current_academic_session', params: {'p_session_id': id}); ref.invalidate(systemSettingsDataProvider); } catch (e) { _error('$e'); }
  }

  Future<void> deleteSession(int id) async {
    try { await SupabaseConfig.client.from('academic_sessions').delete().eq('id', id).eq('school_id', schoolId); ref.invalidate(systemSettingsDataProvider); } catch (e) { _error('$e'); }
  }

  Future<void> addFee() async {
    final name = TextEditingController();
    final amount = TextEditingController();
    final result = await showDialog<bool>(context: context, builder: (d) => AlertDialog(title: const Text('Fee Structure'), content: Column(mainAxisSize: MainAxisSize.min, children: [TextField(controller: name, decoration: const InputDecoration(labelText: 'Fee name')), const SizedBox(height: 10), TextField(controller: amount, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Amount'))]), actions: [TextButton(onPressed: () => Navigator.pop(d, false), child: const Text('Cancel')), FilledButton(onPressed: () => Navigator.pop(d, true), child: const Text('Save'))]));
    if (result != true) { name.dispose(); amount.dispose(); return; }
    final value = double.tryParse(amount.text.trim());
    if (name.text.trim().isEmpty || value == null) { name.dispose(); amount.dispose(); _error('Enter a valid fee name and amount.'); return; }
    try { await SupabaseConfig.client.from('fee_categories').insert({'school_id': schoolId, 'name': name.text.trim(), 'amount': value, 'is_active': true}); ref.invalidate(systemSettingsDataProvider); } catch (e) { _error('$e'); }
    name.dispose(); amount.dispose();
  }

  Future<void> deleteFee(int id) async { try { await SupabaseConfig.client.from('fee_categories').delete().eq('id', id).eq('school_id', schoolId); ref.invalidate(systemSettingsDataProvider); } catch (e) { _error('$e'); } }
  void _ok(String s) { if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(s), backgroundColor: AppColors.success)); }
  void _error(String s) { if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(s.replaceFirst('Exception: ', '')), backgroundColor: Colors.redAccent)); }

  @override
  Widget build(BuildContext context) {
    final sessions = List<Map<String, dynamic>>.from(widget.data['sessions'] as List);
    final fees = List<Map<String, dynamic>>.from(widget.data['fees'] as List);
    return LayoutBuilder(builder: (context, c) => ListView(padding: EdgeInsets.all(c.maxWidth < 700 ? 16 : 28), children: [
      _hero(), const SizedBox(height: 18),
      SingleChildScrollView(scrollDirection: Axis.horizontal, child: SegmentedButton<int>(segments: const [ButtonSegment(value: 0, label: Text('General')), ButtonSegment(value: 1, label: Text('School')), ButtonSegment(value: 2, label: Text('Academic')), ButtonSegment(value: 3, label: Text('Fees')), ButtonSegment(value: 4, label: Text('Users'))], selected: {tab}, onSelectionChanged: (v) => setState(() => tab = v.first))),
      const SizedBox(height: 18),
      if (tab == 0) _general(),
      if (tab == 1) _school(),
      if (tab == 2) _academic(sessions),
      if (tab == 3) _fees(fees),
      if (tab == 4) _users(),
    ]));
  }

  Widget _hero() => Container(padding: const EdgeInsets.all(22), decoration: BoxDecoration(color: AppColors.primary, borderRadius: BorderRadius.circular(22)), child: const Row(children: [Icon(Icons.tune_rounded, color: Colors.white, size: 32), SizedBox(width: 14), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('System Settings', style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w900)), SizedBox(height: 4), Text('Connected school configuration', style: TextStyle(color: Colors.white70, fontSize: 12))]))]));
  Widget _general() => _panel('General', Icons.settings_rounded, [SwitchListTile.adaptive(value: notifications, onChanged: canManage ? (v) => setState(() => notifications = v) : null, title: const Text('Notifications')), SwitchListTile.adaptive(value: darkMode, onChanged: canManage ? (v) => setState(() => darkMode = v) : null, title: const Text('Dark mode preference')), SwitchListTile.adaptive(value: backup, onChanged: canManage ? (v) => setState(() => backup = v) : null, title: const Text('Automatic backup preference')), if (canManage) FilledButton.icon(onPressed: saveGeneral, icon: const Icon(Icons.save_rounded), label: const Text('Save'))]);
  Widget _school() => _panel('School Profile', Icons.school_rounded, [TextField(controller: schoolName, enabled: canManage, decoration: const InputDecoration(labelText: 'School name')), const SizedBox(height: 12), Text('School ID: $schoolId', style: const TextStyle(color: AppColors.textMuted)), if (canManage) ...[const SizedBox(height: 12), FilledButton.icon(onPressed: saveSchool, icon: const Icon(Icons.save_rounded), label: const Text('Save'))]]);
  Widget _academic(List<Map<String, dynamic>> list) => _panel('Academic Sessions', Icons.calendar_month_rounded, [if (canManage) Align(alignment: Alignment.centerRight, child: FilledButton.icon(onPressed: addSession, icon: const Icon(Icons.add_rounded), label: const Text('Add'))), if (list.isEmpty) const _Empty(text: 'No academic session configured.'), ...list.map((s) => Card(elevation: 0, child: ListTile(title: Text(s['name']?.toString() ?? '', style: const TextStyle(fontWeight: FontWeight.w800)), subtitle: Text('${s['start_date']} → ${s['end_date']}'), leading: Icon(s['is_current'] == true ? Icons.check_circle : Icons.calendar_today, color: s['is_current'] == true ? AppColors.success : AppColors.primary), trailing: canManage ? Row(mainAxisSize: MainAxisSize.min, children: [if (s['is_current'] != true) IconButton(onPressed: () => currentSession((s['id'] as num).toInt()), icon: const Icon(Icons.radio_button_checked_rounded)), IconButton(onPressed: () => deleteSession((s['id'] as num).toInt()), icon: const Icon(Icons.delete_outline, color: Colors.redAccent))]) : null)))]);
  Widget _fees(List<Map<String, dynamic>> list) => _panel('Fee Structures', Icons.payments_rounded, [if (canManage) Align(alignment: Alignment.centerRight, child: FilledButton.icon(onPressed: addFee, icon: const Icon(Icons.add_rounded), label: const Text('Add'))), if (list.isEmpty) const _Empty(text: 'No fee structure configured.'), ...list.map((f) => Card(elevation: 0, child: ListTile(title: Text(f['name']?.toString() ?? '', style: const TextStyle(fontWeight: FontWeight.w800)), subtitle: Text('Amount: ${f['amount']}'), trailing: canManage ? IconButton(onPressed: () => deleteFee((f['id'] as num).toInt()), icon: const Icon(Icons.delete_outline, color: Colors.redAccent)) : null)))]);
  Widget _users() => _panel('Users & Communication', Icons.groups_rounded, [const Text('Passwords are never displayed in settings. Use the dedicated modules for account management.'), const SizedBox(height: 10), _nav('Teachers', Icons.school_rounded, '/teacher'), _nav('Parents', Icons.family_restroom_rounded, '/parent'), _nav('Staff & Team', Icons.badge_rounded, '/staff'), _nav('Communication', Icons.forum_rounded, '/communication')]);
  Widget _nav(String title, IconData icon, String route) => Card(elevation: 0, child: ListTile(leading: Icon(icon, color: AppColors.primary), title: Text(title, style: const TextStyle(fontWeight: FontWeight.w800)), trailing: const Icon(Icons.chevron_right_rounded), onTap: () => context.go(route)));
  Widget _panel(String title, IconData icon, List<Widget> children) => Card(elevation: 0, child: Padding(padding: const EdgeInsets.all(18), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Row(children: [Icon(icon, color: AppColors.primary), const SizedBox(width: 10), Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900))]), const SizedBox(height: 12), ...children])));
}

class _Empty extends StatelessWidget {
  final String text;
  const _Empty({required this.text});
  @override Widget build(BuildContext context) => Padding(padding: const EdgeInsets.all(18), child: Text(text, style: const TextStyle(color: AppColors.textSecondary)));
}
