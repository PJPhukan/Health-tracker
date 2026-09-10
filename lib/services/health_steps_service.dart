import 'package:flutter/foundation.dart';
import 'package:health/health.dart';

/// Result of asking for / checking step-read access.
enum HealthAccess {
  /// Not asked yet.
  unknown,

  /// Steps can be read.
  granted,

  /// The user declined, or hasn't granted it.
  denied,

  /// No health platform on this device (Health Connect missing, web, etc.).
  unavailable,
}

/// Thin wrapper over the `health` plugin for the one thing v2 needs: today's
/// step count from Health Connect (Android) / HealthKit (iOS).
///
/// Everything is defensive — a device with no health platform, a revoked
/// permission, or a plugin error all resolve to "fall back to manual entry".
class HealthStepsService {
  HealthStepsService({Health? health}) : _health = health ?? Health();

  final Health _health;
  static const _types = [HealthDataType.STEPS];
  static const _perms = [HealthDataAccess.READ];

  bool _configured = false;

  Future<void> _ensureConfigured() async {
    if (_configured) return;
    await _health.configure();
    _configured = true;
  }

  /// Is there a health platform we can even talk to?
  Future<bool> isSupported() async {
    try {
      await _ensureConfigured();
      if (defaultTargetPlatform == TargetPlatform.android) {
        return await _health.isHealthConnectAvailable();
      }
      return defaultTargetPlatform == TargetPlatform.iOS;
    } catch (e) {
      if (kDebugMode) debugPrint('health isSupported failed: $e');
      return false;
    }
  }

  /// Current access without prompting.
  Future<HealthAccess> currentAccess() async {
    try {
      await _ensureConfigured();
      if (!await isSupported()) return HealthAccess.unavailable;
      final has = await _health.hasPermissions(_types, permissions: _perms);
      // iOS never discloses READ grants → null. Treat unknown as "try it".
      if (has == null) return HealthAccess.unknown;
      return has ? HealthAccess.granted : HealthAccess.denied;
    } catch (e) {
      if (kDebugMode) debugPrint('health currentAccess failed: $e');
      return HealthAccess.unavailable;
    }
  }

  /// Prompts for step-read access. Returns the resulting [HealthAccess].
  Future<HealthAccess> requestAccess() async {
    try {
      await _ensureConfigured();
      if (!await isSupported()) return HealthAccess.unavailable;
      final ok =
          await _health.requestAuthorization(_types, permissions: _perms);
      return ok ? HealthAccess.granted : HealthAccess.denied;
    } catch (e) {
      if (kDebugMode) debugPrint('health requestAccess failed: $e');
      return HealthAccess.unavailable;
    }
  }

  /// Total steps recorded so far today, or null if unavailable / not permitted.
  Future<int?> stepsToday() async {
    try {
      await _ensureConfigured();
      final now = DateTime.now();
      final midnight = DateTime(now.year, now.month, now.day);
      final total = await _health.getTotalStepsInInterval(midnight, now);
      return (total != null && total >= 0) ? total : null;
    } catch (e) {
      if (kDebugMode) debugPrint('health stepsToday failed: $e');
      return null;
    }
  }

  /// Deep-links to the Health Connect install page (Android, no-op elsewhere).
  Future<void> promptInstallHealthConnect() async {
    try {
      await _health.installHealthConnect();
    } catch (e) {
      if (kDebugMode) debugPrint('installHealthConnect failed: $e');
    }
  }
}
