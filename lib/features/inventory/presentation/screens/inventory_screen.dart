import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/network/supabase_client.dart';
import '../../../../core/widgets/main_wrapper.dart';

class InventoryScreen extends StatefulWidget {
  const InventoryScreen({super.key});

  @override
  State<InventoryScreen> createState() => _InventoryScreenState();
}

class _InventoryScreenState extends State<InventoryScreen> {
  final SupabaseClient _client = SupabaseConfig.client;
  bool _loading = true;
  String? _error;
  int? _schoolId;
  bool _canManage = false;
  List<Map<String, dynamic>> _items = const [];

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
      debugPrint('Inventory school RPC failed: $e');
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

  Future<void> _load() async {
    if (!mounted) return;
    setState(() { _loading = true; _error = null; });
    try {
      final profile = await _profile();
      final schoolId = await _school(profile);
      if (schoolId == null) throw Exception('Your account is not linked to a school.');
      final rows = await _client
          .from('inventory_items')
          .select('id, school_id, name, category, quantity, unit, reorder_level, notes, created_at, updated_at')
          .eq('school_id', schoolId)
          .order('name');
      if (!mounted) return;
      setState(() {
        _schoolId = schoolId;
        _canManage = _manager(profile);
        _items = List<Map<String, dynamic>>.from(rows);
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() { _error = _friendly(e); _loading = false; });
    }
  }

  Future<void> _edit([Map<String, dynamic>? existing]) async {
    if (!_canManage) return;
    final name = TextEditingController(text: existing?['name']?.toString() ?? '');
    final category = TextEditingController(text: existing?['category']?.toString() ?? '');
    final quantity = TextEditingController(text: existing == null ? '0' : _int(existing['quantity']).toString());
    final unit = TextEditingController(text: existing?['unit']?.toString() ?? '');
    final reorder = TextEditingController(text: existing == null ? '0' : _int(existing['reorder_level']).toString());
    final notes = TextEditingController(text: existing?['notes']?.toString() ?? '');
    String? dialogError;
    bool saving = false;

    final saved = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(existing == null ? 'Add inventory item' : 'Edit inventory item'),
          content: SizedBox(
            width: 500,
            child: SingleChildScrollView(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                TextField(controller: name, autofocus: true, textCapitalization: TextCapitalization.words, decoration: const InputDecoration(labelText: 'Item name', prefixIcon: Icon(Icons.inventory_2_outlined))),
                const SizedBox(height: 12),
                TextField(controller: category, textCapitalization: TextCapitalization.words, decoration: const InputDecoration(labelText: 'Category', prefixIcon: Icon(Icons.category_outlined))),
                const SizedBox(height: 12),
                Row(children: [
                  Expanded(child: TextField(controller: quantity, keyboardType: TextInputType.number, inputFormatters: [FilteringTextInputFormatter.digitsOnly], decoration: const InputDecoration(labelText: 'Quantity', prefixIcon: Icon(Icons.numbers_rounded)))),
                  const SizedBox(width: 12),
                  Expanded(child: TextField(controller: unit, decoration: const InputDecoration(labelText: 'Unit', hintText: 'pcs, boxes, kg', prefixIcon: Icon(Icons.straighten_outlined)))),
                ]),
                const SizedBox(height: 12),
                TextField(controller: reorder, keyboardType: TextInputType.number, inputFormatters: [FilteringTextInputFormatter.digitsOnly], decoration: const InputDecoration(labelText: 'Reorder level', prefixIcon: Icon(Icons.notification_important_outlined))),
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
                final itemName = name.text.trim();
                final qty = int.tryParse(quantity.text.trim());
                final level = int.tryParse(reorder.text.trim());
                if (itemName.isEmpty) { setDialogState(() => dialogError = 'Item name is required.'); return; }
                if (qty == null || qty < 0) { setDialogState(() => dialogError = 'Enter a valid quantity.'); return; }
                if (level == null || level < 0) { setDialogState(() => dialogError = 'Enter a valid reorder level.'); return; }
                if (schoolId == null) { setDialogState(() => dialogError = 'School link is missing.'); return; }
                setDialogState(() { saving = true; dialogError = null; });
                final payload = <String, dynamic>{
                  'school_id': schoolId,
                  'name': itemName,
                  'category': category.text.trim().isEmpty ? null : category.text.trim(),
                  'quantity': qty,
                  'unit': unit.text.trim().isEmpty ? null : unit.text.trim(),
                  'reorder_level': level,
                  'notes': notes.text.trim().isEmpty ? null : notes.text.trim(),
                  'updated_at': DateTime.now().toUtc().toIso8601String(),
                };
                try {
                  if (existing == null) {
                    await _client.from('inventory_items').insert(payload);
                  } else {
                    await _client.from('inventory_items').update(payload).eq('id', existing['id']);
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
    name.dispose(); category.dispose(); quantity.dispose(); unit.dispose(); reorder.dispose(); notes.dispose();
    if (saved == true) await _load();
  }

  Future<void> _delete(Map<String, dynamic> row) async {
    if (!_canManage) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete inventory item?'),
        content: Text('Delete ${row['name']} from inventory?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(context, true), style: FilledButton.styleFrom(backgroundColor: Theme.of(context).colorScheme.error), child: const Text('Delete')),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await _client.from('inventory_items').delete().eq('id', row['id']);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Inventory item deleted.')));
      await _load();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(_friendly(e))));
    }
  }

