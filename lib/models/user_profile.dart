import 'dart:convert';

/// Biological sex, used by the Mifflin-St Jeor BMR equation.
enum Gender { male, female, other }

enum ActivityLevel { sedentary, light, moderate, active }

enum PrimaryGoal { gainWeight, loseWeight, maintain, buildMuscle }

extension GenderLabel on Gender {
  String get label => switch (this) {
        Gender.male => 'Male',
        Gender.female => 'Female',
        Gender.other => 'Prefer not to say',
      };
}

extension ActivityLevelInfo on ActivityLevel {
  String get label => switch (this) {
        ActivityLevel.sedentary => 'Sedentary',
        ActivityLevel.light => 'Lightly active',
        ActivityLevel.moderate => 'Moderately active',
        ActivityLevel.active => 'Very active',
      };

  String get description => switch (this) {
        ActivityLevel.sedentary => 'Desk job, little or no exercise',
        ActivityLevel.light => 'Light exercise 1–3 days a week',
        ActivityLevel.moderate => 'Moderate exercise 3–5 days a week',
        ActivityLevel.active => 'Hard exercise 6–7 days a week',
      };

  /// Standard Harris-Benedict/Mifflin activity multipliers.
  double get multiplier => switch (this) {
        ActivityLevel.sedentary => 1.2,
        ActivityLevel.light => 1.375,
        ActivityLevel.moderate => 1.55,
        ActivityLevel.active => 1.725,
      };
}

extension PrimaryGoalInfo on PrimaryGoal {
  String get label => switch (this) {
        PrimaryGoal.gainWeight => 'Gain weight',
        PrimaryGoal.loseWeight => 'Lose weight',
        PrimaryGoal.maintain => 'Maintain',
        PrimaryGoal.buildMuscle => 'Build muscle',
      };

  String get description => switch (this) {
        PrimaryGoal.gainWeight => 'Eat above maintenance to add mass',
        PrimaryGoal.loseWeight => 'Eat below maintenance to lose fat',
        PrimaryGoal.maintain => 'Hold steady at your current weight',
        PrimaryGoal.buildMuscle => 'A modest surplus with high protein',
      };

  /// Daily calorie delta applied on top of TDEE.
  int get calorieDelta => switch (this) {
        PrimaryGoal.gainWeight => 400,
        PrimaryGoal.buildMuscle => 300,
        PrimaryGoal.loseWeight => -400,
        PrimaryGoal.maintain => 0,
      };

  /// Grams of protein per kg of bodyweight. A deficit gets the highest ratio
  /// to protect lean mass while cutting.
  double get proteinPerKg => switch (this) {
        PrimaryGoal.buildMuscle => 2.0,
        PrimaryGoal.gainWeight => 1.8,
        PrimaryGoal.loseWeight => 2.2,
        PrimaryGoal.maintain => 1.6,
      };
}

T _enumFrom<T extends Enum>(List<T> values, Object? raw, T fallback) {
  if (raw is! String) return fallback;
  for (final v in values) {
    if (v.name == raw) return v;
  }
  return fallback;
}

/// The daily targets the whole app measures against.
///
/// Replaces v1's hardcoded `HealthGoal`; [HealthGoals.starter] preserves those
/// original numbers for users who haven't onboarded yet.
class HealthGoals {
  const HealthGoals({
    required this.calories,
    required this.proteinGrams,
    required this.stepsMin,
    required this.stepsMax,
    required this.sleepMinHours,
    required this.sleepMaxHours,
    required this.objective,
  });

  final int calories;
  final int proteinGrams;
  final int stepsMin;
  final int stepsMax;
  final double sleepMinHours;
  final double sleepMaxHours;

  /// Human-readable goal ("build muscle"), fed to the AI prompt.
  final String objective;

  /// v1's fixed targets — the fallback before a profile exists.
  static const starter = HealthGoals(
    calories: 1738,
    proteinGrams: 48,
    stepsMin: 5000,
    stepsMax: 7000,
    sleepMinHours: 7,
    sleepMaxHours: 8,
    objective: 'muscle / weight gain',
  );

  String get promptText =>
      'Daily target: at least $calories kcal and $proteinGrams g protein, '
      'goal is $objective. Steps target: $stepsMin-$stepsMax per day. '
      'Sleep target: ${_trim(sleepMinHours)}-${_trim(sleepMaxHours)} hours.';

  static String _trim(double v) =>
      v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toStringAsFixed(1);

  @override
  bool operator ==(Object other) =>
      other is HealthGoals &&
      other.calories == calories &&
      other.proteinGrams == proteinGrams &&
      other.stepsMin == stepsMin &&
      other.stepsMax == stepsMax &&
      other.sleepMinHours == sleepMinHours &&
      other.sleepMaxHours == sleepMaxHours &&
      other.objective == objective;

  @override
  int get hashCode => Object.hash(calories, proteinGrams, stepsMin, stepsMax,
      sleepMinHours, sleepMaxHours, objective);

  HealthGoals copyWith({
    int? calories,
    int? proteinGrams,
    int? stepsMin,
    int? stepsMax,
    double? sleepMinHours,
    double? sleepMaxHours,
    String? objective,
  }) =>
      HealthGoals(
        calories: calories ?? this.calories,
        proteinGrams: proteinGrams ?? this.proteinGrams,
        stepsMin: stepsMin ?? this.stepsMin,
        stepsMax: stepsMax ?? this.stepsMax,
        sleepMinHours: sleepMinHours ?? this.sleepMinHours,
        sleepMaxHours: sleepMaxHours ?? this.sleepMaxHours,
        objective: objective ?? this.objective,
      );

