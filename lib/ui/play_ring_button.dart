import 'package:flutter/material.dart';

import '../app/strings.dart';
import '../app/theme/tokens.dart';

/// Large circular play / pause control. Disabled until Phase 3.
class PlayRingButton extends StatelessWidget {
  const PlayRingButton({super.key, required this.size});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: '${S.playPause} - ${S.soonPlayback}',
      child: Semantics(
        button: true,
        enabled: false,
        label: S.playPause,
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: const Color(0x2EFFFFFF), width: 2),
          ),
          child: Icon(
            Icons.pause_rounded,
            size: size * 0.5,
            color: NexaColors.textDisabled,
          ),
        ),
      ),
    );
  }
}
