import 'dart:async';

import 'package:flutter/material.dart';

import '../services/tts_service.dart';
import '../theme/app_theme.dart';

/// Small speaker/stop icon button that reads [text] aloud via [TtsService],
/// tagged as [tag] so independent buttons (e.g. the suggestion text vs the
/// buy list) each know whether *they* are the one currently playing.
///
/// Hidden entirely when the user has turned text-to-speech off in Settings.
class TtsSpeakerButton extends StatefulWidget {
  const TtsSpeakerButton({
    super.key,
    required this.text,
    required this.tag,
    this.size = 20,
  });

  final String text;
  final String tag;
  final double size;

  @override
  State<TtsSpeakerButton> createState() => _TtsSpeakerButtonState();
}

class _TtsSpeakerButtonState extends State<TtsSpeakerButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulseController = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  );
  late final Animation<double> _pulse = Tween(begin: 1.0, end: 1.1).animate(
    CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
  );

  StreamSubscription<TtsPlaybackState>? _sub;
  bool _playing = false;

  @override
  void initState() {
    super.initState();
    _sync();
    _sub = TtsService.instance.stateStream.listen((_) => _sync());
  }

  void _sync() {
    final playing = TtsService.instance.isActive(widget.tag);
    if (playing == _playing) return;
    setState(() => _playing = playing);
    if (playing) {
      _pulseController.repeat(reverse: true);
    } else {
      _pulseController.stop();
      _pulseController.value = 0;
    }
  }

  Future<void> _toggle() async {
    if (_playing) {
      await TtsService.instance.stop();
    } else {
      await TtsService.instance.speak(widget.text, tag: widget.tag);
    }
  }

  @override
  void dispose() {
    _sub?.cancel();
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: TtsService.instance.enabled,
      builder: (context, ttsEnabled, _) {
        if (!ttsEnabled) return const SizedBox.shrink();
        return Material(
          color: Colors.transparent,
          shape: const CircleBorder(),
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: _toggle,
            child: Padding(
              padding: const EdgeInsets.all(6),
              child: AnimatedBuilder(
                animation: _pulse,
                builder: (context, child) => Transform.scale(
                  scale: _playing ? _pulse.value : 1.0,
                  child: child,
                ),
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 200),
                  child: Icon(
                    _playing ? Icons.stop_rounded : Icons.volume_up_rounded,
                    key: ValueKey(_playing),
                    size: widget.size,
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
