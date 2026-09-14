import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/app_colors.dart';
import '../../core/network/supabase_client.dart';
import '../../core/widgets/main_wrapper.dart';

enum RecordFieldType { text, multiline, number, money, date, select }

class RecordField {
  final String column;
  final String label;
  final RecordFieldType type;
  final bool required;
  final List<String> options;
  final String? hint;
  final bool showInSummary;

  const RecordField({
    required this.column,
    required this.label,
    this.type = RecordFieldType.text,
    this.required = false,
    this.options = const [],
    this.hint,
    this.showInSummary = true,
  });
}

/// A metric card computed from the loaded rows of a module.
class RecordMetric {
  final String label;
  final IconData icon;
  final Color color;
  final String Function(List<Map<String, dynamic>> rows) value;

  const RecordMetric({
    required this.label,
    required this.icon,
    required this.color,
    required this.value,
  });
}

/// Optional colored status chip rendered on every record card.
class RecordStatus {
  final String column;
  final Map<String, Color> colors;

  const RecordStatus({required this.column, this.colors = const {}});

  Color colorOf(String value) =>
      colors[value.toLowerCase()] ?? AppColors.textSecondary;
}

class RecordModuleConfig {
  final String table;
  final String title;
  final String subtitle;
  final IconData icon;
  final String titleColumn;
  final List<String> subtitleColumns;
  final List<RecordField> fields;
  final List<RecordMetric> metrics;
  final RecordStatus? status;
  final String orderColumn;
  final bool orderAscending;

  const RecordModuleConfig({
    required this.table,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.titleColumn,
    required this.fields,
    this.subtitleColumns = const [],
    this.metrics = const [],
    this.status,
    this.orderColumn = 'created_at',
    this.orderAscending = false,
  });
}

typedef RecordRow = Map<String, dynamic>;

class RecordModuleController
    extends AutoDisposeFamilyAsyncNotifier<List<RecordRow>, RecordModuleConfig> {
  late RecordModuleConfig _config;

  @override
  Future<List<RecordRow>> build(RecordModuleConfig arg) async {
    _config = arg;
    return _fetch();
  }

  Future<int> _requireSchoolId() async {
    final schoolId = await ref.read(schoolIdProvider.future);

    if (schoolId == null) {
      throw Exception('School not found for the current user.');
    }

    return schoolId;
  }

  Future<List<RecordRow>> _fetch() async {
    final schoolId = await _requireSchoolId();

    final data = await SupabaseConfig.client
        .from(_config.table)
        .select()
        .eq('school_id', schoolId)
        .order(_config.orderColumn, ascending: _config.orderAscending);

    return (data as List)
        .map((item) => Map<String, dynamic>.from(item as Map))
        .toList();
  }

  Future<void> refresh() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(_fetch);
  }

  Future<void> save(RecordRow values, {String? id}) async {
    final schoolId = await _requireSchoolId();
    final payload = <String, dynamic>{...values, 'school_id': schoolId};

    if (id == null) {
      await SupabaseConfig.client.from(_config.table).insert(payload);
    } else {
      await SupabaseConfig.client
          .from(_config.table)
          .update(values)
          .eq('id', id)
          .eq('school_id', schoolId);
    }

    await refresh();
  }

  Future<void> delete(String id) async {
    final schoolId = await _requireSchoolId();

    await SupabaseConfig.client
        .from(_config.table)
        .delete()
        .eq('id', id)
        .eq('school_id', schoolId);

    await refresh();
  }
}

final recordModuleProvider = AsyncNotifierProvider.autoDispose
    .family<RecordModuleController, List<RecordRow>, RecordModuleConfig>(
  RecordModuleController.new,
);

/// Data driven screen used by the operational modules (transport, hostel,
/// inventory, payroll, accounting and classrooms). Each module only supplies a
/// [RecordModuleConfig]; listing, search, metrics and CRUD are shared.
class RecordModuleScreen extends ConsumerStatefulWidget {
  final RecordModuleConfig config;

  const RecordModuleScreen({super.key, required this.config});

  @override
  ConsumerState<RecordModuleScreen> createState() => _RecordModuleScreenState();
}

