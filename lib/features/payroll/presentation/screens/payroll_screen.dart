import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/network/supabase_client.dart';
import '../../../../core/widgets/main_wrapper.dart';

class PayrollScreen extends StatefulWidget {
  const PayrollScreen({super.key});

  @override
  State<PayrollScreen> createState() => _PayrollScreenState();
}

class _PayrollScreenState extends State<PayrollScreen> {
  final SupabaseClient _client = SupabaseConfig.client;

  bool _loading = true;
  String? _error;
  int? _schoolId;
  bool _canManage = false;
  List<Map<String, dynamic>> _records = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<Map<String, dynamic>?> _getProfile() async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return null;

    try {
      return await _client
          .from('profiles')
          .select('school_id, role, is_active')
          .eq('id', userId)
          .maybeSingle();
    } catch (e) {
      debugPrint('Payroll profile lookup failed: $e');
      return null;
    }
  }

  Future<int?> _getSchoolId(Map<String, dynamic>? profile) async {
    try {
      final result = await _client.rpc('get_my_school_id');
      if (result is int) return result;
      if (result is num) return result.toInt();
      final parsed = int.tryParse(result?.toString() ?? '');
      if (parsed != null) return parsed;
    } catch (e) {
      debugPrint('get_my_school_id failed: $e');
    }

    final value = profile?['school_id'];
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '');
  }

  bool _profileCanManage(Map<String, dynamic>? profile) {
    if (profile == null) return false;
    final role = profile['role']?.toString().trim().toLowerCase() ?? '';
    final active = profile['is_active'] != false;
    return active && (role == 'principal' || role == 'staff');
  }

  Future<void> _load() async {
    if (!mounted) return;
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final profile = await _getProfile();
      final schoolId = await _getSchoolId(profile);
      if (schoolId == null) {
        throw Exception('Your account is not linked to a school.');
      }

      final rows = await _client
          .from('payroll_records')
          .select(
            'id, school_id, employee_name, employee_role, pay_period, '
            'basic_salary, allowances, deductions, status, paid_at, notes, '
            'created_at, updated_at',
          )
          .eq('school_id', schoolId)
          .order('created_at', ascending: false);

      if (!mounted) return;
      setState(() {
        _schoolId = schoolId;
        _canManage = _profileCanManage(profile);
        _records = List<Map<String, dynamic>>.from(rows);
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = _friendlyError(e);
        _loading = false;
      });
    }
  }

  String _friendlyError(Object error) {
    if (error is PostgrestException) return error.message;
    if (error is AuthException) return error.message;
    return error.toString().replaceFirst('Exception: ', '');
  }

  double _number(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '') ?? 0;
  }

  double _netPay(Map<String, dynamic> record) {
    return _number(record['basic_salary']) +
        _number(record['allowances']) -
        _number(record['deductions']);
  }

  String _money(dynamic value) {
    final amount = value is Map<String, dynamic> ? _netPay(value) : _number(value);
    final negative = amount < 0;
    final absolute = amount.abs();
    final fixed = absolute.toStringAsFixed(2).split('.');
    final digits = fixed[0];
    final grouped = StringBuffer();
    for (var i = 0; i < digits.length; i++) {
      if (i > 0 && (digits.length - i) % 3 == 0) grouped.write(',');
      grouped.write(digits[i]);
    }
    return '${negative ? '-' : ''}PKR ${grouped.toString()}.${fixed[1]}';
  }

  String _dateLabel(dynamic value) {
    final parsed = DateTime.tryParse(value?.toString() ?? '')?.toLocal();
    if (parsed == null) return 'Not recorded';
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(parsed.day)}/${two(parsed.month)}/${parsed.year} '
        '${two(parsed.hour)}:${two(parsed.minute)}';
  }

  String _status(Map<String, dynamic> record) {
    return record['status']?.toString().trim().toLowerCase() ?? 'pending';
  }

  Future<void> _showEditor([Map<String, dynamic>? existing]) async {
    if (!_canManage) {
      _showReadOnlyMessage();
      return;
    }

    final employeeController = TextEditingController(
      text: existing?['employee_name']?.toString() ?? '',
    );
    final roleController = TextEditingController(
      text: existing?['employee_role']?.toString() ?? '',
    );
    final periodController = TextEditingController(
      text: existing?['pay_period']?.toString() ?? '',
    );
    final basicController = TextEditingController(
      text: existing == null ? '' : _number(existing['basic_salary']).toStringAsFixed(2),
    );
    final allowanceController = TextEditingController(
      text: existing == null ? '0' : _number(existing['allowances']).toStringAsFixed(2),
    );
    final deductionController = TextEditingController(
      text: existing == null ? '0' : _number(existing['deductions']).toStringAsFixed(2),
    );
    final notesController = TextEditingController(
      text: existing?['notes']?.toString() ?? '',
    );
    var selectedStatus = _status(existing ?? const <String, dynamic>{});
    if (selectedStatus != 'pending' && selectedStatus != 'paid') {
      selectedStatus = 'pending';
    }
    String? dialogError;
    bool saving = false;

    final saved = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) {
          InputDecoration decoration(String label, IconData icon, {String? hint}) {
            return InputDecoration(
              labelText: label,
              hintText: hint,
              prefixIcon: Icon(icon),
            );
          }

          return AlertDialog(
            title: Text(existing == null ? 'Add payroll record' : 'Edit payroll record'),
            content: SizedBox(
              width: 520,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: employeeController,
                      autofocus: true,
                      textCapitalization: TextCapitalization.words,
                      decoration: decoration(
                        'Employee name',
                        Icons.person_outline_rounded,
                        hint: 'e.g. Muhammad Ali',
                      ),
                    ),
                    const SizedBox(height: 14),
                    TextField(
                      controller: roleController,
                      textCapitalization: TextCapitalization.words,
                      decoration: decoration(
                        'Employee role',
                        Icons.badge_outlined,
                        hint: 'e.g. Teacher',
                      ),
                    ),
                    const SizedBox(height: 14),
                    TextField(
                      controller: periodController,
                      decoration: decoration(
                        'Pay period',
                        Icons.calendar_month_outlined,
                        hint: 'e.g. September 2026',
                      ),
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: basicController,
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            inputFormatters: [
                              FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}')),
                            ],
                            decoration: decoration('Basic salary', Icons.payments_outlined),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextField(
                            controller: allowanceController,
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            inputFormatters: [
                              FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}')),
                            ],
                            decoration: decoration('Allowances', Icons.add_card_outlined),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: deductionController,
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            inputFormatters: [
                              FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}')),
                            ],
                            decoration: decoration('Deductions', Icons.money_off_csred_outlined),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            initialValue: selectedStatus,
                            decoration: decoration('Status', Icons.task_alt_rounded),
                            items: const [
                              DropdownMenuItem(value: 'pending', child: Text('Pending')),
                              DropdownMenuItem(value: 'paid', child: Text('Paid')),
                            ],
                            onChanged: saving
                                ? null
                                : (value) {
                                    if (value != null) {
                                      setDialogState(() => selectedStatus = value);
                                    }
                                  },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    TextField(
                      controller: notesController,
                      minLines: 2,
                      maxLines: 4,
                      textCapitalization: TextCapitalization.sentences,
                      decoration: decoration('Notes', Icons.notes_rounded, hint: 'Optional'),
                    ),
                    if (dialogError != null) ...[
                      const SizedBox(height: 14),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          dialogError!,
                          style: TextStyle(color: Theme.of(context).colorScheme.error),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: saving ? null : () => Navigator.pop(dialogContext, false),
                child: const Text('Cancel'),
              ),
              FilledButton.icon(
                onPressed: saving
                    ? null
                    : () async {
                        final employee = employeeController.text.trim();
                        final role = roleController.text.trim();
                        final period = periodController.text.trim();
                        final basic = double.tryParse(basicController.text.trim());
                        final allowance = double.tryParse(allowanceController.text.trim());
                        final deduction = double.tryParse(deductionController.text.trim());
                        final notes = notesController.text.trim();
                        final schoolId = _schoolId;

                        String? validationError;
                        if (employee.isEmpty) {
                          validationError = 'Employee name is required.';
                        } else if (period.isEmpty) {
                          validationError = 'Pay period is required.';
                        } else if (basic == null || basic < 0) {
                          validationError = 'Enter a valid basic salary.';
                        } else if (allowance == null || allowance < 0) {
                          validationError = 'Enter valid allowances.';
                        } else if (deduction == null || deduction < 0) {
                          validationError = 'Enter valid deductions.';
                        } else if (deduction > basic + allowance) {
                          validationError = 'Deductions cannot exceed salary plus allowances.';
                        } else if (schoolId == null) {
                          validationError = 'School link is missing.';
                        }

                        if (validationError != null) {
                          setDialogState(() => dialogError = validationError);
                          return;
                        }

                        setDialogState(() {
                          saving = true;
                          dialogError = null;
                        });

                        try {
                          final wasPaid = existing != null && _status(existing) == 'paid';
                          final existingPaidAt = existing == null ? null : existing['paid_at'];
                          final payload = <String, dynamic>{
                            'school_id': schoolId,
                            'employee_name': employee,
                            'employee_role': role.isEmpty ? null : role,
                            'pay_period': period,
                            'basic_salary': basic,
                            'allowances': allowance,
                            'deductions': deduction,
                            'status': selectedStatus,
                            'paid_at': selectedStatus == 'paid'
                                ? (wasPaid && existingPaidAt != null
                                    ? existingPaidAt
                                    : DateTime.now().toUtc().toIso8601String())
                                : null,
                            'notes': notes.isEmpty ? null : notes,
                            'updated_at': DateTime.now().toUtc().toIso8601String(),
                          };

                          if (existing == null) {
                            await _client.from('payroll_records').insert(payload);
                          } else {
                            await _client
                                .from('payroll_records')
                                .update(payload)
                                .eq('id', existing['id']);
                          }

                          if (dialogContext.mounted) {
                            Navigator.pop(dialogContext, true);
                          }
                        } catch (e) {
                          setDialogState(() {
                            saving = false;
                            dialogError = _friendlyError(e);
                          });
                        }
                      },
                icon: saving
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.save_outlined),
                label: Text(existing == null ? 'Create' : 'Save'),
              ),
            ],
          );
        },
      ),
    );

    employeeController.dispose();
    roleController.dispose();
    periodController.dispose();
    basicController.dispose();
    allowanceController.dispose();
    deductionController.dispose();
    notesController.dispose();

    if (saved == true) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(existing == null ? 'Payroll record created.' : 'Payroll record updated.')),
        );
      }
      await _load();
    }
  }

  Future<void> _delete(Map<String, dynamic> record) async {
    if (!_canManage) {
      _showReadOnlyMessage();
      return;
    }

    final employee = record['employee_name']?.toString() ?? 'this employee';
    final period = record['pay_period']?.toString() ?? '';
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete payroll record?'),
        content: Text('Delete the $period payroll record for $employee? This cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      await _client.from('payroll_records').delete().eq('id', record['id']);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$employee payroll record deleted.')),
      );
      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_friendlyError(e))),
      );
    }
  }

  void _showReadOnlyMessage() {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Payroll is read-only for this account. Principal or staff access is required to make changes.'),
      ),
    );
  }

  Color _statusColor(BuildContext context, String status) {
    if (status == 'paid') return const Color(0xFF16A34A);
    if (status == 'pending') return const Color(0xFFF59E0B);
    return Theme.of(context).colorScheme.secondary;
  }

  @override
  Widget build(BuildContext context) {
    final paidCount = _records.where((record) => _status(record) == 'paid').length;
    final pendingCount = _records.where((record) => _status(record) == 'pending').length;
    final totalNet = _records.fold<double>(0, (sum, record) => sum + _netPay(record));

    return MainWrapper(
      child: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(24),
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(
                    Icons.payments_rounded,
                    color: Colors.white,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 16),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Payroll',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                          letterSpacing: -0.5,
                        ),
                      ),
                      Text(
                        'Manage salary records and staff payments for your school.',
                        style: TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
                FilledButton.icon(
                  onPressed: _loading || _schoolId == null || !_canManage
                      ? null
                      : () => _showEditor(),
                  icon: const Icon(Icons.add_rounded),
                  label: const Text('Add payroll'),
                ),
              ],
            ),
            if (!_loading && _schoolId != null && !_canManage) ...[
              const SizedBox(height: 16),
              const _ReadOnlyBanner(),
            ],
            const SizedBox(height: 24),
            if (_loading)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 80),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_error != null)
              _ErrorCard(message: _error!, onRetry: _load)
            else if (_records.isEmpty)
              _EmptyCard(canManage: _canManage, onAdd: () => _showEditor())
            else ...[
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  _SummaryChip(
                    icon: Icons.receipt_long_outlined,
                    label: '${_records.length} records',
                  ),
                  _SummaryChip(
                    icon: Icons.account_balance_wallet_outlined,
                    label: _money(totalNet),
                  ),
                  _SummaryChip(
                    icon: Icons.check_circle_outline_rounded,
                    label: '$paidCount paid',
                  ),
                  _SummaryChip(
                    icon: Icons.schedule_rounded,
                    label: '$pendingCount pending',
                  ),
                ],
              ),
              const SizedBox(height: 18),
              Card(
                clipBehavior: Clip.antiAlias,
                child: Column(
                  children: [
                    for (var i = 0; i < _records.length; i++) ...[
                      _PayrollTile(
                        record: _records[i],
                        netPay: _money(_records[i]),
                        paidLabel: _dateLabel(_records[i]['paid_at']),
                        statusColor: _statusColor(context, _status(_records[i])),
                        canManage: _canManage,
                        onEdit: () => _showEditor(_records[i]),
                        onDelete: () => _delete(_records[i]),
                      ),
                      if (i != _records.length - 1) const Divider(height: 1),
                    ],
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _PayrollTile extends StatelessWidget {
  const _PayrollTile({
    required this.record,
    required this.netPay,
    required this.paidLabel,
    required this.statusColor,
    required this.canManage,
    required this.onEdit,
    required this.onDelete,
  });

  final Map<String, dynamic> record;
  final String netPay;
  final String paidLabel;
  final Color statusColor;
  final bool canManage;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final employee = record['employee_name']?.toString() ?? 'Unnamed employee';
    final role = record['employee_role']?.toString().trim() ?? '';
    final period = record['pay_period']?.toString() ?? 'No pay period';
    final status = record['status']?.toString().trim().toLowerCase() ?? 'pending';
    final notes = record['notes']?.toString().trim() ?? '';

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        leading: CircleAvatar(
          backgroundColor: statusColor.withValues(alpha: 0.12),
          foregroundColor: statusColor,
          child: Icon(status == 'paid' ? Icons.check_rounded : Icons.schedule_rounded),
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(
                employee,
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
            ),
            const SizedBox(width: 8),
            _StatusPill(status: status, color: statusColor),
          ],
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 5),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(role.isEmpty ? period : '$role • $period'),
              const SizedBox(height: 2),
              Text(
                status == 'paid' ? 'Net pay: $netPay • Paid $paidLabel' : 'Net pay: $netPay',
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              if (notes.isNotEmpty) ...[
                const SizedBox(height: 2),
                Text(
                  notes,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: AppColors.textSecondary),
                ),
              ],
            ],
          ),
        ),
        trailing: canManage
            ? PopupMenuButton<String>(
                onSelected: (value) {
                  if (value == 'edit') onEdit();
                  if (value == 'delete') onDelete();
                },
                itemBuilder: (context) => const [
                  PopupMenuItem(
                    value: 'edit',
                    child: ListTile(
                      leading: Icon(Icons.edit_outlined),
                      title: Text('Edit'),
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                  PopupMenuItem(
                    value: 'delete',
                    child: ListTile(
                      leading: Icon(Icons.delete_outline),
                      title: Text('Delete'),
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                ],
              )
            : null,
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.status, required this.color});

  final String status;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(99),
        ),
        child: Text(
          status.isEmpty ? 'Pending' : '${status[0].toUpperCase()}${status.substring(1)}',
          style: TextStyle(
            color: color,
            fontSize: 11,
            fontWeight: FontWeight.w800,
          ),
        ),
      );
}

