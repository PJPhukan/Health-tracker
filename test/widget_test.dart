import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:health_tracker/main.dart';
import 'package:health_tracker/screens/quick_start/quick_start_flow.dart';
import 'package:health_tracker/screens/splash_screen.dart';
import 'package:health_tracker/services/guest_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    GuestService.instance.resetForTesting();
    await GuestService.instance.init();
  });

  testWidgets('boots through the splash into first-run Quick Start flow',
      (tester) async {
    await tester.pumpWidget(const HealthTrackerApp());

    // First frame is the animated splash.
    expect(find.byType(SplashScreen), findsOneWidget);
    expect(find.text('Stock Plate'), findsOneWidget);

    // Advance splash animation
    for (var i = 0; i < 20; i++) {
      await tester.pump(const Duration(milliseconds: 300));
    }

    // Completely new user lands on DisclaimerScreen
    expect(find.text('Before We Begin'), findsOneWidget);
    expect(find.text('I understand — let\'s go →'), findsOneWidget);

    // Acknowledge notice
    await tester.tap(find.byType(Checkbox));
    await tester.pumpAndSettle();
    await tester.tap(find.text('I understand — let\'s go →'));
    await tester.pumpAndSettle();

    // Now lands on Screen 1: Quick Start
    expect(find.byType(QuickStartFlow), findsOneWidget);
    expect(find.text("What's in your kitchen right now?"), findsOneWidget);
    expect(find.text('Rice'), findsOneWidget);
    expect(find.text('Eggs'), findsOneWidget);
    expect(find.text('Next →'), findsOneWidget);

    await tester.pump(const Duration(seconds: 5));
  });
}
