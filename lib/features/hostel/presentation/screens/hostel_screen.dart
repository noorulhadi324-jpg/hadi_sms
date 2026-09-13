import 'package:flutter/material.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../shared/widgets/record_module_screen.dart';

final hostelModuleConfig = RecordModuleConfig(
  table: 'hostel_rooms',
  title: 'Hostel',
  subtitle: 'Blocks, rooms, occupancy and warden details.',
  icon: Icons.apartment_rounded,
  titleColumn: 'room_number',
  subtitleColumns: const ['block_name', 'room_type'],
  status: const RecordStatus(
    column: 'status',
    colors: {
      'available': AppColors.success,
      'full': AppColors.info,
      'maintenance': AppColors.warning,
    },
  ),
  fields: const [
    RecordField(column: 'room_number', label: 'Room number', required: true),
    RecordField(column: 'block_name', label: 'Block', required: true),
    RecordField(
      column: 'room_type',
      label: 'Room type',
      type: RecordFieldType.select,
      required: true,
      options: ['boys', 'girls', 'staff'],
    ),
    RecordField(
      column: 'capacity',
      label: 'Capacity',
      type: RecordFieldType.number,
      required: true,
    ),
    RecordField(
      column: 'occupied',
      label: 'Occupied beds',
      type: RecordFieldType.number,
    ),
    RecordField(column: 'warden_name', label: 'Warden'),
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
      options: ['available', 'full', 'maintenance'],
    ),
  ],
  metrics: [
    RecordMetric(
      label: 'Rooms',
      icon: Icons.meeting_room_rounded,
      color: AppColors.primary,
      value: (rows) => rows.length.toString(),
    ),
    RecordMetric(
      label: 'Beds',
      icon: Icons.bed_rounded,
      color: AppColors.info,
      value: (rows) => rows
          .fold<int>(
            0,
            (total, row) => total + ((row['capacity'] as num?)?.toInt() ?? 0),
          )
          .toString(),
    ),
    RecordMetric(
      label: 'Occupied beds',
      icon: Icons.groups_rounded,
      color: AppColors.success,
      value: (rows) => rows
          .fold<int>(
            0,
            (total, row) => total + ((row['occupied'] as num?)?.toInt() ?? 0),
          )
          .toString(),
    ),
    RecordMetric(
      label: 'Under maintenance',
      icon: Icons.build_rounded,
      color: AppColors.warning,
      value: (rows) =>
          rows.where((row) => row['status'] == 'maintenance').length.toString(),
    ),
  ],
);

class HostelScreen extends StatelessWidget {
  const HostelScreen({super.key});

  @override
  Widget build(BuildContext context) =>
      RecordModuleScreen(config: hostelModuleConfig);
}
