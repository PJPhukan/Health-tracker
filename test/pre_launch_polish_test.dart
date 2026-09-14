import 'package:flutter_test/flutter_test.dart';
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
}
