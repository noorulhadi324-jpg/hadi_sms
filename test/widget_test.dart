import 'package:flutter_test/flutter_test.dart';
import 'package:school_management_system/main.dart';

void main() {
  testWidgets('app renders the startup error screen when Supabase is unavailable',
      (tester) async {
    await tester.pumpWidget(
      const HadiSmsApp(startupError: 'Supabase unavailable'),
    );
    await tester.pump();

    expect(find.byType(HadiSmsApp), findsOneWidget);
    expect(find.textContaining('Startup Error'), findsOneWidget);
  });
}
