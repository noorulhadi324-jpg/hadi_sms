import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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
  final school = await client.from('schools').select('id,school_name,registration_number,address,phone_number,email,logo_url').eq('id', schoolId).single();
  final settings = await client.from('school_settings').select('id,school_id,notifications_enabled,dark_mode,auto_backup').eq('school_id', schoolId).maybeSingle();
  final sessions = await client.from('academic_sessions').select('id,name,start_date,end_date,is_current').eq('school_id', schoolId).order('start_date', ascending: false);
  final fees = await client.from('fee_categories').select('id,name,amount,description,is_active').eq('school_id', schoolId).order('name');
  return {'school_id': schoolId, 'role': profile['role'], 'school': school, 'settings': settings, 'sessions': sessions, 'fees': fees};
});

class SystemSettingsScreen extends ConsumerWidget {
  const SystemSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final data = ref.watch(systemSettingsDataProvider);
    return MainWrapper(
      child: data.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Column(mainAxisSize: MainAxisSize.min, children: [const Icon(Icons.error_outline_rounded, color: Colors.redAccent, size: 50), const SizedBox(height: 12), Text('$e'), const SizedBox(height: 12), FilledButton(onPressed: () => ref.invalidate(systemSettingsDataProvider), child: const Text('Retry'))])),
        data: (value) => _SettingsBody(data: value),
      ),
    );
  }
}

class _SettingsBody extends ConsumerStatefulWidget {
  final Map<String, dynamic> data;
  const _SettingsBody({required this.data});

  @override
  ConsumerState<_SettingsBody> createState() => _SettingsBodyState();
}

class _SettingsBodyState extends ConsumerState<_SettingsBody> {
  int tab = 0;
  late final TextEditingController schoolName;
  late bool notifications;
  late bool darkMode;
  late bool backup;

  @override
  void initState() {
    super.initState();
    final school = Map<String, dynamic>.from(widget.data['school'] as Map);
    final settings = widget.data['settings'] == null ? <String, dynamic>{} : Map<String, dynamic>.from(widget.data['settings'] as Map);
    schoolName = TextEditingController(text: school['school_name']?.toString() ?? '');
    notifications = settings['notifications_enabled'] != false;
    darkMode = settings['dark_mode'] == true;
    backup = settings['auto_backup'] != false;
  }

  @override
  void dispose() {
    schoolName.dispose();
    super.dispose();
  }

  int get schoolId => (widget.data['school_id'] as num).toInt();
  String get role => widget.data['role']?.toString() ?? '';
  bool get canManage => role == 'principal' || role == 'staff';

  Future<void> _saveGeneral() async {
    await SupabaseConfig.client.from('school_settings').update({'notifications_enabled': notifications, 'dark_mode': darkMode, 'auto_backup': backup, 'updated_at': DateTime.now().toUtc().toIso8601String()}).eq('school_id', schoolId);
    _ok('General settings saved.');
  }

  Future<void> _saveSchool() async {
    if (schoolName.text.trim().isEmpty) return _error('School name is required.');
    await SupabaseConfig.client.from('schools').update({'school_name': schoolName.text.trim()}).eq('id', schoolId);
    _ok('School profile updated.');
  }

