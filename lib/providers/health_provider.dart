import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../database/health_repository.dart';
import '../database/sync_service.dart';
import '../models/models.dart';
import '../models/user_profile.dart';
import '../screens/pantry_screen.dart';
import '../services/gemini_service.dart';
import '../services/health_steps_service.dart';
import '../services/notification_service.dart';
import '../services/suggestion_cache_service.dart';
import '../services/template_matcher.dart';
import '../services/toast_center.dart';

enum SuggestionStatus { idle, loading, success, error }

class HealthProvider extends ChangeNotifier {
  HealthProvider({
    HealthRepository? repo,
    GeminiService? ai,
    HealthStepsService? healthSteps,
    SyncService? sync,
    SuggestionCacheService? suggestionCache,
  })  : _sync = sync,
        _repo = repo ?? HealthRepository(sync: sync),
        _ai = ai ?? GeminiService(),
        _healthSteps = healthSteps ?? HealthStepsService() {
    _cache = suggestionCache ??
        SuggestionCacheService(repo: _repo, ai: _ai);
  }

  final HealthRepository _repo;
  final GeminiService _ai;
  final HealthStepsService _healthSteps;
  final SyncService? _sync;
  late final SuggestionCacheService _cache;

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

  /// The cached row backing [suggestionText] — null until the first
  /// suggestion of the day exists. Home reads this for its preview card and
  /// to decide the FAB's label; the Suggestion screen reads it for the
  /// "Suggested at …" timestamp.
  SuggestionEntry? _todaySuggestion;
  SuggestionEntry? get todaySuggestion => _todaySuggestion;
  bool get hasTodaySuggestion => _todaySuggestion != null;

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

  /// [offerRoutinePrompt] is false when the meal already came from a
  /// favorite or a template — no point suggesting "save as routine?" for a
  /// meal that already is one.
  Future<void> addMeal(
    MealType type,
    String description, {
    bool offerRoutinePrompt = true,
  }) async {
    final now = DateTime.now();
    final desc = description.trim();
    await _repo.insertMeal(MealEntry(
      date: dateKey(now),
      mealType: type,
      foodDescription: desc,
      timestamp: now.toIso8601String(),
    ));
    await loadToday();
    // Never blocks the save above: a slow or failed Gemini call just means no
    // pantry update happens this time.
    unawaited(_autoDeductPantry(desc));
    if (offerRoutinePrompt) unawaited(_maybeOfferSaveAsRoutine(type, desc));
  }

  /// Asks Gemini which pantry items this meal likely used up and marks them
  /// low. Best-effort and silent on any failure — logging the meal must never
  /// depend on this succeeding.
  Future<void> _autoDeductPantry(String foodDescription) async {
    try {
      final pantry = await _repo.getAllPantryItems();
      if (pantry.isEmpty) return;
      final names = await _ai.suggestPantryDeductions(foodDescription, pantry);
      if (names.isEmpty) return;

      final toMark = pantry.where((item) =>
          !item.isLow &&
          names.any((n) => n.toLowerCase() == item.itemName.toLowerCase()));
      var count = 0;
      for (final item in toMark) {
        await _repo.updatePantryItem(item.copyWith(isLow: true));
        count++;
      }
      if (count == 0) return;
      await loadPantry();
      ToastCenter.showWithView(
        'Pantry updated — $count item${count == 1 ? '' : 's'} marked low',
        (_) => const PantryScreen(),
      );
    } catch (e) {
      if (kDebugMode) debugPrint('auto-deduct failed: $e');
    }
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
    loadTemplates();
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
    if (favorite.id != null) {
      await _repo.bumpFavoriteUse(favorite.id!);
      unawaited(_maybeOfferSmartRoutine(favorite));
    }
    await loadFavorites();
    await loadToday();
    unawaited(_autoDeductPantry(favorite.loggedDescription));
  }

  // ---- meal templates (recurring meals) ----

