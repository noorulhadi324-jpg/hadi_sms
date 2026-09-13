import 'package:flutter/material.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../shared/widgets/record_module_screen.dart';

double _amountOf(Map<String, dynamic> row, String type) {
  if (row['entry_type'] != type) {
    return 0;
  }

  return (row['amount'] as num?)?.toDouble() ?? 0;
}

final accountingModuleConfig = RecordModuleConfig(
  table: 'accounting_entries',
  title: 'Accounting',
  subtitle: 'Income and expense ledger of the school.',
  icon: Icons.account_balance_rounded,
  titleColumn: 'description',
  subtitleColumns: const ['category', 'entry_date'],
  orderColumn: 'entry_date',
  status: const RecordStatus(
    column: 'entry_type',
    colors: {'income': AppColors.success, 'expense': AppColors.error},
  ),
  fields: const [
    RecordField(column: 'description', label: 'Description', required: true),
    RecordField(
      column: 'entry_type',
      label: 'Entry type',
      type: RecordFieldType.select,
      required: true,
      options: ['income', 'expense'],
    ),
    RecordField(
      column: 'category',
      label: 'Category',
      required: true,
      hint: 'Tuition, Utilities, Salaries...',
    ),
    RecordField(
      column: 'amount',
      label: 'Amount',
      type: RecordFieldType.money,
      required: true,
    ),
    RecordField(
      column: 'entry_date',
      label: 'Entry date',
      type: RecordFieldType.date,
      required: true,
    ),
    RecordField(
      column: 'payment_method',
      label: 'Payment method',
      type: RecordFieldType.select,
      options: ['cash', 'bank', 'cheque', 'online'],
    ),
    RecordField(column: 'reference_no', label: 'Reference no'),
    RecordField(
      column: 'notes',
      label: 'Notes',
      type: RecordFieldType.multiline,
      showInSummary: false,
    ),
  ],
  metrics: [
    RecordMetric(
      label: 'Entries',
      icon: Icons.list_alt_rounded,
      color: AppColors.primary,
      value: (rows) => rows.length.toString(),
    ),
    RecordMetric(
      label: 'Total income',
      icon: Icons.trending_up_rounded,
      color: AppColors.success,
      value: (rows) =>
          'Rs ${formatAmount(rows.fold<double>(0, (total, row) => total + _amountOf(row, 'income')))}',
    ),
    RecordMetric(
      label: 'Total expense',
      icon: Icons.trending_down_rounded,
      color: AppColors.error,
      value: (rows) =>
          'Rs ${formatAmount(rows.fold<double>(0, (total, row) => total + _amountOf(row, 'expense')))}',
    ),
    RecordMetric(
      label: 'Net balance',
      icon: Icons.balance_rounded,
      color: AppColors.info,
      value: (rows) {
        final balance = rows.fold<double>(
          0,
          (total, row) =>
              total + _amountOf(row, 'income') - _amountOf(row, 'expense'),
        );

        return 'Rs ${formatAmount(balance)}';
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
