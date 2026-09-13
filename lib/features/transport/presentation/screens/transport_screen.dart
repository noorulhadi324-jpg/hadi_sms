import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/network/supabase_client.dart';
import '../../../../core/widgets/main_wrapper.dart';

class TransportScreen extends StatefulWidget {
  const TransportScreen({super.key});

  @override
  State<TransportScreen> createState() => _TransportScreenState();
}

class _TransportScreenState extends State<TransportScreen> {
  final SupabaseClient _client = SupabaseConfig.client;
  bool _loading = true;
  String? _error;
  int? _schoolId;
  bool _canManage = false;
  List<Map<String, dynamic>> _vehicles = const [];

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
      debugPrint('Transport school RPC failed: $e');
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

  Future<void> _load() async {
    if (!mounted) return;
    setState(() { _loading = true; _error = null; });
    try {
      final profile = await _profile();
      final schoolId = await _school(profile);
      if (schoolId == null) throw Exception('Your account is not linked to a school.');
      final rows = await _client
          .from('transport_vehicles')
          .select('id, school_id, vehicle_number, route_name, driver_name, driver_phone, capacity, status, notes, created_at, updated_at')
          .eq('school_id', schoolId)
          .order('vehicle_number');
      if (!mounted) return;
      setState(() {
        _schoolId = schoolId;
        _canManage = _manager(profile);
        _vehicles = List<Map<String, dynamic>>.from(rows);
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() { _error = _friendly(e); _loading = false; });
    }
  }

  int _int(dynamic value) => value is num ? value.toInt() : int.tryParse(value?.toString() ?? '') ?? 0;
  String _status(Map<String, dynamic> row) => row['status']?.toString().toLowerCase().trim() ?? 'active';

  Future<void> _edit([Map<String, dynamic>? existing]) async {
    if (!_canManage) return;
    final vehicle = TextEditingController(text: existing?['vehicle_number']?.toString() ?? '');
    final route = TextEditingController(text: existing?['route_name']?.toString() ?? '');
    final driver = TextEditingController(text: existing?['driver_name']?.toString() ?? '');
    final phone = TextEditingController(text: existing?['driver_phone']?.toString() ?? '');
    final capacity = TextEditingController(text: existing == null ? '0' : _int(existing['capacity']).toString());
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
          title: Text(existing == null ? 'Add vehicle' : 'Edit vehicle'),
          content: SizedBox(
            width: 500,
            child: SingleChildScrollView(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                TextField(controller: vehicle, autofocus: true, decoration: const InputDecoration(labelText: 'Vehicle number', prefixIcon: Icon(Icons.directions_bus_outlined))),
                const SizedBox(height: 12),
                TextField(controller: route, decoration: const InputDecoration(labelText: 'Route name', prefixIcon: Icon(Icons.route_outlined))),
                const SizedBox(height: 12),
                TextField(controller: driver, textCapitalization: TextCapitalization.words, decoration: const InputDecoration(labelText: 'Driver name', prefixIcon: Icon(Icons.person_outline))),
                const SizedBox(height: 12),
                TextField(controller: phone, keyboardType: TextInputType.phone, decoration: const InputDecoration(labelText: 'Driver phone', prefixIcon: Icon(Icons.phone_outlined))),
                const SizedBox(height: 12),
                Row(children: [
                  Expanded(child: TextField(controller: capacity, keyboardType: TextInputType.number, inputFormatters: [FilteringTextInputFormatter.digitsOnly], decoration: const InputDecoration(labelText: 'Capacity', prefixIcon: Icon(Icons.event_seat_outlined)))),
                  const SizedBox(width: 12),
                  Expanded(child: DropdownButtonFormField<String>(
                    value: status,
                    decoration: const InputDecoration(labelText: 'Status', prefixIcon: Icon(Icons.task_alt_outlined)),
                    items: const [
                      DropdownMenuItem(value: 'active', child: Text('Active')),
                      DropdownMenuItem(value: 'inactive', child: Text('Inactive')),
                      DropdownMenuItem(value: 'maintenance', child: Text('Maintenance')),
                    ],
                    onChanged: saving ? null : (v) { if (v != null) setDialogState(() => status = v); },
                  )),
                ]),
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
                final number = vehicle.text.trim();
                final cap = int.tryParse(capacity.text.trim());
                if (number.isEmpty) { setDialogState(() => dialogError = 'Vehicle number is required.'); return; }
                if (cap == null || cap < 0) { setDialogState(() => dialogError = 'Enter a valid capacity.'); return; }
                if (schoolId == null) { setDialogState(() => dialogError = 'School link is missing.'); return; }
                setDialogState(() { saving = true; dialogError = null; });
                final payload = <String, dynamic>{
                  'school_id': schoolId,
                  'vehicle_number': number,
                  'route_name': route.text.trim().isEmpty ? null : route.text.trim(),
                  'driver_name': driver.text.trim().isEmpty ? null : driver.text.trim(),
                  'driver_phone': phone.text.trim().isEmpty ? null : phone.text.trim(),
                  'capacity': cap,
                  'status': status,
                  'notes': notes.text.trim().isEmpty ? null : notes.text.trim(),
                  'updated_at': DateTime.now().toUtc().toIso8601String(),
                };
                try {
                  if (existing == null) {
                    await _client.from('transport_vehicles').insert(payload);
                  } else {
                    await _client.from('transport_vehicles').update(payload).eq('id', existing['id']);
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
    vehicle.dispose(); route.dispose(); driver.dispose(); phone.dispose(); capacity.dispose(); notes.dispose();
    if (saved == true) await _load();
  }

  Future<void> _delete(Map<String, dynamic> row) async {
    if (!_canManage) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete vehicle?'),
        content: Text('Delete ${row['vehicle_number']} from transport records?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(context, true), style: FilledButton.styleFrom(backgroundColor: Theme.of(context).colorScheme.error), child: const Text('Delete')),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await _client.from('transport_vehicles').delete().eq('id', row['id']);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Vehicle deleted.')));
      await _load();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(_friendly(e))));
    }
  }

