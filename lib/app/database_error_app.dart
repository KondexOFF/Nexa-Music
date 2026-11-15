import 'package:flutter/material.dart';

import '../core/database/database_safety.dart';
import 'strings.dart';
import 'theme/nexa_theme.dart';
import 'theme/tokens.dart';

/// Shown instead of NEXA when its database could not be opened or updated.
/// The copy made before the update has already been put back, so nothing
/// of the user's library, playlists or favourites is lost.
class DatabaseErrorApp extends StatelessWidget {
  const DatabaseErrorApp({super.key, required this.error});

  final DatabaseOpenFailed error;

  @override
  Widget build(BuildContext context) => MaterialApp(
    debugShowCheckedModeBanner: false,
    home: Scaffold(
      backgroundColor: NexaColors.background,
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(S.dbFailedTitle, style: NexaText.h2),
                const SizedBox(height: 12),
                Text(
                  error.restoredFrom == null
                      ? S.dbFailedNoCopy
                      : S.dbFailedRestored(
                          error.restoredFrom!.split(RegExp(r'[\\/]')).last,
                        ),
                  style: NexaText.body,
                ),
                const SizedBox(height: 12),
                SelectableText(
                  error.reason,
                  style: NexaText.caption,
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}
