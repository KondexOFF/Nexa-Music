import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;

import '../../app/config.dart';
import '../../app/strings.dart';
import '../../app/theme/nexa_theme.dart';
import '../../app/theme/tokens.dart';
import '../../ui/nexa_widgets.dart';
import '../discover/catalog_providers.dart';
import 'update_controller.dart';
import 'update_installer.dart';
import 'update_source.dart';

String _mb(int bytes) => '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';

String _date(DateTime? d) {
  if (d == null) {
    return '';
  }
  final l = d.toLocal();
  String two(int n) => n.toString().padLeft(2, '0');
  return '${l.year}-${two(l.month)}-${two(l.day)}';
}

String _when(DateTime d) {
  final l = d.toLocal();
  String two(int n) => n.toString().padLeft(2, '0');
  return '${_date(l)} ${two(l.hour)}:${two(l.minute)}';
}

String problemText(UpdateState s) =>
    S.updProblem(s.problem?.name ?? '', s.detail);

String? resultText(UpdaterResult r) => switch (r.state) {
  'ok' => r.mode == 'rollback' ? S.updRollbackDone(r.to) : S.updDone(r.to),
  'failed_rolled_back' => S.updRolledBack(r.from),
  'not_closed' => S.updNotClosed,
  _ => S.updFailedResult(r.detail),
};

/// The notification with the four actions, then download progress and the
/// choice of when to install. Opened by the daily check (AppShell) and by
/// "Update now" in Settings > About.
Future<void> showUpdateDialog(BuildContext context) => showDialog<void>(
  context: context,
  barrierDismissible: false,
  builder: (_) => const UpdateDialog(),
);

Future<void> showWhatsNew(BuildContext context, UpdateState s) {
  final r = s.release;
  if (r == null) {
    return Future.value();
  }
  return showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      backgroundColor: NexaColors.panelRaised,
      title: Text(r.name, style: NexaText.h3),
      content: SizedBox(
        width: 560,
        height: 360,
        child: SingleChildScrollView(
          child: SelectableText(
            r.notes.trim().isEmpty ? r.tag : r.notes.trim(),
            key: const ValueKey('update-notes'),
            style: NexaText.body,
          ),
        ),
      ),
      actions: [
        if (r.pageUrl.isNotEmpty)
          Consumer(
            builder: (context, ref, _) => TextButton(
              onPressed: () => unawaited(ref.read(linkOpenerProvider)(r.pageUrl)),
              child: const Text(S.updOpenRelease),
            ),
          ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text(S.updClose),
        ),
      ],
    ),
  );
}

class UpdateDialog extends ConsumerWidget {
  const UpdateDialog({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(updateProvider);
    final ctl = ref.read(updateProvider.notifier);
    final r = s.release;
    void close() => Navigator.of(context).pop();
    final List<Widget> actions;
    final Widget body;
    switch (s.phase) {
      case UpdatePhase.downloading:
        body = Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              s.downloadPhase == 1 ? S.updDownloading : S.updUnpacking,
              style: NexaText.body,
            ),
            const SizedBox(height: 12),
            LinearProgressIndicator(
              key: const ValueKey('update-progress'),
              value: s.progress,
              color: NexaColors.accent,
              backgroundColor: NexaColors.panel,
            ),
            const SizedBox(height: 6),
            Text(
              s.progress == null ? '' : '${(s.progress! * 100).round()} %',
              key: const ValueKey('update-percent'),
              style: NexaText.caption,
            ),
          ],
        );
        actions = const [];
      case UpdatePhase.ready:
        body = Text(
          S.updReadyBody(s.staged?.version.toString() ?? ''),
          style: NexaText.body,
        );
        actions = [
          TextButton(
            key: const ValueKey('update-on-exit'),
            onPressed: () {
              ctl.installOnExit();
              close();
            },
            child: const Text(S.updOnExit),
          ),
          FilledButton(
            key: const ValueKey('update-restart'),
            onPressed: () => unawaited(ctl.installNow()),
            child: const Text(S.updRestartNow),
          ),
        ];
      case UpdatePhase.installing:
        body = const Text(S.updInstalling, style: NexaText.body);
        actions = const [];
      case UpdatePhase.error:
        body = Text(
          problemText(s),
          key: const ValueKey('update-error'),
          style: NexaText.body,
        );
        actions = [
          TextButton(onPressed: close, child: const Text(S.updClose)),
          if (r != null)
            FilledButton(
              onPressed: () => unawaited(ctl.download()),
              child: const Text(S.updRetry),
            ),
        ];
      default:
        final size = r?.package == null ? '' : _mb(r!.package!.size);
        final date = r?.publishedAt == null ? '' : ', ${_date(r!.publishedAt)}';
        body = Text(
          S.updAvailableBody(kAppVersion, size, date),
          style: NexaText.body,
        );
        actions = [
          TextButton(
            key: const ValueKey('update-skip'),
            onPressed: () {
              unawaited(ctl.skip());
              close();
            },
            child: const Text(S.updSkip),
          ),
          TextButton(
            key: const ValueKey('update-later'),
            onPressed: close,
            child: const Text(S.updLater),
          ),
          TextButton(
            key: const ValueKey('update-whats-new'),
            onPressed: () => unawaited(showWhatsNew(context, s)),
            child: const Text(S.updWhatsNew),
          ),
          FilledButton(
            key: const ValueKey('update-now'),
            onPressed: () => unawaited(ctl.download()),
            child: const Text(S.updNow),
          ),
        ];
    }
    return AlertDialog(
      backgroundColor: NexaColors.panelRaised,
      title: Text(
        S.updAvailableTitle(r?.version.toString() ?? ''),
        style: NexaText.h3,
      ),
      content: SizedBox(width: 480, child: body),
      actions: actions,
    );
  }
}

