import 'package:flutter/material.dart';

import '../app/strings.dart';
import '../app/theme/tokens.dart';
import 'nexa_widgets.dart';

/// Large circular play / pause control. Disabled (with a reason) when
/// nothing is loaded.
class PlayRingButton extends StatelessWidget {
  const PlayRingButton({
    super.key,
    required this.size,
    this.playing = false,
    this.onPressed,
  });

  final double size;
  final bool playing;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null;
    final label = playing ? S.pause : S.play;
    return NexaTooltip(
      message: enabled ? label : '${S.playPause} - ${S.nothingToPlay}',
      child: Semantics(
        button: true,
        enabled: enabled,
        label: enabled ? label : S.playPause,
        child: Material(
          type: MaterialType.transparency,
          shape: const CircleBorder(),
          child: InkWell(
            onTap: onPressed,
            customBorder: const CircleBorder(),
            hoverColor: NexaColors.accentFaint,
            child: Container(
              width: size,
              height: size,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: enabled ? NexaColors.accent : const Color(0x2EFFFFFF),
                  width: 2,
                ),
              ),
              child: Icon(
                playing ? Icons.pause_rounded : Icons.play_arrow_rounded,
                size: size * 0.5,
                color: enabled
                    ? NexaColors.textPrimary
                    : NexaColors.textDisabled,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
