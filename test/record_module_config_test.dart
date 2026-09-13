import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:school_management_system/core/constants/app_colors.dart';
import 'package:school_management_system/features/transport/presentation/screens/transport_screen.dart';
import 'package:school_management_system/shared/widgets/record_module_screen.dart';

void main() {
  group('RecordStatus', () {
    const status = RecordStatus(
      column: 'status',
      colors: {'active': AppColors.success},
    );

    test('matches configured colors case-insensitively', () {
      expect(status.colorOf('Active'), AppColors.success);
    });

    test('falls back to a neutral color for unknown values', () {
      expect(status.colorOf('archived'), AppColors.textSecondary);
    });
  });

  group('transport module config', () {
    test('is school scoped through a dedicated table and required fields', () {
      final config = transportModuleConfig;

      expect(config.table, 'transport_routes');
      expect(config.titleColumn, isNotEmpty);
      expect(config.fields.where((field) => field.required), isNotEmpty);
      expect(config.metrics, isNotEmpty);
    });

    test('every field declares a column and label', () {
      for (final field in transportModuleConfig.fields) {
        expect(field.column, isNotEmpty);
        expect(field.label, isNotEmpty);
      }
    });
  });

  group('RecordMetric', () {
    test('computes its value from the loaded rows', () {
      final metric = RecordMetric(
        label: 'Rows',
        icon: Icons.list_rounded,
        color: AppColors.primary,
        value: (rows) => rows.length.toString(),
      );

      expect(metric.value([{'id': 1}, {'id': 2}]), '2');
    });
  });
}
