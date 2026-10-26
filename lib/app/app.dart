import 'package:flutter/material.dart';

import 'shell/app_shell.dart';
import 'shell/keyboard_shortcuts.dart';
import 'strings.dart';
import 'theme/nexa_theme.dart';

/// Root widget of NEXA Music. Expects a ProviderScope above it.
class NexaApp extends StatelessWidget {
  const NexaApp({super.key, this.ambientMotion = true});

  /// False disables decorative looping animation (tests).
  final bool ambientMotion;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: S.appTitle,
      debugShowCheckedModeBanner: false,
      theme: buildNexaTheme(),
      home: KeyboardShortcuts(child: AppShell(ambientMotion: ambientMotion)),
    );
  }
}
