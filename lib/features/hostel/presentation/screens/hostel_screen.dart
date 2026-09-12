import 'package:flutter/material.dart';
import '../../../../core/widgets/module_screen.dart';

class HostelScreen extends StatelessWidget {
  const HostelScreen({super.key});
  @override
  Widget build(BuildContext context) => ModuleScreen(
    title: 'Hostel',
    subtitle: 'Manage rooms, residents and hostel operations.',
    icon: Icons.hotel_rounded,
    metrics: const [
      ModuleMetric('Total', '128', 'This session', Icons.grid_view_rounded, Color(0xFF7C3AED)),
      ModuleMetric('Active', '96', 'Currently active', Icons.check_circle_outline_rounded, Color(0xFF16A34A)),
      ModuleMetric('Pending', '18', 'Needs attention', Icons.schedule_rounded, Color(0xFFF59E0B)),
      ModuleMetric('Updated', 'Today', 'Latest activity', Icons.update_rounded, Color(0xFF2563EB)),
    ],
    actions: const [
      ModuleAction('Add new record', Icons.add_circle_outline_rounded),
      ModuleAction('Import / upload', Icons.file_upload_outlined),
      ModuleAction('Export report', Icons.file_download_outlined),
      ModuleAction('View settings', Icons.tune_rounded),
    ],
    rows: const [
      ModuleRow('New record created', 'HADI SMS • Today', 'Just now', Icons.add_task_rounded, Color(0xFF7C3AED)),
      ModuleRow('Monthly data updated', 'School management', 'Today', Icons.sync_rounded, Color(0xFF2563EB)),
      ModuleRow('Review pending items', 'Requires attention', 'Pending', Icons.warning_amber_rounded, Color(0xFFF59E0B)),
      ModuleRow('System activity', 'Everything is running normally', 'OK', Icons.verified_rounded, Color(0xFF16A34A)),
    ],
  );
}