  @override
  Widget build(BuildContext context) {
    final active = _vehicles.where((e) => _status(e) == 'active').length;
    final capacity = _vehicles.fold<int>(0, (sum, e) => sum + _int(e['capacity']));
    final routes = _vehicles.map((e) => e['route_name']?.toString().trim() ?? '').where((e) => e.isNotEmpty).toSet().length;
    return MainWrapper(
      child: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(24),
          children: [
            _Header(canAdd: !_loading && _schoolId != null && _canManage, onAdd: () => _edit()),
            if (!_loading && _schoolId != null && !_canManage) const Padding(padding: EdgeInsets.only(top: 16), child: _ReadOnly()),
            const SizedBox(height: 24),
            if (_loading)
              const Padding(padding: EdgeInsets.symmetric(vertical: 80), child: Center(child: CircularProgressIndicator()))
            else if (_error != null)
              _Error(message: _error!, onRetry: _load)
            else if (_vehicles.isEmpty)
              _Empty(canManage: _canManage, onAdd: () => _edit())
            else ...[
              Wrap(spacing: 12, runSpacing: 12, children: [
                _Chip(Icons.directions_bus_outlined, '${_vehicles.length} vehicles'),
                _Chip(Icons.check_circle_outline, '$active active'),
                _Chip(Icons.route_outlined, '$routes routes'),
                _Chip(Icons.event_seat_outlined, '$capacity seats'),
              ]),
              const SizedBox(height: 18),
              Card(child: Column(children: [
                for (var i = 0; i < _vehicles.length; i++) ...[
                  ListTile(
                    leading: CircleAvatar(backgroundColor: AppColors.primary.withValues(alpha: 0.10), foregroundColor: AppColors.primary, child: const Icon(Icons.directions_bus_outlined)),
                    title: Text(_vehicles[i]['vehicle_number']?.toString() ?? 'Unnamed vehicle', style: const TextStyle(fontWeight: FontWeight.w800)),
                    subtitle: Text([
                      _vehicles[i]['route_name']?.toString().trim(),
                      _vehicles[i]['driver_name']?.toString().trim(),
                      'Capacity ${_int(_vehicles[i]['capacity'])}',
                      _status(_vehicles[i]),
                    ].whereType<String>().where((e) => e.isNotEmpty).join(' • ')),
                    trailing: _canManage ? PopupMenuButton<String>(
                      onSelected: (v) { if (v == 'edit') _edit(_vehicles[i]); if (v == 'delete') _delete(_vehicles[i]); },
                      itemBuilder: (_) => const [
                        PopupMenuItem(value: 'edit', child: Text('Edit')),
                        PopupMenuItem(value: 'delete', child: Text('Delete')),
                      ],
                    ) : null,
                  ),
                  if (i != _vehicles.length - 1) const Divider(height: 1),
                ],
              ])),
            ],
          ],
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.canAdd, required this.onAdd});
  final bool canAdd; final VoidCallback onAdd;
  @override
  Widget build(BuildContext context) => Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
    Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: AppColors.primary, borderRadius: BorderRadius.circular(14)), child: const Icon(Icons.directions_bus_rounded, color: Colors.white)),
    const SizedBox(width: 16),
    const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('Transport', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900)), Text('Manage routes, vehicles and drivers.', style: TextStyle(color: AppColors.textSecondary, fontSize: 13))])),
    FilledButton.icon(onPressed: canAdd ? onAdd : null, icon: const Icon(Icons.add_rounded), label: const Text('Add vehicle')),
  ]);
}

