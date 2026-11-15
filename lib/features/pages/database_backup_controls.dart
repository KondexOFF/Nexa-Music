import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;

import '../../app/strings.dart';
import '../../app/theme/nexa_theme.dart';
import '../../app/theme/tokens.dart';
import '../../core/database/database_safety.dart';
import '../../ui/nexa_widgets.dart';
import '../library/library_dialogs.dart';
import '../library/library_providers.dart';

/// Backups of the library database (playlists, favourites, history).
final databaseSafetyProvider = FutureProvider<DatabaseSafety>(
  (ref) => DatabaseSafety.forApp(),
);

/// Settings: the newest backups, "Back up now" and "Restore at next start"
/// (the database is open while NEXA runs, so a copy goes back at the next
/// start - and the current file is kept as a backup first).
class DatabaseBackupControls extends ConsumerStatefulWidget {
  const DatabaseBackupControls({super.key});

  @override
  ConsumerState<DatabaseBackupControls> createState() =>
      _DatabaseBackupControlsState();
}

class _DatabaseBackupControlsState
    extends ConsumerState<DatabaseBackupControls> {
  bool _busy = false;
  String? _message;

  static const int _shown = 5;

  Future<void> _backupNow(DatabaseSafety safety) async {
    setState(() => _busy = true);
    String text;
    try {
      final copy = await safety.backupNow(ref.read(appDatabaseProvider));
      text = S.dbBackupDone(p.basename(copy.path));
    } on Object {
      text = S.dbBackupFailed;
    }
    if (mounted) {
      setState(() {
        _busy = false;
        _message = text;
      });
    }
  }

  Future<void> _restore(DatabaseSafety safety, File copy) async {
    final ok = await confirmAction(
      context,
      title: S.dbRestoreTitle,
      body: S.dbRestoreBody(_label(copy)),
      action: S.dbRestoreAction,
    );
    if (!ok) {
      return;
    }
    safety.requestRestore(copy);
    if (mounted) {
      setState(() => _message = null);
    }
  }

  static String _label(File copy) {
    final m = copy.lastModifiedSync();
    String two(int v) => v.toString().padLeft(2, '0');
    return '${m.year}-${two(m.month)}-${two(m.day)} '
        '${two(m.hour)}:${two(m.minute)}  (${p.basename(copy.path)})';
  }

  @override
  Widget build(BuildContext context) {
    final safety = ref.watch(databaseSafetyProvider).value;
    if (safety == null) {
      return const SizedBox.shrink();
    }
    final copies = safety.list();
    final pending = safety.pendingRestore;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        NexaPillButton(
          key: const ValueKey('db-backup-now'),
          label: S.dbBackupNow,
          icon: Icons.save_alt_rounded,
          variant: PillVariant.secondary,
          height: 42,
          onPressed: _busy ? null : () => _backupNow(safety),
          disabledReason: S.dbBackupBusy,
        ),
        if (_message != null) ...[
          const SizedBox(height: 8),
          Text(_message!, style: NexaText.caption),
        ],
        if (pending != null) ...[
          const SizedBox(height: 10),
          Wrap(
            spacing: 12,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(
                S.dbRestorePending(pending),
                key: const ValueKey('db-restore-pending'),
                style: NexaText.body.copyWith(color: NexaColors.coral),
              ),
              NexaTextLink(
                label: S.cancel,
                showArrow: false,
                onTap: () => setState(safety.cancelRestore),
              ),
            ],
          ),
        ],
        const SizedBox(height: 10),
        if (copies.isEmpty)
          const Text(S.dbNoBackups, style: NexaText.caption)
        else
          for (final copy in copies.take(_shown))
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      _label(copy),
                      style: NexaText.caption,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: NexaSpace.sm),
                  NexaTextLink(
                    label: S.dbRestoreAction,
                    showArrow: false,
                    onTap: () => _restore(safety, copy),
                  ),
                ],
              ),
            ),
      ],
    );
  }
}
