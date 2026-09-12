import '../models/models.dart';

/// Loose text matching for meal templates — "rice and dal" should match
/// "Rice + dal + egg" without an exact string comparison. Pure, no ML.
class TemplateMatcher {
  const TemplateMatcher._();

  static const _stopwords = {
    'and', 'with', 'the', 'a', 'an', 'for', 'of', 'plus', 'some', 'my'
  };

  static Set<String> _tokens(String s) => s
      .toLowerCase()
      .split(RegExp(r'[^a-z0-9]+'))
      .where((w) => w.isNotEmpty && !_stopwords.contains(w))
      .toSet();

  /// Jaccard similarity (0..1) of the two descriptions' significant words.
  static double similarity(String a, String b) {
    final ta = _tokens(a);
    final tb = _tokens(b);
    if (ta.isEmpty || tb.isEmpty) return 0;
    final intersection = ta.intersection(tb).length;
    final union = ta.union(tb).length;
    return union == 0 ? 0 : intersection / union;
  }

  /// True when the two descriptions are "close enough" to count as the same
  /// meal for routine-matching purposes.
  static bool matches(String a, String b, {double threshold = 0.34}) =>
      similarity(a, b) >= threshold;

  /// Today's day type for matching against [MealTemplate.dayType].
  static DayType todayType([DateTime? now]) {
    final weekday = (now ?? DateTime.now()).weekday;
    return (weekday == DateTime.saturday || weekday == DateTime.sunday)
        ? DayType.weekend
        : DayType.weekday;
  }

  /// The best template for [slot] today, or null if none applies.
  static MealTemplate? bestFor(
    List<MealTemplate> templates,
    MealType slot, {
    DateTime? now,
  }) {
    final today = todayType(now);
    for (final t in templates) {
      if (t.mealSlot != slot) continue;
      if (t.dayType != DayType.everyday && t.dayType != today) continue;
      return t;
    }
    return null;
  }
}
