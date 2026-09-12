import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/network/supabase_client.dart';
import '../../../../core/widgets/main_wrapper.dart';

const staffRoles = <String>['Management','Fee Collection','Accountant','Admission','Office Administration','Receptionist','Coordinator','Librarian','IT / Computer Operator','HR / Admin','Exam Coordinator','Transport Incharge','Store Keeper','Peon / Support Staff','Security','Other'];

final staffProvider = FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final schoolId = await ref.watch(schoolIdProvider.future);
  if (schoolId == null) throw Exception('Your account is not linked to a school.');
  final rows = await SupabaseConfig.client.from('profiles').select('id,full_name,email,phone,role,staff_role,is_active,cnic,gender,created_at').eq('school_id', schoolId).eq('role', 'staff').order('created_at', ascending: false);
  return List<Map<String, dynamic>>.from(rows);
});

class StaffScreen extends ConsumerWidget {
  const StaffScreen({super.key});
  @override Widget build(BuildContext context, WidgetRef ref) => MainWrapper(child: ref.watch(staffProvider).when(
    loading: () => const Center(child: CircularProgressIndicator()),
    error: (e, _) => Center(child: Column(mainAxisSize: MainAxisSize.min, children: [Text('$e'), const SizedBox(height: 12), FilledButton(onPressed: () => ref.invalidate(staffProvider), child: const Text('Retry'))])),
    data: (list) => _StaffPage(list: list),
  ));
}

class _StaffPage extends ConsumerStatefulWidget {
  final List<Map<String, dynamic>> list;
  const _StaffPage({required this.list});
  @override ConsumerState<_StaffPage> createState() => _StaffPageState();
}

class _StaffPageState extends ConsumerState<_StaffPage> {
  String search = '';

  List<String> _roles(dynamic value) => value == null ? [] : value.toString().replaceAll('[','').replaceAll(']','').replaceAll('"','').split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();

