import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/network/supabase_client.dart';

class ParentData {
  final List<Map<String, dynamic>> parents;
  final List<Map<String, dynamic>> pendingParents;
  final int totalStudents;
  final int activeParents;

  const ParentData({
    required this.parents,
    required this.pendingParents,
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
      .select('id, full_name, father_name, mobile_number, class_name, section_name, parent_email, school_id')
      .eq('school_id', schoolId)
      .order('full_name');

  final students = List<Map<String, dynamic>>.from(studentsResponse);
  final parentRows = List<Map<String, dynamic>>.from(parentsResponse);
  final registeredEmails = parentRows
      .map((p) => (p['email'] ?? '').toString().trim().toLowerCase())
      .where((email) => email.isNotEmpty)
      .toSet();

  final parents = parentRows.map((p) {
    final email = (p['email'] ?? '').toString().trim().toLowerCase();
    final children = students.where((s) =>
        (s['parent_email'] ?? '').toString().trim().toLowerCase() == email).toList();
    return {...p, 'children': children};
  }).toList();

  final pendingByEmail = <String, Map<String, dynamic>>{};
  for (final student in students) {
    final email = (student['parent_email'] ?? '').toString().trim().toLowerCase();
    if (email.isEmpty || registeredEmails.contains(email)) continue;

    final pending = pendingByEmail.putIfAbsent(email, () => {
      'email': email,
      'full_name': (student['father_name'] ?? '').toString().trim().isEmpty
          ? 'Parent'
          : student['father_name'].toString().trim(),
      'phone': (student['mobile_number'] ?? '').toString().trim(),
      'children': <Map<String, dynamic>>[],
    });
    (pending['children'] as List<Map<String, dynamic>>).add(student);
  }

  return ParentData(
    parents: parents,
    pendingParents: pendingByEmail.values.toList(),
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

  Future<Map<String, dynamic>?> _createParentAccount({
    required String name,
    required String email,
    String phone = '',
    String gender = 'Male',
    String password = '',
  }) async {
    final cleanName = name.trim();
    final cleanEmail = email.trim().toLowerCase();
    if (cleanName.isEmpty || !cleanEmail.contains('@')) {
      _show('Parent name and a valid email are required.', true);
      return null;
    }

    final response = await SupabaseConfig.client.functions.invoke(
      'create-role-account',
      body: {
        'role': 'parent',
        'full_name': cleanName,
        'email': cleanEmail,
        'phone': phone.trim(),
        'gender': gender,
        if (password.trim().length >= 6) 'password': password.trim(),
      },
    );

    final data = Map<String, dynamic>.from(response.data as Map);
    if (data['success'] != true) {
      throw AuthException(data['error']?.toString() ?? 'Could not create parent account.');
    }
    return data;
  }

  Future<void> _addParent() async {
    final name = TextEditingController();
    final email = TextEditingController();
    final phone = TextEditingController();
    final password = TextEditingController();
    String gender = 'Male';

    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Add Parent', style: TextStyle(fontWeight: FontWeight.w800)),
          content: SizedBox(
            width: 460,
            child: SingleChildScrollView(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                TextField(controller: name, decoration: const InputDecoration(labelText: 'Full name', prefixIcon: Icon(Icons.person_outline))),
                const SizedBox(height: 12),
                TextField(controller: email, keyboardType: TextInputType.emailAddress, decoration: const InputDecoration(labelText: 'Email', prefixIcon: Icon(Icons.email_outlined))),
                const SizedBox(height: 12),
                TextField(controller: phone, keyboardType: TextInputType.phone, decoration: const InputDecoration(labelText: 'Phone', prefixIcon: Icon(Icons.phone_outlined))),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: gender,
                  decoration: const InputDecoration(labelText: 'Gender', prefixIcon: Icon(Icons.wc_outlined)),
                  items: const [DropdownMenuItem(value: 'Male', child: Text('Male')), DropdownMenuItem(value: 'Female', child: Text('Female'))],
                  onChanged: (v) => setState(() => gender = v ?? 'Male'),
                ),
                const SizedBox(height: 12),
                TextField(controller: password, obscureText: true, decoration: const InputDecoration(labelText: 'Password (optional)', helperText: 'Leave empty to generate a secure temporary password.', prefixIcon: Icon(Icons.lock_outline))),
              ]),
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

    setState(() => _saving = true);
    try {
      final data = await _createParentAccount(
        name: name.text,
        email: email.text,
        phone: phone.text,
        gender: gender,
        password: password.text,
      );
      ref.invalidate(parentProvider);
      final generated = data?['temporary_password']?.toString();
      _show(generated == null || generated.isEmpty
          ? 'Parent account created successfully.'
          : 'Parent created. Email: ${email.text.trim()}\nTemporary password: $generated');
    } on FunctionException catch (e) {
      _show('Could not create parent: ${e.details ?? e.reasonPhrase ?? e.toString()}', true);
    } on AuthException catch (e) {
      _show(e.message, true);
    } catch (e) {
      _show('Could not create parent: $e', true);
    } finally {
      if (mounted) setState(() => _saving = false);
      name.dispose(); email.dispose(); phone.dispose(); password.dispose();
    }
  }

  Future<void> _createPendingParent(Map<String, dynamic> pending) async {
    setState(() => _saving = true);
    try {
      final data = await _createParentAccount(
        name: pending['full_name']?.toString() ?? 'Parent',
        email: pending['email']?.toString() ?? '',
        phone: pending['phone']?.toString() ?? '',
      );
      ref.invalidate(parentProvider);
      final generated = data?['temporary_password']?.toString();
      _show(generated == null || generated.isEmpty
          ? 'Parent login created successfully.'
          : 'Parent login created.\nEmail: ${pending['email']}\nTemporary password: $generated');
    } on FunctionException catch (e) {
      _show('Could not create parent login: ${e.details ?? e.reasonPhrase ?? e.toString()}', true);
    } on AuthException catch (e) {
      _show(e.message, true);
    } catch (e) {
      _show('Could not create parent login: $e', true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _toggleParent(Map<String, dynamic> parent) async {
    try {
      final active = parent['is_active'] != false;
      await SupabaseConfig.client.from('profiles').update({'is_active': !active}).eq('id', parent['id']);
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
        actions: [IconButton(onPressed: () => ref.invalidate(parentProvider), tooltip: 'Refresh', icon: const Icon(Icons.refresh_rounded)), const SizedBox(width: 8)],
      ),
      floatingActionButton: FloatingActionButton.extended(onPressed: _saving ? null : _addParent, icon: const Icon(Icons.person_add_alt_1_rounded), label: const Text('Add Parent')),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => _ErrorView(message: e.toString(), onRetry: () => ref.invalidate(parentProvider)),
        data: (data) {
          final parents = _filtered(data.parents);
          final pending = _filtered(data.pendingParents);
          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(parentProvider),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 100),
              children: [
                Wrap(spacing: 12, runSpacing: 12, children: [
                  _StatCard('Total Parents', '${data.parents.length}', Icons.family_restroom_rounded),
                  _StatCard('Active', '${data.activeParents}', Icons.verified_user_outlined),
                  _StatCard('Students', '${data.totalStudents}', Icons.school_outlined),
                  _StatCard('Pending Logins', '${data.pendingParents.length}', Icons.pending_actions_rounded),
                ]),
                const SizedBox(height: 20),
                TextField(
                  controller: _searchController,
                  onChanged: (_) => setState(() {}),
                  decoration: InputDecoration(hintText: 'Search parent by name, email or phone...', prefixIcon: const Icon(Icons.search_rounded), suffixIcon: _searchController.text.isEmpty ? null : IconButton(onPressed: () { _searchController.clear(); setState(() {}); }, icon: const Icon(Icons.clear_rounded)), filled: true, fillColor: Colors.white, border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none)),
                ),
                if (pending.isNotEmpty) ...[
                  const SizedBox(height: 20),
                  const Text('Parents from Student Records', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
                  const SizedBox(height: 8),
                  ...pending.map(_pendingCard),
                ],
                const SizedBox(height: 18),
                const Text('Parent Accounts', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
                const SizedBox(height: 8),
                if (parents.isEmpty) const _EmptyParents() else ...parents.map(_parentCard),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _pendingCard(Map<String, dynamic> pending) {
    final children = List<Map<String, dynamic>>.from(pending['children'] ?? const []);
    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        leading: const CircleAvatar(child: Icon(Icons.person_add_alt_1_rounded)),
        title: Text(pending['full_name']?.toString() ?? 'Parent', style: const TextStyle(fontWeight: FontWeight.w800)),
        subtitle: Text('${pending['email']}\n${children.length} linked student${children.length == 1 ? '' : 's'}'),
        isThreeLine: true,
        trailing: FilledButton(onPressed: _saving ? null : () => _createPendingParent(pending), child: const Text('Create Login')),
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
        trailing: PopupMenuButton<String>(onSelected: (value) { if (value == 'toggle') _toggleParent(parent); }, itemBuilder: (_) => [PopupMenuItem(value: 'toggle', child: Text(active ? 'Deactivate' : 'Activate'))]),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 0, 18, 18),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [const Text('Linked Children', style: TextStyle(fontWeight: FontWeight.w800)), const Spacer(), Chip(label: Text(active ? 'Active' : 'Inactive'))]),
              const SizedBox(height: 8),
              if (children.isEmpty) const Text('No student is linked to this parent email yet.', style: TextStyle(color: Colors.grey)) else ...children.map((child) => ListTile(dense: true, contentPadding: EdgeInsets.zero, leading: const Icon(Icons.school_outlined), title: Text(child['full_name']?.toString() ?? 'Student', style: const TextStyle(fontWeight: FontWeight.w700)), subtitle: Text('${child['class_name'] ?? '-'}${child['section_name'] == null ? '' : ' • ${child['section_name']}'}'))),
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
  Widget build(BuildContext context) => SizedBox(width: 220, child: Card(elevation: 0, child: Padding(padding: const EdgeInsets.all(18), child: Row(children: [Container(padding: const EdgeInsets.all(11), decoration: BoxDecoration(color: Theme.of(context).colorScheme.primaryContainer, borderRadius: BorderRadius.circular(12)), child: Icon(icon)), const SizedBox(width: 12), Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: const TextStyle(fontSize: 12, color: Colors.grey)), const SizedBox(height: 4), Text(value, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900))])] )));
}

class _EmptyParents extends StatelessWidget {
  const _EmptyParents();
  @override
  Widget build(BuildContext context) => Card(elevation: 0, child: Padding(padding: const EdgeInsets.all(35), child: Column(children: [const Icon(Icons.family_restroom_outlined, size: 56), const SizedBox(height: 12), const Text('No parent accounts found', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)), const SizedBox(height: 6), const Text('Create a parent account or create a login from a pending student parent record.', textAlign: TextAlign.center)])));
}

class _ErrorView extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _ErrorView({required this.message, required this.onRetry});
  @override
  Widget build(BuildContext context) => Center(child: Padding(padding: const EdgeInsets.all(24), child: Column(mainAxisSize: MainAxisSize.min, children: [const Icon(Icons.error_outline_rounded, size: 52), const SizedBox(height: 12), Text(message, textAlign: TextAlign.center), const SizedBox(height: 14), FilledButton.icon(onPressed: onRetry, icon: const Icon(Icons.refresh_rounded), label: const Text('Try Again'))])));
}