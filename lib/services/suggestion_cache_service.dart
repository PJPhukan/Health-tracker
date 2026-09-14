import '../database/health_repository.dart';
import '../models/models.dart';
import '../models/user_profile.dart';
import 'gemini_service.dart';

/// Owns "what is today's suggestion" so the Home and Suggestion screens don't
/// each re-implement the cache-or-generate decision.
///
/// A suggestion is never generated more than once silently per day — once
/// [ensureToday] has produced one, every later call just returns the cached
/// row until [regenerate] is called explicitly (the "Get New Suggestion 🔄"
/// button). Regenerating inserts a new `suggestion_history` row rather than
/// overwriting the old one, so the full history stays intact for the past-
/// suggestions screen; [HealthRepository.getTodaySuggestion] always reads the
/// newest row for the day, so the UI transparently sees the replacement.
class SuggestionCacheService {
  SuggestionCacheService({required HealthRepository repo, required GeminiService ai})
      : _repo = repo,
        _ai = ai;

  final HealthRepository _repo;
  final GeminiService _ai;

  /// Today's cached suggestion, if one has already been generated.
  Future<SuggestionEntry?> getTodaySuggestion() => _repo.getTodaySuggestion();

  /// Returns today's cached suggestion, generating and persisting one first
  /// if none exists yet (first open of a new day). Returns null only if
  /// there's no cache AND generation failed (offline, no key, etc.) — callers
  /// should treat that as "nothing to show yet", not an error to surface.
  Future<SuggestionEntry?> ensureToday(
    DailySummary summary,
    List<PantryItem> pantry,
    HealthGoals goals,
  ) async {
    final cached = await _repo.getTodaySuggestion();
    if (cached != null) return cached;
    try {
      return await regenerate(summary, pantry, goals);
    } catch (_) {
      return null;
    }
  }

  /// Forces a brand-new suggestion, regardless of what's cached. Throws
  /// [AiException] on failure — the caller (HealthProvider) turns that into
  /// the error state the UI already knows how to show.
  Future<SuggestionEntry> regenerate(
    DailySummary summary,
    List<PantryItem> pantry,
    HealthGoals goals,
  ) async {
    final missingCount =
        await _repo.getNegativeFeedbackCountForReason('Missing ingredients');
    final result = await _ai.getSuggestion(
      summary,
      pantry,
      goals,
      missingIngredientsWarning: missingCount > 2,
    );
    final entry = SuggestionEntry(
      date: summary.date,
      prompt: result.prompt,
      response: result.text,
      timestamp: DateTime.now().toIso8601String(),
    );
    await _repo.insertSuggestion(entry);
    return entry;
  }
}
