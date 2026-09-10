import 'package:flutter_test/flutter_test.dart';
import 'package:health_tracker/main.dart';
import 'package:health_tracker/screens/splash_screen.dart';

void main() {
  testWidgets('app boots through the splash into the home greeting',
      (tester) async {
    await tester.pumpWidget(const HealthTrackerApp());

    // First frame is the animated splash.
    expect(find.byType(SplashScreen), findsOneWidget);
    expect(find.text('Stock Plate'), findsOneWidget);

    // Let the splash timeline run and auto-navigate to the home shell.
    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle();

    expect(find.textContaining('Good '), findsOneWidget);
  });
}
