import 'package:flutter_test/flutter_test.dart';
import 'package:health_tracker/models/models.dart';
import 'package:health_tracker/services/template_matcher.dart';

MealTemplate _template({
  required DayType dayType,
  required MealType slot,
  String description = 'Rice + dal + egg',
}) =>
    MealTemplate(
      profileId: 'local',
      dayType: dayType,
      mealSlot: slot,
      foodDescription: description,
      createdAt: DateTime.now().toIso8601String(),
    );

void main() {
  group('TemplateMatcher.similarity / matches (loose text matching)', () {
    test('a partial, differently-ordered description still matches', () {
      expect(
          TemplateMatcher.matches('rice and dal', 'Rice + dal + egg'), isTrue);
    });

    test('completely unrelated meals do not match', () {
      expect(TemplateMatcher.matches('oatmeal and banana', 'Rice + dal + egg'),
          isFalse);
    });

    test('is case-insensitive and ignores punctuation', () {
      expect(TemplateMatcher.matches('RICE, DAL!!', 'rice + dal'), isTrue);
    });

    test('empty input never matches', () {
      expect(TemplateMatcher.matches('', 'Rice + dal + egg'), isFalse);
      expect(TemplateMatcher.similarity('', ''), 0);
    });

    test('an identical description is a perfect match', () {
      expect(TemplateMatcher.similarity('Rice and dal', 'Rice and dal'), 1.0);
    });
  });

  group('TemplateMatcher.todayType', () {
    test('a Saturday is a weekend', () {
      expect(TemplateMatcher.todayType(DateTime(2026, 9, 12)), // Saturday
          DayType.weekend);
    });

    test('a Wednesday is a weekday', () {
      expect(TemplateMatcher.todayType(DateTime(2026, 9, 9)), // Wednesday
          DayType.weekday);
    });
  });

  group('TemplateMatcher.bestFor (day-type matching)', () {
    final saturday = DateTime(2026, 9, 12);
    final wednesday = DateTime(2026, 9, 9);

    test('a weekday template only applies on a weekday', () {
      final templates = [_template(dayType: DayType.weekday, slot: MealType.breakfast)];
      expect(TemplateMatcher.bestFor(templates, MealType.breakfast, now: wednesday),
          isNotNull);
      expect(TemplateMatcher.bestFor(templates, MealType.breakfast, now: saturday),
          isNull);
    });

    test('a weekend template only applies on a weekend', () {
      final templates = [_template(dayType: DayType.weekend, slot: MealType.breakfast)];
      expect(TemplateMatcher.bestFor(templates, MealType.breakfast, now: saturday),
          isNotNull);
      expect(TemplateMatcher.bestFor(templates, MealType.breakfast, now: wednesday),
          isNull);
    });

    test('an "everyday" template applies on both', () {
      final templates = [_template(dayType: DayType.everyday, slot: MealType.dinner)];
      expect(TemplateMatcher.bestFor(templates, MealType.dinner, now: saturday),
          isNotNull);
      expect(TemplateMatcher.bestFor(templates, MealType.dinner, now: wednesday),
          isNotNull);
    });

    test('only the matching slot is returned, never a different one', () {
      final templates = [_template(dayType: DayType.everyday, slot: MealType.breakfast)];
      expect(TemplateMatcher.bestFor(templates, MealType.dinner, now: wednesday),
          isNull);
    });

    test('returns null when there are no templates at all', () {
      expect(TemplateMatcher.bestFor(const [], MealType.breakfast, now: wednesday),
          isNull);
    });

    test('the first matching template wins when there are several', () {
      final templates = [
        _template(
            dayType: DayType.weekday,
            slot: MealType.breakfast,
            description: 'Oats'),
        _template(
            dayType: DayType.everyday,
            slot: MealType.breakfast,
            description: 'Toast'),
      ];
      final match =
          TemplateMatcher.bestFor(templates, MealType.breakfast, now: wednesday);
      expect(match?.foodDescription, 'Oats');
    });
  });
}
