import 'package:flutter/material.dart';

import '../../../../shared/widgets/school_work_screen.dart';

class HomeworkScreen extends StatelessWidget {
  const HomeworkScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const SchoolWorkScreen(
      workType: 'homework',
      title: 'Homework',
      singularLabel: 'Homework',
      icon: Icons.menu_book_rounded,
    );
  }
}