  List<MealTemplate> _templates = [];
  List<MealTemplate> get templates => _templates;

  Future<void> loadTemplates() async {
    try {
      _templates = await _repo.getMealTemplates(_profileId);
    } catch (e) {
      if (kDebugMode) debugPrint('loadTemplates failed: $e');
    }
    notifyListeners();
  }

  Future<void> addTemplate({
    required DayType dayType,
    required MealType mealSlot,
    required String description,
  }) async {
    final trimmed = description.trim();
    if (trimmed.isEmpty) return;
    await _repo.insertMealTemplate(MealTemplate(
      profileId: _profileId,
      dayType: dayType,
      mealSlot: mealSlot,
      foodDescription: trimmed,
      createdAt: DateTime.now().toIso8601String(),
    ));
    await loadTemplates();
  }

  Future<void> deleteTemplate(int id) async {
    await _repo.deleteMealTemplate(id);
    await loadTemplates();
  }

  /// Logs a template's meal in one tap, then quiets today's banner for that
  /// slot (whether it was "Yes" or dismissed — either way today is settled).
  Future<void> logTemplateMeal(MealTemplate template) async {
    await addMeal(template.mealSlot, template.foodDescription,
        offerRoutinePrompt: false);
    dismissRoutineSuggestion(template.mealSlot);
  }

  final _dismissedRoutineSlots = <String>{};

  String _routineDismissKey(MealType slot) =>
      '${dateKey(DateTime.now())}_${slot.name}';

  void dismissRoutineSuggestion(MealType slot) {
    _dismissedRoutineSlots.add(_routineDismissKey(slot));
    notifyListeners();
  }

  /// The routine banner to show on Home for [slot], or null. Never automatic
  /// — always requires the "Log it?" tap.
  MealTemplate? routineSuggestionFor(MealType slot) {
    if (_dismissedRoutineSlots.contains(_routineDismissKey(slot))) return null;
    final alreadyLogged =
        _today?.meals.any((m) => m.mealType == slot) ?? false;
    if (alreadyLogged) return null;
    return TemplateMatcher.bestFor(_templates, slot);
  }

  // ---- "save as routine?" prompts ----

  TemplateSuggestion? _pendingTemplateSuggestion;
  TemplateSuggestion? get pendingTemplateSuggestion => _pendingTemplateSuggestion;

  void clearTemplateSuggestion() {
    if (_pendingTemplateSuggestion == null) return;
    _pendingTemplateSuggestion = null;
    notifyListeners();
  }

