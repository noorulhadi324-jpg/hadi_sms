import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/network/supabase_client.dart';

class ParentData {
  final List<Map<String, dynamic>> parents;
  final int totalStudents;
  final int activeParents;

  const ParentData({
    required this.parents,
    required this.totalStudents,
    required this.activeParents,
  });
}

final parentProvider = FutureProvider.autoDispose<ParentData>((ref) async {
  final client = SupabaseConfig.client;
  final user = client.auth.currentUser;
  if (user == null) throw const AuthException('Please login again.');

  final profile = await client
      .from('profiles')
      .select('school_id, role')
      .eq('id', user.id)
      .maybeSingle();

  if (profile == null || profile['school_id'] == null) {
    throw const AuthException('Your account is not linked to a school.');
  }

  final schoolId = profile['school_id'];

  final parentsResponse = await client
      .from('profiles')
      .select('id, full_name, email, phone, gender, is_active, created_at, school_id, role')
      .eq('school_id', schoolId)
      .eq('role', 'parent')
      .order('full_name');

  final studentsResponse = await client
      .from('students')
      .select('id, full_name, class_name, section_name, parent_email, school_id')
      .eq('school_id', schoolId)
      .order('full_name');

  final students = List<Map<String, dynamic>>.from(studentsResponse);
  final parents = List<Map<String, dynamic>>.from(parentsResponse).map((p) {
    final email = (p['email'] ?? '').toString().trim().toLowerCase();
    final children = students.where((s) =>
        (s['parent_email'] ?? '').toString().trim().toLowerCase() == email).toList();
    return {...p, 'children': children};
  }).toList();

  return ParentData(
    parents: parents,
    totalStudents: students.length,
    activeParents: parents.where((p) => p['is_active'] != false).length,
  );
});

class ParentsScreen extends ConsumerStatefulWidget {
  const ParentsScreen({super.key});

  @override
  ConsumerState<ParentsScreen> createState() => _ParentsScreenState();
}

class _ParentsScreenState extends ConsumerState<ParentsScreen> {
  final _searchController = TextEditingController();
  bool _saving = false;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<Map<String, dynamic>> _filtered(List<Map<String, dynamic>> parents) {
    final q = _searchController.text.trim().toLowerCase();
    if (q.isEmpty) return parents;
    return parents.where((p) {
      return (p['full_name'] ?? '').toString().toLowerCase().contains(q) ||
          (p['email'] ?? '').toString().toLowerCase().contains(q) ||
          (p['phone'] ?? '').toString().toLowerCase().contains(q);
    }).toList();
  }

