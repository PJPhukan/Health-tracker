import 'package:flutter_test/flutter_test.dart';
import 'package:health_tracker/models/models.dart';
import 'package:health_tracker/services/streak_calculator.dart';

void main() {
  final now = DateTime(2026, 9, 10); // a fixed "today"
  String day(int agoDays) =>
      dateKey(now.subtract(Duration(days: agoDays)));

  group('loggingStreak', () {
    test('counts back from today', () {
      final logged = [day(0), day(1), day(2), day(4)]; // gap at day 3
      expect(StreakCalculator.loggingStreak(logged, now: now), 3);
    });

    test('still counts when today has no entry but yesterday does', () {
      final logged = [day(1), day(2), day(3)];
      expect(StreakCalculator.loggingStreak(logged, now: now), 3);
    });

    test('zero when neither today nor yesterday logged', () {
      expect(StreakCalculator.loggingStreak([day(2), day(3)], now: now), 0);
    });

    test('zero for no data', () {
      expect(StreakCalculator.loggingStreak(const [], now: now), 0);
    });
  });

  group('stepGoalStreak', () {
    StepsEntry steps(int agoDays, int count) =>
        StepsEntry(date: day(agoDays), stepCount: count);

    test('consecutive days meeting the target', () {
      final data = [
        steps(0, 8200),
        steps(1, 7000),
        steps(2, 9000),
        steps(3, 3000), // misses
        steps(4, 8000),
      ];
      expect(StreakCalculator.stepGoalStreak(data, 7000, now: now), 3);
    });

    test('a miss today but a run through yesterday still counts', () {
      final data = [steps(0, 1200), steps(1, 8000), steps(2, 8000)];
      expect(StreakCalculator.stepGoalStreak(data, 7000, now: now), 2);
    });

    test('zero when the most recent day misses', () {
      final data = [steps(0, 100), steps(1, 200)];
      expect(StreakCalculator.stepGoalStreak(data, 7000, now: now), 0);
    });
  });
}
