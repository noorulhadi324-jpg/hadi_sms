import 'package:flutter/material.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../shared/widgets/record_module_screen.dart';

/// Uses the vehicle table already installed in the connected Supabase project.
final transportModuleConfig = RecordModuleConfig(
  table: 'transport_vehicles',
  title: 'Transport',
  subtitle: 'Manage school vehicles, routes, drivers and seat capacity.',
  icon: Icons.directions_bus_rounded,
  titleColumn: 'vehicle_number',
  subtitleColumns: const ['route_name', 'driver_name', 'driver_phone'],
  status: const RecordStatus(
    column: 'status',
    colors: {
      'active': AppColors.success,
      'maintenance': AppColors.warning,
      'inactive': AppColors.textSecondary,
    },
  ),
  fields: const [
    RecordField(column: 'vehicle_number', label: 'Vehicle number', required: true),
    RecordField(column: 'route_name', label: 'Route name', required: true),
    RecordField(column: 'driver_name', label: 'Driver name', required: true),
    RecordField(column: 'driver_phone', label: 'Driver phone'),
    RecordField(column: 'capacity', label: 'Seat capacity', type: RecordFieldType.number),
    RecordField(column: 'status', label: 'Status', type: RecordFieldType.select, options: ['active', 'maintenance', 'inactive']),
    RecordField(column: 'notes', label: 'Notes', type: RecordFieldType.multiline, showInSummary: false),
  ],
  metrics: [
    RecordMetric(
      label: 'Vehicles',
      icon: Icons.directions_bus_rounded,
      color: AppColors.primary,
      value: (rows) => rows.length.toString(),
    ),
    RecordMetric(
      label: 'Active',
      icon: Icons.check_circle_outline_rounded,
      color: AppColors.success,
      value: (rows) => rows.where((row) => row['status'] == 'active').length.toString(),
    ),
    RecordMetric(
      label: 'Seats',
      icon: Icons.event_seat_rounded,
      color: AppColors.info,
      value: (rows) => rows.fold<int>(0, (sum, row) => sum + ((row['capacity'] as num?)?.toInt() ?? 0)).toString(),
    ),
  ],
);

class TransportScreen extends StatelessWidget {
  const TransportScreen({super.key});

  @override
  Widget build(BuildContext context) =>
      RecordModuleScreen(config: transportModuleConfig);
}
