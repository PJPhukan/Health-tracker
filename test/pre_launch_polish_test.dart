import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:health_tracker/constants/app_strings.dart';
import 'package:health_tracker/services/guest_service.dart';
import 'package:health_tracker/services/streak_milestone_service.dart';
import 'package:health_tracker/services/tutorial_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('TutorialService', () {
    test('initially hasSeenTutorial is false', () async {
      final seen = await TutorialService.instance.hasSeenTutorial();
      expect(seen, isFalse);
    });

    test('markTutorialSeen sets flag to true', () async {
      await TutorialService.instance.markTutorialSeen();
      final seen = await TutorialService.instance.hasSeenTutorial();
      expect(seen, isTrue);
    });

    test('resetForTesting clears flag', () async {
      await TutorialService.instance.markTutorialSeen();
      await TutorialService.instance.resetForTesting();
      final seen = await TutorialService.instance.hasSeenTutorial();
      expect(seen, isFalse);
    });

    testWidgets('TutorialCard: when onBack is null, no Back button rendered', (tester) async {
      var nextCalled = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TutorialCard(
              title: "Step 1",
              message: "Description",
              stepLabel: "1 of 4",
              isLast: false,
              onNext: () => nextCalled = true,
              onSkip: () {},
              onBack: null,
            ),
          ),
        ),
      );

      expect(find.text("Back"), findsNothing);
      expect(find.text("Skip"), findsOneWidget);
      expect(find.text("Got it \u2192"), findsOneWidget);

      await tester.tap(find.text("Got it \u2192"));
      expect(nextCalled, isTrue);
    });

    testWidgets('TutorialCard: when onBack is provided, Back button is rendered and clickable', (tester) async {
      var backCalled = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TutorialCard(
              title: "Step 2",
              message: "Pantry description",
              stepLabel: "2 of 4",
              isLast: false,
              onNext: () {},
              onSkip: () {},
              onBack: () => backCalled = true,
            ),
          ),
        ),
      );

      expect(find.text("Back"), findsOneWidget);
      expect(find.byIcon(Icons.arrow_back_rounded), findsOneWidget);
      expect(find.text("Skip"), findsOneWidget);
      expect(find.text("Got it \u2192"), findsOneWidget);

      await tester.tap(find.text("Back"));
      expect(backCalled, isTrue);
    });
  });

  group('StreakMilestoneService', () {
    test('checkUncelebratedMilestone returns null for streak < 3', () async {
      final m = await StreakMilestoneService.instance.checkUncelebratedMilestone(2);
      expect(m, isNull);
    });

    test('checkUncelebratedMilestone detects 3-day milestone', () async {
      final m = await StreakMilestoneService.instance.checkUncelebratedMilestone(3);
      expect(m, equals(3));

      await StreakMilestoneService.instance.markMilestoneCelebrated(3);
      final m2 = await StreakMilestoneService.instance.checkUncelebratedMilestone(3);
      expect(m2, isNull);
    });

    test('checkUncelebratedMilestone detects 7-day milestone when 3 already celebrated', () async {
      await StreakMilestoneService.instance.markMilestoneCelebrated(3);
      final m = await StreakMilestoneService.instance.checkUncelebratedMilestone(7);
      expect(m, equals(7));

      await StreakMilestoneService.instance.markMilestoneCelebrated(7);
      final m2 = await StreakMilestoneService.instance.checkUncelebratedMilestone(7);
      expect(m2, isNull);
    });

    test('resetForTesting clears milestones', () async {
      await StreakMilestoneService.instance.markMilestoneCelebrated(3);
      await StreakMilestoneService.instance.resetForTesting();
      final celebrated = await StreakMilestoneService.instance.hasCelebratedMilestone(3);
      expect(celebrated, isFalse);
    });
  });

  group('AppStrings', () {
    test('contains non-empty essential user copy', () {
      expect(AppStrings.appName, equals('Stock Plate'));
      expect(AppStrings.offlineBannerText, isNotEmpty);
      expect(AppStrings.offlineSuggestionError, isNotEmpty);
      expect(AppStrings.networkTimeoutMessage, equals('That took longer than expected. Try again?'));
      expect(AppStrings.historyEmptyTitle, isNotEmpty);
      expect(AppStrings.pantryEmptyTitle, isNotEmpty);
      expect(AppStrings.disclaimerMedicalNotice, isNotEmpty);
      expect(AppStrings.privacyPolicyUrl, startsWith('https://'));
      expect(AppStrings.termsOfServiceUrl, startsWith('https://'));
    });
  });

  group('DisclaimerService / GuestService disclaimer flag', () {
    test('initially hasSeenDisclaimer is false', () async {
      final guest = GuestService.instance;
      guest.resetForTesting();
      await guest.init();
      expect(guest.hasSeenDisclaimer, isFalse);
    });

    test('setHasSeenDisclaimer updates flag and persists', () async {
      final guest = GuestService.instance;
      guest.resetForTesting();
      await guest.init();
      await guest.setHasSeenDisclaimer(true);
      expect(guest.hasSeenDisclaimer, isTrue);

      guest.resetForTesting();
      await guest.init();
      expect(guest.hasSeenDisclaimer, isTrue);
    });
  });
}
