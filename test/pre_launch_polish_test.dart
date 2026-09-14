import 'package:flutter_test/flutter_test.dart';
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
}
