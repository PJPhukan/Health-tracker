import 'package:flutter/foundation.dart';

import '../database/health_repository.dart';
import '../database/sync_service.dart';
import '../models/models.dart';
import '../models/user_profile.dart';
import '../services/gemini_service.dart';
import '../services/health_steps_service.dart';
import '../services/notification_service.dart';

enum SuggestionStatus { idle, loading, success, error }

class HealthProvider extends ChangeNotifier {
  HealthProvider({
    HealthRepository? repo,
    GeminiService? ai,
    HealthStepsService? healthSteps,
    SyncService? sync,
  })  : _sync = sync,
        _repo = repo ?? HealthRepository(sync: sync),
        _ai = ai ?? GeminiService(),
        _healthSteps = healthSteps ?? HealthStepsService();

  final HealthRepository _repo;
  final GeminiService _ai;
  final HealthStepsService _healthSteps;
  final SyncService? _sync;

  /// Pull the cloud copy down, flush pending local writes, then refresh the UI.
  /// Called on login and on every app resume; a no-op in local-only mode.
  Future<void> syncNow() async {
    if (_sync == null || !_sync.enabled) return;
    await _sync.syncNow();
    await loadToday();
    await loadFavorites();
  }

  /// Current daily targets, pushed in from [ProfileController] via a
  /// ChangeNotifierProxyProvider. Falls back to v1's fixed numbers.
  HealthGoals _goals = HealthGoals.starter;
  HealthGoals get goals => _goals;

  void syncGoals(HealthGoals next) {
    if (next == _goals) return;
    _goals = next;
    notifyListeners();
  }

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

  // ---- auto step tracking (Health Connect / HealthKit) ----

  HealthAccess _healthAccess = HealthAccess.unknown;
  HealthAccess get healthAccess => _healthAccess;

  /// True once we've auto-synced steps at least once this session (so the Steps
  /// form knows the shown value came from the device).
  bool _stepsAutoSynced = false;
  bool get stepsAutoSynced => _stepsAutoSynced;

  bool get stepsAutoTracked => _healthAccess == HealthAccess.granted;

  /// Called once on app start. Silently syncs steps if access is already there;
  /// never prompts.
  Future<void> initHealthSync() async {
    _healthAccess = await _healthSteps.currentAccess();
    notifyListeners();
    if (_healthAccess == HealthAccess.granted) {
      await _syncStepsFromHealth();
    }
  }

  /// Prompts for step-read access (from the Steps form / a home prompt).
  /// Returns true if granted.
  Future<bool> connectHealthData() async {
    _healthAccess = await _healthSteps.requestAccess();
    notifyListeners();
    if (_healthAccess == HealthAccess.granted) {
      await _syncStepsFromHealth();
      await loadToday();
      return true;
    }
    return false;
  }

  /// Fetches today's device step count and writes it as today's steps row when
  /// it differs from what's stored. Manual entry stays the fallback: this only
  /// runs when access is granted.
  Future<void> _syncStepsFromHealth() async {
    final steps = await _healthSteps.stepsToday();
    if (steps == null) return;
    final existing = await _repo.getTodaySteps();
    if (existing?.stepCount == steps) {
      _stepsAutoSynced = true;
      return;
    }
    await _repo.insertSteps(
        StepsEntry(date: dateKey(DateTime.now()), stepCount: steps));
    _stepsAutoSynced = true;
  }

  /// Manual "sync now" from the Steps form.
  Future<void> refreshStepsFromHealth() async {
    if (_healthAccess != HealthAccess.granted) return;
    await _syncStepsFromHealth();
    await loadToday();
  }

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

  /// Cancels + reschedules today's reminders, suppressing whichever slots are
  /// already satisfied. Safe to call often — on app start, resume, and once
  /// at local midnight.
  Future<void> refreshReminders() async {
    final today = _today ?? await _repo.getDailySummary();
    final breakfastLogged =
        today.meals.any((m) => m.mealType == MealType.breakfast);
    final suggestionToday = await _repo.hasSuggestionOn(dateKey(DateTime.now()));
    await NotificationService.instance.rescheduleToday(
      breakfastLogged: breakfastLogged,
      suggestionFetchedToday: suggestionToday,
    );
  }

  // ---- logging ----

  /// Voice -> structured meal fields, for the mic button on the meal form.
  /// Returns null on any failure; the caller falls back to the raw transcript.
  Future<VoiceMealParse?> parseVoiceMeal(String transcript) =>
      _ai.parseVoiceMeal(transcript);

