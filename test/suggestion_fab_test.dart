import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:health_tracker/providers/auth_controller.dart';
import 'package:health_tracker/providers/health_provider.dart';
import 'package:health_tracker/providers/profile_controller.dart';
import 'package:health_tracker/screens/main_shell.dart';
import 'package:health_tracker/screens/suggestion_screen.dart';
import 'package:health_tracker/services/guest_service.dart';
import 'package:health_tracker/services/subscription_service.dart';
import 'package:health_tracker/services/tutorial_service.dart';
import 'package:health_tracker/widgets/floating_nav_bar.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await TutorialService.instance.resetForTesting();
    GuestService.instance.resetForTesting();
    await GuestService.instance.init();
    await GuestService.instance.setHasSeenDisclaimer(true);
  });

  testWidgets('Test clicking Suggestion FAB in MainShell', (tester) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('has_seen_tutorial', true);

    final health = HealthProvider();
    final profile = ProfileController();

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider.value(value: AuthController()),
          ChangeNotifierProvider.value(value: profile),
          ChangeNotifierProvider.value(value: health),
          ChangeNotifierProvider.value(value: GuestService.instance),
          ChangeNotifierProvider(create: (_) => SubscriptionService()..init()),
        ],
        child: const MaterialApp(
          home: MainShell(),
        ),
      ),
    );

    for (int i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 200));
    }

    final fabFinder = find.byType(FloatingActionButton);
    expect(fabFinder, findsOneWidget);

    final navFinder = find.byType(FloatingNavBar);
    expect(navFinder, findsOneWidget);

    await tester.tap(fabFinder);
    for (int i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 200));
    }

    expect(find.byType(SuggestionScreen), findsOneWidget);
  });
}
