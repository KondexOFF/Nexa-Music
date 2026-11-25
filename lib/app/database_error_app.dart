import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;

import '../core/database/app_database.dart';
import '../core/database/database_safety.dart';
import 'strings.dart';
import 'theme/nexa_theme.dart';
import 'theme/tokens.dart';

/// Shown instead of NEXA when its database could not be opened or updated.
/// The copy made before the update has already been put back, so nothing
/// of the user's library, playlists or favourites is lost. A library saved
/// by a newer NEXA is not opened at all; the copy from before that upgrade
/// can be put back (the current file is kept as a protected backup).
class DatabaseErrorApp extends StatefulWidget {
  const DatabaseErrorApp({super.key, required this.error});

  final DatabaseOpenFailed error;

  @override
  State<DatabaseErrorApp> createState() => _DatabaseErrorAppState();
}

class _DatabaseErrorAppState extends State<DatabaseErrorApp> {
  bool _restored = false;
  String? _failure;

  File? get _copy => widget.error.safety?.newestCopyFor(
    AppDatabase.currentSchemaVersion,
  );

  void _restore(File copy) {
    try {
      widget.error.safety!.restore(copy);
      setState(() => _restored = true);
    } on Object catch (e) {
      setState(() => _failure = '$e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final error = widget.error;
    final newer = error.newerSchema;
    final copy = newer == null ? null : _copy;
    return MaterialApp(
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
                  Text(
                    newer == null ? S.dbFailedTitle : S.dbNewerTitle,
                    style: NexaText.h2,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    newer != null
                        ? S.dbNewerBody(newer, AppDatabase.currentSchemaVersion)
                        : error.restoredFrom == null
                        ? S.dbFailedNoCopy
                        : S.dbFailedRestored(
                            error.restoredFrom!.split(RegExp(r'[\\/]')).last,
                          ),
                    style: NexaText.body,
                  ),
                  const SizedBox(height: 12),
                  if (newer != null) ...[
                    if (_restored)
                      const Text(
                        S.dbNewerRestored,
                        key: ValueKey('db-newer-restored'),
                        style: NexaText.body,
                      )
                    else if (copy == null)
                      const Text(S.dbNewerNoCopy, style: NexaText.caption)
                    else
                      FilledButton(
                        key: const ValueKey('db-newer-restore'),
                        onPressed: () => _restore(copy),
                        child: Text(S.dbNewerRestore(p.basename(copy.path))),
                      ),
                    if (_failure != null) ...[
                      const SizedBox(height: 8),
                      SelectableText(_failure!, style: NexaText.caption),
                    ],
                  ] else
                    SelectableText(error.reason, style: NexaText.caption),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
