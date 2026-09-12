// Data classes for all local DB tables.
// Dates are stored as ISO yyyy-MM-dd strings; timestamps as full ISO-8601.
//
// `syncId` (v3): a stable, cross-device id that doubles as the Firestore
// document id under `users/{uid}/<collection>/`. Null only for rows created
// before v3 that haven't been through the one-time migration yet. The local
// autoincrement `id` stays the key the UI passes around.

String dateKey(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

enum MealType { breakfast, lunch, dinner, snack }

MealType mealTypeFromString(String s) =>
    MealType.values.firstWhere((e) => e.name == s, orElse: () => MealType.snack);

class MealEntry {
  final int? id;
  final String? syncId;
  final String date; // yyyy-MM-dd
  final MealType mealType;
  final String foodDescription;
  final String timestamp; // ISO-8601

  MealEntry({
    this.id,
    this.syncId,
    required this.date,
    required this.mealType,
    required this.foodDescription,
    required this.timestamp,
  });

  Map<String, Object?> toMap() => {
        if (id != null) 'id': id,
        if (syncId != null) 'syncId': syncId,
        'date': date,
        'mealType': mealType.name,
        'foodDescription': foodDescription,
        'timestamp': timestamp,
      };

  factory MealEntry.fromMap(Map<String, Object?> m) => MealEntry(
        id: m['id'] as int?,
        syncId: m['syncId'] as String?,
        date: m['date'] as String,
        mealType: mealTypeFromString(m['mealType'] as String),
        foodDescription: m['foodDescription'] as String,
        timestamp: m['timestamp'] as String,
      );
}

class WorkoutEntry {
  final int? id;
  final String? syncId;
  final String date;
  final String exerciseType;
  final int durationMinutes;
  final String notes;
  final String timestamp;

  WorkoutEntry({
    this.id,
    this.syncId,
    required this.date,
    required this.exerciseType,
    required this.durationMinutes,
    this.notes = '',
    required this.timestamp,
  });

  Map<String, Object?> toMap() => {
        if (id != null) 'id': id,
        if (syncId != null) 'syncId': syncId,
        'date': date,
        'exerciseType': exerciseType,
        'durationMinutes': durationMinutes,
        'notes': notes,
        'timestamp': timestamp,
      };

  factory WorkoutEntry.fromMap(Map<String, Object?> m) => WorkoutEntry(
        id: m['id'] as int?,
        syncId: m['syncId'] as String?,
        date: m['date'] as String,
        exerciseType: m['exerciseType'] as String,
        durationMinutes: (m['durationMinutes'] as num).toInt(),
        notes: (m['notes'] as String?) ?? '',
        timestamp: m['timestamp'] as String,
      );
}

class SleepEntry {
  final int? id;
  final String? syncId;
  final String date;
  final String sleepTime; // HH:mm
  final String wakeTime; // HH:mm
  final double totalHours;

  SleepEntry({
    this.id,
    this.syncId,
    required this.date,
    required this.sleepTime,
    required this.wakeTime,
    required this.totalHours,
  });

  Map<String, Object?> toMap() => {
        if (id != null) 'id': id,
        if (syncId != null) 'syncId': syncId,
        'date': date,
        'sleepTime': sleepTime,
        'wakeTime': wakeTime,
        'totalHours': totalHours,
      };

  factory SleepEntry.fromMap(Map<String, Object?> m) => SleepEntry(
        id: m['id'] as int?,
        syncId: m['syncId'] as String?,
        date: m['date'] as String,
        sleepTime: m['sleepTime'] as String,
        wakeTime: m['wakeTime'] as String,
        totalHours: (m['totalHours'] as num).toDouble(),
      );

  /// Computes hours between a sleep and wake time, wrapping past midnight.
  static double hoursBetween(String sleep, String wake) {
    final s = _mins(sleep);
    final w = _mins(wake);
    final diff = (w - s + 24 * 60) % (24 * 60);
    return diff / 60.0;
  }

  static int _mins(String hhmm) {
    final parts = hhmm.split(':');
    return int.parse(parts[0]) * 60 + int.parse(parts[1]);
  }
}

class WeightEntry {
  final int? id;
  final String? syncId;
  final String date;
  final double weightKg;

  WeightEntry({this.id, this.syncId, required this.date, required this.weightKg});

  Map<String, Object?> toMap() => {
        if (id != null) 'id': id,
        if (syncId != null) 'syncId': syncId,
        'date': date,
        'weightKg': weightKg,
      };

  factory WeightEntry.fromMap(Map<String, Object?> m) => WeightEntry(
        id: m['id'] as int?,
        syncId: m['syncId'] as String?,
        date: m['date'] as String,
        weightKg: (m['weightKg'] as num).toDouble(),
      );
}

class StepsEntry {
  final int? id;
  final String? syncId;
  final String date;
  final int stepCount;

  StepsEntry({this.id, this.syncId, required this.date, required this.stepCount});

  Map<String, Object?> toMap() => {
        if (id != null) 'id': id,
        if (syncId != null) 'syncId': syncId,
        'date': date,
        'stepCount': stepCount,
      };

  factory StepsEntry.fromMap(Map<String, Object?> m) => StepsEntry(
        id: m['id'] as int?,
        syncId: m['syncId'] as String?,
        date: m['date'] as String,
        stepCount: (m['stepCount'] as num).toInt(),
      );
}

class PantryItem {
  final int? id;
  final String? syncId;
  final String itemName;
  final String quantity; // free text: "2kg", "low", "plenty", or ''
  final bool isLow;
  final String lastUpdated; // ISO-8601

  PantryItem({
    this.id,
    this.syncId,
    required this.itemName,
    this.quantity = '',
    this.isLow = false,
    required this.lastUpdated,
  });

  PantryItem copyWith({String? itemName, String? quantity, bool? isLow}) =>
      PantryItem(
        id: id,
        syncId: syncId,
        itemName: itemName ?? this.itemName,
        quantity: quantity ?? this.quantity,
        isLow: isLow ?? this.isLow,
        lastUpdated: DateTime.now().toIso8601String(),
      );

  Map<String, Object?> toMap() => {
        if (id != null) 'id': id,
        if (syncId != null) 'syncId': syncId,
        'itemName': itemName,
        'quantity': quantity,
        'isLow': isLow ? 1 : 0,
        'lastUpdated': lastUpdated,
      };

  factory PantryItem.fromMap(Map<String, Object?> m) => PantryItem(
        id: m['id'] as int?,
        syncId: m['syncId'] as String?,
        itemName: m['itemName'] as String,
        quantity: (m['quantity'] as String?) ?? '',
        isLow: ((m['isLow'] as num?) ?? 0) != 0,
        lastUpdated: m['lastUpdated'] as String,
      );
}

/// A reusable "quick add" meal — e.g. "Rice + dal + egg". Stored locally in
/// `meal_favorites`, scoped to a profile id so accounts don't share them on a
/// shared device.
class MealFavorite {
  final int? id;
  final String? syncId;
  final String profileId;
  final String name;
  final String description;
  final MealType mealType;
  final int useCount;
  final String createdAt;

  MealFavorite({
    this.id,
    this.syncId,
    required this.profileId,
    required this.name,
    this.description = '',
    this.mealType = MealType.snack,
    this.useCount = 0,
    required this.createdAt,
  });

  MealFavorite copyWith({
    String? name,
    String? description,
    MealType? mealType,
    int? useCount,
  }) =>
      MealFavorite(
        id: id,
        syncId: syncId,
        profileId: profileId,
        name: name ?? this.name,
        description: description ?? this.description,
        mealType: mealType ?? this.mealType,
        useCount: useCount ?? this.useCount,
        createdAt: createdAt,
      );

  Map<String, Object?> toMap() => {
        if (id != null) 'id': id,
        if (syncId != null) 'syncId': syncId,
        'profileId': profileId,
        'name': name,
        'description': description,
        'mealType': mealType.name,
        'useCount': useCount,
        'createdAt': createdAt,
      };

  factory MealFavorite.fromMap(Map<String, Object?> m) => MealFavorite(
        id: m['id'] as int?,
        syncId: m['syncId'] as String?,
        profileId: (m['profileId'] as String?) ?? 'local',
        name: m['name'] as String,
        description: (m['description'] as String?) ?? '',
        mealType: mealTypeFromString((m['mealType'] as String?) ?? 'snack'),
        useCount: (m['useCount'] as num?)?.toInt() ?? 0,
        createdAt: (m['createdAt'] as String?) ??
            DateTime.now().toIso8601String(),
      );

  /// What gets written into the meal log when this favorite is tapped.
  String get loggedDescription =>
      description.trim().isEmpty ? name : '$name — ${description.trim()}';
}

/// Which days a [MealTemplate] applies to.
enum DayType { weekday, weekend, everyday }

DayType dayTypeFromString(String s) =>
    DayType.values.firstWhere((e) => e.name == s, orElse: () => DayType.everyday);

/// A recurring meal — "Weekday breakfast: Rice + dal + egg". Matched against
/// today by [TemplateMatcher] to proactively suggest a one-tap log.
class MealTemplate {
  final int? id;
  final String? syncId;
  final String profileId;
  final DayType dayType;
  final MealType mealSlot;
  final String foodDescription;
  final List<String> items;
  final String createdAt;

  MealTemplate({
    this.id,
    this.syncId,
    required this.profileId,
    required this.dayType,
    required this.mealSlot,
    required this.foodDescription,
    this.items = const [],
    required this.createdAt,
  });

  Map<String, Object?> toMap() => {
        if (id != null) 'id': id,
        if (syncId != null) 'syncId': syncId,
        'profileId': profileId,
        'dayType': dayType.name,
        'mealSlot': mealSlot.name,
        'foodDescription': foodDescription,
        'items': items.join('|'),
        'createdAt': createdAt,
      };

  factory MealTemplate.fromMap(Map<String, Object?> m) => MealTemplate(
        id: m['id'] as int?,
        syncId: m['syncId'] as String?,
        profileId: (m['profileId'] as String?) ?? 'local',
        dayType: dayTypeFromString((m['dayType'] as String?) ?? 'everyday'),
        mealSlot: mealTypeFromString((m['mealSlot'] as String?) ?? 'snack'),
        foodDescription: m['foodDescription'] as String,
        items: ((m['items'] as String?) ?? '')
            .split('|')
            .where((s) => s.isNotEmpty)
            .toList(),
        createdAt:
            (m['createdAt'] as String?) ?? DateTime.now().toIso8601String(),
      );
}

class SuggestionEntry {
  final int? id;
  final String? syncId;
  final String date;
  final String prompt;
  final String response;
  final String timestamp;

  SuggestionEntry({
    this.id,
    this.syncId,
    required this.date,
    required this.prompt,
    required this.response,
    required this.timestamp,
  });

  Map<String, Object?> toMap() => {
        if (id != null) 'id': id,
        if (syncId != null) 'syncId': syncId,
        'date': date,
        'prompt': prompt,
        'response': response,
        'timestamp': timestamp,
      };

  factory SuggestionEntry.fromMap(Map<String, Object?> m) => SuggestionEntry(
        id: m['id'] as int?,
        syncId: m['syncId'] as String?,
        date: m['date'] as String,
        prompt: m['prompt'] as String,
        response: m['response'] as String,
        timestamp: m['timestamp'] as String,
      );
}

/// A day's worth of logged data, used for the home summary and AI prompt.
class DailySummary {
  final String date;
  final List<MealEntry> meals;
  final List<WorkoutEntry> workouts;
  final SleepEntry? sleep;
  final StepsEntry? steps;
  final WeightEntry? weight;

  DailySummary({
    required this.date,
    required this.meals,
    required this.workouts,
    this.sleep,
    this.steps,
    this.weight,
  });

  bool get workoutDone => workouts.isNotEmpty;
  double get sleepHours => sleep?.totalHours ?? 0;
  int get stepCount => steps?.stepCount ?? 0;
}
