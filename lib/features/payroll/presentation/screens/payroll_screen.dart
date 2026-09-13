import 'package:flutter/material.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../shared/widgets/record_module_screen.dart';

double _netSalary(Map<String, dynamic> row) {
  final basic = (row['basic_salary'] as num?)?.toDouble() ?? 0;
  final allowances = (row['allowances'] as num?)?.toDouble() ?? 0;
  final deductions = (row['deductions'] as num?)?.toDouble() ?? 0;

  return basic + allowances - deductions;
}

final payrollModuleConfig = RecordModuleConfig(
  table: 'payroll_records',
  title: 'Payroll',
  subtitle: 'Monthly salary sheets for teachers and staff.',
  icon: Icons.account_balance_wallet_rounded,
  titleColumn: 'employee_name',
  subtitleColumns: const ['designation', 'pay_period'],
  orderColumn: 'pay_period',
  status: const RecordStatus(
    column: 'status',
    colors: {
      'paid': AppColors.success,
      'pending': AppColors.warning,
      'on_hold': AppColors.error,
    },
  ),
  fields: const [
    RecordField(column: 'employee_name', label: 'Employee name', required: true),
    RecordField(column: 'designation', label: 'Designation'),
    RecordField(
      column: 'pay_period',
      label: 'Pay period',
      required: true,
      hint: '2026-09',
    ),
    RecordField(
      column: 'basic_salary',
      label: 'Basic salary',
      type: RecordFieldType.money,
      required: true,
    ),
    RecordField(
      column: 'allowances',
      label: 'Allowances',
      type: RecordFieldType.money,
    ),
    RecordField(
      column: 'deductions',
      label: 'Deductions',
      type: RecordFieldType.money,
    ),
    RecordField(
      column: 'paid_on',
      label: 'Paid on',
      type: RecordFieldType.date,
    ),
    RecordField(
      column: 'status',
      label: 'Status',
      type: RecordFieldType.select,
      required: true,
      options: ['pending', 'paid', 'on_hold'],
    ),
  ],
  metrics: [
    RecordMetric(
      label: 'Salary slips',
      icon: Icons.receipt_long_rounded,
      color: AppColors.primary,
      value: (rows) => rows.length.toString(),
    ),
    RecordMetric(
      label: 'Net payable',
      icon: Icons.payments_rounded,
      color: AppColors.info,
      value: (rows) =>
          'Rs ${formatAmount(rows.fold<double>(0, (total, row) => total + _netSalary(row)))}',
    ),
    RecordMetric(
      label: 'Paid',
      icon: Icons.verified_rounded,
      color: AppColors.success,
      value: (rows) => 'Rs ${formatAmount(rows.where((row) => row['status'] == 'paid').fold<double>(0, (total, row) => total + _netSalary(row)))}',
    ),
    RecordMetric(
      label: 'Pending slips',
      icon: Icons.schedule_rounded,
      color: AppColors.warning,
      value: (rows) =>
          rows.where((row) => row['status'] != 'paid').length.toString(),
    ),
  ],
);

class PayrollScreen extends StatelessWidget {
  const PayrollScreen({super.key});

  @override
  Widget build(BuildContext context) =>
      RecordModuleScreen(config: payrollModuleConfig);
}
