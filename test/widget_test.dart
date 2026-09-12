import 'package:flutter_test/flutter_test.dart';
import 'package:school_management_system/main.dart';

void main() {
  testWidgets('HADI SMS app builds', (tester) async {
    await tester.pumpWidget(const HadiSmsApp());
    await tester.pump();
    expect(find.byType(HadiSmsApp), findsOneWidget);
  });
}
