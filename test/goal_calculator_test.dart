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

  group('edge cases', () {
    test('"other" gender BMR uses the averaged constant (-78)', () {
      // 10*70 + 6.25*170 - 5*25 - 78 = 1559.5
      final bmr = GoalCalculator.bmr(
          gender: Gender.other, weightKg: 70, heightCm: 170, age: 25);
      expect(bmr, closeTo(1559.5, 0.01));
    });

    test('maintain applies no calorie delta beyond rounding', () {
      final maintenance = GoalCalculator.tdee(
        gender: Gender.male,
        weightKg: 80,
        heightCm: 180,
        age: 30,
        activity: ActivityLevel.sedentary,
      );
      final goals = GoalCalculator.fromInputs(
        gender: Gender.male,
        age: 30,
        heightCm: 180,
        currentWeightKg: 80,
        activity: ActivityLevel.sedentary,
        goal: PrimaryGoal.maintain,
      );
      expect(goals.calories, closeTo(maintenance, 25)); // within one rounding step
    });

    test('buildMuscle: +300 kcal delta and 2.0 g/kg protein', () {
      final goals = GoalCalculator.fromInputs(
        gender: Gender.male,
        age: 28,
        heightCm: 178,
        currentWeightKg: 75,
        activity: ActivityLevel.moderate,
        goal: PrimaryGoal.buildMuscle,
      );
      final maintenance = GoalCalculator.tdee(
        gender: Gender.male,
        weightKg: 75,
        heightCm: 178,
        age: 28,
        activity: ActivityLevel.moderate,
      );
      expect(goals.calories, closeTo(maintenance + 300, 25));
      expect(goals.proteinGrams, (75 * 2.0).round());
    });

    test('the female floor (1200) is lower than the male floor (1500)', () {
      const commonInputs = (
        age: 70,
        heightCm: 140.0,
        currentWeightKg: 40.0,
        activity: ActivityLevel.sedentary,
        goal: PrimaryGoal.loseWeight,
      );
      final female = GoalCalculator.fromInputs(
        gender: Gender.female,
        age: commonInputs.age,
        heightCm: commonInputs.heightCm,
        currentWeightKg: commonInputs.currentWeightKg,
        activity: commonInputs.activity,
        goal: commonInputs.goal,
      );
      final male = GoalCalculator.fromInputs(
        gender: Gender.male,
        age: commonInputs.age,
        heightCm: commonInputs.heightCm,
        currentWeightKg: commonInputs.currentWeightKg,
        activity: commonInputs.activity,
        goal: commonInputs.goal,
      );
      expect(female.calories, greaterThanOrEqualTo(1200));
      expect(male.calories, greaterThanOrEqualTo(1500));
    });

    test('calories are always rounded to a multiple of 50', () {
      for (final activity in ActivityLevel.values) {
        for (final goal in PrimaryGoal.values) {
          final goals = GoalCalculator.fromInputs(
            gender: Gender.male,
            age: 40,
            heightCm: 172,
            currentWeightKg: 68,
            activity: activity,
            goal: goal,
          );
          expect(goals.calories % 50, 0,
              reason: '$activity / $goal produced ${goals.calories}');
        }
      }
    });

    test('steps and sleep targets widen as activity level increases', () {
      final sedentary = GoalCalculator.fromInputs(
        gender: Gender.male,
        age: 30,
        heightCm: 175,
        currentWeightKg: 70,
        activity: ActivityLevel.sedentary,
        goal: PrimaryGoal.maintain,
      );
      final active = GoalCalculator.fromInputs(
        gender: Gender.male,
        age: 30,
        heightCm: 175,
        currentWeightKg: 70,
        activity: ActivityLevel.active,
        goal: PrimaryGoal.maintain,
      );
      expect(active.stepsMin, greaterThan(sedentary.stepsMin));
      expect(active.stepsMax, greaterThan(sedentary.stepsMax));
      expect(active.sleepMaxHours, greaterThanOrEqualTo(sedentary.sleepMaxHours));
    });

    test('boundary ages (13 and 100) compute without error and differ', () {
      final young = GoalCalculator.bmr(
          gender: Gender.male, weightKg: 50, heightCm: 160, age: 13);
      final old = GoalCalculator.bmr(
          gender: Gender.male, weightKg: 50, heightCm: 160, age: 100);
      expect(young, greaterThan(old)); // BMR falls with age, all else equal
    });
  });
}
