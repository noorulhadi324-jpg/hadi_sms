import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/network/supabase_client.dart';
import '../../../../core/widgets/main_wrapper.dart';

class HostelScreen extends StatefulWidget {
  const HostelScreen({super.key});

  @override
  State<HostelScreen> createState() => _HostelScreenState();
}

class _HostelScreenState extends State<HostelScreen> {
  final SupabaseClient _client = SupabaseConfig.client;
  bool _loading = true;
  String? _error;
  int? _schoolId;
  bool _canManage = false;
  List<Map<String, dynamic>> _rooms = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<Map<String, dynamic>?> _profile() async {
    final id = _client.auth.currentUser?.id;
    if (id == null) return null;
    return _client.from('profiles').select('school_id, role, is_active').eq('id', id).maybeSingle();
  }

  Future<int?> _school(Map<String, dynamic>? profile) async {
    try {
      final value = await _client.rpc('get_my_school_id');
      if (value is num) return value.toInt();
      final parsed = int.tryParse(value?.toString() ?? '');
      if (parsed != null) return parsed;
    } catch (e) {
      debugPrint('Hostel school RPC failed: $e');
    }
    final value = profile?['school_id'];
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '');
  }

  bool _manager(Map<String, dynamic>? profile) {
    final role = profile?['role']?.toString().toLowerCase().trim() ?? '';
    return profile?['is_active'] != false && (role == 'principal' || role == 'staff');
  }

  String _friendly(Object error) {
    if (error is PostgrestException) return error.message;
    if (error is AuthException) return error.message;
    return error.toString().replaceFirst('Exception: ', '');
  }

  int _int(dynamic value) => value is num ? value.toInt() : int.tryParse(value?.toString() ?? '') ?? 0;
  String _status(Map<String, dynamic> room) => room['status']?.toString().toLowerCase().trim() ?? 'active';

  Future<void> _load() async {
    if (!mounted) return;
    setState(() { _loading = true; _error = null; });
    try {
      final profile = await _profile();
      final schoolId = await _school(profile);
      if (schoolId == null) throw Exception('Your account is not linked to a school.');
      final rows = await _client
          .from('hostel_rooms')
          .select('id, school_id, hostel_name, room_number, capacity, occupied, warden_name, status, notes, created_at, updated_at')
          .eq('school_id', schoolId)
          .order('hostel_name')
          .order('room_number');
      if (!mounted) return;
      setState(() {
        _schoolId = schoolId;
        _canManage = _manager(profile);
        _rooms = List<Map<String, dynamic>>.from(rows);
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() { _error = _friendly(e); _loading = false; });
    }
  }

  Future<void> _edit([Map<String, dynamic>? existing]) async {
    if (!_canManage) return;
    final hostel = TextEditingController(text: existing?['hostel_name']?.toString() ?? '');
    final room = TextEditingController(text: existing?['room_number']?.toString() ?? '');
    final capacity = TextEditingController(text: existing == null ? '0' : _int(existing['capacity']).toString());
    final occupied = TextEditingController(text: existing == null ? '0' : _int(existing['occupied']).toString());
    final warden = TextEditingController(text: existing?['warden_name']?.toString() ?? '');
    final notes = TextEditingController(text: existing?['notes']?.toString() ?? '');
    var status = _status(existing ?? const <String, dynamic>{});
    if (!['active', 'inactive', 'maintenance'].contains(status)) status = 'active';
    String? dialogError;
    bool saving = false;

    final saved = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(existing == null ? 'Add hostel room' : 'Edit hostel room'),
          content: SizedBox(
            width: 500,
            child: SingleChildScrollView(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                TextField(controller: hostel, autofocus: true, textCapitalization: TextCapitalization.words, decoration: const InputDecoration(labelText: 'Hostel name', prefixIcon: Icon(Icons.apartment_outlined))),
                const SizedBox(height: 12),
                TextField(controller: room, decoration: const InputDecoration(labelText: 'Room number', prefixIcon: Icon(Icons.meeting_room_outlined))),
                const SizedBox(height: 12),
                Row(children: [
                  Expanded(child: TextField(controller: capacity, keyboardType: TextInputType.number, inputFormatters: [FilteringTextInputFormatter.digitsOnly], decoration: const InputDecoration(labelText: 'Capacity', prefixIcon: Icon(Icons.bed_outlined)))),
                  const SizedBox(width: 12),
                  Expanded(child: TextField(controller: occupied, keyboardType: TextInputType.number, inputFormatters: [FilteringTextInputFormatter.digitsOnly], decoration: const InputDecoration(labelText: 'Occupied', prefixIcon: Icon(Icons.people_outline)))),
                ]),
                const SizedBox(height: 12),
                TextField(controller: warden, textCapitalization: TextCapitalization.words, decoration: const InputDecoration(labelText: 'Warden name', prefixIcon: Icon(Icons.person_outline))),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: status,
                  decoration: const InputDecoration(labelText: 'Status', prefixIcon: Icon(Icons.task_alt_outlined)),
                  items: const [
                    DropdownMenuItem(value: 'active', child: Text('Active')),
                    DropdownMenuItem(value: 'inactive', child: Text('Inactive')),
                    DropdownMenuItem(value: 'maintenance', child: Text('Maintenance')),
                  ],
                  onChanged: saving ? null : (v) { if (v != null) setDialogState(() => status = v); },
                ),
                const SizedBox(height: 12),
                TextField(controller: notes, minLines: 2, maxLines: 4, decoration: const InputDecoration(labelText: 'Notes', prefixIcon: Icon(Icons.notes_rounded))),
                if (dialogError != null) ...[
                  const SizedBox(height: 12),
                  Align(alignment: Alignment.centerLeft, child: Text(dialogError!, style: TextStyle(color: Theme.of(context).colorScheme.error))),
                ],
              ]),
            ),
          ),
          actions: [
            TextButton(onPressed: saving ? null : () => Navigator.pop(dialogContext, false), child: const Text('Cancel')),
            FilledButton.icon(
              onPressed: saving ? null : () async {
                final schoolId = _schoolId;
                final hostelName = hostel.text.trim();
                final roomNumber = room.text.trim();
                final cap = int.tryParse(capacity.text.trim());
                final occ = int.tryParse(occupied.text.trim());
                if (hostelName.isEmpty) { setDialogState(() => dialogError = 'Hostel name is required.'); return; }
                if (roomNumber.isEmpty) { setDialogState(() => dialogError = 'Room number is required.'); return; }
                if (cap == null || cap < 0) { setDialogState(() => dialogError = 'Enter a valid capacity.'); return; }
                if (occ == null || occ < 0) { setDialogState(() => dialogError = 'Enter a valid occupied count.'); return; }
                if (occ > cap) { setDialogState(() => dialogError = 'Occupied beds cannot exceed room capacity.'); return; }
                if (schoolId == null) { setDialogState(() => dialogError = 'School link is missing.'); return; }
                setDialogState(() { saving = true; dialogError = null; });
                final payload = <String, dynamic>{
                  'school_id': schoolId,
                  'hostel_name': hostelName,
                  'room_number': roomNumber,
                  'capacity': cap,
                  'occupied': occ,
                  'warden_name': warden.text.trim().isEmpty ? null : warden.text.trim(),
                  'status': status,
                  'notes': notes.text.trim().isEmpty ? null : notes.text.trim(),
                  'updated_at': DateTime.now().toUtc().toIso8601String(),
                };
                try {
                  if (existing == null) {
                    await _client.from('hostel_rooms').insert(payload);
                  } else {
                    await _client.from('hostel_rooms').update(payload).eq('id', existing['id']);
                  }
                  if (dialogContext.mounted) Navigator.pop(dialogContext, true);
                } catch (e) {
                  setDialogState(() { saving = false; dialogError = _friendly(e); });
                }
              },
              icon: saving ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.save_outlined),
              label: Text(existing == null ? 'Create' : 'Save'),
            ),
          ],
        ),
      ),
    );
    hostel.dispose(); room.dispose(); capacity.dispose(); occupied.dispose(); warden.dispose(); notes.dispose();
    if (saved == true) await _load();
  }

  Future<void> _delete(Map<String, dynamic> row) async {
    if (!_canManage) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete hostel room?'),
        content: Text('Delete ${row['hostel_name']} room ${row['room_number']}?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(context, true), style: FilledButton.styleFrom(backgroundColor: Theme.of(context).colorScheme.error), child: const Text('Delete')),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await _client.from('hostel_rooms').delete().eq('id', row['id']);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Hostel room deleted.')));
      await _load();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(_friendly(e))));
    }
  }

  @override
  Widget build(BuildContext context) {
    final capacity = _rooms.fold<int>(0, (sum, e) => sum + _int(e['capacity']));
    final occupied = _rooms.fold<int>(0, (sum, e) => sum + _int(e['occupied']));
    final available = capacity - occupied;
    final active = _rooms.where((e) => _status(e) == 'active').length;
    return MainWrapper(
      child: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(24),
          children: [
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: AppColors.primary, borderRadius: BorderRadius.circular(14)), child: const Icon(Icons.hotel_rounded, color: Colors.white)),
              const SizedBox(width: 16),
              const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('Hostel', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900)), Text('Manage hostel rooms, occupancy and wardens.', style: TextStyle(color: AppColors.textSecondary, fontSize: 13))])),
              FilledButton.icon(onPressed: !_loading && _schoolId != null && _canManage ? () => _edit() : null, icon: const Icon(Icons.add_rounded), label: const Text('Add room')),
            ]),
            if (!_loading && _schoolId != null && !_canManage) const Padding(padding: EdgeInsets.only(top: 16), child: _ReadOnly()),
            const SizedBox(height: 24),
            if (_loading)
              const Padding(padding: EdgeInsets.symmetric(vertical: 80), child: Center(child: CircularProgressIndicator()))
            else if (_error != null)
              _Error(message: _error!, onRetry: _load)
            else if (_rooms.isEmpty)
              _Empty(canManage: _canManage, onAdd: () => _edit())
            else ...[
              Wrap(spacing: 12, runSpacing: 12, children: [
                _Chip(Icons.meeting_room_outlined, '${_rooms.length} rooms'),
                _Chip(Icons.check_circle_outline, '$active active'),
                _Chip(Icons.bed_outlined, '$occupied / $capacity occupied'),
                _Chip(Icons.event_available_outlined, '$available available'),
              ]),
              const SizedBox(height: 18),
              Card(child: Column(children: [
                for (var i = 0; i < _rooms.length; i++) ...[
                  ListTile(
                    leading: CircleAvatar(backgroundColor: AppColors.primary.withValues(alpha: 0.10), foregroundColor: AppColors.primary, child: const Icon(Icons.meeting_room_outlined)),
                    title: Text('${_rooms[i]['hostel_name'] ?? 'Hostel'} • Room ${_rooms[i]['room_number'] ?? '-'}', style: const TextStyle(fontWeight: FontWeight.w800)),
                    subtitle: Text([
                      '${_int(_rooms[i]['occupied'])}/${_int(_rooms[i]['capacity'])} occupied',
                      _rooms[i]['warden_name']?.toString().trim().isNotEmpty == true ? 'Warden ${_rooms[i]['warden_name']}' : null,
                      _status(_rooms[i]),
                    ].whereType<String>().where((e) => e.isNotEmpty).join(' • ')),
                    trailing: _canManage ? PopupMenuButton<String>(
                      onSelected: (v) { if (v == 'edit') _edit(_rooms[i]); if (v == 'delete') _delete(_rooms[i]); },
                      itemBuilder: (_) => const [PopupMenuItem(value: 'edit', child: Text('Edit')), PopupMenuItem(value: 'delete', child: Text('Delete'))],
                    ) : null,
                  ),
                  if (i != _rooms.length - 1) const Divider(height: 1),
                ],
              ])),
            ],
          ],
        ),
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip(this.icon, this.label); final IconData icon; final String label;
  @override
  Widget build(BuildContext context) => Container(padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10), decoration: BoxDecoration(color: AppColors.primary.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(12)), child: Row(mainAxisSize: MainAxisSize.min, children: [Icon(icon, size: 18, color: AppColors.primary), const SizedBox(width: 8), Text(label, style: const TextStyle(fontWeight: FontWeight.w700))]));
}
class _ReadOnly extends StatelessWidget {
  const _ReadOnly();
  @override
  Widget build(BuildContext context) => const Card(child: Padding(padding: EdgeInsets.all(14), child: Row(children: [Icon(Icons.visibility_outlined), SizedBox(width: 10), Expanded(child: Text('Read-only access. Principal or staff access is required to change hostel rooms.'))])));
}
class _Empty extends StatelessWidget {
  const _Empty({required this.canManage, required this.onAdd}); final bool canManage; final VoidCallback onAdd;
  @override
  Widget build(BuildContext context) => Card(child: Padding(padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 24), child: Column(children: [const Icon(Icons.hotel_outlined, size: 48, color: AppColors.textMuted), const SizedBox(height: 12), const Text('No hostel rooms yet', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)), if (canManage) ...[const SizedBox(height: 16), FilledButton.icon(onPressed: onAdd, icon: const Icon(Icons.add), label: const Text('Add room'))]])));
}
class _Error extends StatelessWidget {
  const _Error({required this.message, required this.onRetry}); final String message; final Future<void> Function() onRetry;
  @override
  Widget build(BuildContext context) => Card(child: Padding(padding: const EdgeInsets.all(24), child: Column(children: [Icon(Icons.error_outline, color: Theme.of(context).colorScheme.error, size: 40), const SizedBox(height: 12), Text(message, textAlign: TextAlign.center), const SizedBox(height: 16), OutlinedButton.icon(onPressed: onRetry, icon: const Icon(Icons.refresh), label: const Text('Retry'))])));
}
