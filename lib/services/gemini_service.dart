import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/models.dart';
import '../models/user_profile.dart';

class AiException implements Exception {
  final String message;
  AiException(this.message);
  @override
  String toString() => message;
}

/// Result of an AI suggestion request.
class SuggestionResult {
  final String prompt;
  final String text;
  SuggestionResult({required this.prompt, required this.text});
}

/// A voice transcript parsed into structured meal-log fields (v4 stage 1).
class VoiceMealParse {
  final MealType mealType;
  final String foodDescription;
  final List<String> items;
  VoiceMealParse({
    required this.mealType,
    required this.foodDescription,
    required this.items,
  });
}

/// Calls Google Gemini (free tier) via REST. No fallback provider — if the
/// request fails the caller gets an [AiException] and the UI shows a retry.
class GeminiService {
  GeminiService({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  // Provide the key at build time:
  //   flutter run --dart-define=GEMINI_API_KEY=xxx
  static const _geminiKey = String.fromEnvironment('GEMINI_API_KEY');
  static const _geminiModel = 'gemini-3.1-flash-lite';

  bool get hasKey => _geminiKey.isNotEmpty;

  String buildPrompt(
      DailySummary s, List<PantryItem> pantry, HealthGoals goals,
      {bool missingIngredientsWarning = false}) {
    final stock = pantry.isEmpty
        ? 'nothing recorded'
        : pantry.map((p) {
            final qty = p.quantity.trim().isEmpty ? '' : ' (${p.quantity})';
            final low = p.isLow ? ' [running low]' : '';
            return '${p.itemName}$qty$low';
          }).join(', ');
    final meals = s.meals.isEmpty
        ? 'nothing logged yet'
        : s.meals
            .map((m) => '${m.mealType.name}: ${m.foodDescription}')
            .join('; ');
    final workout = s.workouts.isEmpty
        ? 'no workout'
        : s.workouts
            .map((w) => '${w.exerciseType} for ${w.durationMinutes} min')
            .join('; ');
    final sleep = s.sleep == null
        ? 'not logged'
        : '${s.sleepHours.toStringAsFixed(1)} hours';
    final steps = s.steps == null ? 'not logged' : '${s.stepCount} steps';

    final feedbackRule = missingIngredientsWarning
        ? '\nPreviously the user said suggestions had missing ingredients — make sure every item is in their pantry list.\n'
        : '';

    return '''
Here's what I have in stock: $stock.

Here's what I ate/did today:
- Meals: $meals
- Workout: $workout
- Sleep: $sleep
- Steps: $steps

My goal is: ${goals.promptText}
$feedbackRule
Based on what I have in stock, suggest what I should eat next (specify meal:
breakfast/lunch/dinner). Include approximate calories and protein and one sentence
of reasoning.
If a balanced meal isn't possible with current stock, tell me what's missing and
should be bought today — put that on its own final line starting exactly with
"Buy today:" followed by a comma-separated list.
Keep the suggestion practical and use only realistic combinations from what's
available. Keep it under 130 words.
''';
  }

  Future<SuggestionResult> getSuggestion(
    DailySummary summary,
    List<PantryItem> pantry,
    HealthGoals goals, {
    bool missingIngredientsWarning = false,
  }) async {
    final prompt = buildPrompt(summary, pantry, goals,
        missingIngredientsWarning: missingIngredientsWarning);
    if (!hasKey) {
      throw AiException(
          'No API key configured. Pass --dart-define=GEMINI_API_KEY=… when running.');
    }

    try {
      final text = await _callGemini(prompt);
      return SuggestionResult(prompt: prompt, text: text);
    } on TimeoutException {
      throw AiException("That took longer than expected. Try again?");
    } on AiException {
      rethrow;
    } catch (e) {
      if (e is TimeoutException) {
        throw AiException("That took longer than expected. Try again?");
      }
      // Network error, timeout, bad JSON, etc. — no fallback, surface a
      // clean error so the UI can offer a retry.
      throw AiException("Couldn't get suggestion, try again.");
    }
  }

  Future<String> _callGemini(String prompt) async {
    final uri = Uri.parse(
        'https://generativelanguage.googleapis.com/v1beta/models/$_geminiModel:generateContent?key=$_geminiKey');
    final resp = await _client
        .post(uri,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'contents': [
                {
                  'parts': [
                    {'text': prompt}
                  ]
                }
              ]
            }))
        .timeout(const Duration(seconds: 30));

    if (resp.statusCode != 200) {
      throw AiException('Gemini error ${resp.statusCode}');
    }
    final body = jsonDecode(resp.body) as Map<String, Object?>;
    final candidates = body['candidates'] as List?;
    if (candidates == null || candidates.isEmpty) {
      throw AiException('Gemini returned no candidates');
    }
    final content = (candidates.first as Map)['content'] as Map?;
    final parts = content?['parts'] as List?;
    final text = parts
        ?.map((p) => (p as Map)['text'] as String? ?? '')
        .join('\n')
        .trim();
    if (text == null || text.isEmpty) {
      throw AiException('Gemini returned an empty response');
    }
    return text;
  }

