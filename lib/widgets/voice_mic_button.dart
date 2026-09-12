import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:speech_to_text/speech_to_text.dart';

import '../theme/app_theme.dart';

/// Large mic button for voice meal logging.
///
/// Tap to start listening (shows a pulsing waveform), tap again — or stay
/// silent for a few seconds — to stop. On a final transcript it calls
/// [onTranscript]. Any recognizer failure (denied permission, unsupported
/// device, engine error) is swallowed: the caller's manual text field is
/// always right there as the fallback, so nothing needs to be shown for it.
class VoiceMicButton extends StatefulWidget {
  const VoiceMicButton({super.key, required this.onTranscript});

  final ValueChanged<String> onTranscript;

  @override
  State<VoiceMicButton> createState() => VoiceMicButtonState();
}

class VoiceMicButtonState extends State<VoiceMicButton>
    with SingleTickerProviderStateMixin {
  static const _rationaleShownKey = 'voice_mic_rationale_shown';

  final SpeechToText _speech = SpeechToText();
  bool _listening = false;
  bool _available = true;

  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _pulse.dispose();
    if (_listening) _speech.stop();
    super.dispose();
  }

  Future<bool> _showRationaleOnce() async {
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool(_rationaleShownKey) == true) return true;
    if (!mounted) return false;
    final proceed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        icon: const Icon(Icons.mic_rounded, color: AppColors.teal, size: 32),
        title: const Text('Log meals by voice'),
        content: const Text(
            'Stock Plate uses your microphone to let you log meals by voice. '
            'Say what you ate and we’ll fill in the form for you.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Not now')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Continue')),
        ],
      ),
    );
    if (proceed == true) await prefs.setBool(_rationaleShownKey, true);
    return proceed ?? false;
  }

  /// Starts listening. Public so a caller (e.g. "log it" from a routine
  /// suggestion) can trigger voice capture without the user tapping first.
  Future<void> start() async {
    if (_listening || !_available) return;
    if (!await _showRationaleOnce()) return;

    final ok = await _speech.initialize(
      onStatus: (status) {
        if (status == 'done' || status == 'notListening') {
          if (mounted) setState(() => _listening = false);
        }
      },
      onError: (_) {
        if (mounted) setState(() => _listening = false);
      },
    );
    if (!mounted) return;
    if (!ok) {
      setState(() => _available = false);
      return;
    }

    setState(() => _listening = true);
    await _speech.listen(
      onResult: (result) {
        if (result.finalResult) {
          widget.onTranscript(result.recognizedWords);
        }
      },
      listenOptions: SpeechListenOptions(
        partialResults: true,
        cancelOnError: true,
        pauseFor: const Duration(seconds: 3),
        listenFor: const Duration(seconds: 30),
      ),
    );
  }

  Future<void> _stop() async {
    await _speech.stop();
    if (mounted) setState(() => _listening = false);
  }

  void _toggle() => _listening ? _stop() : start();

  @override
  Widget build(BuildContext context) {
    if (!_available) return const SizedBox.shrink();
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        GestureDetector(
          onTap: _toggle,
          child: AnimatedBuilder(
            animation: _pulse,
            builder: (context, child) {
              final v = _listening ? _pulse.value : 0.0;
              return Stack(
                alignment: Alignment.center,
                children: [
                  Container(
                    width: 64 + 24 * v,
                    height: 64 + 24 * v,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppColors.accent.withValues(alpha: 0.12 * (1 - v)),
                    ),
                  ),
                  child!,
                ],
              );
            },
            child: Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _listening ? AppColors.accent : AppColors.teal,
                boxShadow: kSoftShadow,
              ),
              child: Icon(
                _listening ? Icons.stop_rounded : Icons.mic_rounded,
                color: Colors.white,
                size: 28,
              ),
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          _listening ? 'Listening… tap to stop' : 'Tap to speak your meal',
          style: Theme.of(context)
              .textTheme
              .labelSmall
              ?.copyWith(color: AppColors.textSecondary),
        ),
      ],
    );
  }
}
