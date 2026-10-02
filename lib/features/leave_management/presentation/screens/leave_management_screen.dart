import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/network/supabase_client.dart';
import '../../../../core/widgets/main_wrapper.dart';

class LeaveManagementScreen extends StatefulWidget {
  const LeaveManagementScreen({super.key});

  @override
  State<LeaveManagementScreen> createState() => _LeaveManagementScreenState();
}

class _LeaveManagementScreenState extends State<LeaveManagementScreen> {
  final SupabaseClient _client = SupabaseConfig.client;
  bool _loading = true;
  bool _working = false;
  bool _canManage = false;
  List<Map<String, dynamic>> _rows = const [];
  String _filter = 'all';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final uid = _client.auth.currentUser?.id;
      if (uid == null) throw Exception('Please login again.');
      final profile = await _client.from('profiles').select('role,school_id').eq('id', uid).maybeSingle();
      if (profile == null || profile['school_id'] == null) {
        throw Exception('Your account is not linked to a school.');
      }
      final role = profile['role']?.toString() ?? '';
      final rows = await _client.from('leave_requests').select(
        'id,user_id,leave_type,start_date,end_date,reason,status,approved_by,approved_at,created_at,profiles:user_id(full_name,role)'
      ).order('created_at', ascending: false);
      if (!mounted) return;
      setState(() {
        _canManage = role == 'principal' || role == 'staff';
        _rows = List<Map<String, dynamic>>.from(rows);
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      _message(e.toString().replaceFirst('Exception: ', ''), true);
    }
  }

