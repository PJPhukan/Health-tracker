import '../models/models.dart';

/// Derives streak counts from logged data. Pure + stateless — recomputed on
/// every Progress screen load rather than stored.
class StreakCalculator {
  const StreakCalculator._();

  /// Consecutive days (counting back from today, or yesterday if today has no
  /// entry yet) on which at least one meal was logged.
  ///
  /// [loggedDates] is the set of `yyyy-MM-dd` strings that have >=1 meal.
  static int loggingStreak(Iterable<String> loggedDates, {DateTime? now}) {
    final today = _dayOnly(now ?? DateTime.now());
    final logged = loggedDates.toSet();

    // Allow the streak to "start" today or yesterday so it doesn't read 0 for
    // the whole morning before the first meal is logged.
    var cursor = logged.contains(dateKey(today))
        ? today
        : today.subtract(const Duration(days: 1));
    if (!logged.contains(dateKey(cursor))) return 0;

    var count = 0;
    while (logged.contains(dateKey(cursor))) {
      count++;
      cursor = cursor.subtract(const Duration(days: 1));
    }
    return count;
  }

  /// Consecutive days on which the step count met [stepsTarget].
  static int stepGoalStreak(
    List<StepsEntry> steps,
    int stepsTarget, {
    DateTime? now,
  }) {
    final today = _dayOnly(now ?? DateTime.now());
    final byDate = {
      for (final s in steps) s.date: s.stepCount,
    };

    bool met(DateTime d) => (byDate[dateKey(d)] ?? 0) >= stepsTarget;

    var cursor = met(today)
        ? today
        : today.subtract(const Duration(days: 1));
    if (!met(cursor)) return 0;

    var count = 0;
    while (met(cursor)) {
      count++;
      cursor = cursor.subtract(const Duration(days: 1));
    }
    return count;
  }

  static DateTime _dayOnly(DateTime d) => DateTime(d.year, d.month, d.day);
}
