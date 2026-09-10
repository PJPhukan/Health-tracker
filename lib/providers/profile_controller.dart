import 'package:flutter/foundation.dart';

import '../database/profile_repository.dart';
import '../models/user_profile.dart';

enum ProfileState { loading, ready, error }

/// Holds the signed-in user's profile + goals for the widget tree.
///
/// [goals] always returns something usable — [HealthGoals.starter] (v1's fixed
/// numbers) until a real profile is loaded — so callers never see null targets.
class ProfileController extends ChangeNotifier {
  ProfileController({ProfileRepository? repo})
      : _repo = repo ?? ProfileRepository();

  final ProfileRepository _repo;

  ProfileState _state = ProfileState.loading;
  ProfileState get state => _state;

  UserProfile? _profile;
  UserProfile? get profile => _profile;

  String _profileId = UserProfileIds.local;
  String get profileId => _profileId;

  bool _offline = false;

  /// True when the profile shown is a local copy and the cloud wasn't reachable.
  bool get offline => _offline;

  String? _error;
  String? get error => _error;

  /// Whether onboarding still needs to run for the current user.
  bool get needsOnboarding =>
      _state == ProfileState.ready &&
      (_profile == null || !_profile!.onboardingComplete);

  /// Effective daily targets — the whole app measures against this.
  HealthGoals get goals => _profile?.goals ?? HealthGoals.starter;

  /// Called by the auth gate whenever the signed-in user changes.
  Future<void> bind(String profileId) async {
    _profileId = profileId;
    _state = ProfileState.loading;
    _error = null;
    notifyListeners();
    await _reload();
  }

  Future<void> refresh() => _reload();

  Future<void> _reload() async {
    try {
      final result = await _repo.load(_profileId);
      _profile = result.profile;
      _offline = result.offline;
    } catch (e) {
      // A load failure (e.g. storage unavailable) shouldn't trap the user on a
      // dead screen — fall through with no profile so onboarding can run.
      if (kDebugMode) debugPrint('Profile load failed: $e');
      _profile = null;
      _offline = false;
    }
    _state = ProfileState.ready;
    notifyListeners();
  }

  /// Persists a freshly-built profile from onboarding.
  /// Returns true when the cloud write also succeeded.
  Future<bool> completeOnboarding(UserProfile draft) async {
    final finished = draft.copyWith(onboardingComplete: true);
    final synced = await _repo.save(finished);
    _profile = finished;
    _offline = !synced && _profileId != UserProfileIds.local;
    _state = ProfileState.ready;
    notifyListeners();
    return synced;
  }

  /// Persists edited goals from the Settings screen.
  Future<bool> updateGoals(HealthGoals goals) async {
    final current = _profile;
    if (current == null) return false;
    final synced = await _repo.saveGoals(current, goals);
    _profile = current.copyWith(goals: goals);
    _offline = !synced && _profileId != UserProfileIds.local;
    notifyListeners();
    return synced;
  }

  /// Persists edited profile fields (name/age/weight/etc.) and recalculated goals.
  Future<bool> updateProfile(UserProfile updated) async {
    final synced = await _repo.save(updated);
    _profile = updated;
    _offline = !synced && _profileId != UserProfileIds.local;
    notifyListeners();
    return synced;
  }

  void resetForSignOut() {
    _profile = null;
    _profileId = UserProfileIds.local;
    _state = ProfileState.loading;
    _offline = false;
    _error = null;
    notifyListeners();
  }
}
