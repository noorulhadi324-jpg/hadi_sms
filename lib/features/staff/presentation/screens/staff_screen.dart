import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/network/supabase_client.dart';
import '../../../../core/widgets/main_wrapper.dart';

const List<String> staffRoles = [
  'Management', 'Fee Collection', 'Accountant', 'Admission',
  'Office Administration', 'Receptionist', 'Coordinator', 'Librarian',
  'IT / Computer Operator', 'HR / Admin', 'Exam Coordinator',
  'Transport Incharge', 'Store Keeper', 'Peon / Support Staff', 'Security', 'Other',
];

final staffProvider = FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final schoolId = await ref.watch(schoolIdProvider.future);
  if (schoolId == null) throw Exception('Your account is not linked to a school.');

  final rows = await SupabaseConfig.client
      .from('profiles')
      .select('id,full_name,email,phone,role,staff_role,school_id,is_active,cnic,gender,created_at')
      .eq('school_id', schoolId)
      .eq('role', 'staff')
      .order('created_at', ascending: false);

  return List<Map<String, dynamic>>.from(rows);
});

class StaffScreen extends ConsumerWidget {
  const StaffScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final users = ref.watch(staffProvider);
    return MainWrapper(
      child: users.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Column(mainAxisSize: MainAxisSize.min, children: [Text(e.toString()), const SizedBox(height: 12), FilledButton(onPressed: () => ref.invalidate(staffProvider), child: const Text('Retry'))])),
        data: (list) => _StaffContent(list: list),
      ),
    );
  }
}

class _StaffContent extends ConsumerStatefulWidget {
  final List<Map<String, dynamic>> list;
  const _StaffContent({required this.list});
  @override
  ConsumerState<_StaffContent> createState() => _StaffContentState();
}

class _StaffContentState extends ConsumerState<_StaffContent> {
  String search = '';

  List<String> _roles(dynamic value) {
    if (value == null) return [];
    final text = value.toString();
    return text.replaceAll('[', '').replaceAll(']', '').replaceAll('"', '').split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
  }

