import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:health_tracker/models/user_profile.dart';
import 'package:health_tracker/providers/auth_controller.dart';
import 'package:health_tracker/providers/health_provider.dart';
import 'package:health_tracker/providers/profile_controller.dart';
import 'package:health_tracker/screens/auth/auth_gate.dart';
import 'package:health_tracker/screens/auth/signup_screen.dart';
import 'package:health_tracker/screens/main_shell.dart';
import 'package:health_tracker/screens/quick_start/quick_start_flow.dart';
import 'package:health_tracker/services/guest_service.dart';
import 'package:health_tracker/services/subscription_service.dart';
import 'package:health_tracker/widgets/guest_gate_dialog.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

Widget createTestApp({
  required GuestService guest,
  AuthController? auth,
  ProfileController? profile,
  HealthProvider? health,
}) {
  return MultiProvider(
    providers: [
      ChangeNotifierProvider.value(value: auth ?? AuthController()),
      ChangeNotifierProvider.value(value: profile ?? ProfileController()),
      ChangeNotifierProvider.value(value: health ?? HealthProvider()),
      ChangeNotifierProvider.value(value: guest),
      ChangeNotifierProvider(create: (_) => SubscriptionService()..init()),
    ],
    child: const MaterialApp(
      home: AuthGate(),
    ),
  );
}

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

  group('First-Run Quick Start Flow', () {
    testWidgets('Screen 1: Next button is disabled until at least 2 chips are selected',
        (tester) async {
      await tester.pumpWidget(createTestApp(guest: GuestService.instance));
      await tester.pumpAndSettle();

      expect(find.byType(QuickStartFlow), findsOneWidget);
      expect(find.text("What's in your kitchen right now?"), findsOneWidget);

      final nextButtonFinder = find.widgetWithText(FilledButton, 'Next →');
      expect(nextButtonFinder, findsOneWidget);

      // Initially 0 items selected -> FilledButton.onPressed is null
      final FilledButton button0 = tester.widget(nextButtonFinder);
      expect(button0.onPressed, isNull);

      // Tap 1 item ('Eggs')
      await tester.tap(find.text('Eggs'));
      await tester.pumpAndSettle();

      final FilledButton button1 = tester.widget(nextButtonFinder);
      expect(button1.onPressed, isNull);

      // Tap 2nd item ('Bread')
      await tester.tap(find.text('Bread'));
      await tester.pumpAndSettle();

      final FilledButton button2 = tester.widget(nextButtonFinder);
      expect(button2.onPressed, isNotNull);
    });

    testWidgets('Full flow: Screen 1 -> Screen 2 Goal -> Screen 3 Instant Suggestion loads',
        (tester) async {
      await tester.pumpWidget(createTestApp(guest: GuestService.instance));
      await tester.pumpAndSettle();

      // Screen 1: Select 2 items
      await tester.tap(find.text('Eggs'));
      await tester.tap(find.text('Bread'));
      await tester.pumpAndSettle();

      // Proceed to Screen 2
      await tester.tap(find.widgetWithText(FilledButton, 'Next →'));
      await tester.pumpAndSettle();

      // Screen 2: Quick Goal
      expect(find.text("What's your main goal?"), findsOneWidget);
      expect(find.text('Build muscle'), findsOneWidget);
      expect(find.text('Gain weight'), findsOneWidget);
      expect(find.text('Lose weight'), findsOneWidget);
      expect(find.text('Stay healthy'), findsOneWidget);

      // Tap 'Build muscle' card -> immediately proceeds to Screen 3
      await tester.tap(find.text('Build muscle'));
      for (var i = 0; i < 10; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }

      // Screen 3: Loaded Instant Suggestion
      expect(find.text('Instant Kitchen Match'), findsOneWidget);
      expect(find.text('Ready to make right now'), findsOneWidget);
      expect(find.text('Save this & track your progress →'), findsOneWidget);
      expect(find.text('Free account — takes 30 seconds'), findsOneWidget);
      expect(find.text('Just browsing? Skip for now →'), findsOneWidget);
    });

    testWidgets('Screen 3: "Skip for now" enters guest mode and shows guest banner on HomeScreen',
        (tester) async {
      await tester.pumpWidget(createTestApp(guest: GuestService.instance));
      await tester.pumpAndSettle();

      // Complete Screen 1
      await tester.tap(find.text('Eggs'));
      await tester.tap(find.text('Bread'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Next →'));
      await tester.pumpAndSettle();

      // Complete Screen 2
      await tester.tap(find.text('Stay healthy'));
      for (var i = 0; i < 10; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }

      // Tap "Just browsing? Skip for now →"
      final skipFinder = find.text('Just browsing? Skip for now →');
      await tester.ensureVisible(skipFinder);
      await tester.pump();
      await tester.tap(skipFinder);
      for (var i = 0; i < 10; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }

      // Verifies Guest Mode active and MainShell reached
      expect(GuestService.instance.isGuest, isTrue);
      expect(GuestService.instance.hasSeenQuickStart, isTrue);
      expect(GuestService.instance.guestSuggestionsCount, 1);
      expect(find.byType(MainShell), findsOneWidget);
      expect(find.text("You're in guest mode — save your data"), findsOneWidget);
      expect(find.text('Sign up free →'), findsOneWidget);

      // Drain database idle timers and midnight timer in test
      await tester.pump(const Duration(seconds: 11));
    });

    testWidgets('Screen 3: "Save this" navigates to motivated SignupScreen with Google primary button',
        (tester) async {
      await tester.pumpWidget(createTestApp(guest: GuestService.instance));
      for (var i = 0; i < 5; i++) {
        await tester.pump(const Duration(milliseconds: 200));
      }

      // Complete Screen 1 & 2
      await tester.tap(find.text('Rice'));
      await tester.tap(find.text('Dal'));
      for (var i = 0; i < 3; i++) {
        await tester.pump(const Duration(milliseconds: 200));
      }
      await tester.tap(find.widgetWithText(FilledButton, 'Next →'));
      for (var i = 0; i < 3; i++) {
        await tester.pump(const Duration(milliseconds: 200));
      }
      await tester.tap(find.text('Build muscle'));
      for (var i = 0; i < 10; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }

      // Tap "Save this & track your progress →"
      final saveFinder = find.text('Save this & track your progress →');
      await tester.ensureVisible(saveFinder);
      await tester.pump();
      await tester.tap(saveFinder);
      for (var i = 0; i < 5; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }

      // Motivated signup screen appears
      expect(find.byType(SignupScreen), findsOneWidget);
      expect(find.text('Save your suggestion and start tracking'), findsOneWidget);
      expect(find.text('Sign up with Google'), findsOneWidget);
      expect(find.text('Or sign up with email'), findsOneWidget);

      await tester.pump(const Duration(seconds: 11));
    });

    testWidgets('Guest Mode: after 3 suggestions, soft gate dialog shows',
        (tester) async {
      final guest = GuestService.instance;
      await guest.startGuestMode(
        ingredients: ['Eggs', 'Bread'],
        goal: PrimaryGoal.buildMuscle,
        suggestion: 'Test meal',
      );
      // Already 1 suggestion used
      expect(guest.canRequestSuggestion, isTrue);

      // Record 2nd and 3rd
      await guest.recordSuggestionUsed(); // 2
      await guest.recordSuggestionUsed(); // 3
      expect(guest.canRequestSuggestion, isFalse);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (ctx) => ElevatedButton(
                onPressed: () {
                  if (!guest.canRequestSuggestion) {
                    showGuestSoftGate(ctx);
                  }
                },
                child: const Text('Get Suggestion'),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Get Suggestion'));
      await tester.pumpAndSettle();

      // Soft gate dialog is shown
      expect(
        find.text("You've used 3 free suggestions — create a free account to keep going"),
        findsOneWidget,
      );
      expect(find.text('Sign up free →'), findsOneWidget);
    });

    testWidgets('Returning user: skips Quick Start flow entirely',
        (tester) async {
      // Mark as returning user
      await GuestService.instance.setHasSeenQuickStart(true);

      // Test returning user
      await tester.pumpWidget(createTestApp(guest: GuestService.instance));
      for (var i = 0; i < 5; i++) {
        await tester.pump(const Duration(milliseconds: 200));
      }

      // QuickStartFlow is skipped!
      expect(find.byType(QuickStartFlow), findsNothing);
      await tester.pump(const Duration(seconds: 11));
    });
  });
}