class _RecordModuleScreenState extends ConsumerState<RecordModuleScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _query = '';

  RecordModuleConfig get _config => widget.config;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<RecordRow> _filter(List<RecordRow> rows) {
    if (_query.trim().isEmpty) {
      return rows;
    }

    final query = _query.trim().toLowerCase();

    return rows.where((row) {
      return row.values.any(
        (value) => value != null && value.toString().toLowerCase().contains(query),
      );
    }).toList();
  }

  Future<void> _openForm({RecordRow? row}) async {
    final saved = await showDialog<bool>(
      context: context,
      builder: (_) => _RecordFormDialog(config: _config, row: row),
    );

    if (saved == true && mounted) {
      _showMessage('${_config.title} record saved.');
    }
  }

  Future<void> _confirmDelete(RecordRow row) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete record'),
        content: Text(
          'Delete "${row[_config.titleColumn] ?? 'this record'}"? '
          'This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true) {
      return;
    }

    try {
      await ref
          .read(recordModuleProvider(_config).notifier)
          .delete(row['id'].toString());

      if (mounted) {
        _showMessage('Record deleted.');
      }
    } catch (error) {
      if (mounted) {
        _showMessage('Delete failed: $error', isError: true);
      }
    }
  }

  void _showMessage(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? AppColors.error : AppColors.success,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(recordModuleProvider(_config));

    return MainWrapper(
      child: Scaffold(
        backgroundColor: AppColors.background,
        floatingActionButton: FloatingActionButton.extended(
          onPressed: () => _openForm(),
          icon: const Icon(Icons.add_rounded),
          label: const Text('Add record'),
        ),
        body: RefreshIndicator(
          onRefresh: () =>
              ref.read(recordModuleProvider(_config).notifier).refresh(),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 90),
            physics: const AlwaysScrollableScrollPhysics(),
            children: [
              _Header(config: _config),
              const SizedBox(height: 20),
              _SearchBox(
                controller: _searchController,
                hint: 'Search ${_config.title.toLowerCase()}...',
                onChanged: (value) => setState(() => _query = value),
              ),
              const SizedBox(height: 20),
              state.when(
                loading: () => const Padding(
                  padding: EdgeInsets.symmetric(vertical: 60),
                  child: Center(child: CircularProgressIndicator()),
                ),
                error: (error, _) => _ErrorState(
                  message: error.toString(),
                  onRetry: () =>
                      ref.read(recordModuleProvider(_config).notifier).refresh(),
                ),
                data: (rows) {
                  final visible = _filter(rows);

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (_config.metrics.isNotEmpty) ...[
                        _MetricsGrid(metrics: _config.metrics, rows: rows),
                        const SizedBox(height: 24),
                      ],
                      if (visible.isEmpty)
                        _EmptyState(
                          config: _config,
                          filtered: rows.isNotEmpty,
                          onAdd: () => _openForm(),
                        )
                      else
                        ...visible.map(
                          (row) => Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: _RecordCard(
                              config: _config,
                              row: row,
                              onEdit: () => _openForm(row: row),
                              onDelete: () => _confirmDelete(row),
                            ),
                          ),
                        ),
                    ],
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  final RecordModuleConfig config;

  const _Header({required this.config});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppColors.primaryLight,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Icon(config.icon, color: AppColors.primary, size: 26),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                config.title,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                config.subtitle,
                style: const TextStyle(
                  fontSize: 13,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _SearchBox extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final ValueChanged<String> onChanged;

  const _SearchBox({
    required this.controller,
    required this.hint,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      onChanged: onChanged,
      decoration: InputDecoration(
        hintText: hint,
        prefixIcon: const Icon(Icons.search_rounded),
        filled: true,
        fillColor: AppColors.surface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.border),
        ),
      ),
    );
  }
}

class _MetricsGrid extends StatelessWidget {
  final List<RecordMetric> metrics;
  final List<RecordRow> rows;

  const _MetricsGrid({required this.metrics, required this.rows});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        int columns = 1;

        if (constraints.maxWidth >= 1100) {
          columns = 4;
        } else if (constraints.maxWidth >= 760) {
          columns = 3;
        } else if (constraints.maxWidth >= 480) {
          columns = 2;
        }

        const spacing = 14.0;
        final width =
            (constraints.maxWidth - spacing * (columns - 1)) / columns;

        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: metrics
              .map(
                (metric) => SizedBox(
                  width: width,
                  child: _MetricCard(metric: metric, rows: rows),
                ),
              )
              .toList(),
        );
      },
    );
  }
}

class _MetricCard extends StatelessWidget {
  final RecordMetric metric;
  final List<RecordRow> rows;

