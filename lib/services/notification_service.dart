import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' show TimeOfDay;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

/// Where a tapped notification should take the user.
enum NotificationDeepLink { mealLog, suggestion, progress }

/// The three daily reminder slots.
enum ReminderSlot { morning, lunch, evening }

extension on ReminderSlot {
  int get notificationId => switch (this) {
        ReminderSlot.morning => 1,
        ReminderSlot.lunch => 2,
        ReminderSlot.evening => 3,
      };

  String get payload => switch (this) {
        ReminderSlot.morning => 'meal_log',
        ReminderSlot.lunch => 'suggestion',
        ReminderSlot.evening => 'progress',
      };

  ({String title, String body}) get content => switch (this) {
        ReminderSlot.morning => (
            title: 'Good morning! 🌅',
            body: 'Log your breakfast to stay on track today.',
          ),
        ReminderSlot.lunch => (
            title: 'Lunchtime 🍽️',
            body: 'Tap to see what you can make from your pantry.',
          ),
        ReminderSlot.evening => (
            title: 'Evening check-in',
            body: 'How did today go? Take a look at your progress.',
          ),
      };
}

/// Daily reminder preferences, persisted to SharedPreferences.
class NotificationPrefs {
  const NotificationPrefs({
    required this.enabled,
    required this.morning,
    required this.lunch,
    required this.evening,
  });

  final bool enabled;
  final TimeOfDay morning;
  final TimeOfDay lunch;
  final TimeOfDay evening;

  static const defaultMorning = TimeOfDay(hour: 8, minute: 0);
  static const defaultLunch = TimeOfDay(hour: 13, minute: 0);
  static const defaultEvening = TimeOfDay(hour: 21, minute: 0);

  TimeOfDay forSlot(ReminderSlot slot) => switch (slot) {
        ReminderSlot.morning => morning,
        ReminderSlot.lunch => lunch,
        ReminderSlot.evening => evening,
      };

  NotificationPrefs copyWith({
    bool? enabled,
    TimeOfDay? morning,
    TimeOfDay? lunch,
    TimeOfDay? evening,
  }) =>
      NotificationPrefs(
        enabled: enabled ?? this.enabled,
        morning: morning ?? this.morning,
        lunch: lunch ?? this.lunch,
        evening: evening ?? this.evening,
      );
}