class _Chip extends StatelessWidget {
  const _Chip(this.icon, this.label); final IconData icon; final String label;
  @override
  Widget build(BuildContext context) => Container(padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10), decoration: BoxDecoration(color: AppColors.primary.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(12)), child: Row(mainAxisSize: MainAxisSize.min, children: [Icon(icon, size: 18, color: AppColors.primary), const SizedBox(width: 8), Text(label, style: const TextStyle(fontWeight: FontWeight.w700))]));
}

class _ReadOnly extends StatelessWidget {
  const _ReadOnly();
  @override
  Widget build(BuildContext context) => const Card(child: Padding(padding: EdgeInsets.all(14), child: Row(children: [Icon(Icons.visibility_outlined), SizedBox(width: 10), Expanded(child: Text('Read-only access. Principal or staff access is required to change transport records.'))])));
}

class _Empty extends StatelessWidget {
  const _Empty({required this.canManage, required this.onAdd}); final bool canManage; final VoidCallback onAdd;
  @override
  Widget build(BuildContext context) => Card(child: Padding(padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 24), child: Column(children: [const Icon(Icons.directions_bus_outlined, size: 48, color: AppColors.textMuted), const SizedBox(height: 12), const Text('No vehicles yet', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)), if (canManage) ...[const SizedBox(height: 16), FilledButton.icon(onPressed: onAdd, icon: const Icon(Icons.add), label: const Text('Add vehicle'))]])));
}

class _Error extends StatelessWidget {
  const _Error({required this.message, required this.onRetry}); final String message; final Future<void> Function() onRetry;
  @override
  Widget build(BuildContext context) => Card(child: Padding(padding: const EdgeInsets.all(24), child: Column(children: [Icon(Icons.error_outline, color: Theme.of(context).colorScheme.error, size: 40), const SizedBox(height: 12), Text(message, textAlign: TextAlign.center), const SizedBox(height: 16), OutlinedButton.icon(onPressed: onRetry, icon: const Icon(Icons.refresh), label: const Text('Retry'))])));
}