  Future<void> addMeal(MealType type, String description) async {
    final now = DateTime.now();
    final desc = description.trim();
    await _repo.insertMeal(MealEntry(
      date: dateKey(now),
      mealType: type,
      foodDescription: desc,
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

  /// Batch-adds a checklist worth of items at once — pantry onboarding.
  /// Returns how many were actually added (duplicates are skipped).
  Future<int> addPantryItemsBatch(List<String> names) async {
    final added = await _repo.addPantryItemsBatch(names);
    await loadPantry();
    return added;
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

  // ---- meal favorites (quick add) ----

  /// Which account's favorites to load — pushed in via the proxy provider.
  String _profileId = 'local';

  void syncProfileId(String id) {
    if (id == _profileId) return;
    _profileId = id;
    loadFavorites();
  }

  List<MealFavorite> _favorites = [];
  List<MealFavorite> get favorites => _favorites;

  Future<void> loadFavorites() async {
    try {
      _favorites = await _repo.getFavorites(_profileId);
    } catch (e) {
      if (kDebugMode) debugPrint('loadFavorites failed: $e');
    }
    notifyListeners();
  }

  Future<void> addFavorite({
    required String name,
    String description = '',
    MealType mealType = MealType.snack,
  }) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return;
    await _repo.insertFavorite(MealFavorite(
      profileId: _profileId,
      name: trimmed,
      description: description.trim(),
      mealType: mealType,
      createdAt: DateTime.now().toIso8601String(),
    ));
    await loadFavorites();
  }

  /// Save an already-logged meal as a reusable favorite (star button).
  Future<void> favoriteFromMeal(MealEntry meal) async {
    await _repo.insertFavorite(MealFavorite(
      profileId: _profileId,
      name: meal.foodDescription.trim(),
      mealType: meal.mealType,
      createdAt: DateTime.now().toIso8601String(),
    ));
    await loadFavorites();
  }

  Future<void> updateFavorite(MealFavorite favorite) async {
    await _repo.updateFavorite(favorite);
    await loadFavorites();
  }

  Future<void> deleteFavorite(int id) async {
    await _repo.deleteFavorite(id);
    await loadFavorites();
  }

  /// One-tap log: writes the favorite as today's meal and bumps its use count.
  Future<void> logFavorite(MealFavorite favorite) async {
    final now = DateTime.now();
    await _repo.insertMeal(MealEntry(
      date: dateKey(now),
      mealType: favorite.mealType,
      foodDescription: favorite.loggedDescription,
      timestamp: now.toIso8601String(),
    ));
    if (favorite.id != null) await _repo.bumpFavoriteUse(favorite.id!);
    await loadFavorites();
    await loadToday();
  }

  /// True if a meal with this description is already a favorite (drives the
  /// filled/outline star on logged meals).
  bool isFavorite(String description) {
    final d = description.trim().toLowerCase();
    return _favorites.any((f) => f.loggedDescription.toLowerCase() == d ||
        f.name.toLowerCase() == d);
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
      final result = await _ai.getSuggestion(summary, pantry, _goals);
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

  /// Past AI suggestions, newest first — for the suggestion history screen.
  Future<List<SuggestionEntry>> suggestionHistory() => _repo.getSuggestions();

  // ---- progress dashboard ----

  /// One shot of everything the Progress screen charts + streaks need.
  Future<ProgressData> progressData() async {
    return ProgressData(
      weight: await _repo.getRecentWeight(days: 30),
      steps: await _repo.getRecentSteps(days: 30),
      sleep: await _repo.getRecentSleep(days: 7),
      mealCountsByDay: await _repo.mealCountsByDay(days: 7),
      mealLoggedDates: await _repo.mealLoggedDates(),
      goals: _goals,
    );
  }
}

/// Immutable bundle for the Progress screen.
class ProgressData {
  ProgressData({
    required this.weight,
    required this.steps,
    required this.sleep,
    required this.mealCountsByDay,
    required this.mealLoggedDates,
    required this.goals,
  });

  final List<WeightEntry> weight;
  final List<StepsEntry> steps;
  final List<SleepEntry> sleep;
  final Map<String, int> mealCountsByDay;
  final List<String> mealLoggedDates;
  final HealthGoals goals;

  bool get isEmpty =>
      weight.isEmpty &&
      steps.isEmpty &&
      sleep.isEmpty &&
      mealCountsByDay.isEmpty;
}
