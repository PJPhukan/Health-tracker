import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'toast_center.dart';

enum TtsPlaybackState { stopped, playing, paused }

/// On-device text-to-speech for reading suggestion cards and pantry buy
/// lists aloud — a reading aid, not a music player: nothing ever auto-plays,
/// only one utterance plays app-wide at a time, and playback never survives
/// a screen change or the app going to the background.
///
/// Callers identify themselves with a [String] `tag` (e.g. `'suggestion'`
/// vs `'buylist'`) so two independent speaker buttons can share this one
/// engine instance while each still knows whether *it* is the one playing.
class TtsService {
  TtsService._() {
    _tts
      ..setLanguage('en-US')
      ..setSpeechRate(0.5)
      ..setPitch(1.0)
      ..setVolume(1.0);
    _tts.setCompletionHandler(() => _markStopped());
    _tts.setCancelHandler(() => _markStopped());
    _tts.setErrorHandler((msg) {
      _markStopped();
      ToastCenter.show("Text-to-speech isn't available on this device");
      if (kDebugMode) debugPrint('TTS error: $msg');
    });
    _loadEnabled();
  }

  static final TtsService instance = TtsService._();

  static const _kEnabledPref = 'ttsEnabled';

  final FlutterTts _tts = FlutterTts();
  final _stateController = StreamController<TtsPlaybackState>.broadcast();

  TtsPlaybackState _state = TtsPlaybackState.stopped;
  String? _activeTag;

  /// Whether the speaker buttons should show at all — the Settings ▸
  /// Accessibility toggle. Defaults to on; persisted in SharedPreferences so
  /// it survives app restarts.
  final ValueNotifier<bool> enabled = ValueNotifier<bool>(true);

  Future<void> _loadEnabled() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      enabled.value = prefs.getBool(_kEnabledPref) ?? true;
    } catch (e) {
      if (kDebugMode) debugPrint('TTS pref load failed: $e');
    }
  }

  Future<void> setEnabled(bool value) async {
    enabled.value = value;
    if (!value) await stop();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_kEnabledPref, value);
    } catch (e) {
      if (kDebugMode) debugPrint('TTS pref save failed: $e');
    }
  }

  Stream<TtsPlaybackState> get stateStream => _stateController.stream;
  TtsPlaybackState get state => _state;
  bool get isPlaying => _state == TtsPlaybackState.playing;

  /// True when [tag]'s own utterance is the one currently playing — lets an
  /// individual speaker button know whether to show the "stop" state.
  bool isActive(String tag) =>
      _activeTag == tag && _state == TtsPlaybackState.playing;

  /// Reads [text] aloud, tagged as belonging to [tag]. Only one utterance
  /// plays app-wide — starting a new one (even from a different tag) stops
  /// whatever was already playing.
  Future<void> speak(String text, {required String tag}) async {
    if (text.trim().isEmpty || !enabled.value) return;
    await _tts.stop();
    _activeTag = tag;
    _setState(TtsPlaybackState.playing);
    try {
      final result = await _tts.speak(text);
      // Some platforms return 0/failure synchronously (e.g. no TTS engine
      // installed) instead of routing through the error handler.
      if (result != 1) {
        _markStopped();
        ToastCenter.show("Text-to-speech isn't available on this device");
      }
    } catch (e) {
      _markStopped();
      ToastCenter.show("Text-to-speech isn't available on this device");
      if (kDebugMode) debugPrint('TTS speak failed: $e');
    }
  }

  Future<void> stop() async {
    if (_state == TtsPlaybackState.stopped) return;
    try {
      await _tts.stop();
    } catch (e) {
      if (kDebugMode) debugPrint('TTS stop failed: $e');
    }
    _markStopped();
  }

  void _markStopped() {
    _activeTag = null;
    _setState(TtsPlaybackState.stopped);
  }

  void _setState(TtsPlaybackState s) {
    if (_state == s) return;
    _state = s;
    _stateController.add(s);
  }

  void dispose() {
    _tts.stop();
    _stateController.close();
    enabled.dispose();
  }
}
