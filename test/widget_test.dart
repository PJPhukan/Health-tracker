import 'package:flutter_test/flutter_test.dart';
import 'package:health_tracker/main.dart';
import 'package:health_tracker/screens/onboarding/onboarding_flow.dart';
import 'package:health_tracker/screens/splash_screen.dart';

void main() {
  testWidgets('boots through the splash into first-run onboarding '
      '(local-only mode, no profile yet)', (tester) async {
    await tester.pumpWidget(const HealthTrackerApp());

    // First frame is the animated splash.
    expect(find.byType(SplashScreen), findsOneWidget);
    expect(find.text('Stock Plate'), findsOneWidget);

    // Splash timeline (~2.3s) then the auth gate resolves. Firebase ships with
    // placeholder config in CI → local-only mode, and with no saved profile
    // the gate routes to onboarding.
    for (var i = 0; i < 20; i++) {
      await tester.pump(const Duration(milliseconds: 300));
    }

    expect(find.byType(OnboardingFlow), findsOneWidget);
    expect(find.text('What should we call you?'), findsOneWidget);
  });
}
