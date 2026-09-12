import 'package:flutter/material.dart';

class ParentDashboardScreen extends StatelessWidget {
  const ParentDashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Parent Portal')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: const [
          Card(
            child: ListTile(
              leading: Icon(Icons.person),
              title: Text('My Child'),
              subtitle: Text('Student profile and linked school information'),
            ),
          ),
          Card(
            child: ListTile(
              leading: Icon(Icons.calendar_month),
              title: Text('Attendance'),
              subtitle: Text('Attendance history and monthly summary'),
            ),
          ),
          Card(
            child: ListTile(
              leading: Icon(Icons.menu_book),
              title: Text('Homework'),
              subtitle: Text('Assignments and submission status'),
            ),
          ),
          Card(
            child: ListTile(
              leading: Icon(Icons.assessment),
              title: Text('Results'),
              subtitle: Text('Marks, grades and report cards'),
            ),
          ),
          Card(
            child: ListTile(
              leading: Icon(Icons.payments),
              title: Text('Fees'),
              subtitle: Text('Invoices, payments and receipts'),
            ),
          ),
        ],
      ),
    );
  }
}
