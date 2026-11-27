import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../features/profile/profile.dart';
import 'shell/app_shell.dart';
import 'shell/keyboard_shortcuts.dart';
import 'strings.dart';
import 'theme/nexa_theme.dart';
import 'theme/tokens.dart';

/// Root widget of NEXARYVE. Expects a ProviderScope above it.
class NexaApp extends ConsumerWidget {
  const NexaApp({super.key, this.ambientMotion = true});

  /// False disables decorative looping animation (tests).
  final bool ambientMotion;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // D-042 Local Profile: accent colour and animation level are applied
    // to the design tokens before anything below is built.
    final accent = ref.watch(profileProvider.select((p) => p.accent));
    final motion = ref.watch(profileProvider.select((p) => p.motion));
    NexaColors.applyAccent(
      color: accent.color,
      deep: accent.deep,
      glow: accent.glow,
    );
    NexaMotion.applyScale(switch (motion) {
      MotionLevel.full => 1,
      MotionLevel.reduced => 0.5,
      MotionLevel.off => 0,
    });
    return MaterialApp(
      title: S.appTitle,
      debugShowCheckedModeBanner: false,
      theme: buildNexaTheme(),
      builder: (context, child) => motion == MotionLevel.off
          ? MediaQuery(
              data: MediaQuery.of(context).copyWith(disableAnimations: true),
              child: child!,
            )
          : child!,
      home: _Restyle(
        look: '${accent.id}/${motion.name}',
        child: KeyboardShortcuts(
          child: AppShell(
            ambientMotion: ambientMotion && motion == MotionLevel.full,
          ),
        ),
      ),
    );
  }
}

/// Builds everything below again when the look changes, keeping all state
/// (scroll positions, the YouTube player): widgets read the tokens while
/// building, and const widgets would otherwise keep the old colours.
class _Restyle extends StatefulWidget {
  const _Restyle({required this.look, required this.child});

  final String look;
  final Widget child;

  @override
  State<_Restyle> createState() => _RestyleState();
}

class _RestyleState extends State<_Restyle> {
  @override
  void didUpdateWidget(_Restyle oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.look != widget.look) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) {
          return;
        }
        void rebuild(Element e) {
          e.markNeedsBuild();
          e.visitChildren(rebuild);
        }

        (context as Element).visitChildren(rebuild);
      });
    }
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
