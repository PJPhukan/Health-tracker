import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class StreakMilestoneService {
  StreakMilestoneService._();
  static final StreakMilestoneService instance = StreakMilestoneService._();

  static const List<int> milestones = [3, 7, 14, 30];

  static String _prefKey(int days) => 'streak_milestone_celebrated_$days';

  Future<bool> hasCelebratedMilestone(int days) async {
    final sp = await SharedPreferences.getInstance();
    return sp.getBool(_prefKey(days)) ?? false;
  }

  Future<void> markMilestoneCelebrated(int days) async {
    final sp = await SharedPreferences.getInstance();
    await sp.setBool(_prefKey(days), true);
  }

  /// Checks if current streak matches any milestone that hasn't been celebrated yet.
  /// Returns the highest uncelebrated milestone <= currentStreak, or null if none.
  Future<int?> checkUncelebratedMilestone(int currentStreak) async {
    for (final milestone in milestones.reversed) {
      if (currentStreak >= milestone) {
        final celebrated = await hasCelebratedMilestone(milestone);
        if (!celebrated) {
          return milestone;
        }
      }
    }
    return null;
  }

  @visibleForTesting
  Future<void> resetForTesting() async {
    final sp = await SharedPreferences.getInstance();
    for (final m in milestones) {
      await sp.remove(_prefKey(m));
    }
  }
}