  Future<void> _addOrEdit({Map<String, dynamic>? staff}) async {
    final editing = staff != null;
    final name = TextEditingController(text: staff?['full_name']?.toString() ?? '');
    final email = TextEditingController(text: staff?['email']?.toString() ?? '');
    final phone = TextEditingController(text: staff?['phone']?.toString() ?? '');
    final cnic = TextEditingController(text: staff?['cnic']?.toString() ?? '');
    String gender = ['male', 'female', 'other'].contains(staff?['gender']) ? staff!['gender'].toString() : 'male';
    bool active = staff?['is_active'] != false;
    final selected = _roles(staff?['staff_role']).toSet();
    bool saving = false;

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => StatefulBuilder(builder: (context, setState) => AlertDialog(
        title: Text(editing ? 'Edit Staff' : 'Add Staff', style: const TextStyle(fontWeight: FontWeight.w900)),
        content: SizedBox(
          width: 560,
          child: SingleChildScrollView(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              _field(name, 'Full Name', Icons.person_outline_rounded, capitalization: TextCapitalization.words),
              const SizedBox(height: 12),
              _field(email, 'Email Address', Icons.email_outlined, keyboard: TextInputType.emailAddress, enabled: !editing),
              const SizedBox(height: 12),
              _field(phone, 'Phone', Icons.phone_outlined, keyboard: TextInputType.phone),
              const SizedBox(height: 12),
              _field(cnic, 'CNIC', Icons.badge_outlined, keyboard: TextInputType.number),
              const SizedBox(height: 18),
              DropdownButtonFormField<String>(value: gender, decoration: const InputDecoration(labelText: 'Gender', prefixIcon: Icon(Icons.person_search_outlined)), items: const [DropdownMenuItem(value: 'male', child: Text('Male')), DropdownMenuItem(value: 'female', child: Text('Female')), DropdownMenuItem(value: 'other', child: Text('Other'))], onChanged: saving ? null : (v) => setState(() => gender = v ?? gender)),
              const SizedBox(height: 18),
              const Text('Staff Responsibilities', style: TextStyle(fontWeight: FontWeight.w900)),
              const SizedBox(height: 8),
              Wrap(spacing: 7, runSpacing: 7, children: staffRoles.map((role) => FilterChip(label: Text(role), selected: selected.contains(role), onSelected: saving ? null : (v) => setState(() { if (v) selected.add(role); else selected.remove(role); }))).toList()),
              const SizedBox(height: 12),
              SwitchListTile(contentPadding: EdgeInsets.zero, value: active, title: const Text('Active Account', style: TextStyle(fontWeight: FontWeight.w700)), onChanged: saving ? null : (v) => setState(() => active = v)),
              if (!editing) const Padding(padding: EdgeInsets.only(top: 8), child: Card(child: Padding(padding: EdgeInsets.all(12), child: Row(children: [Icon(Icons.mark_email_read_rounded, color: AppColors.primary), SizedBox(width: 10), Expanded(child: Text('کوئی temporary password یہاں نہیں ہوگا۔ Staff کو invitation email ملے گی اور وہ اپنا password خود set کرے گا۔', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)))])))),
            ]),
          ),
        ),
        actions: [
          TextButton(onPressed: saving ? null : () => Navigator.pop(dialogContext), child: const Text('Cancel')),
          FilledButton(onPressed: saving ? null : () async {
            if (name.text.trim().isEmpty) return _error('Full name is required.');
            if (!editing && !email.text.trim().contains('@')) return _error('Valid email is required.');
            if (selected.isEmpty) return _error('Select at least one staff responsibility.');
            setState(() => saving = true);
            try {
              final client = SupabaseConfig.client;
              if (editing) {
                await client.from('profiles').update({
                  'full_name': name.text.trim(),
                  'phone': phone.text.trim().isEmpty ? null : phone.text.trim(),
                  'cnic': cnic.text.trim().isEmpty ? null : cnic.text.trim(),
                  'gender': gender,
                  'staff_role': selected.join(', '),
                  'is_active': active,
                }).eq('id', staff!['id']);
              } else {
                final response = await client.functions.invoke('create-staff-account', body: {
                  'full_name': name.text.trim(),
                  'email': email.text.trim().toLowerCase(),
                  'phone': phone.text.trim(),
                  'cnic': cnic.text.trim(),
                  'gender': gender,
                  'staff_role': selected.join(', '),
                });
                final data = Map<String, dynamic>.from(response.data as Map);
                if (data['success'] != true) throw Exception(data['error'] ?? 'Unable to create staff account.');
              }
              ref.invalidate(staffProvider);
              if (context.mounted) Navigator.pop(dialogContext);
              if (mounted) _success(editing ? 'Staff updated successfully.' : 'Staff invitation sent successfully.');
            } catch (e) {
              setState(() => saving = false);
              _error(e.toString().replaceFirst('Exception: ', ''));
            }
          }, child: saving ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : Text(editing ? 'Save Changes' : 'Create & Send Invite')),
        ],
      )),
    );
    name.dispose(); email.dispose(); phone.dispose(); cnic.dispose();
  }

  Future<void> _manage(Map<String, dynamic> staff, String action) async {
    try {
      final response = await SupabaseConfig.client.functions.invoke('manage-role-account', body: {'action': action, 'user_id': staff['id']});
      final data = Map<String, dynamic>.from(response.data as Map);
      if (data['success'] != true) throw Exception(data['error'] ?? 'Operation failed.');
      ref.invalidate(staffProvider);
      if (mounted) _success(data['message']?.toString() ?? 'Done.');
    } catch (e) {
      if (mounted) _error(e.toString().replaceFirst('Exception: ', ''));
    }
  }

  Future<void> _delete(Map<String, dynamic> staff) async {
    final ok = await showDialog<bool>(context: context, builder: (c) => AlertDialog(title: const Text('Delete Staff?'), content: Text('Delete ${staff['full_name'] ?? 'this staff account'} permanently?'), actions: [TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancel')), FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('Delete'))]));
    if (ok == true) await _manage(staff, 'delete');
  }

  void _error(String message) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message), backgroundColor: Colors.red));
  void _success(String message) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message), backgroundColor: Colors.green));

  @override
  Widget build(BuildContext context) {
    final filtered = widget.list.where((u) {
      final q = search.toLowerCase();
      return q.isEmpty || '${u['full_name']} ${u['email']} ${u['phone']} ${u['staff_role']}'.toLowerCase().contains(q);
    }).toList();

    return Stack(children: [
      ListView(padding: const EdgeInsets.all(24), children: [
        Row(children: [const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('Staff Management', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900)), SizedBox(height: 4), Text('Add, edit, activate/deactivate and delete staff accounts.', style: TextStyle(color: AppColors.textSecondary))])), FilledButton.icon(onPressed: () => _addOrEdit(), icon: const Icon(Icons.person_add_alt_1_rounded), label: const Text('Add Staff'))]),
        const SizedBox(height: 20),
        TextField(onChanged: (v) => setState(() => search = v), decoration: const InputDecoration(prefixIcon: Icon(Icons.search), hintText: 'Search staff...')),
        const SizedBox(height: 20),
        ...filtered.map((staff) => Card(margin: const EdgeInsets.only(bottom: 10), child: ListTile(
          leading: CircleAvatar(backgroundColor: AppColors.primary.withValues(alpha: .08), child: const Icon(Icons.badge_rounded, color: AppColors.primary)),
          title: Text(staff['full_name']?.toString() ?? 'Unnamed Staff', style: const TextStyle(fontWeight: FontWeight.w800)),
          subtitle: Text('${staff['email'] ?? ''}\n${staff['staff_role'] ?? 'Staff'}'),
          isThreeLine: true,
          trailing: PopupMenuButton<String>(onSelected: (value) { if (value == 'edit') _addOrEdit(staff: staff); if (value == 'delete') _delete(staff); if (value == 'activate') _manage(staff, 'activate'); if (value == 'deactivate') _manage(staff, 'deactivate'); }, itemBuilder: (_) => [const PopupMenuItem(value: 'edit', child: ListTile(leading: Icon(Icons.edit_rounded), title: Text('Edit'))), PopupMenuItem(value: staff['is_active'] == false ? 'activate' : 'deactivate', child: ListTile(leading: Icon(staff['is_active'] == false ? Icons.check_circle : Icons.pause_circle), title: Text(staff['is_active'] == false ? 'Activate' : 'Deactivate'))), const PopupMenuDivider(), const PopupMenuItem(value: 'delete', child: ListTile(leading: Icon(Icons.delete_outline_rounded, color: Colors.red), title: Text('Delete')))]),
        ))),
      ]),
    ]);
  }

  Widget _field(TextEditingController c, String label, IconData icon, {TextInputType? keyboard, bool enabled = true, TextCapitalization capitalization = TextCapitalization.none}) => TextField(controller: c, enabled: enabled, keyboardType: keyboard, textCapitalization: capitalization, decoration: InputDecoration(labelText: label, prefixIcon: Icon(icon)));
}
