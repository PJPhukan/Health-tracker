import 'package:flutter/material.dart' show TimeOfDay;
import 'package:flutter_test/flutter_test.dart';
import 'package:health_tracker/services/notification_service.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

void main() {
  setUpAll(() {
    tzdata.initializeTimeZones();
    tz.setLocalLocation(tz.getLocation('Asia/Kolkata'));
  });

  group('NotificationService.slotsToSchedule (suppression)', () {
    test('schedules all three slots when nothing is done yet', () {
      final slots = NotificationService.slotsToSchedule(
          breakfastLogged: false, suggestionFetchedToday: false);
      expect(
          slots,
          containsAll([
            ReminderSlot.morning,
            ReminderSlot.lunch,
            ReminderSlot.evening,
          ]));
    });

    test('suppresses morning once breakfast is logged', () {
      final slots = NotificationService.slotsToSchedule(
          breakfastLogged: true, suggestionFetchedToday: false);
      expect(slots, isNot(contains(ReminderSlot.morning)));
      expect(slots, contains(ReminderSlot.lunch));
      expect(slots, contains(ReminderSlot.evening));
    });

    test('suppresses lunch once a suggestion was fetched today', () {
      final slots = NotificationService.slotsToSchedule(
          breakfastLogged: false, suggestionFetchedToday: true);
      expect(slots, isNot(contains(ReminderSlot.lunch)));
      expect(slots, contains(ReminderSlot.morning));
      expect(slots, contains(ReminderSlot.evening));
    });

    test('evening is never suppressed', () {
      final slots = NotificationService.slotsToSchedule(
          breakfastLogged: true, suggestionFetchedToday: true);
      expect(slots, [ReminderSlot.evening]);
    });
  });

  group('NotificationService.nextOccurrence', () {
    test('stays on the same day when the time is still ahead', () {
      final now = tz.TZDateTime(tz.local, 2026, 3, 10, 7, 0);
      final next =
          NotificationService.nextOccurrence(const TimeOfDay(hour: 8, minute: 0), now: now);
      expect(next.year, 2026);
      expect(next.month, 3);
      expect(next.day, 10);
      expect(next.hour, 8);
    });

    test('rolls over to tomorrow once the time has passed', () {
      final now = tz.TZDateTime(tz.local, 2026, 3, 10, 22, 0);
      final next = NotificationService.nextOccurrence(
          const TimeOfDay(hour: 21, minute: 0),
          now: now);
      expect(next.day, 11);
      expect(next.hour, 21);
    });

    test('an exact time-of-now match rolls to tomorrow, not a re-fire now',
        () {
      final now = tz.TZDateTime(tz.local, 2026, 3, 10, 8, 0);
      final next = NotificationService.nextOccurrence(
          const TimeOfDay(hour: 8, minute: 0),
          now: now);
      expect(next.day, 11);
    });

    test('rolls over the month/year boundary correctly', () {
      final now = tz.TZDateTime(tz.local, 2025, 12, 31, 22, 0);
      final next = NotificationService.nextOccurrence(
          const TimeOfDay(hour: 21, minute: 0),
          now: now);
      expect(next.year, 2026);
      expect(next.month, 1);
      expect(next.day, 1);
    });
  });

  group('NotificationPrefs', () {
    test('copyWith only overrides the given fields', () {
      const prefs = NotificationPrefs(
        enabled: true,
        morning: TimeOfDay(hour: 8, minute: 0),
        lunch: TimeOfDay(hour: 13, minute: 0),
        evening: TimeOfDay(hour: 21, minute: 0),
      );
      final updated = prefs.copyWith(enabled: false);
      expect(updated.enabled, isFalse);
      expect(updated.morning, prefs.morning);
      expect(updated.lunch, prefs.lunch);
      expect(updated.evening, prefs.evening);
    });

    test('forSlot returns the matching time', () {
      const prefs = NotificationPrefs(
        enabled: true,
        morning: TimeOfDay(hour: 7, minute: 30),
        lunch: TimeOfDay(hour: 12, minute: 45),
        evening: TimeOfDay(hour: 20, minute: 0),
      );
      expect(prefs.forSlot(ReminderSlot.morning), prefs.morning);
      expect(prefs.forSlot(ReminderSlot.lunch), prefs.lunch);
      expect(prefs.forSlot(ReminderSlot.evening), prefs.evening);
    });
  });
}
