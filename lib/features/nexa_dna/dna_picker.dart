import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/strings.dart';
import '../../app/theme/nexa_theme.dart';
import '../../app/theme/tokens.dart';
import '../../core/models/listening.dart';
import '../../ui/nexa_widgets.dart';
import 'dna_providers.dart';

/// Opens the NEXA DNA picker. Closing it (Done or Skip) marks the first
/// choice as made, so it is not offered again automatically.
Future<void> showDnaPicker(BuildContext context) async {
  final container = ProviderScope.containerOf(context);
  await showDialog<void>(
    context: context,
    builder: (_) => const DnaPickerDialog(),
  );
  await container.read(dnaSettingsProvider.notifier).setOnboarded(true);
}

/// NEXA DNA: genres and artists from the user's own library. Each chip
/// cycles neutral -> liked -> excluded -> neutral; changes are saved at once.
class DnaPickerDialog extends ConsumerWidget {
  const DnaPickerDialog({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tags = ref.watch(libraryTagsProvider).value ?? const LibraryTags();
    final choices = ref.watch(tasteItemsProvider).value ?? const [];
    final consent = ref.watch(
      dnaSettingsProvider.select((s) => s.historyConsent),
    );
    final size = MediaQuery.sizeOf(context);
    return Dialog(
      backgroundColor: NexaColors.panelRaised,
      insetPadding: const EdgeInsets.all(24),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 720,
          maxHeight: size.height - 48,
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(28, 24, 28, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(S.dnaTitle, style: NexaText.h2),
              const SizedBox(height: 8),
              const Text(S.dnaIntro, style: NexaText.bodySecondary),
              const SizedBox(height: 18),
              Flexible(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (tags.genres.isEmpty && tags.artists.isEmpty)
                        const Text(S.dnaNoTags, style: NexaText.bodySecondary),
                      if (tags.genres.isNotEmpty)
                        TasteChipGroup(
                          title: S.dnaGenres,
                          kind: TasteKind.genre,
                          values: tags.genres,
                          choices: choices,
                        ),
                      if (tags.artists.isNotEmpty)
                        TasteChipGroup(
                          title: S.dnaArtists,
                          kind: TasteKind.artist,
                          values: tags.artists,
                          choices: choices,
                        ),
                    ],
                  ),
                ),
              ),
              const Divider(height: 28, color: NexaColors.divider),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(S.historyQuestion, style: NexaText.title),
                        SizedBox(height: 4),
                        Text(S.historyQuestionInfo, style: NexaText.caption),
                      ],
                    ),
                  ),
                  const SizedBox(width: 16),
                  Switch(
                    value: consent,
                    onChanged: (v) => ref
                        .read(dnaSettingsProvider.notifier)
                        .setHistoryConsent(v),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text(S.skip),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text(S.done),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A titled group of three-state taste chips.
class TasteChipGroup extends ConsumerWidget {
  const TasteChipGroup({
    super.key,
    required this.title,
    required this.kind,
    required this.values,
    required this.choices,
  });

  final String title;
  final TasteKind kind;
  final List<String> values;
  final List<TasteChoice> choices;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final byKey = {
      for (final c in choices)
        if (c.kind == kind) c.key: c,
    };
    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title.toUpperCase(), style: NexaText.overline),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final v in values)
                TasteChip(
                  label: v,
                  choice: byKey[tasteKey(v)],
                  onTap: () => _cycle(ref, v, byKey[tasteKey(v)]),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _cycle(WidgetRef ref, String value, TasteChoice? current) {
    final repo = ref.read(tasteRepositoryProvider);
    if (current == null) {
      return repo.setItem(kind, value);
    }
    if (!current.excluded) {
      return repo.setItem(kind, value, excluded: true);
    }
    return repo.removeItem(kind, value);
  }
}

/// Chip showing a taste choice: neutral, liked (accent) or excluded.
class TasteChip extends StatelessWidget {
  const TasteChip({
    super.key,
    required this.label,
    required this.choice,
    this.onTap,
  });

  final String label;
  final TasteChoice? choice;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final liked = choice != null && !choice!.excluded;
    final excluded = choice?.excluded ?? false;
    final color = liked
        ? NexaColors.accent
        : excluded
        ? NexaColors.coral
        : NexaColors.textSecondary;
    final state = liked
        ? S.dnaLiked
        : excluded
        ? S.dnaExcluded
        : null;
    return Container(
        decoration: BoxDecoration(
          color: liked
              ? NexaColors.accentSoft
              : excluded
              ? const Color(0x1FFF7E6E)
              : const Color(0x0AFFFFFF),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: liked || excluded
                ? color.withValues(alpha: 0.6)
                : NexaColors.border,
          ),
        ),
        child: NexaTappable(
          onTap: onTap,
          semanticLabel: state == null ? label : '$label, $state',
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (liked || excluded) ...[
                  Icon(
                    liked ? Icons.favorite_rounded : Icons.block_rounded,
                    size: 15,
                    color: color,
                  ),
                  const SizedBox(width: 6),
                ],
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 220),
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: NexaText.body.copyWith(
                      fontSize: 13.5,
                      color: liked || excluded
                          ? NexaColors.textPrimary
                          : NexaColors.textSecondary,
                      decoration: excluded ? TextDecoration.lineThrough : null,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
    );
  }
}
