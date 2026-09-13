import 'package:flutter/material.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../shared/widgets/record_module_screen.dart';

final transportModuleConfig = RecordModuleConfig(
  table: 'transport_routes',
  title: 'Transport',
  subtitle: 'Routes, vehicles, drivers and seat allocation.',
  icon: Icons.directions_bus_rounded,
  titleColumn: 'route_name',
  subtitleColumns: const ['vehicle_number', 'driver_name'],
  status: const RecordStatus(
    column: 'status',
    colors: {
      'active': AppColors.success,
      'maintenance': AppColors.warning,
      'inactive': AppColors.textSecondary,
    },
  ),
  fields: const [
    RecordField(
      column: 'route_name',
      label: 'Route name',
      required: true,
      hint: 'City Center - Campus',
    ),
    RecordField(column: 'vehicle_number', label: 'Vehicle number', required: true),
    RecordField(column: 'driver_name', label: 'Driver name', required: true),
    RecordField(column: 'driver_phone', label: 'Driver phone'),
    RecordField(
      column: 'capacity',
      label: 'Seat capacity',
      type: RecordFieldType.number,
      required: true,
    ),
    RecordField(
      column: 'occupied_seats',
      label: 'Occupied seats',
      type: RecordFieldType.number,
    ),
    RecordField(
      column: 'monthly_fee',
      label: 'Monthly fee',
      type: RecordFieldType.money,
    ),
    RecordField(
      column: 'status',
      label: 'Status',
      type: RecordFieldType.select,
      required: true,
      options: ['active', 'maintenance', 'inactive'],
    ),
    RecordField(
      column: 'notes',
      label: 'Notes',
      type: RecordFieldType.multiline,
      showInSummary: false,
    ),
  ],
  metrics: [
    RecordMetric(
      label: 'Routes',
      icon: Icons.alt_route_rounded,
      color: AppColors.primary,
      value: (rows) => rows.length.toString(),
    ),
    RecordMetric(
      label: 'Active routes',
      icon: Icons.check_circle_outline_rounded,
      color: AppColors.success,
      value: (rows) =>
          rows.where((row) => row['status'] == 'active').length.toString(),
    ),
    RecordMetric(
      label: 'Seats occupied',
      icon: Icons.event_seat_rounded,
      color: AppColors.info,
      value: (rows) => rows
          .fold<int>(
            0,
            (total, row) => total + ((row['occupied_seats'] as num?)?.toInt() ?? 0),
          )
          .toString(),
    ),
    RecordMetric(
      label: 'Seats available',
      icon: Icons.airline_seat_recline_normal_rounded,
      color: AppColors.warning,
      value: (rows) {
        final capacity = rows.fold<int>(
          0,
          (total, row) => total + ((row['capacity'] as num?)?.toInt() ?? 0),
        );
        final occupied = rows.fold<int>(
          0,
          (total, row) => total + ((row['occupied_seats'] as num?)?.toInt() ?? 0),
        );

        return (capacity - occupied).clamp(0, capacity).toString();
      },
    ),
  ],
);

class TransportScreen extends StatelessWidget {
  const TransportScreen({super.key});

  @override
  Widget build(BuildContext context) =>
      RecordModuleScreen(config: transportModuleConfig);
}