  const _MetricCard({required this.metric, required this.rows});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: metric.color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(metric.icon, color: metric.color, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  metric.value(rows),
                  style: const TextStyle(
                    fontSize: 19,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                  ),
                ),
                Text(
                  metric.label,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _RecordCard extends StatelessWidget {
  final RecordModuleConfig config;
  final RecordRow row;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _RecordCard({
    required this.config,
    required this.row,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final status = config.status;
    final statusValue = status == null ? null : formatValue(row[status.column]);

    final summary = config.fields
        .where((field) => field.showInSummary && row[field.column] != null)
        .where((field) => field.column != config.titleColumn)
        .where((field) => status == null || field.column != status.column)
        .take(4)
        .toList();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      formatValue(row[config.titleColumn]),
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    if (config.subtitleColumns.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(
                          config.subtitleColumns
                              .map((column) => formatValue(row[column]))
                              .where((value) => value.isNotEmpty)
                              .join(' • '),
                          style: const TextStyle(
                            fontSize: 12.5,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              if (statusValue != null && statusValue.isNotEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: status!.colorOf(statusValue).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    statusValue,
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                      color: status.colorOf(statusValue),
                    ),
                  ),
                ),
              IconButton(
                tooltip: 'Edit',
                onPressed: onEdit,
                icon: const Icon(Icons.edit_outlined, size: 19),
              ),
              IconButton(
                tooltip: 'Delete',
                onPressed: onDelete,
                icon: const Icon(
                  Icons.delete_outline_rounded,
                  size: 19,
                  color: AppColors.error,
                ),
              ),
            ],
          ),
          if (summary.isNotEmpty) ...[
            const Divider(height: 24, color: AppColors.divider),
            Wrap(
              spacing: 24,
              runSpacing: 10,
              children: summary
                  .map(
                    (field) => _SummaryItem(
                      label: field.label,
                      value: formatValue(row[field.column], field: field),
                    ),
                  )
                  .toList(),
            ),
          ],
        ],
      ),
    );
  }
}

class _SummaryItem extends StatelessWidget {
  final String label;
  final String value;

  const _SummaryItem({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label.toUpperCase(),
          style: const TextStyle(
            fontSize: 10,
            letterSpacing: 0.6,
            fontWeight: FontWeight.w700,
            color: AppColors.textMuted,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: const TextStyle(
            fontSize: 13.5,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
        ),
      ],
    );
  }
}

class _EmptyState extends StatelessWidget {
  final RecordModuleConfig config;
  final bool filtered;
  final VoidCallback onAdd;

  const _EmptyState({
    required this.config,
    required this.filtered,
    required this.onAdd,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 24),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          Icon(config.icon, size: 42, color: AppColors.textMuted),
          const SizedBox(height: 12),
          Text(
            filtered
                ? 'No record matches your search.'
                : 'No ${config.title.toLowerCase()} records yet.',
            style: const TextStyle(
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            filtered
                ? 'Try a different keyword.'
                : 'Add your first record to start tracking.',
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 13,
              color: AppColors.textSecondary,
            ),
          ),
          if (!filtered) ...[
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: onAdd,
              icon: const Icon(Icons.add_rounded),
              label: const Text('Add record'),
            ),
          ],
        ],
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ErrorState({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.error.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.error.withValues(alpha: 0.25)),
      ),
      child: Column(
        children: [
          const Icon(Icons.error_outline_rounded, color: AppColors.error),
          const SizedBox(height: 10),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 13, color: AppColors.textPrimary),
          ),
          const SizedBox(height: 14),
          OutlinedButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Retry'),
          ),
        ],
      ),
    );
  }
}

class _RecordFormDialog extends ConsumerStatefulWidget {
  final RecordModuleConfig config;
  final RecordRow? row;

  const _RecordFormDialog({required this.config, this.row});

  @override
  ConsumerState<_RecordFormDialog> createState() => _RecordFormDialogState();
}

class _RecordFormDialogState extends ConsumerState<_RecordFormDialog> {
  final _formKey = GlobalKey<FormState>();
  final Map<String, TextEditingController> _controllers = {};
  final Map<String, String?> _selections = {};

  bool _saving = false;
  String? _error;

  bool get _isEdit => widget.row != null;

  @override
  void initState() {
    super.initState();

    for (final field in widget.config.fields) {
      final value = widget.row?[field.column];

      if (field.type == RecordFieldType.select) {
        _selections[field.column] = value?.toString();
      } else {
        _controllers[field.column] = TextEditingController(
          text: value == null ? '' : value.toString(),
        );
      }
    }
  }

