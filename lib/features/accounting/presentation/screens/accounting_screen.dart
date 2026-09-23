import 'package:flutter/material.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../shared/widgets/record_module_screen.dart';

final accountingModuleConfig = RecordModuleConfig(
  table: 'accounting_entries',
  title: 'Accounting Ledger',
  subtitle: 'Record income and expenses and track your school balance.',
  icon: Icons.account_balance_wallet_rounded,
  titleColumn: 'description',
  subtitleColumns: const ['category', 'entry_type', 'entry_date'],
  orderColumn: 'entry_date',
  status: const RecordStatus(
    column: 'entry_type',
    colors: {
      'income': AppColors.success,
      'expense': AppColors.error,
    },
  ),
  fields: const [
    RecordField(column: 'description', label: 'Description', required: true),
    RecordField(column: 'entry_type', label: 'Type', type: RecordFieldType.select, required: true, options: ['income', 'expense']),
    RecordField(column: 'category', label: 'Category', required: true),
    RecordField(column: 'amount', label: 'Amount', type: RecordFieldType.money, required: true),
    RecordField(column: 'entry_date', label: 'Date', type: RecordFieldType.date, required: true),
    RecordField(column: 'payment_method', label: 'Payment method', type: RecordFieldType.select, options: ['cash', 'bank', 'cheque', 'online']),
    RecordField(column: 'reference_no', label: 'Reference number'),
    RecordField(column: 'notes', label: 'Notes', type: RecordFieldType.multiline, showInSummary: false),
  ],
  metrics: [
    RecordMetric(
      label: 'Entries',
      icon: Icons.receipt_long_rounded,
      color: AppColors.primary,
      value: (rows) => rows.length.toString(),
    ),
    RecordMetric(
      label: 'Income',
      icon: Icons.south_west_rounded,
      color: AppColors.success,
      value: (rows) => 'PKR ${rows.where((row) => row['entry_type'] == 'income').fold<double>(0, (sum, row) => sum + ((row['amount'] as num?)?.toDouble() ?? 0)).toStringAsFixed(0)}',
    ),
    RecordMetric(
      label: 'Expenses',
      icon: Icons.north_east_rounded,
      color: AppColors.error,
      value: (rows) => 'PKR ${rows.where((row) => row['entry_type'] == 'expense').fold<double>(0, (sum, row) => sum + ((row['amount'] as num?)?.toDouble() ?? 0)).toStringAsFixed(0)}',
    ),
    RecordMetric(
      label: 'Balance',
      icon: Icons.account_balance_rounded,
      color: AppColors.info,
      value: (rows) {
        final income = rows.where((row) => row['entry_type'] == 'income').fold<double>(0, (sum, row) => sum + ((row['amount'] as num?)?.toDouble() ?? 0));
        final expense = rows.where((row) => row['entry_type'] == 'expense').fold<double>(0, (sum, row) => sum + ((row['amount'] as num?)?.toDouble() ?? 0));
        return 'PKR ${(income - expense).toStringAsFixed(0)}';
      },
    ),
  ],
);

class AccountingScreen extends StatelessWidget {
  const AccountingScreen({super.key});

  @override
  Widget build(BuildContext context) =>
      RecordModuleScreen(config: accountingModuleConfig);
}
