import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:school_management_system/main.dart';

void main() {
  testWidgets('HADI SMS renders a safe startup-error state', (tester) async {
    const startupFailure = 'Test startup failure';

    await tester.pumpWidget(
      const HadiSmsApp(startupError: startupFailure),
    );
    await tester.pump();

    expect(find.byType(HadiSmsApp), findsOneWidget);
    expect(find.byType(MaterialApp), findsOneWidget);
    expect(find.textContaining('Startup Error'), findsOneWidget);
    expect(find.textContaining(startupFailure), findsOneWidget);
  });
}