  /// Instant meal suggestion for the 60-second first-run experience.
  /// Calls Gemini using the exact prompt requested, with a graceful fallback
  /// if offline or without an API key.
  Future<String> getQuickStartSuggestion({
    required List<String> ingredients,
    required String goal,
    required String mealTime,
  }) async {
    final prompt = '''
I have these ingredients: ${ingredients.join(', ')}.
My goal is: $goal.
Suggest ONE practical meal I can make right now for $mealTime.
Keep it under 100 words, practical and direct. Start with the meal name, then brief instructions.
''';

    if (hasKey) {
      try {
        return await _callGemini(prompt);
      } catch (e) {
        // Fall back to offline generator below if network or quota fails
      }
    }

    return _fallbackQuickSuggestion(ingredients, goal, mealTime);
  }

  String _fallbackQuickSuggestion(
    List<String> ingredients,
    String goal,
    String mealTime,
  ) {
    final lower = ingredients.map((e) => e.toLowerCase()).toSet();
    if (lower.contains('eggs') || lower.contains('bread')) {
      return 'Savory Scrambled Eggs on Toast\n\n'
          'Whisk 2-3 eggs with salt and pepper. Sauté diced onion and tomato '
          'in a little ghee or oil until tender, then pour in eggs and scramble gently. '
          'Serve over warm toasted bread for a quick, protein-rich $mealTime meal '
          'perfect for your goal to $goal.';
    }
    if (lower.contains('rice') || lower.contains('dal')) {
      return 'Comforting One-Pot Dal Khichdi\n\n'
          'Rinse dal and rice together. Sauté diced onion, tomato, and spices in ghee, '
          'then add rice, dal, and water (1:3 ratio). Simmer until creamy and soft. '
          'A balanced, wholesome $mealTime bowl supporting your journey to $goal.';
    }
    if (lower.contains('chicken')) {
      return 'Quick Skillet Spiced Chicken\n\n'
          'Dice chicken into bite-sized pieces. Sear in a hot pan with onion, tomato, '
          'and your favorite seasoning until cooked through and golden. High in lean protein '
          'to power your progress toward $goal.';
    }
    final firstTwo = ingredients.take(2).join(' and ');
    return 'Nourishing $firstTwo Bowl\n\n'
        'Combine $firstTwo with available kitchen staples. Lightly sauté and season '
        'to taste for a satisfying, nutrient-dense $mealTime dish crafted to support '
        'your goal to $goal.';
  }

  // ── v4: voice logging + pantry auto-deduct ────────────────────────────────
  //
  // Both of these are "secondary" AI calls: a failure must never block the
  // action the user actually asked for (saving a meal). Neither checks
  // [hasKey] up front — they just attempt the call and turn any failure
  // (missing key, network, timeout, malformed JSON) into a null/empty result
  // for the caller to fall back on silently.

