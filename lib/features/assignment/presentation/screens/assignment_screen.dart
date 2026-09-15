import 'package:flutter/material.dart';

import '../../../../shared/widgets/school_work_screen.dart';

class AssignmentsScreen extends StatelessWidget {
  const AssignmentsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const SchoolWorkScreen(
      workType: 'assignment',
      title: 'Assignments',
      singularLabel: 'Assignment',
      icon: Icons.assignment_rounded,
    );
  }
}