  Future<void> _addSession() async {
    final name = TextEditingController();
    DateTime start = DateTime(DateTime.now().year, 4, 1);
    DateTime end = DateTime(DateTime.now().year + 1, 3, 31);
    final result = await showDialog<bool>(context: context, builder: (dialogContext) => StatefulBuilder(builder: (context, setState) => AlertDialog(title: const Text('Add Academic Session'), content: Column(mainAxisSize: MainAxisSize.min, children: [TextField(controller: name, decoration: const InputDecoration(labelText: 'Session name', hintText: '2026-27')), const SizedBox(height: 12), ListTile(title: Text('Start: ${_date(start)}'), trailing: const Icon(Icons.calendar_month_rounded), onTap: () async { final d = await showDatePicker(context: context, firstDate: DateTime(2020), lastDate: DateTime(2040), initialDate: start); if (d != null) setState(() => start = d); }), ListTile(title: Text('End: ${_date(end)}'), trailing: const Icon(Icons.event_available_rounded), onTap: () async { final d = await showDatePicker(context: context, firstDate: start, lastDate: DateTime(2040), initialDate: end); if (d != null) setState(() => end = d); })]), actions: [TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Cancel')), FilledButton(onPressed: () => Navigator.pop(dialogContext, true), child: const Text('Add'))])));
    if (result != true) { name.dispose(); return; }
    if (name.text.trim().isEmpty) { name.dispose(); return _error('Session name is required.'); }
    try {
      await SupabaseConfig.client.from('academic_sessions').insert({'school_id': schoolId, 'name': name.text.trim(), 'start_date': _isoDate(start), 'end_date': _isoDate(end)});
      name.dispose();
      ref.invalidate(systemSettingsDataProvider);
    } catch (e) { name.dispose(); _error('$e'); }
  }

  Future<void> _setCurrent(int id) async {
    try {
      await SupabaseConfig.client.rpc('set_current_academic_session', params: {'p_session_id': id});
      ref.invalidate(systemSettingsDataProvider);
    } catch (e) { _error('$e'); }
  }

  Future<void> _deleteSession(int id) async {
    try {
      await SupabaseConfig.client.from('academic_sessions').delete().eq('id', id).eq('school_id', schoolId);
      ref.invalidate(systemSettingsDataProvider);
    } catch (e) { _error('$e'); }
  }

  Future<void> _addFee() async {
    final name = TextEditingController();
    final amount = TextEditingController();
    final description = TextEditingController();
    final result = await showDialog<bool>(context: context, builder: (dialogContext) => AlertDialog(title: const Text('Add Fee Structure'), content: Column(mainAxisSize: MainAxisSize.min, children: [TextField(controller: name, decoration: const InputDecoration(labelText: 'Fee name')), const SizedBox(height: 10), TextField(controller: amount, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Amount')), const SizedBox(height: 10), TextField(controller: description, decoration: const InputDecoration(labelText: 'Description'))]), actions: [TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Cancel')), FilledButton(onPressed: () => Navigator.pop(dialogContext, true), child: const Text('Save'))]));
    if (result != true) { name.dispose(); amount.dispose(); description.dispose(); return; }
    final value = double.tryParse(amount.text.trim());
    if (name.text.trim().isEmpty || value == null) { name.dispose(); amount.dispose(); description.dispose(); return _error('Enter a valid fee name and amount.'); }
    try {
      await SupabaseConfig.client.from('fee_categories').insert({'school_id': schoolId, 'name': name.text.trim(), 'amount': value, 'description': description.text.trim(), 'is_active': true});
      name.dispose(); amount.dispose(); description.dispose(); ref.invalidate(systemSettingsDataProvider);
    } catch (e) { name.dispose(); amount.dispose(); description.dispose(); _error('$e'); }
  }

  Future<void> _deleteFee(int id) async {
    try { await SupabaseConfig.client.from('fee_categories').delete().eq('id', id).eq('school_id', schoolId); ref.invalidate(systemSettingsDataProvider); } catch (e) { _error('$e'); }
  }

  void _ok(String text) { if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text), backgroundColor: AppColors.success)); }
  void _error(String text) { if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text.replaceFirst('Exception: ', '')), backgroundColor: Colors.redAccent)); }

  @override
  Widget build(BuildContext context) {
    final sessions = List<Map<String, dynamic>>.from(widget.data['sessions'] as List);
    final fees = List<Map<String, dynamic>>.from(widget.data['fees'] as List);
    return LayoutBuilder(builder: (context, c) {
      final mobile = c.maxWidth < 760;
      return ListView(padding: EdgeInsets.all(mobile ? 16 : 28), children: [
        Container(padding: const EdgeInsets.all(22), decoration: BoxDecoration(color: AppColors.primary, borderRadius: BorderRadius.circular(22)), child: const Row(children: [Icon(Icons.tune_rounded, color: Colors.white, size: 32), SizedBox(width: 14), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('System Settings', style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w900)), SizedBox(height: 4), Text('School, academic, finance and user configuration', style: TextStyle(color: Colors.white70, fontSize: 12))]))])),
        const SizedBox(height: 18),
        SingleChildScrollView(scrollDirection: Axis.horizontal, child: SegmentedButton<int>(segments: const [ButtonSegment(value: 0, label: Text('General'), icon: Icon(Icons.settings_rounded)), ButtonSegment(value: 1, label: Text('School'), icon: Icon(Icons.school_rounded)), ButtonSegment(value: 2, label: Text('Academic'), icon: Icon(Icons.calendar_month_rounded)), ButtonSegment(value: 3, label: Text('Fees'), icon: Icon(Icons.payments_rounded)), ButtonSegment(value: 4, label: Text('Users'), icon: Icon(Icons.groups_rounded))], selected: {tab}, onSelectionChanged: (v) => setState(() => tab = v.first))),
        const SizedBox(height: 18),
        if (tab == 0) _general(),
        if (tab == 1) _school(),
        if (tab == 2) _academic(sessions),
        if (tab == 3) _fees(fees),
        if (tab == 4) _users(),
      ]);
    });
  }

  Widget _general() => _panel('Application', Icons.settings_applications_rounded, [SwitchListTile.adaptive(value: notifications, onChanged: canManage ? (v) => setState(() => notifications = v) : null, title: const Text('Notifications'), subtitle: const Text('Enable school notifications and announcements')), SwitchListTile.adaptive(value: darkMode, onChanged: canManage ? (v) => setState(() => darkMode = v) : null, title: const Text('Dark mode preference'), subtitle: const Text('Stored as the school preference')), SwitchListTile.adaptive(value: backup, onChanged: canManage ? (v) => setState(() => backup = v) : null, title: const Text('Automatic backup preference'), subtitle: const Text('Keep automatic backup preference enabled')), const SizedBox(height: 8), if (canManage) FilledButton.icon(onPressed: _saveGeneral, icon: const Icon(Icons.save_rounded), label: const Text('Save General Settings'))]);

  Widget _school() => _panel('School Profile', Icons.school_rounded, [TextField(controller: schoolName, enabled: canManage, decoration: const InputDecoration(labelText: 'School name', prefixIcon: Icon(Icons.school_rounded))), const SizedBox(height: 12), Text('School ID: $schoolId', style: const TextStyle(color: AppColors.textMuted, fontSize: 12)), const SizedBox(height: 16), if (canManage) FilledButton.icon(onPressed: _saveSchool, icon: const Icon(Icons.save_rounded), label: const Text('Save School Profile'))]);

  Widget _academic(List<Map<String, dynamic>> sessions) => _panel('Academic Sessions', Icons.calendar_month_rounded, [if (canManage) Align(alignment: Alignment.centerRight, child: FilledButton.icon(onPressed: _addSession, icon: const Icon(Icons.add_rounded), label: const Text('Add Session'))), const SizedBox(height: 8), if (sessions.isEmpty) const _EmptyBox(text: 'No academic sessions configured yet.'), ...sessions.map((s) => Card(elevation: 0, child: ListTile(leading: CircleAvatar(backgroundColor: s['is_current'] == true ? AppColors.success.withValues(alpha: .12) : AppColors.primary.withValues(alpha: .08), child: Icon(s['is_current'] == true ? Icons.check_rounded : Icons.calendar_today_rounded, color: s['is_current'] == true ? AppColors.success : AppColors.primary)), title: Text(s['name']?.toString() ?? '', style: const TextStyle(fontWeight: FontWeight.w800)), subtitle: Text('${s['start_date']} → ${s['end_date']}'), trailing: canManage ? Row(mainAxisSize: MainAxisSize.min, children: [if (s['is_current'] != true) IconButton(tooltip: 'Set current', onPressed: () => _setCurrent((s['id'] as num).toInt()), icon: const Icon(Icons.radio_button_checked_rounded)), IconButton(tooltip: 'Delete', onPressed: () => _deleteSession((s['id'] as num).toInt()), icon: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent))]) : (s['is_current'] == true ? const Chip(label: Text('CURRENT')) : null)))]);

  Widget _fees(List<Map<String, dynamic>> fees) => _panel('Fee Structures', Icons.payments_rounded, [if (canManage) Align(alignment: Alignment.centerRight, child: FilledButton.icon(onPressed: _addFee, icon: const Icon(Icons.add_rounded), label: const Text('Add Fee'))), const SizedBox(height: 8), if (fees.isEmpty) const _EmptyBox(text: 'No fee structures configured yet.'), ...fees.map((f) => Card(elevation: 0, child: ListTile(leading: const CircleAvatar(child: Icon(Icons.payments_rounded)), title: Text(f['name']?.toString() ?? '', style: const TextStyle(fontWeight: FontWeight.w800)), subtitle: Text(f['description']?.toString() ?? ''), trailing: canManage ? Row(mainAxisSize: MainAxisSize.min, children: [Text('${f['amount']}', style: const TextStyle(fontWeight: FontWeight.w900)), IconButton(onPressed: () => _deleteFee((f['id'] as num).toInt()), icon: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent))]) : Text('${f['amount']}')))]);

  Widget _users() => _panel('User Management', Icons.groups_rounded, [const Text('User accounts are managed through their dedicated modules. Passwords are not displayed here.', style: TextStyle(color: AppColors.textSecondary)), const SizedBox(height: 14), _nav('Teachers', Icons.school_rounded, '/teacher'), _nav('Parents', Icons.family_restroom_rounded, '/parent'), _nav('Staff & Team', Icons.badge_rounded, '/staff'), _nav('Communication', Icons.forum_rounded, '/communication')]);

  Widget _nav(String title, IconData icon, String route) => Card(elevation: 0, child: ListTile(leading: Icon(icon, color: AppColors.primary), title: Text(title, style: const TextStyle(fontWeight: FontWeight.w800)), trailing: const Icon(Icons.chevron_right_rounded), onTap: () => Navigator.of(context).popAndPushNamed(route)));

  Widget _panel(String title, IconData icon, List<Widget> children) => Card(elevation: 0, child: Padding(padding: const EdgeInsets.all(18), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Row(children: [Icon(icon, color: AppColors.primary), const SizedBox(width: 10), Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900))]), const SizedBox(height: 16), ...children])));

  String _date(DateTime d) => '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
  String _isoDate(DateTime d) => '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
}

class _EmptyBox extends StatelessWidget {
  final String text;
  const _EmptyBox({required this.text});
  @override
  Widget build(BuildContext context) => Container(width: double.infinity, padding: const EdgeInsets.all(20), decoration: BoxDecoration(color: AppColors.primary.withValues(alpha: .05), borderRadius: BorderRadius.circular(14)), child: Text(text, style: const TextStyle(color: AppColors.textSecondary)));
}
