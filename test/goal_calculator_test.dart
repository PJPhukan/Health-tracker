import 'package:flutter_test/flutter_test.dart';
import 'package:health_tracker/models/user_profile.dart';
import 'package:health_tracker/services/goal_calculator.dart';

void main() {
  group('Mifflin-St Jeor BMR', () {
    test('matches the textbook value for a man', () {
      // 10*80 + 6.25*180 - 5*30 + 5 = 1780
      final bmr = GoalCalculator.bmr(
          gender: Gender.male, weightKg: 80, heightCm: 180, age: 30);
      expect(bmr, closeTo(1780, 0.01));
    });

    test('matches the textbook value for a woman', () {
      // 10*60 + 6.25*165 - 5*30 - 161 = 1320.25
      final bmr = GoalCalculator.bmr(
          gender: Gender.female, weightKg: 60, heightCm: 165, age: 30);
      expect(bmr, closeTo(1320.25, 0.01));
    });
  });

  test('TDEE applies the activity multiplier', () {
    final tdee = GoalCalculator.tdee(
      gender: Gender.male,
      weightKg: 80,
      heightCm: 180,
      age: 30,
      activity: ActivityLevel.moderate, // 1.55
    );
    expect(tdee, closeTo(1780 * 1.55, 0.01));
  });

  group('fromInputs', () {
    test('a weight-gain goal lands above maintenance with high protein', () {
      final goals = GoalCalculator.fromInputs(
        gender: Gender.male,
        age: 25,
        heightCm: 175,
        currentWeightKg: 70,
        activity: ActivityLevel.light,
        goal: PrimaryGoal.gainWeight,
      );
      // maintenance ~ 2417; +400 delta, rounded to 50
      expect(goals.calories, greaterThan(2600));
      expect(goals.calories % 50, 0);
      // 70kg * 1.8 g/kg
      expect(goals.proteinGrams, 126);
      expect(goals.objective, 'gain weight');
      expect(goals.stepsMin, lessThan(goals.stepsMax));
      expect(goals.sleepMinHours, lessThanOrEqualTo(goals.sleepMaxHours));
    });

    test('an aggressive cut is floored, never unsafe', () {
      final goals = GoalCalculator.fromInputs(
        gender: Gender.female,
        age: 60,
        heightCm: 150,
        currentWeightKg: 45,
        activity: ActivityLevel.sedentary,
        goal: PrimaryGoal.loseWeight,
      );
      expect(goals.calories, greaterThanOrEqualTo(1200));
    });

    test('loseWeight uses the highest protein ratio (2.2 g/kg)', () {
      final goals = GoalCalculator.fromInputs(
        gender: Gender.male,
        age: 30,
        heightCm: 180,
        currentWeightKg: 80,
        activity: ActivityLevel.moderate,
        goal: PrimaryGoal.loseWeight,
      );
      expect(goals.proteinGrams, (80 * 2.2).round());
    });
  });

  test('HealthGoals equality is value-based (guards the proxy provider)', () {
    expect(HealthGoals.starter, equals(HealthGoals.starter.copyWith()));
    expect(HealthGoals.starter,
        isNot(equals(HealthGoals.starter.copyWith(calories: 2000))));
  });
}
