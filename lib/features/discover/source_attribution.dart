import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/strings.dart';
import '../../app/theme/nexa_theme.dart';
import '../../app/theme/tokens.dart';
import '../../core/models/track.dart';
import '../../ui/nexa_widgets.dart';
import 'catalog_providers.dart';

/// Source badge for a catalog track ("AUDIUS", "JAMENDO").
class SourceBadge extends StatelessWidget {
  const SourceBadge({super.key, required this.source});

  final TrackSource source;

  @override
  Widget build(BuildContext context) =>
      StatusBadge(label: source.label, color: sourceColor(source));
}

/// One icon per source (compact rows, Sources card).
IconData sourceIcon(TrackSource source) => switch (source) {
  TrackSource.local => Icons.library_music_rounded,
  TrackSource.audius => Icons.podcasts_rounded,
  TrackSource.jamendo => Icons.album_rounded,
  TrackSource.youtube => Icons.smart_display_rounded,
  TrackSource.soundcloud => Icons.cloud_rounded,
};

/// The source as a small coloured icon with its name as tooltip - for
/// narrow rows (Up Next) where a badge would hide the title.
class SourceIcon extends StatelessWidget {
  const SourceIcon({super.key, required this.source, this.size = 15});

  final TrackSource source;
  final double size;

  @override
  Widget build(BuildContext context) => NexaTooltip(
    message: source.label,
    child: Semantics(
      label: source.label,
      child: Icon(sourceIcon(source), size: size, color: sourceColor(source)),
    ),
  );
}

/// One colour per source, the same everywhere (badges, Sources card).
Color sourceColor(TrackSource source) => switch (source) {
  TrackSource.local => NexaColors.textSecondary,
  TrackSource.audius => NexaColors.accent,
  TrackSource.jamendo => NexaColors.sky,
  TrackSource.youtube => NexaColors.coral,
  TrackSource.soundcloud => NexaColors.orange,
};

/// Credits for a catalog track: artist "on <source>", licence and a link to
/// the track page (required attribution / backlink).
class SourceAttribution extends ConsumerWidget {
  const SourceAttribution({super.key, required this.track});

  final Track track;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final open = ref.read(linkOpenerProvider);
    final page = track.pageUrl;
    final license = track.license;
    final licenseUrl = track.licenseUrl;
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Wrap(
        spacing: 10,
        runSpacing: 6,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          SourceBadge(source: track.source),
          Text(
            '${track.artist} ${S.onSource(track.source.label)}',
            style: NexaText.bodySecondary,
          ),
          if (license != null)
            NexaTextLink(
              label: S.sourceLicense(license),
              showArrow: false,
              onTap: licenseUrl == null ? null : () => open(licenseUrl),
            ),
          if (page != null)
            NexaTextLink(label: S.openPage, onTap: () => open(page)),
          const Text(S.noMixOnline, style: NexaText.caption),
        ],
      ),
    );
  }
}
