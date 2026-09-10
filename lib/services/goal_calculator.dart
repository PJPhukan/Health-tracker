import 'dart:math' as math;

import '../models/user_profile.dart';

/// Turns the onboarding answers into a first set of daily targets.
///
/// The user reviews and can override every number on the next screen, so these
/// are a sensible starting point, not gospel.
class GoalCalculator {
  const GoalCalculator._();

  /// Mifflin-St Jeor resting metabolic rate (kcal/day).
  ///   men:   10·kg + 6.25·cm − 5·age + 5
  ///   women: 10·kg + 6.25·cm − 5·age − 161
  /// "Other" uses the average of the two constants.
  static double bmr({
    required Gender gender,
    required double weightKg,
    required double heightCm,
    required int age,
  }) {
    final base = 10 * weightKg + 6.25 * heightCm - 5 * age;
    final constant = switch (gender) {
      Gender.male => 5.0,
      Gender.female => -161.0,
      Gender.other => -78.0,
    };
    return base + constant;
  }

  /// BMR × activity multiplier.
  static double tdee({
    required Gender gender,
    required double weightKg,
    required double heightCm,
    required int age,
    required ActivityLevel activity,
  }) =>
      bmr(gender: gender, weightKg: weightKg, heightCm: heightCm, age: age) *
      activity.multiplier;

  static ({int min, int max}) _stepsFor(ActivityLevel a) => switch (a) {
        ActivityLevel.sedentary => (min: 5000, max: 7000),
        ActivityLevel.light => (min: 7000, max: 9000),
        ActivityLevel.moderate => (min: 8000, max: 10000),
        ActivityLevel.active => (min: 10000, max: 12000),
      };

  static ({double min, double max}) _sleepFor(ActivityLevel a) => switch (a) {
        ActivityLevel.active => (min: 7.5, max: 9),
        ActivityLevel.moderate => (min: 7, max: 9),
        _ => (min: 7, max: 8),
      };

  static int _round50(double v) => (v / 50).round() * 50;

  /// Full target set from a profile's inputs.
  static HealthGoals fromInputs({
    required Gender gender,
    required int age,
    required double heightCm,
    required double currentWeightKg,
    required ActivityLevel activity,
    required PrimaryGoal goal,
  }) {
    final maintenance = tdee(
      gender: gender,
      weightKg: currentWeightKg,
      heightCm: heightCm,
      age: age,
      activity: activity,
    );

    // Clamp calories to a safe floor so an aggressive cut can't go too low.
    final floor = gender == Gender.female ? 1200.0 : 1500.0;
    final calories =
        math.max(floor, maintenance + goal.calorieDelta).roundToDouble();

    final protein = (currentWeightKg * goal.proteinPerKg).round();
    final steps = _stepsFor(activity);
    final sleep = _sleepFor(activity);

    return HealthGoals(
      calories: _round50(calories),
      proteinGrams: protein,
      stepsMin: steps.min,
      stepsMax: steps.max,
      sleepMinHours: sleep.min,
      sleepMaxHours: sleep.max,
      objective: goal.label.toLowerCase(),
    );
  }
}
