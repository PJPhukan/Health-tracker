/// Fixed health goal — hardcoded for v1.
class HealthGoal {
  static const int minCalories = 1738;
  static const int minProteinGrams = 48;
  static const String objective = 'muscle / weight gain';
  static const int stepsMin = 5000;
  static const int stepsMax = 7000;
  static const double sleepMinHours = 7;
  static const double sleepMaxHours = 8;

  static String get promptText =>
      'Daily target: at least $minCalories kcal and $minProteinGrams g protein, '
      'goal is $objective. Steps target: $stepsMin-$stepsMax per day. '
      'Sleep target: ${sleepMinHours.toStringAsFixed(0)}-${sleepMaxHours.toStringAsFixed(0)} hours.';
}