/// Schedules the three daily reminders, wires notification taps to a
/// deep-link target, and applies "don't nag me about what's already done"
/// suppression.
///
/// Real background scheduling across many days without ever opening the app
/// would need a periodic background task (e.g. WorkManager) — out of scope
/// here. Instead [rescheduleToday] is called on app start and every resume
/// (see `MainShell`), plus once at the next local midnight while the app
/// stays open in the foreground, which covers the stated "reschedule at
/// midnight or app resume" requirement without a new background dependency.
class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  final _plugin = FlutterLocalNotificationsPlugin();
  bool _initialized = false;

  /// Set when a notification is tapped (foreground or cold start). The UI
  /// consumes and clears this — see `MainShell`.
  final ValueNotifier<NotificationDeepLink?> deepLink = ValueNotifier(null);

  static const _kEnabled = 'notif_enabled';
  static const _kHour = {
    ReminderSlot.morning: 'notif_morning_h',
    ReminderSlot.lunch: 'notif_lunch_h',
    ReminderSlot.evening: 'notif_evening_h',
  };
  static const _kMinute = {
    ReminderSlot.morning: 'notif_morning_m',
    ReminderSlot.lunch: 'notif_lunch_m',
    ReminderSlot.evening: 'notif_evening_m',
  };

  Future<void> init() async {
    if (_initialized) return;
    tzdata.initializeTimeZones();
    try {
      final tzInfo = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(tzInfo.identifier));
    } catch (e) {
      if (kDebugMode) debugPrint('Timezone detection failed: $e');
      // Falls back to UTC — reminders still fire, just not necessarily at the
      // exact wall-clock time until the device's zone is resolved correctly.
    }

    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const darwinInit = DarwinInitializationSettings();
    try {
      await _plugin.initialize(
        settings: const InitializationSettings(
            android: androidInit, iOS: darwinInit),
        onDidReceiveNotificationResponse: (response) =>
            _applyPayload(response.payload),
      );
      final launchDetails = await _plugin.getNotificationAppLaunchDetails();
      if (launchDetails?.didNotificationLaunchApp == true) {
        _applyPayload(launchDetails?.notificationResponse?.payload);
      }
      _initialized = true;
    } catch (e) {
      if (kDebugMode) debugPrint('Notification init failed: $e');
    }
  }

  void _applyPayload(String? payload) {
    final link = switch (payload) {
      'meal_log' => NotificationDeepLink.mealLog,
      'suggestion' => NotificationDeepLink.suggestion,
      'progress' => NotificationDeepLink.progress,
      _ => null,
    };
    if (link != null) deepLink.value = link;
  }

  /// Requests OS notification permission (Android 13+ / iOS). Safe to call
  /// repeatedly — a no-op once granted or permanently denied.
  Future<bool> requestPermission() async {
    try {
      final android = _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      if (android != null) {
        return await android.requestNotificationsPermission() ?? false;
      }
      final ios = _plugin.resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin>();
      if (ios != null) {
        return await ios.requestPermissions(
                alert: true, badge: true, sound: true) ??
            false;
      }
      return true; // platform without a permission concept (e.g. desktop)
    } catch (e) {
      if (kDebugMode) debugPrint('Notification permission request failed: $e');
      return false;
    }
  }

  Future<NotificationPrefs> loadPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    TimeOfDay time(ReminderSlot slot, TimeOfDay fallback) {
      final h = prefs.getInt(_kHour[slot]!);
      final m = prefs.getInt(_kMinute[slot]!);
      return (h == null || m == null) ? fallback : TimeOfDay(hour: h, minute: m);
    }

    return NotificationPrefs(
      enabled: prefs.getBool(_kEnabled) ?? true,
      morning: time(ReminderSlot.morning, NotificationPrefs.defaultMorning),
      lunch: time(ReminderSlot.lunch, NotificationPrefs.defaultLunch),
      evening: time(ReminderSlot.evening, NotificationPrefs.defaultEvening),
    );
  }

  Future<void> setEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kEnabled, enabled);
  }

  Future<void> setTime(ReminderSlot slot, TimeOfDay time) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_kHour[slot]!, time.hour);
    await prefs.setInt(_kMinute[slot]!, time.minute);
  }

  /// The next wall-clock occurrence of [time] — today if it hasn't passed
  /// yet, otherwise tomorrow. Pure and framework-independent (pass [now] in
  /// tests); the timezone package itself needs no platform channel.
  static tz.TZDateTime nextOccurrence(TimeOfDay time, {tz.TZDateTime? now}) {
    final n = now ?? tz.TZDateTime.now(tz.local);
    var when =
        tz.TZDateTime(n.location, n.year, n.month, n.day, time.hour, time.minute);
    if (!when.isAfter(n)) when = when.add(const Duration(days: 1));
    return when;
  }

  /// Which slots should be (re)scheduled today, given what's already been
  /// done. Evening is never suppressed. Pure — no plugin calls.
  static List<ReminderSlot> slotsToSchedule({
    required bool breakfastLogged,
    required bool suggestionFetchedToday,
  }) =>
      [
        if (!breakfastLogged) ReminderSlot.morning,
        if (!suggestionFetchedToday) ReminderSlot.lunch,
        ReminderSlot.evening,
      ];

  Future<void> _schedule(ReminderSlot slot, TimeOfDay time) async {
    final c = slot.content;
    await _plugin.zonedSchedule(
      id: slot.notificationId,
      scheduledDate: nextOccurrence(time),
      title: c.title,
      body: c.body,
      payload: slot.payload,
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          'daily_reminders',
          'Daily reminders',
          channelDescription: 'Meal, suggestion and check-in reminders',
        ),
        iOS: DarwinNotificationDetails(),
      ),
    );
  }

  /// Cancels and reschedules today's slate, skipping (suppressing) whichever
  /// slots are already satisfied. Call on app start, on resume, and once at
  /// local midnight.
  Future<void> rescheduleToday({
    required bool breakfastLogged,
    required bool suggestionFetchedToday,
  }) async {
    if (!_initialized) return;
    try {
      for (final slot in ReminderSlot.values) {
        await _plugin.cancel(id: slot.notificationId);
      }
      final prefs = await loadPrefs();
      if (!prefs.enabled) return;

      final slots = slotsToSchedule(
        breakfastLogged: breakfastLogged,
        suggestionFetchedToday: suggestionFetchedToday,
      );
      for (final slot in slots) {
        await _schedule(slot, prefs.forSlot(slot));
      }
    } catch (e) {
      if (kDebugMode) debugPrint('Notification scheduling failed: $e');
    }
  }

  Future<void> cancelAll() async {
    try {
      await _plugin.cancelAll();
    } catch (e) {
      if (kDebugMode) debugPrint('cancelAll failed: $e');
    }
  }

  /// Fires immediately, for the "Test notification" button in Settings.
  Future<void> showTest() async {
    if (!_initialized) return;
    const content = (
      title: 'Evening check-in',
      body: 'This is what your reminders will look like.',
    );
    try {
      await _plugin.show(
        id: 99,
        title: content.title,
        body: content.body,
        notificationDetails: const NotificationDetails(
          android: AndroidNotificationDetails(
            'daily_reminders',
            'Daily reminders',
            channelDescription: 'Meal, suggestion and check-in reminders',
          ),
          iOS: DarwinNotificationDetails(),
        ),
        payload: 'progress',
      );
    } catch (e) {
      if (kDebugMode) debugPrint('Test notification failed: $e');
    }
  }
}