  static String _timeOfDayHint() {
    final h = DateTime.now().hour;
    if (h < 11) return 'morning (likely breakfast)';
    if (h < 16) return 'afternoon (likely lunch)';
    if (h < 21) return 'evening (likely dinner)';
    return 'night (likely a snack)';
  }

  /// Turns a raw voice transcript into structured meal fields. Returns null on
  /// any failure — the caller falls back to showing the raw transcript.
  Future<VoiceMealParse?> parseVoiceMeal(String transcript) async {
    final input = transcript.trim();
    if (input.isEmpty) return null;
    final prompt = '''
Parse this voice input into a structured meal entry. Return ONLY valid JSON, no explanation:
{
  "mealType": "breakfast|lunch|dinner|snack",
  "foodDescription": "clean description of what was eaten",
  "items": ["item1", "item2"]
}
Voice input: "$input"
If meal type isn't clear from context, infer from current time of day: ${_timeOfDayHint()}.
''';
    try {
      final raw = await _callGemini(prompt);
      final map = jsonDecode(extractJsonObject(raw)) as Map<String, Object?>;
      final description = (map['foodDescription'] as String?)?.trim();
      if (description == null || description.isEmpty) return null;
      final items = (map['items'] as List?)
              ?.map((e) => e.toString())
              .where((e) => e.trim().isNotEmpty)
              .toList() ??
          const [];
      return VoiceMealParse(
        mealType: mealTypeFromString((map['mealType'] as String?) ?? 'snack'),
        foodDescription: description,
        items: items,
      );
    } catch (e) {
      return null;
    }
  }

  /// Asks which of the given [pantry] items were likely used up by
  /// [foodDescription]. Returns the (exact, pantry-supplied) item names to
  /// mark low — an empty list on any failure, network or parse.
  Future<List<String>> suggestPantryDeductions(
    String foodDescription,
    List<PantryItem> pantry,
  ) async {
    if (pantry.isEmpty || foodDescription.trim().isEmpty) return const [];
    final stockList = pantry.map((p) => p.itemName).join(', ');
    final prompt = '''
Given this meal: "${foodDescription.trim()}"
And this pantry: [$stockList]
Return ONLY valid JSON — no explanation:
{
  "deductions": [
    {"itemName": "exact name from pantry list", "deplete": true|false}
  ]
}
deplete = true means this ingredient was likely used and should be marked as low/depleted.
Only include items from the provided pantry list. Don't invent new items.
''';
    try {
      final raw = await _callGemini(prompt);
      final map = jsonDecode(extractJsonObject(raw)) as Map<String, Object?>;
      final deductions = map['deductions'] as List?;
      if (deductions == null) return const [];
      final pantryNames = {for (final p in pantry) p.itemName.toLowerCase()};
      return deductions
          .whereType<Map>()
          .where((d) => d['deplete'] == true)
          .map((d) => (d['itemName'] as String?)?.trim() ?? '')
          .where((name) =>
              name.isNotEmpty && pantryNames.contains(name.toLowerCase()))
          .toList();
    } catch (e) {
      return const [];
    }
  }

  /// Pulls the first top-level `{...}` object out of a Gemini response,
  /// tolerating a ```json fenced block or stray prose around it.
  static String extractJsonObject(String raw) {
    var s = raw.trim();
    final fence = RegExp(r'```(?:json)?\s*([\s\S]*?)```');
    final fenced = fence.firstMatch(s);
    if (fenced != null) s = fenced.group(1)!.trim();
    final start = s.indexOf('{');
    final end = s.lastIndexOf('}');
    if (start == -1 || end == -1 || end < start) {
      throw const FormatException('No JSON object found in response');
    }
    return s.substring(start, end + 1);
  }
}
