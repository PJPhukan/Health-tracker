import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/user_profile.dart';

/// Manages the first-run experience, guest sessions, and soft-gate suggestion limits.
class GuestService extends ChangeNotifier {
  GuestService._();
  static final GuestService instance = GuestService._();

  static const _keyHasSeenQuickStart = 'has_seen_quick_start';
  static const _keyIsGuest = 'is_guest_session';
  static const _keyGuestSuggestions = 'guest_suggestions_count';
  static const _keyPendingProfilePrompt = 'pending_profile_prompt';

  bool _initialized = false;
  bool get isInitialized => _initialized;

  bool _hasSeenQuickStart = false;
  bool get hasSeenQuickStart => _hasSeenQuickStart;

  bool _isGuest = false;
  bool get isGuest => _isGuest;

  int _guestSuggestionsCount = 0;
  int get guestSuggestionsCount => _guestSuggestionsCount;

  bool _pendingProfilePrompt = false;
  bool get pendingProfilePrompt => _pendingProfilePrompt;

  // Temporary holding for quick-start data before conversion/saving
  List<String> _quickStartIngredients = [];
  List<String> get quickStartIngredients => List.unmodifiable(_quickStartIngredients);

  PrimaryGoal? _quickStartGoal;
  PrimaryGoal? get quickStartGoal => _quickStartGoal;

  String? _quickStartSuggestion;
  String? get quickStartSuggestion => _quickStartSuggestion;

  Future<void> init() async {
    if (_initialized) return;
    final prefs = await SharedPreferences.getInstance();
    _hasSeenQuickStart = prefs.getBool(_keyHasSeenQuickStart) ?? false;
    _isGuest = prefs.getBool(_keyIsGuest) ?? false;
    _guestSuggestionsCount = prefs.getInt(_keyGuestSuggestions) ?? 0;
    _pendingProfilePrompt = prefs.getBool(_keyPendingProfilePrompt) ?? false;
    _initialized = true;
    notifyListeners();
  }

  @visibleForTesting
  void resetForTesting() {
    _initialized = false;
    _hasSeenQuickStart = false;
    _isGuest = false;
    _guestSuggestionsCount = 0;
    _pendingProfilePrompt = false;
    _quickStartIngredients = [];
    _quickStartGoal = null;
    _quickStartSuggestion = null;
  }

  void cacheQuickStartData({
    required List<String> ingredients,
    required PrimaryGoal goal,
    required String suggestion,
  }) {
    _quickStartIngredients = List.from(ingredients);
    _quickStartGoal = goal;
    _quickStartSuggestion = suggestion;
  }

  Future<void> setHasSeenQuickStart(bool val) async {
    _hasSeenQuickStart = val;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyHasSeenQuickStart, val);
    notifyListeners();
  }

  Future<void> startGuestMode({
    required List<String> ingredients,
    required PrimaryGoal goal,
    required String suggestion,
  }) async {
    cacheQuickStartData(
      ingredients: ingredients,
      goal: goal,
      suggestion: suggestion,
    );
    _hasSeenQuickStart = true;
    _isGuest = true;
    _guestSuggestionsCount = 1; // Quick-start instant suggestion counts as #1
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyHasSeenQuickStart, true);
    await prefs.setBool(_keyIsGuest, true);
    await prefs.setInt(_keyGuestSuggestions, _guestSuggestionsCount);
    notifyListeners();
  }

  bool get canRequestSuggestion {
    if (!_isGuest) return true;
    return _guestSuggestionsCount < 3;
  }

  Future<void> recordSuggestionUsed() async {
    if (!_isGuest) return;
    _guestSuggestionsCount++;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_keyGuestSuggestions, _guestSuggestionsCount);
    notifyListeners();
  }

  Future<void> setPendingProfilePrompt(bool val) async {
    _pendingProfilePrompt = val;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyPendingProfilePrompt, val);
    notifyListeners();
  }

  Future<void> markGuestConverted() async {
    _isGuest = false;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyIsGuest, false);
    notifyListeners();
  }

  /// Sensible default goal configuration mapped from the quick-start goal selection.
  /// Gain: +400 kcal surplus
  /// Lose: -400 kcal deficit
  /// Muscle: high protein (2.0g/kg, +300 kcal)
  /// Healthy: maintenance (0 kcal delta, 1.6g/kg)
  static HealthGoals defaultGoalsFor(PrimaryGoal goal) {
    switch (goal) {
      case PrimaryGoal.gainWeight:
        return const HealthGoals(
          calories: 2400,
          proteinGrams: 126,
          stepsMin: 7000,
          stepsMax: 9000,
          sleepMinHours: 7,
          sleepMaxHours: 8,
          objective: 'gain weight',
        );
      case PrimaryGoal.loseWeight:
        return const HealthGoals(
          calories: 1600,
          proteinGrams: 154,
          stepsMin: 8000,
          stepsMax: 10000,
          sleepMinHours: 7,
          sleepMaxHours: 8,
          objective: 'lose weight',
        );
      case PrimaryGoal.buildMuscle:
        return const HealthGoals(
          calories: 2300,
          proteinGrams: 140,
          stepsMin: 7000,
          stepsMax: 9000,
          sleepMinHours: 7.5,
          sleepMaxHours: 9,
          objective: 'build muscle',
        );
      case PrimaryGoal.maintain:
        return const HealthGoals(
          calories: 2000,
          proteinGrams: 112,
          stepsMin: 7000,
          stepsMax: 9000,
          sleepMinHours: 7,
          sleepMaxHours: 8,
          objective: 'stay healthy',
        );
    }
  }
}
