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
      DailySummary s, List<PantryItem> pantry, HealthGoals goals) {
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

    return '''
Here's what I have in stock: $stock.

Here's what I ate/did today:
- Meals: $meals
- Workout: $workout
- Sleep: $sleep
- Steps: $steps

My goal is: ${goals.promptText}

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
    HealthGoals goals,
  ) async {
    final prompt = buildPrompt(summary, pantry, goals);
    if (!hasKey) {
      throw AiException(
          'No API key configured. Pass --dart-define=GEMINI_API_KEY=… when running.');
    }

    try {
      final text = await _callGemini(prompt);
      return SuggestionResult(prompt: prompt, text: text);
    } on AiException {
      rethrow;
    } catch (e) {
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
}
