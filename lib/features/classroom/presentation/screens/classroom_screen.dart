import 'package:flutter/material.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../shared/widgets/record_module_screen.dart';

final classroomModuleConfig = RecordModuleConfig(
  table: 'classrooms',
  title: 'Classrooms',
  subtitle: 'Physical rooms, capacity and facilities.',
  icon: Icons.meeting_room_rounded,
  titleColumn: 'room_name',
  subtitleColumns: const ['building', 'floor'],
  orderColumn: 'room_name',
  orderAscending: true,
  status: const RecordStatus(
    column: 'status',
    colors: {
      'available': AppColors.success,
      'occupied': AppColors.info,
      'maintenance': AppColors.warning,
    },
  ),
  fields: const [
    RecordField(column: 'room_name', label: 'Room name', required: true),
    RecordField(column: 'building', label: 'Building'),
    RecordField(column: 'floor', label: 'Floor'),
    RecordField(
      column: 'capacity',
      label: 'Seating capacity',
      type: RecordFieldType.number,
      required: true,
    ),
    RecordField(
      column: 'room_type',
      label: 'Room type',
      type: RecordFieldType.select,
      required: true,
      options: ['classroom', 'lab', 'library', 'hall', 'office'],
    ),
    RecordField(column: 'assigned_class', label: 'Assigned class'),
    RecordField(
      column: 'facilities',
      label: 'Facilities',
      type: RecordFieldType.multiline,
      hint: 'Projector, smart board, air conditioning...',
      showInSummary: false,
    ),
    RecordField(
      column: 'status',
      label: 'Status',
      type: RecordFieldType.select,
      required: true,
      options: ['available', 'occupied', 'maintenance'],
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
      label: 'Total seats',
      icon: Icons.event_seat_rounded,
      color: AppColors.info,
      value: (rows) => rows
          .fold<int>(
            0,
            (total, row) => total + ((row['capacity'] as num?)?.toInt() ?? 0),
          )
          .toString(),
    ),
    RecordMetric(
      label: 'Available',
      icon: Icons.door_front_door_rounded,
      color: AppColors.success,
      value: (rows) =>
          rows.where((row) => row['status'] == 'available').length.toString(),
    ),
    RecordMetric(
      label: 'Labs',
      icon: Icons.science_rounded,
      color: AppColors.warning,
      value: (rows) =>
          rows.where((row) => row['room_type'] == 'lab').length.toString(),
    ),
  ],
);

class ClassroomsScreen extends StatelessWidget {
  const ClassroomsScreen({super.key});

  @override
  Widget build(BuildContext context) =>
      RecordModuleScreen(config: classroomModuleConfig);
}
