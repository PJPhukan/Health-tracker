import 'package:flutter_test/flutter_test.dart';
import 'package:health_tracker/main.dart';

void main() {
  testWidgets('app boots to the home greeting', (tester) async {
    await tester.pumpWidget(const HealthTrackerApp());
    await tester.pump();
    expect(find.textContaining('Good '), findsOneWidget);
  });
}