  @override
  void dispose() {
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _pickDate(RecordField field) async {
    final controller = _controllers[field.column]!;
    final current = DateTime.tryParse(controller.text);

    final picked = await showDatePicker(
      context: context,
      initialDate: current ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );

    if (picked != null) {
      controller.text = _formatDate(picked);
    }
  }

  Map<String, dynamic> _collectValues() {
    final values = <String, dynamic>{};

    for (final field in widget.config.fields) {
      if (field.type == RecordFieldType.select) {
        values[field.column] = _selections[field.column];
        continue;
      }

      final raw = _controllers[field.column]!.text.trim();

      if (raw.isEmpty) {
        values[field.column] = null;
        continue;
      }

      switch (field.type) {
        case RecordFieldType.number:
          values[field.column] = int.tryParse(raw);
        case RecordFieldType.money:
          values[field.column] = double.tryParse(raw);
        default:
          values[field.column] = raw;
      }
    }

    return values;
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _saving = true;
      _error = null;
    });

    try {
      await ref.read(recordModuleProvider(widget.config).notifier).save(
            _collectValues(),
            id: widget.row?['id']?.toString(),
          );

      if (mounted) {
        Navigator.of(context).pop(true);
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = error.toString();
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(
        '${_isEdit ? 'Edit' : 'Add'} ${widget.config.title.toLowerCase()} record',
      ),
      content: SizedBox(
        width: 460,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (final field in widget.config.fields)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 14),
                    child: _buildField(field),
                  ),
                if (_error != null)
                  Text(
                    _error!,
                    style: const TextStyle(
                      color: AppColors.error,
                      fontSize: 12.5,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.of(context).pop(false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _saving ? null : _submit,
          child: _saving
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Save'),
        ),
      ],
    );
  }

  Widget _buildField(RecordField field) {
    final decoration = InputDecoration(
      labelText: field.required ? '${field.label} *' : field.label,
      hintText: field.hint,
      border: const OutlineInputBorder(),
    );

    if (field.type == RecordFieldType.select) {
      return DropdownButtonFormField<String>(
        initialValue: _selections[field.column],
        decoration: decoration,
        items: field.options
            .map(
              (option) => DropdownMenuItem(value: option, child: Text(option)),
            )
            .toList(),
        onChanged: (value) => setState(() => _selections[field.column] = value),
        validator: (value) => _validate(field, value),
      );
    }

    final controller = _controllers[field.column]!;

    if (field.type == RecordFieldType.date) {
      return TextFormField(
        controller: controller,
        readOnly: true,
        decoration: decoration.copyWith(
          suffixIcon: const Icon(Icons.calendar_today_rounded, size: 18),
        ),
        onTap: () => _pickDate(field),
        validator: (value) => _validate(field, value),
      );
    }

    final isNumeric = field.type == RecordFieldType.number ||
        field.type == RecordFieldType.money;

    return TextFormField(
      controller: controller,
      decoration: decoration,
      maxLines: field.type == RecordFieldType.multiline ? 3 : 1,
      keyboardType: isNumeric
          ? const TextInputType.numberWithOptions(decimal: true)
          : TextInputType.text,
      inputFormatters: isNumeric
          ? [
              FilteringTextInputFormatter.allow(
                field.type == RecordFieldType.money
                    ? RegExp(r'[0-9.]')
                    : RegExp(r'[0-9]'),
              ),
            ]
          : null,
      validator: (value) => _validate(field, value),
    );
  }

  String? _validate(RecordField field, String? value) {
    final text = value?.trim() ?? '';

    if (field.required && text.isEmpty) {
      return '${field.label} is required';
    }

    if (text.isEmpty) {
      return null;
    }

    if (field.type == RecordFieldType.number && int.tryParse(text) == null) {
      return 'Enter a whole number';
    }

    if (field.type == RecordFieldType.money && double.tryParse(text) == null) {
      return 'Enter a valid amount';
    }

    return null;
  }
}

String formatValue(dynamic value, {RecordField? field}) {
  if (value == null) {
    return '';
  }

  if (field?.type == RecordFieldType.money && value is num) {
    return 'Rs ${formatAmount(value)}';
  }

  if (field?.type == RecordFieldType.date) {
    final date = DateTime.tryParse(value.toString());

    if (date != null) {
      return _formatDate(date);
    }
  }

  return value.toString();
}

String _formatDate(DateTime date) {
  final month = date.month.toString().padLeft(2, '0');
  final day = date.day.toString().padLeft(2, '0');

  return '${date.year}-$month-$day';
}

/// Formats an amount with thousands separators, e.g. `1234567` -> `1,234,567`.
String formatAmount(num value) {
  final rounded = value.round().abs().toString();
  final buffer = StringBuffer(value < 0 ? '-' : '');

  for (var i = 0; i < rounded.length; i++) {
    if (i > 0 && (rounded.length - i) % 3 == 0) {
      buffer.write(',');
    }
    buffer.write(rounded[i]);
  }

  return buffer.toString();
}