  Future<void> _applyLeave() async {
    final type = TextEditingController(text: 'Casual');
    final reason = TextEditingController();
    DateTime start = DateTime.now();
    DateTime end = start;
    try {
      final saved = await showDialog<bool>(
        context: context,
        builder: (context) => StatefulBuilder(
          builder: (context, setDialogState) => AlertDialog(
            title: const Text('Apply for Leave'),
            content: SizedBox(
              width: 480,
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                TextField(controller: type, decoration: const InputDecoration(labelText: 'Leave type')),
                const SizedBox(height: 12),
                Row(children: [
                  Expanded(child: OutlinedButton.icon(
                    onPressed: () async {
                      final d = await showDatePicker(context: context, firstDate: DateTime(2020), lastDate: DateTime(2100), initialDate: start);
                      if (d != null) setDialogState(() { start = d; if (end.isBefore(start)) end = start; });
                    },
                    icon: const Icon(Icons.calendar_today),
                    label: Text('From ' + _fmtDate(start)),
                  )),
                  const SizedBox(width: 8),
                  Expanded(child: OutlinedButton.icon(
                    onPressed: () async {
                      final d = await showDatePicker(context: context, firstDate: start, lastDate: DateTime(2100), initialDate: end);
                      if (d != null) setDialogState(() => end = d);
                    },
                    icon: const Icon(Icons.event),
                    label: Text('To ' + _fmtDate(end)),
                  )),
                ]),
                const SizedBox(height: 12),
                TextField(controller: reason, maxLines: 4, decoration: const InputDecoration(labelText: 'Reason', alignLabelWithHint: true)),
              ]),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
              FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Submit')),
            ],
          ),
        ),
      );
      if (saved != true) return;
      if (reason.text.trim().isEmpty) {
        _message('Reason is required.', true);
        return;
      }
      setState(() => _working = true);
      final uid = _client.auth.currentUser!.id;
      final profile = await _client.from('profiles').select('school_id').eq('id', uid).single();
      await _client.from('leave_requests').insert({
        'school_id': profile['school_id'],
        'user_id': uid,
        'leave_type': type.text.trim(),
        'start_date': _fmtDate(start),
        'end_date': _fmtDate(end),
        'reason': reason.text.trim(),
        'status': 'pending',
      });
      _message('Leave request submitted.');
      await _load();
    } catch (e) {
      _message('Could not submit leave: ' + e.toString(), true);
    } finally {
      type.dispose();
      reason.dispose();
      if (mounted) setState(() => _working = false);
    }
  }

  Future<void> _changeStatus(Map<String, dynamic> row, String status) async {
    if (!_canManage) return;
    setState(() => _working = true);
    try {
      await _client.from('leave_requests').update({
        'status': status,
        'approved_by': _client.auth.currentUser!.id,
        'approved_at': status == 'approved' ? DateTime.now().toIso8601String() : null,
      }).eq('id', row['id']);
      _message(status == 'approved' ? 'Leave approved.' : 'Leave rejected.');
      await _load();
    } catch (e) {
      _message('Could not update leave: ' + e.toString(), true);
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  String _fmtDate(DateTime value) =>
      value.year.toString().padLeft(4, '0') + '-' +
      value.month.toString().padLeft(2, '0') + '-' +
      value.day.toString().padLeft(2, '0');

  void _message(String text, [bool error = false]) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(text),
      backgroundColor: error ? AppColors.error : AppColors.success,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final visible = _filter == 'all'
        ? _rows
        : _rows.where((row) => row['status'] == _filter).toList();

    return MainWrapper(
      child: Scaffold(
        backgroundColor: AppColors.background,
        floatingActionButton: FloatingActionButton.extended(
          onPressed: _working ? null : _applyLeave,
          icon: const Icon(Icons.add_task_rounded),
          label: const Text('Apply Leave'),
        ),
        body: RefreshIndicator(
          onRefresh: _load,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 90),
            children: [
              const Text('Leave Management', style: TextStyle(fontSize: 25, fontWeight: FontWeight.w900)),
              const SizedBox(height: 4),
              Text(
                _canManage ? 'Review and manage school leave requests.' : 'Submit and track your leave requests.',
                style: const TextStyle(color: AppColors.textSecondary),
              ),
              const SizedBox(height: 18),
              Wrap(
                spacing: 8,
                children: ['all', 'pending', 'approved', 'rejected', 'cancelled'].map(
                  (value) => ChoiceChip(
                    label: Text(value[0].toUpperCase() + value.substring(1)),
                    selected: _filter == value,
                    onSelected: (_) => setState(() => _filter = value),
                  ),
                ).toList(),
              ),
              const SizedBox(height: 18),
              if (_loading)
                const Center(child: Padding(padding: EdgeInsets.all(40), child: CircularProgressIndicator()))
              else if (visible.isEmpty)
                const Card(child: Padding(padding: EdgeInsets.all(30), child: Center(child: Text('No leave requests found.'))))
              else
                ...visible.map(_card),
            ],
          ),
        ),
      ),
    );
  }

  Widget _card(Map<String, dynamic> row) {
    final profile = row['profiles'] is Map ? Map<String, dynamic>.from(row['profiles']) : <String, dynamic>{};
    final status = row['status']?.toString() ?? 'pending';
    final color = status == 'approved'
        ? AppColors.success
        : status == 'rejected'
            ? AppColors.error
            : status == 'pending'
                ? AppColors.warning
                : AppColors.textSecondary;

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            CircleAvatar(child: Icon(status == 'approved' ? Icons.check : status == 'rejected' ? Icons.close : Icons.pending_actions)),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(profile['full_name']?.toString() ?? 'User', style: const TextStyle(fontWeight: FontWeight.w800)),
              Text(
                (row['leave_type']?.toString() ?? 'Leave') + ' • ' +
                (row['start_date']?.toString() ?? '—') + ' → ' +
                (row['end_date']?.toString() ?? '—'),
                style: const TextStyle(color: AppColors.textSecondary),
              ),
            ])),
            Chip(label: Text(status.toUpperCase()), backgroundColor: color.withValues(alpha: .12)),
          ]),
          const SizedBox(height: 10),
          Text(row['reason']?.toString() ?? '—'),
          if (_canManage && status == 'pending')
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Row(mainAxisAlignment: MainAxisAlignment.end, children: [
                OutlinedButton(
                  onPressed: _working ? null : () => _changeStatus(row, 'rejected'),
                  child: const Text('Reject'),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  onPressed: _working ? null : () => _changeStatus(row, 'approved'),
                  child: const Text('Approve'),
                ),
              ]),
            ),
        ]),
      ),
    );
  }
}
