import 'package:flutter/foundation.dart';

import '../database/health_repository.dart';
import '../models/models.dart';
import '../services/gemini_service.dart';

enum SuggestionStatus { idle, loading, success, error }

class HealthProvider extends ChangeNotifier {
  HealthProvider({HealthRepository? repo, GeminiService? ai})
      : _repo = repo ?? HealthRepository(),
        _ai = ai ?? GeminiService();

  final HealthRepository _repo;
  final GeminiService _ai;

  DailySummary? _today;
  DailySummary? get today => _today;

  bool _loading = false;
  bool get loading => _loading;

  SuggestionStatus _suggestionStatus = SuggestionStatus.idle;
  SuggestionStatus get suggestionStatus => _suggestionStatus;

  String? _suggestionText;
  String? get suggestionText => _suggestionText;

  String? _suggestionError;
  String? get suggestionError => _suggestionError;

  String? _loadError;
  String? get loadError => _loadError;

  Future<void> loadToday() async {
    _loading = true;
    _loadError = null;
    notifyListeners();
    try {
      _today = await _repo.getDailySummary();
    } catch (e) {
      _loadError = 'Could not load your data.';
      if (kDebugMode) debugPrint('loadToday failed: $e');
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  // ---- logging ----

  Future<void> addMeal(MealType type, String description) async {
    final now = DateTime.now();
    await _repo.insertMeal(MealEntry(
      date: dateKey(now),
      mealType: type,
      foodDescription: description.trim(),
      timestamp: now.toIso8601String(),
    ));
    await loadToday();
  }

  Future<void> deleteMeal(int id) async {
    await _repo.deleteMeal(id);
    await loadToday();
  }

  Future<void> updateMeal(MealEntry entry, String description) async {
    await _repo.updateMeal(MealEntry(
      id: entry.id,
      date: entry.date,
      mealType: entry.mealType,
      foodDescription: description.trim(),
      timestamp: entry.timestamp,
    ));
    await loadToday();
  }

  Future<void> addWorkout(String type, int minutes, String notes) async {
    final now = DateTime.now();
    await _repo.insertWorkout(WorkoutEntry(
      date: dateKey(now),
      exerciseType: type.trim(),
      durationMinutes: minutes,
      notes: notes.trim(),
      timestamp: now.toIso8601String(),
    ));
    await loadToday();
  }

  Future<void> deleteWorkout(int id) async {
    await _repo.deleteWorkout(id);
    await loadToday();
  }

  Future<void> updateWorkout(
      WorkoutEntry entry, String type, int minutes, String notes) async {
    await _repo.updateWorkout(WorkoutEntry(
      id: entry.id,
      date: entry.date,
      exerciseType: type.trim(),
      durationMinutes: minutes,
      notes: notes.trim(),
      timestamp: entry.timestamp,
    ));
    await loadToday();
  }

  Future<void> addSleep(String sleepTime, String wakeTime) async {
    final now = DateTime.now();
    await _repo.insertSleep(SleepEntry(
      date: dateKey(now),
      sleepTime: sleepTime,
      wakeTime: wakeTime,
      totalHours: SleepEntry.hoursBetween(sleepTime, wakeTime),
    ));
    await loadToday();
  }

  Future<void> deleteSleep(int id) async {
    await _repo.deleteSleep(id);
    await loadToday();
  }

  Future<void> updateSleep(
      SleepEntry entry, String sleepTime, String wakeTime) async {
    await _repo.updateSleep(SleepEntry(
      id: entry.id,
      date: entry.date,
      sleepTime: sleepTime,
      wakeTime: wakeTime,
      totalHours: SleepEntry.hoursBetween(sleepTime, wakeTime),
    ));
    await loadToday();
  }

  Future<void> addWeight(double kg) async {
    final now = DateTime.now();
    await _repo.insertWeight(WeightEntry(date: dateKey(now), weightKg: kg));
    await loadToday();
  }

  Future<void> deleteWeight(int id) async {
    await _repo.deleteWeight(id);
    await loadToday();
  }

  Future<void> updateWeight(WeightEntry entry, double kg) async {
    await _repo.updateWeight(
        WeightEntry(id: entry.id, date: entry.date, weightKg: kg));
    await loadToday();
  }

  Future<void> addSteps(int count) async {
    final now = DateTime.now();
    await _repo.insertSteps(StepsEntry(date: dateKey(now), stepCount: count));
    await loadToday();
  }

  Future<void> deleteSteps(int id) async {
    await _repo.deleteSteps(id);
    await loadToday();
  }

  Future<void> updateSteps(StepsEntry entry, int count) async {
    await _repo.updateSteps(
        StepsEntry(id: entry.id, date: entry.date, stepCount: count));
    await loadToday();
  }

  // ---- pantry ----

  List<PantryItem> _pantry = [];
  List<PantryItem> get pantry => _pantry;

  Future<void> loadPantry() async {
    try {
      _pantry = await _repo.getAllPantryItems();
    } catch (e) {
      if (kDebugMode) debugPrint('loadPantry failed: $e');
    }
    notifyListeners();
  }

  Future<void> addPantryItem(String name, String quantity) async {
    await _repo.insertPantryItem(PantryItem(
      itemName: name.trim(),
      quantity: quantity.trim(),
      lastUpdated: DateTime.now().toIso8601String(),
    ));
    await loadPantry();
  }

  Future<void> updatePantryItem(PantryItem item) async {
    await _repo.updatePantryItem(item);
    await loadPantry();
  }

  Future<void> deletePantryItem(int id) async {
    await _repo.deletePantryItem(id);
    await loadPantry();
  }

  // ---- history ----

  Future<List<String>> recentDates({int days = 7}) =>
      _repo.getRecentDates(days: days);
  Future<DailySummary> summaryForDate(String date) =>
      _repo.getDailySummary(DateTime.parse(date));

  // ---- AI ----

  Future<void> getSuggestion() async {
    _suggestionStatus = SuggestionStatus.loading;
    _suggestionError = null;
    notifyListeners();

    try {
      final summary = _today ?? await _repo.getDailySummary();
      final pantry = await _repo.getAllPantryItems();
      final result = await _ai.getSuggestion(summary, pantry);
      _suggestionText = result.text;
      _suggestionStatus = SuggestionStatus.success;

      await _repo.insertSuggestion(SuggestionEntry(
        date: summary.date,
        prompt: result.prompt,
        response: result.text,
        timestamp: DateTime.now().toIso8601String(),
      ));
    } catch (e) {
      _suggestionStatus = SuggestionStatus.error;
      _suggestionError =
          e is AiException ? e.message : "Couldn't get suggestion, try again.";
      if (kDebugMode) debugPrint('getSuggestion failed: $e');
    }
    notifyListeners();
  }
}
