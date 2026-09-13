import 'package:flutter/material.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../shared/widgets/record_module_screen.dart';

final inventoryModuleConfig = RecordModuleConfig(
  table: 'inventory_items',
  title: 'Inventory',
  subtitle: 'Stock of school assets, supplies and equipment.',
  icon: Icons.inventory_2_rounded,
  titleColumn: 'item_name',
  subtitleColumns: const ['category', 'location'],
  fields: const [
    RecordField(column: 'item_name', label: 'Item name', required: true),
    RecordField(
      column: 'category',
      label: 'Category',
      type: RecordFieldType.select,
      required: true,
      options: ['furniture', 'stationery', 'electronics', 'sports', 'other'],
    ),
    RecordField(
      column: 'quantity',
      label: 'Quantity',
      type: RecordFieldType.number,
      required: true,
    ),
    RecordField(
      column: 'reorder_level',
      label: 'Reorder level',
      type: RecordFieldType.number,
    ),
    RecordField(
      column: 'unit_price',
      label: 'Unit price',
      type: RecordFieldType.money,
    ),
    RecordField(column: 'location', label: 'Storage location'),
    RecordField(column: 'supplier', label: 'Supplier'),
    RecordField(
      column: 'purchased_on',
      label: 'Purchased on',
      type: RecordFieldType.date,
    ),
  ],
  metrics: [
    RecordMetric(
      label: 'Items',
      icon: Icons.category_rounded,
      color: AppColors.primary,
      value: (rows) => rows.length.toString(),
    ),
    RecordMetric(
      label: 'Units in stock',
      icon: Icons.numbers_rounded,
      color: AppColors.info,
      value: (rows) => rows
          .fold<int>(
            0,
            (total, row) => total + ((row['quantity'] as num?)?.toInt() ?? 0),
          )
          .toString(),
    ),
    RecordMetric(
      label: 'Stock value',
      icon: Icons.payments_rounded,
      color: AppColors.success,
      value: (rows) {
        final value = rows.fold<double>(0, (total, row) {
          final quantity = (row['quantity'] as num?)?.toDouble() ?? 0;
          final price = (row['unit_price'] as num?)?.toDouble() ?? 0;

          return total + quantity * price;
        });

        return 'Rs ${formatAmount(value)}';
      },
    ),
    RecordMetric(
      label: 'Low stock',
      icon: Icons.warning_amber_rounded,
      color: AppColors.warning,
      value: (rows) => rows.where((row) {
        final quantity = (row['quantity'] as num?)?.toInt() ?? 0;
        final reorder = (row['reorder_level'] as num?)?.toInt();

        return reorder != null && quantity <= reorder;
      }).length.toString(),
    ),
  ],
);

class InventoryScreen extends StatelessWidget {
  const InventoryScreen({super.key});

  @override
  Widget build(BuildContext context) =>
      RecordModuleScreen(config: inventoryModuleConfig);
}