  Map<String, Object?> toMap() => {
        'calories': calories,
        'proteinGrams': proteinGrams,
        'stepsMin': stepsMin,
        'stepsMax': stepsMax,
        'sleepMinHours': sleepMinHours,
        'sleepMaxHours': sleepMaxHours,
        'objective': objective,
      };

  factory HealthGoals.fromMap(Map<String, Object?> m) => HealthGoals(
        calories: (m['calories'] as num?)?.toInt() ?? starter.calories,
        proteinGrams:
            (m['proteinGrams'] as num?)?.toInt() ?? starter.proteinGrams,
        stepsMin: (m['stepsMin'] as num?)?.toInt() ?? starter.stepsMin,
        stepsMax: (m['stepsMax'] as num?)?.toInt() ?? starter.stepsMax,
        sleepMinHours:
            (m['sleepMinHours'] as num?)?.toDouble() ?? starter.sleepMinHours,
        sleepMaxHours:
            (m['sleepMaxHours'] as num?)?.toDouble() ?? starter.sleepMaxHours,
        objective: (m['objective'] as String?) ?? starter.objective,
      );
}

/// A user's profile plus their (possibly hand-edited) targets.
///
/// Persisted to Firestore at `users/{uid}` with `goals` as a nested map, and
/// mirrored into local SQLite so the app works offline.
class UserProfile {
  const UserProfile({
    required this.uid,
    this.email,
    required this.displayName,
    required this.age,
    required this.gender,
    required this.heightCm,
    required this.currentWeightKg,
    required this.targetWeightKg,
    required this.activityLevel,
    required this.primaryGoal,
    required this.goals,
    this.onboardingComplete = false,
    required this.updatedAt,
  });

  final String uid;
  final String? email;
  final String displayName;
  final int age;
  final Gender gender;
  final double heightCm;
  final double currentWeightKg;
  final double targetWeightKg;
  final ActivityLevel activityLevel;
  final PrimaryGoal primaryGoal;
  final HealthGoals goals;
  final bool onboardingComplete;
  final String updatedAt;

  UserProfile copyWith({
    String? displayName,
    String? email,
    int? age,
    Gender? gender,
    double? heightCm,
    double? currentWeightKg,
    double? targetWeightKg,
    ActivityLevel? activityLevel,
    PrimaryGoal? primaryGoal,
    HealthGoals? goals,
    bool? onboardingComplete,
  }) =>
      UserProfile(
        uid: uid,
        email: email ?? this.email,
        displayName: displayName ?? this.displayName,
        age: age ?? this.age,
        gender: gender ?? this.gender,
        heightCm: heightCm ?? this.heightCm,
        currentWeightKg: currentWeightKg ?? this.currentWeightKg,
        targetWeightKg: targetWeightKg ?? this.targetWeightKg,
        activityLevel: activityLevel ?? this.activityLevel,
        primaryGoal: primaryGoal ?? this.primaryGoal,
        goals: goals ?? this.goals,
        onboardingComplete: onboardingComplete ?? this.onboardingComplete,
        updatedAt: DateTime.now().toIso8601String(),
      );

  Map<String, Object?> toMap() => {
        'uid': uid,
        'email': email,
        'displayName': displayName,
        'age': age,
        'gender': gender.name,
        'heightCm': heightCm,
        'currentWeightKg': currentWeightKg,
        'targetWeightKg': targetWeightKg,
        'activityLevel': activityLevel.name,
        'primaryGoal': primaryGoal.name,
        'goals': goals.toMap(),
        'onboardingComplete': onboardingComplete,
        'updatedAt': updatedAt,
      };

  factory UserProfile.fromMap(Map<String, Object?> m) => UserProfile(
        uid: (m['uid'] as String?) ?? '',
        email: m['email'] as String?,
        displayName: (m['displayName'] as String?) ?? '',
        age: (m['age'] as num?)?.toInt() ?? 30,
        gender: _enumFrom(Gender.values, m['gender'], Gender.other),
        heightCm: (m['heightCm'] as num?)?.toDouble() ?? 170,
        currentWeightKg: (m['currentWeightKg'] as num?)?.toDouble() ?? 70,
        targetWeightKg: (m['targetWeightKg'] as num?)?.toDouble() ?? 70,
        activityLevel: _enumFrom(
            ActivityLevel.values, m['activityLevel'], ActivityLevel.light),
        primaryGoal: _enumFrom(
            PrimaryGoal.values, m['primaryGoal'], PrimaryGoal.maintain),
        goals: m['goals'] is Map
            ? HealthGoals.fromMap(
                Map<String, Object?>.from(m['goals'] as Map))
            : HealthGoals.starter,
        onboardingComplete: m['onboardingComplete'] == true,
        updatedAt: (m['updatedAt'] as String?) ??
            DateTime.now().toIso8601String(),
      );

  String toJson() => jsonEncode(toMap());

  factory UserProfile.fromJson(String source) =>
      UserProfile.fromMap(jsonDecode(source) as Map<String, Object?>);
}