class _SummaryChip extends StatelessWidget {
  const _SummaryChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: AppColors.primary.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 18, color: AppColors.primary),
            const SizedBox(width: 8),
            Text(label, style: const TextStyle(fontWeight: FontWeight.w700)),
          ],
        ),
      );
}

class _ReadOnlyBanner extends StatelessWidget {
  const _ReadOnlyBanner();

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFFF59E0B).withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Row(
          children: [
            Icon(Icons.visibility_outlined, color: Color(0xFFB45309)),
            SizedBox(width: 10),
            Expanded(
              child: Text(
                'Read-only access. Only active principal and staff accounts can add, edit, or delete payroll records.',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
      );
}

class _EmptyCard extends StatelessWidget {
  const _EmptyCard({required this.canManage, required this.onAdd});

  final bool canManage;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) => Card(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 56),
          child: Column(
            children: [
              const Icon(Icons.payments_outlined, size: 48, color: AppColors.textMuted),
              const SizedBox(height: 14),
              const Text(
                'No payroll records yet',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 6),
              Text(
                canManage
                    ? 'Create the first salary record for this school.'
                    : 'There are no payroll records available for this school.',
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppColors.textSecondary),
              ),
              if (canManage) ...[
                const SizedBox(height: 18),
                FilledButton.icon(
                  onPressed: onAdd,
                  icon: const Icon(Icons.add_rounded),
                  label: const Text('Add payroll'),
                ),
              ],
            ],
          ),
        ),
      );
}

class _ErrorCard extends StatelessWidget {
  const _ErrorCard({required this.message, required this.onRetry});

  final String message;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) => Card(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              Icon(Icons.error_outline, color: Theme.of(context).colorScheme.error, size: 40),
              const SizedBox(height: 12),
              Text(message, textAlign: TextAlign.center),
              const SizedBox(height: 16),
              OutlinedButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
}