  /// Generic, one-time-ever nudge after logging any meal manually or by
  /// voice — never shown twice for the same (slot, description) pair, and
  /// never for a meal already logged via a favorite or an existing template.
  Future<void> _maybeOfferSaveAsRoutine(MealType type, String description) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final key =
          'tmpl_prompted_${_profileId}_${type.name}_${description.trim().toLowerCase()}';
      if (prefs.getBool(key) == true) return;
      await prefs.setBool(key, true);
      _pendingTemplateSuggestion = TemplateSuggestion(
        mealType: type,
        description: description,
        message: 'Save this as a routine meal?',
      );
      notifyListeners();
    } catch (e) {
      if (kDebugMode) debugPrint('save-as-routine prompt failed: $e');
    }
  }

  /// Stronger, data-backed nudge once a favorite has been logged 3+ times in
  /// the same slot (use_count from meal_favorites, per the spec) — shown once
  /// per favorite.
  Future<void> _maybeOfferSmartRoutine(MealFavorite favorite) async {
    try {
      final newCount = favorite.useCount + 1; // bumpFavoriteUse just ran
      if (newCount < 3) return;
      final prefs = await SharedPreferences.getInstance();
      final key = 'tmpl_smart_${_profileId}_${favorite.id}';
      if (prefs.getBool(key) == true) return;
      await prefs.setBool(key, true);
      _pendingTemplateSuggestion = TemplateSuggestion(
        mealType: favorite.mealType,
        description: favorite.loggedDescription,
        message: 'You often eat ${favorite.name} for ${favorite.mealType.name} '
            '— want to add it as your routine?',
      );
      notifyListeners();
    } catch (e) {
      if (kDebugMode) debugPrint('smart-routine prompt failed: $e');
    }
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

  /// Called once on app start (after [loadToday]). Shows today's cached
  /// suggestion instantly if one exists; otherwise generates one silently —
  /// no loading spinner surfaces for this, Home's preview card just shows its
  /// placeholder until it resolves. A failure here (offline, no key) is
  /// swallowed: the user simply sees "no suggestion yet" and can tap to try.
  Future<void> initTodaySuggestion() async {
    try {
      final summary = _today ?? await _repo.getDailySummary();
      final pantry = await _repo.getAllPantryItems();
      final entry = await _cache.ensureToday(summary, pantry, _goals);
      if (entry == null) return;
      _todaySuggestion = entry;
      _suggestionText = entry.response;
      _suggestionStatus = SuggestionStatus.success;
      notifyListeners();
    } catch (e) {
      if (kDebugMode) debugPrint('initTodaySuggestion failed: $e');
    }
  }

  /// First suggestion of the day. Kept as a distinct name from
  /// [regenerateSuggestion] for callers' clarity even though the underlying
  /// operation — generate, cache, become "today's" — is identical; by the
  /// time either the Home FAB or the Suggestion screen's button can be
  /// showing "get new", a suggestion already exists, so there's no case
  /// where the wrong one gets called.
  Future<void> getSuggestion() => _generateAndCache();

  /// Forces a fresh suggestion, replacing the cached one for today (a new
  /// row is inserted; [HealthRepository.getTodaySuggestion] always reads the
  /// newest, so the old row survives in suggestion_history for the history
  /// screen). Ad-gating and the upgrade nudge live in the UI layer — see
  /// `regenerateSuggestionFlow` in suggestion_screen.dart.
  Future<void> regenerateSuggestion() => _generateAndCache();

  Future<void> _generateAndCache() async {
    _suggestionStatus = SuggestionStatus.loading;
    _suggestionError = null;
    notifyListeners();

    try {
      final summary = _today ?? await _repo.getDailySummary();
      final pantry = await _repo.getAllPantryItems();
      final entry = await _cache.regenerate(summary, pantry, _goals);
      _todaySuggestion = entry;
      _suggestionText = entry.response;
      _suggestionStatus = SuggestionStatus.success;
    } catch (e) {
      _suggestionStatus = SuggestionStatus.error;
      _suggestionError =
          e is AiException ? e.message : "Couldn't get suggestion, try again.";
      if (kDebugMode) debugPrint('generate suggestion failed: $e');
    }
    notifyListeners();
  }

  /// Past AI suggestions, newest first — for the suggestion history screen.
  Future<List<SuggestionEntry>> suggestionHistory() => _repo.getSuggestions();

  /// Saves the first-run Quick Start instant suggestion directly into history
  /// and marks it as today's suggestion.
  Future<void> seedInitialSuggestion(String suggestionText) async {
    final entry = SuggestionEntry(
      date: dateKey(DateTime.now()),
      prompt: 'Quick Start instant suggestion',
      response: suggestionText,
      timestamp: DateTime.now().toIso8601String(),
    );
    await _repo.insertSuggestion(entry);
    _todaySuggestion = entry;
    _suggestionText = suggestionText;
    _suggestionStatus = SuggestionStatus.success;
    notifyListeners();
  }

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

/// A pending "save this as a routine?" prompt — see
/// [HealthProvider.pendingTemplateSuggestion].
class TemplateSuggestion {
  TemplateSuggestion({
    required this.mealType,
    required this.description,
    required this.message,
  });

  final MealType mealType;
  final String description;
  final String message;
}