/// Settings > About: manual check, the daily check switch, status,
/// "Update now", "What's new" and the rollback.
class UpdateControls extends ConsumerWidget {
  const UpdateControls({super.key});

  Future<void> _confirmRollback(
    BuildContext context,
    WidgetRef ref,
    PreviousVersion target,
  ) async {
    final ctl = ref.read(updateProvider.notifier);
    final v = target.version.toString();
    String body;
    var possible = true;
    try {
      final copy = await ctl.rollbackCopy(target);
      body = copy == null
          ? S.updRollbackBody(v)
          : S.updRollbackDbBody(v, p.basename(copy.path));
    } on UpdateException {
      body = S.updRollbackNoCopy(v);
      possible = false;
    }
    if (!context.mounted) {
      return;
    }
    final yes = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: NexaColors.panelRaised,
        title: Text(S.updRollbackTitle(v), style: NexaText.h3),
        content: SizedBox(
          width: 480,
          child: Text(body, key: const ValueKey('rollback-body'), style: NexaText.body),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text(S.updCancel),
          ),
          if (possible)
            FilledButton(
              key: const ValueKey('rollback-confirm'),
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text(S.updRollbackConfirm),
            ),
        ],
      ),
    );
    if (yes ?? false) {
      await ctl.rollback(target);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(updateProvider);
    final ctl = ref.read(updateProvider.notifier);
    final busy = s.phase == UpdatePhase.checking ||
        s.phase == UpdatePhase.downloading ||
        s.phase == UpdatePhase.installing;
    final String? status = switch (s.phase) {
      UpdatePhase.checking => S.updChecking,
      UpdatePhase.upToDate => S.updUpToDate(kAppVersion),
      UpdatePhase.available =>
        s.isSkipped
            ? S.updSkippedNote(s.release!.version.toString())
            : S.updAvailableTitle(s.release!.version.toString()),
      UpdatePhase.downloading =>
        '${s.downloadPhase == 1 ? S.updDownloading : S.updUnpacking}'
            '${s.progress == null ? '' : ' ${(s.progress! * 100).round()} %'}',
      UpdatePhase.ready =>
        s.installOnExit
            ? S.updOnExitSet
            : S.updReadyBody(s.staged!.version.toString()),
      UpdatePhase.installing => S.updInstalling,
      UpdatePhase.error => problemText(s),
      UpdatePhase.idle => null,
    };
    final result = s.lastResult;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (result != null) ...[
          Text(
            resultText(result)!,
            key: const ValueKey('update-result'),
            style: NexaText.body.copyWith(
              color: result.ok ? NexaColors.sky : NexaColors.coral,
            ),
          ),
          const SizedBox(height: 10),
        ],
        Wrap(
          spacing: 10,
          runSpacing: 10,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            NexaPillButton(
              key: const ValueKey('update-check'),
              label: S.updCheck,
              icon: Icons.system_update_alt_rounded,
              variant: PillVariant.secondary,
              height: 42,
              onPressed: busy ? null : () => unawaited(ctl.check()),
            ),
            if (s.phase == UpdatePhase.available ||
                (s.phase == UpdatePhase.error && s.release != null)) ...[
              NexaPillButton(
                key: const ValueKey('about-update-now'),
                label: S.updNow,
                height: 42,
                onPressed: () {
                  unawaited(ctl.download());
                  unawaited(showUpdateDialog(context));
                },
              ),
              NexaTextLink(
                label: S.updWhatsNew,
                showArrow: false,
                onTap: () => unawaited(showWhatsNew(context, s)),
              ),
            ],
            if (s.phase == UpdatePhase.ready && !s.installOnExit)
              NexaPillButton(
                key: const ValueKey('about-update-restart'),
                label: S.updRestartNow,
                height: 42,
                onPressed: () => unawaited(ctl.installNow()),
              ),
          ],
        ),
        if (status != null) ...[
          const SizedBox(height: 8),
          Text(
            status,
            key: const ValueKey('update-status'),
            style: NexaText.caption.copyWith(color: NexaColors.sky),
          ),
        ],
        if (s.lastCheck != null) ...[
          const SizedBox(height: 4),
          Text(S.updLastCheck(_when(s.lastCheck!)), style: NexaText.caption),
        ],
        const SizedBox(height: 6),
        // One element for screen readers and UI Automation: the switch
        // with its text.
        MergeSemantics(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Switch(
                key: const ValueKey('update-auto'),
                value: s.autoCheck,
                onChanged: (v) => unawaited(ctl.setAutoCheck(v)),
              ),
              const SizedBox(width: 8),
              const Flexible(child: Text(S.updAuto, style: NexaText.body)),
            ],
          ),
        ),
        for (final prev in s.previous.take(1)) ...[
          const SizedBox(height: 6),
          NexaTextLink(
            key: const ValueKey('update-rollback'),
            label: S.updRollback(prev.version.toString()),
            showArrow: false,
            onTap: busy ? null : () => unawaited(_confirmRollback(context, ref, prev)),
          ),
        ],
      ],
    );
  }
}
