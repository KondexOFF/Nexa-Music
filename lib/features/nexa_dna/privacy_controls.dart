import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/strings.dart';
import '../../app/theme/nexa_theme.dart';
import '../../ui/nexa_widgets.dart';
import '../library/library_dialogs.dart';
import 'dna_providers.dart';

/// Settings -> Privacy and learning: consent, pause, private session,
/// deleting the history and resetting NEXA DNA.
class PrivacyControls extends ConsumerWidget {
  const PrivacyControls({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(dnaSettingsProvider);
    final dna = ref.read(dnaSettingsProvider.notifier);
    final events = ref.watch(listeningEventCountProvider).value ?? 0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _SwitchRow(
          title: S.historyConsent,
          info: S.historyConsentInfo,
          value: s.historyConsent,
          onChanged: dna.setHistoryConsent,
        ),
        _SwitchRow(
          title: S.pauseLearning,
          info: S.pauseLearningInfo,
          value: s.learningPaused,
          onChanged: s.historyConsent ? dna.setLearningPaused : null,
        ),
        _SwitchRow(
          title: S.privateSession,
          info: S.privateSessionInfo,
          value: s.privateSession,
          onChanged: dna.setPrivateSession,
        ),
        const SizedBox(height: 8),
        Text(S.historyCount(events), style: NexaText.caption),
        const SizedBox(height: 12),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            NexaPillButton(
              label: S.clearHistory,
              icon: Icons.delete_outline_rounded,
              variant: PillVariant.secondary,
              height: 42,
              onPressed: events == 0
                  ? null
                  : () async {
                      final ok = await confirmAction(
                        context,
                        title: S.clearHistory,
                        body: S.clearHistoryBody,
                        action: S.delete,
                      );
                      if (ok) {
                        await ref.read(tasteRepositoryProvider).clearHistory();
                      }
                    },
              disabledReason: S.historyCount(0),
            ),
            NexaPillButton(
              label: S.resetDna,
              icon: Icons.restart_alt_rounded,
              variant: PillVariant.secondary,
              height: 42,
              onPressed: () async {
                final ok = await confirmAction(
                  context,
                  title: S.resetDna,
                  body: S.resetDnaBody,
                  action: S.reset,
                );
                if (ok) {
                  await ref.read(tasteRepositoryProvider).resetTaste();
                  await dna.resetPreferences();
                }
              },
            ),
          ],
        ),
      ],
    );
  }
}

class _SwitchRow extends StatelessWidget {
  const _SwitchRow({
    required this.title,
    required this.info,
    required this.value,
    required this.onChanged,
  });

  final String title;
  final String info;
  final bool value;
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: NexaText.title),
                const SizedBox(height: 2),
                Text(info, style: NexaText.caption),
              ],
            ),
          ),
          const SizedBox(width: 16),
          Switch(value: value, onChanged: onChanged),
        ],
      ),
    );
  }
}