  Future<void> _edit({Map<String, dynamic>? staff}) async {
    final editing = staff != null;
    final name = TextEditingController(text: staff?['full_name']?.toString() ?? '');
    final email = TextEditingController(text: staff?['email']?.toString() ?? '');
    final phone = TextEditingController(text: staff?['phone']?.toString() ?? '');
    final cnic = TextEditingController(text: staff?['cnic']?.toString() ?? '');
    final selected = _roles(staff?['staff_role']).toSet();
    String gender = ['male','female','other'].contains(staff?['gender']) ? staff!['gender'].toString() : 'male';
    bool active = staff?['is_active'] != false;
    bool saving = false;

    await showDialog(context: context, barrierDismissible: false, builder: (dialogContext) => StatefulBuilder(builder: (context, setDialogState) => AlertDialog(
      title: Text(editing ? 'Edit Staff' : 'Add Staff', style: const TextStyle(fontWeight: FontWeight.w900)),
      content: SizedBox(width: 560, child: SingleChildScrollView(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _field(name, 'Full Name', Icons.person_outline_rounded, TextCapitalization.words), const SizedBox(height: 10),
        _field(email, 'Email', Icons.email_outlined, TextCapitalization.none, enabled: !editing, keyboard: TextInputType.emailAddress), const SizedBox(height: 10),
        _field(phone, 'Phone', Icons.phone_outlined, TextCapitalization.none, keyboard: TextInputType.phone), const SizedBox(height: 10),
        _field(cnic, 'CNIC', Icons.badge_outlined, TextCapitalization.none, keyboard: TextInputType.number), const SizedBox(height: 12),
        DropdownButtonFormField<String>(value: gender, decoration: const InputDecoration(labelText: 'Gender'), items: const [DropdownMenuItem(value:'male',child:Text('Male')),DropdownMenuItem(value:'female',child:Text('Female')),DropdownMenuItem(value:'other',child:Text('Other'))], onChanged: saving ? null : (v) => setDialogState(() => gender = v ?? gender)),
        const SizedBox(height: 14), const Text('Responsibilities', style: TextStyle(fontWeight: FontWeight.w900)), const SizedBox(height: 8),
        Wrap(spacing: 6, runSpacing: 6, children: staffRoles.map((r) => FilterChip(label: Text(r), selected: selected.contains(r), onSelected: saving ? null : (v) => setDialogState(() { if (v) { selected.add(r); } else { selected.remove(r); } }))).toList()),
        const SizedBox(height: 8), SwitchListTile(contentPadding: EdgeInsets.zero, value: active, title: const Text('Active account'), onChanged: saving ? null : (v) => setDialogState(() => active = v)),
        if (!editing) const Padding(padding: EdgeInsets.only(top: 6), child: Text('Staff کو invitation email ملے گی؛ temporary password یہاں دکھایا نہیں جائے گا۔', style: TextStyle(fontSize: 11, color: AppColors.textSecondary))),
      ])),
      actions: [TextButton(onPressed: saving ? null : () => Navigator.pop(dialogContext), child: const Text('Cancel')), FilledButton(onPressed: saving ? null : () async {
        final n = name.text.trim(), e = email.text.trim().toLowerCase();
        if (n.isEmpty) { _error('Full name is required.'); return; }
        if (!editing && !e.contains('@')) { _error('Valid email is required.'); return; }
        if (selected.isEmpty) { _error('Select at least one responsibility.'); return; }
        setDialogState(() => saving = true);
        try {
          if (editing) {
            await SupabaseConfig.client.from('profiles').update({'full_name': n, 'phone': phone.text.trim().isEmpty ? null : phone.text.trim(), 'cnic': cnic.text.trim().isEmpty ? null : cnic.text.trim(), 'gender': gender, 'staff_role': selected.join(', '), 'is_active': active}).eq('id', staff!['id']);
          } else {
            final response = await SupabaseConfig.client.functions.invoke('create-staff-account', body: {'full_name': n, 'email': e, 'phone': phone.text.trim(), 'cnic': cnic.text.trim(), 'gender': gender, 'staff_role': selected.join(', ')});
            final data = Map<String, dynamic>.from(response.data as Map);
            if (data['success'] != true) throw Exception(data['error'] ?? 'Unable to create staff account.');
          }
          ref.invalidate(staffProvider);
          if (context.mounted) Navigator.pop(dialogContext);
          _success(editing ? 'Staff updated.' : 'Invitation sent to staff.');
        } catch (e) { setDialogState(() => saving = false); _error(e.toString().replaceFirst('Exception: ', '')); }
      }, child: saving ? const SizedBox(width:18,height:18,child:CircularProgressIndicator(strokeWidth:2,color:Colors.white)) : Text(editing ? 'Save' : 'Create & Invite'))],
    )));
    name.dispose(); email.dispose(); phone.dispose(); cnic.dispose();
  }

  Future<void> _action(Map<String, dynamic> staff, String action) async {
    try {
      final response = await SupabaseConfig.client.functions.invoke('manage-role-account', body: {'action': action, 'user_id': staff['id']});
      final data = Map<String, dynamic>.from(response.data as Map);
      if (data['success'] != true) throw Exception(data['error'] ?? 'Operation failed.');
      ref.invalidate(staffProvider); _success(data['message']?.toString() ?? 'Done.');
    } catch (e) { _error(e.toString().replaceFirst('Exception: ', '')); }
  }

  Future<void> _delete(Map<String, dynamic> staff) async {
    final yes = await showDialog<bool>(context: context, builder: (d) => AlertDialog(title: const Text('Delete staff?'), content: Text('Delete ${staff['full_name'] ?? 'this account'} permanently?'), actions: [TextButton(onPressed: () => Navigator.pop(d,false), child: const Text('Cancel')), FilledButton(onPressed: () => Navigator.pop(d,true), child: const Text('Delete'))]));
    if (yes == true) await _action(staff, 'delete');
  }

  Widget _field(TextEditingController c, String label, IconData icon, TextCapitalization cap, {bool enabled = true, TextInputType? keyboard}) => TextField(controller:c, enabled:enabled, keyboardType:keyboard, textCapitalization:cap, decoration:InputDecoration(labelText:label,prefixIcon:Icon(icon)));
  void _error(String s) { if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text(s),backgroundColor:Colors.redAccent)); }
  void _success(String s) { if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text(s),backgroundColor:AppColors.success)); }

  @override Widget build(BuildContext context) {
    final q = search.toLowerCase();
    final list = widget.list.where((u) => q.isEmpty || '${u['full_name']} ${u['email']} ${u['phone']} ${u['staff_role']}'.toLowerCase().contains(q)).toList();
    return ListView(padding: const EdgeInsets.all(24), children: [
      Row(children: [const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children:[Text('Staff Management',style:TextStyle(fontSize:28,fontWeight:FontWeight.w900)),SizedBox(height:4),Text('Manage team staff and responsibilities.',style:TextStyle(color:AppColors.textSecondary))])),FilledButton.icon(onPressed:()=>_edit(),icon:const Icon(Icons.person_add_alt_1_rounded),label:const Text('Add Staff'))]),
      const SizedBox(height:18), TextField(onChanged:(v)=>setState(()=>search=v),decoration:const InputDecoration(prefixIcon:Icon(Icons.search_rounded),hintText:'Search staff...')), const SizedBox(height:18),
      ...list.map((staff) => Card(elevation:0,margin:const EdgeInsets.only(bottom:10),child:ListTile(leading:CircleAvatar(backgroundColor:AppColors.primary.withValues(alpha:.08),child:const Icon(Icons.badge_rounded,color:AppColors.primary)),title:Text(staff['full_name']?.toString()??'Unnamed Staff',style:const TextStyle(fontWeight:FontWeight.w800)),subtitle:Text('${staff['email']??''}\n${staff['staff_role']??'Staff'}'),isThreeLine:true,trailing:PopupMenuButton<String>(onSelected:(v){if(v=='edit')_edit(staff:staff);if(v=='delete')_delete(staff);if(v=='activate'||v=='deactivate')_action(staff,v);},itemBuilder:(_)=>[const PopupMenuItem(value:'edit',child:Text('Edit')),PopupMenuItem(value:staff['is_active']==false?'activate':'deactivate',child:Text(staff['is_active']==false?'Activate':'Deactivate')),const PopupMenuItem(value:'delete',child:Text('Delete'))])))),
    ]);
  }
}