  bool _low(Map<String, dynamic> row) {
    final level = _int(row['reorder_level']);
    return level > 0 && _int(row['quantity']) <= level;
  }

  @override
  Widget build(BuildContext context) {
    final totalQuantity = _items.fold<int>(0, (sum, e) => sum + _int(e['quantity']));
    final low = _items.where(_low).length;
    final categories = _items.map((e) => e['category']?.toString().trim() ?? '').where((e) => e.isNotEmpty).toSet().length;
    return MainWrapper(
      child: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(24),
          children: [
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: AppColors.primary, borderRadius: BorderRadius.circular(14)), child: const Icon(Icons.inventory_2_rounded, color: Colors.white)),
              const SizedBox(width: 16),
              const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('Inventory', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900)), Text('Track school assets, stock and supplies.', style: TextStyle(color: AppColors.textSecondary, fontSize: 13))])),
              FilledButton.icon(onPressed: !_loading && _schoolId != null && _canManage ? () => _edit() : null, icon: const Icon(Icons.add_rounded), label: const Text('Add item')),
            ]),
            if (!_loading && _schoolId != null && !_canManage) const Padding(padding: EdgeInsets.only(top: 16), child: _ReadOnly()),
            const SizedBox(height: 24),
            if (_loading)
              const Padding(padding: EdgeInsets.symmetric(vertical: 80), child: Center(child: CircularProgressIndicator()))
            else if (_error != null)
              _Error(message: _error!, onRetry: _load)
            else if (_items.isEmpty)
              _Empty(canManage: _canManage, onAdd: () => _edit())
            else ...[
              Wrap(spacing: 12, runSpacing: 12, children: [
                _Chip(Icons.inventory_2_outlined, '${_items.length} items'),
                _Chip(Icons.numbers_rounded, '$totalQuantity units'),
                _Chip(Icons.category_outlined, '$categories categories'),
                _Chip(Icons.warning_amber_rounded, '$low low stock'),
              ]),
              const SizedBox(height: 18),
              Card(child: Column(children: [
                for (var i = 0; i < _items.length; i++) ...[
                  ListTile(
                    leading: CircleAvatar(
                      backgroundColor: (_low(_items[i]) ? const Color(0xFFF59E0B) : AppColors.primary).withValues(alpha: 0.10),
                      foregroundColor: _low(_items[i]) ? const Color(0xFFB45309) : AppColors.primary,
                      child: Icon(_low(_items[i]) ? Icons.warning_amber_rounded : Icons.inventory_2_outlined),
                    ),
                    title: Text(_items[i]['name']?.toString() ?? 'Unnamed item', style: const TextStyle(fontWeight: FontWeight.w800)),
                    subtitle: Text([
                      _items[i]['category']?.toString().trim(),
                      '${_int(_items[i]['quantity'])} ${_items[i]['unit']?.toString().trim() ?? ''}'.trim(),
                      _low(_items[i]) ? 'Low stock' : null,
                    ].whereType<String>().where((e) => e.isNotEmpty).join(' • ')),
                    trailing: _canManage ? PopupMenuButton<String>(
                      onSelected: (v) { if (v == 'edit') _edit(_items[i]); if (v == 'delete') _delete(_items[i]); },
                      itemBuilder: (_) => const [PopupMenuItem(value: 'edit', child: Text('Edit')), PopupMenuItem(value: 'delete', child: Text('Delete'))],
                    ) : null,
                  ),
                  if (i != _items.length - 1) const Divider(height: 1),
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
  Widget build(BuildContext context) => const Card(child: Padding(padding: EdgeInsets.all(14), child: Row(children: [Icon(Icons.visibility_outlined), SizedBox(width: 10), Expanded(child: Text('Read-only access. Principal or staff access is required to change inventory.'))])));
}
class _Empty extends StatelessWidget {
  const _Empty({required this.canManage, required this.onAdd}); final bool canManage; final VoidCallback onAdd;
  @override
  Widget build(BuildContext context) => Card(child: Padding(padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 24), child: Column(children: [const Icon(Icons.inventory_2_outlined, size: 48, color: AppColors.textMuted), const SizedBox(height: 12), const Text('No inventory items yet', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)), if (canManage) ...[const SizedBox(height: 16), FilledButton.icon(onPressed: onAdd, icon: const Icon(Icons.add), label: const Text('Add item'))]])));
}
class _Error extends StatelessWidget {
  const _Error({required this.message, required this.onRetry}); final String message; final Future<void> Function() onRetry;
  @override
  Widget build(BuildContext context) => Card(child: Padding(padding: const EdgeInsets.all(24), child: Column(children: [Icon(Icons.error_outline, color: Theme.of(context).colorScheme.error, size: 40), const SizedBox(height: 12), Text(message, textAlign: TextAlign.center), const SizedBox(height: 16), OutlinedButton.icon(onPressed: onRetry, icon: const Icon(Icons.refresh), label: const Text('Retry'))])));
}