  Future<void> _addParent() async {
    final name = TextEditingController();
    final email = TextEditingController();
    final phone = TextEditingController();
    final password = TextEditingController(text: 'Parent@12345');
    String gender = 'Male';

    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Add Parent', style: TextStyle(fontWeight: FontWeight.w800)),
          content: SizedBox(
            width: 460,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(controller: name, decoration: const InputDecoration(labelText: 'Full name', prefixIcon: Icon(Icons.person_outline))),
                  const SizedBox(height: 12),
                  TextField(controller: email, keyboardType: TextInputType.emailAddress, decoration: const InputDecoration(labelText: 'Email', prefixIcon: Icon(Icons.email_outlined))),
                  const SizedBox(height: 12),
                  TextField(controller: phone, keyboardType: TextInputType.phone, decoration: const InputDecoration(labelText: 'Phone', prefixIcon: Icon(Icons.phone_outlined))),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    value: gender,
                    decoration: const InputDecoration(labelText: 'Gender', prefixIcon: Icon(Icons.wc_outlined)),
                    items: const [DropdownMenuItem(value: 'Male', child: Text('Male')), DropdownMenuItem(value: 'Female', child: Text('Female'))],
                    onChanged: (v) => setState(() => gender = v ?? 'Male'),
                  ),
                  const SizedBox(height: 12),
                  TextField(controller: password, obscureText: true, decoration: const InputDecoration(labelText: 'Temporary password', prefixIcon: Icon(Icons.lock_outline))),
                  const SizedBox(height: 8),
                  const Align(alignment: Alignment.centerLeft, child: Text('Parent can change this password after login.', style: TextStyle(fontSize: 12, color: Colors.grey))),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Cancel')),
            FilledButton(onPressed: () => Navigator.pop(dialogContext, true), child: const Text('Create Parent')),
          ],
        ),
      ),
    );

    if (result != true) {
      name.dispose(); email.dispose(); phone.dispose(); password.dispose();
      return;
    }

    if (name.text.trim().isEmpty || email.text.trim().isEmpty || password.text.length < 6) {
      _show('Name, email and a password of at least 6 characters are required.', true);
      name.dispose(); email.dispose(); phone.dispose(); password.dispose();
      return;
    }

    final client = SupabaseConfig.client;
    final adminSession = client.auth.currentSession;
    final adminUser = client.auth.currentUser;
    if (adminSession == null || adminUser == null) {
      _show('Admin session expired. Please login again.', true);
      return;
    }

    setState(() => _saving = true);
    try {
      final schoolProfile = await client.from('profiles').select('school_id').eq('id', adminUser.id).maybeSingle();
      final schoolId = schoolProfile?['school_id'];
      if (schoolId == null) throw const AuthException('School linkage not found.');

      final response = await client.auth.signUp(
        email: email.text.trim().toLowerCase(),
        password: password.text,
        data: {
          'full_name': name.text.trim(),
          'phone': phone.text.trim(),
          'gender': gender,
          'role': 'parent',
          'school_id': schoolId.toString(),
        },
      );

      final newUser = response.user;
      if (newUser == null) throw const AuthException('Parent account could not be created.');

      await client.from('profiles').update({
        'school_id': schoolId,
        'role': 'parent',
        'full_name': name.text.trim(),
        'phone': phone.text.trim().isEmpty ? null : phone.text.trim(),
        'gender': gender,
        'is_active': true,
      }).eq('id', newUser.id);

      // signUp may replace the current client session. Restore the administrator session.
      await client.auth.signOut();
      await client.auth.setSession(adminSession.accessToken);

      ref.invalidate(parentProvider);
      _show('Parent account created successfully.\nEmail: ${email.text.trim()}\nTemporary password: ${password.text}');
    } on AuthException catch (e) {
      _show(e.message, true);
    } catch (e) {
      _show('Could not create parent: $e', true);
    } finally {
      if (mounted) setState(() => _saving = false);
      name.dispose(); email.dispose(); phone.dispose(); password.dispose();
    }
  }

  Future<void> _toggleParent(Map<String, dynamic> parent) async {
    final client = SupabaseConfig.client;
    try {
      final active = parent['is_active'] != false;
      await client.from('profiles').update({'is_active': !active}).eq('id', parent['id']);
      ref.invalidate(parentProvider);
      _show(active ? 'Parent account deactivated.' : 'Parent account activated.');
    } catch (e) {
      _show('Could not update parent: $e', true);
    }
  }

  void _show(String message, [bool error = false]) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message), backgroundColor: error ? Colors.red.shade700 : null));
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(parentProvider);
    return Scaffold(
      backgroundColor: const Color(0xFFF6F8FC),
      appBar: AppBar(
        title: const Text('Parents', style: TextStyle(fontWeight: FontWeight.w800)),
        actions: [
          IconButton(onPressed: () => ref.invalidate(parentProvider), tooltip: 'Refresh', icon: const Icon(Icons.refresh_rounded)),
          const SizedBox(width: 8),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _saving ? null : _addParent,
        icon: const Icon(Icons.person_add_alt_1_rounded),
        label: const Text('Add Parent'),
      ),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => _ErrorView(message: e.toString(), onRetry: () => ref.invalidate(parentProvider)),
        data: (data) {
          final parents = _filtered(data.parents);
          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(parentProvider),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 100),
              children: [
                Wrap(spacing: 12, runSpacing: 12, children: [
                  _StatCard('Total Parents', '${data.parents.length}', Icons.family_restroom_rounded),
                  _StatCard('Active', '${data.activeParents}', Icons.verified_user_outlined),
                  _StatCard('Students', '${data.totalStudents}', Icons.school_outlined),
                ]),
                const SizedBox(height: 20),
                TextField(
                  controller: _searchController,
                  onChanged: (_) => setState(() {}),
                  decoration: InputDecoration(
                    hintText: 'Search parent by name, email or phone...',
                    prefixIcon: const Icon(Icons.search_rounded),
                    suffixIcon: _searchController.text.isEmpty ? null : IconButton(onPressed: () { _searchController.clear(); setState(() {}); }, icon: const Icon(Icons.clear_rounded)),
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
                  ),
                ),
                const SizedBox(height: 16),
                if (parents.isEmpty)
                  const _EmptyParents()
                else
                  ...parents.map(_parentCard),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _parentCard(Map<String, dynamic> parent) {
    final children = List<Map<String, dynamic>>.from(parent['children'] ?? const []);
    final name = (parent['full_name'] ?? 'Parent').toString();
    final active = parent['is_active'] != false;
    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 5),
        leading: CircleAvatar(radius: 24, child: Text(name.isEmpty ? 'P' : name.substring(0, 1).toUpperCase())),
        title: Text(name, style: const TextStyle(fontWeight: FontWeight.w800)),
        subtitle: Text('${parent['email'] ?? '-'}\n${parent['phone'] ?? '-'} • ${children.length} child${children.length == 1 ? '' : 'ren'}'),
        trailing: PopupMenuButton<String>(
          onSelected: (value) { if (value == 'toggle') _toggleParent(parent); },
          itemBuilder: (_) => [PopupMenuItem(value: 'toggle', child: Text(active ? 'Deactivate' : 'Activate'))],
        ),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 0, 18, 18),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [const Text('Linked Children', style: TextStyle(fontWeight: FontWeight.w800)), const Spacer(), Chip(label: Text(active ? 'Active' : 'Inactive'))]),
              const SizedBox(height: 8),
              if (children.isEmpty)
                const Text('No student is linked to this parent email yet.', style: TextStyle(color: Colors.grey))
              else
                ...children.map((child) => ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.school_outlined),
                  title: Text(child['full_name']?.toString() ?? 'Student', style: const TextStyle(fontWeight: FontWeight.w700)),
                  subtitle: Text('${child['class_name'] ?? '-'}${child['section_name'] == null ? '' : ' • ${child['section_name']}'}'),
                )),
            ]),
          ),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String title, value;
  final IconData icon;
  const _StatCard(this.title, this.value, this.icon);

  @override
  Widget build(BuildContext context) => SizedBox(
    width: 220,
    child: Card(
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Row(children: [
          Container(padding: const EdgeInsets.all(11), decoration: BoxDecoration(color: Theme.of(context).colorScheme.primaryContainer, borderRadius: BorderRadius.circular(12)), child: Icon(icon)),
          const SizedBox(width: 12),
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: const TextStyle(fontSize: 12, color: Colors.grey)), const SizedBox(height: 4), Text(value, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900))]),
        ]),
      ),
    ),
  );
}

class _EmptyParents extends StatelessWidget {
  const _EmptyParents();
  @override
  Widget build(BuildContext context) => Card(elevation: 0, child: Padding(padding: const EdgeInsets.all(35), child: Column(children: [const Icon(Icons.family_restroom_outlined, size: 56), const SizedBox(height: 12), const Text('No parents found', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)), const SizedBox(height: 6), const Text('Create a parent account using the Add Parent button.', textAlign: TextAlign.center)])));
}

class _ErrorView extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _ErrorView({required this.message, required this.onRetry});
  @override
  Widget build(BuildContext context) => Center(child: Padding(padding: const EdgeInsets.all(24), child: Column(mainAxisSize: MainAxisSize.min, children: [const Icon(Icons.error_outline_rounded, size: 52), const SizedBox(height: 12), Text(message, textAlign: TextAlign.center), const SizedBox(height: 14), FilledButton.icon(onPressed: onRetry, icon: const Icon(Icons.refresh_rounded), label: const Text('Try Again'))])));
}
