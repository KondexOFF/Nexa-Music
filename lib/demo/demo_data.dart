import 'package:flutter/material.dart';

import '../app/theme/tokens.dart';
import '../ui/cover_art.dart';

// DEMO CONTENT for the Phase 1 layout only.
// These are invented names with code-drawn artwork. They are not a music
// library, not playable and are labelled DEMO in the UI. The real library
// arrives in Phase 2.

@immutable
class DemoTrack {
  const DemoTrack({
    required this.title,
    required this.artist,
    required this.album,
    required this.duration,
    required this.art,
  });

  final String title;
  final String artist;
  final String album;
  final Duration duration;
  final CoverArtSpec art;
}

@immutable
class DemoCollection {
  const DemoCollection({
    required this.title,
    required this.subtitle,
    required this.art,
  });

  final String title;
  final String subtitle;
  final CoverArtSpec art;
}

@immutable
class DemoPlaylist {
  const DemoPlaylist({
    required this.name,
    required this.trackCount,
    this.art,
  });

  final String name;
  final int trackCount;

  /// Null means the "Liked Songs" style tile.
  final CoverArtSpec? art;
}

/// One row of the Recently Played table; the meaning of [second] and
/// [third] depends on the selected tab.
@immutable
class DemoRecentRow {
  const DemoRecentRow({
    required this.title,
    required this.second,
    required this.third,
    required this.art,
    this.duration,
  });

  final String title;
  final String second;
  final String third;
  final CoverArtSpec art;
  final Duration? duration;
}

@immutable
class DemoTaste {
  const DemoTaste(this.label, this.icon, this.value, this.color);

  final String label;
  final IconData icon;
  final double value;
  final Color color;
}

enum RecentTab { all, tracks, artists, albums, playlists }

abstract final class DemoData {
  static const DemoTrack nowPlaying = DemoTrack(
    title: 'Parallel Skies',
    artist: 'Arielle',
    album: 'Momentum',
    duration: Duration(minutes: 3, seconds: 56),
    art: CoverArtSpec(7, CoverPalette.sunset),
  );
  static const Duration nowPlayingPosition = Duration(minutes: 1, seconds: 42);
  static const String nowPlayingFormat = 'FLAC · LOSSLESS';

  static const List<DemoTrack> upNext = [
    DemoTrack(
      title: 'Aurora',
      artist: 'Lume',
      album: 'Northbound',
      duration: Duration(minutes: 5, seconds: 3),
      art: CoverArtSpec(11, CoverPalette.ocean),
    ),
    DemoTrack(
      title: 'Falling Light',
      artist: 'Sonder Fields',
      album: 'Velvet Horizon',
      duration: Duration(minutes: 4, seconds: 36),
      art: CoverArtSpec(23, CoverPalette.rose),
    ),
    DemoTrack(
      title: 'Glass Rivers',
      artist: 'Elian',
      album: 'Glass Rivers',
      duration: Duration(minutes: 5, seconds: 17),
      art: CoverArtSpec(31, CoverPalette.storm),
    ),
    DemoTrack(
      title: 'Contours',
      artist: 'Vesh',
      album: 'Lines',
      duration: Duration(minutes: 4, seconds: 4),
      art: CoverArtSpec(43, CoverPalette.night),
    ),
    DemoTrack(
      title: 'A Kind of Home',
      artist: 'Elise Rowan',
      album: 'Porchlight',
      duration: Duration(minutes: 4, seconds: 27),
      art: CoverArtSpec(57, CoverPalette.golden),
    ),
  ];

  static const List<DemoCollection> moments = [
    DemoCollection(
      title: 'Golden Hours',
      subtitle: 'Chill • 56 tracks',
      art: CoverArtSpec(101, CoverPalette.golden),
    ),
    DemoCollection(
      title: 'Midnight Drive',
      subtitle: 'Electronic • 64 tracks',
      art: CoverArtSpec(102, CoverPalette.night),
    ),
    DemoCollection(
      title: 'Indie Mornings',
      subtitle: 'Indie • 48 tracks',
      art: CoverArtSpec(103, CoverPalette.rose),
    ),
    DemoCollection(
      title: 'Peaceful Places',
      subtitle: 'Ambient • 52 tracks',
      art: CoverArtSpec(104, CoverPalette.dusk),
    ),
  ];

  static const List<DemoPlaylist> playlists = [
    DemoPlaylist(name: 'Liked Songs', trackCount: 482),
    DemoPlaylist(
      name: 'Morning Light',
      trackCount: 86,
      art: CoverArtSpec(201, CoverPalette.sunset),
    ),
    DemoPlaylist(
      name: 'Deep Focus',
      trackCount: 121,
      art: CoverArtSpec(202, CoverPalette.ocean),
    ),
    DemoPlaylist(
      name: 'Night Drive',
      trackCount: 94,
      art: CoverArtSpec(203, CoverPalette.storm),
    ),
    DemoPlaylist(
      name: 'Chill Evenings',
      trackCount: 73,
      art: CoverArtSpec(204, CoverPalette.rose),
    ),
    DemoPlaylist(
      name: 'Focus Mode',
      trackCount: 68,
      art: CoverArtSpec(205, CoverPalette.dusk),
    ),
  ];

  static const List<DemoRecentRow> recentTracks = [
    DemoRecentRow(
      title: 'Falling Light',
      second: 'Sonder Fields',
      third: 'Velvet Horizon',
      art: CoverArtSpec(23, CoverPalette.rose),
      duration: Duration(minutes: 4, seconds: 36),
    ),
    DemoRecentRow(
      title: 'Parallel Skies',
      second: 'Arielle',
      third: 'Momentum',
      art: CoverArtSpec(7, CoverPalette.sunset),
      duration: Duration(minutes: 3, seconds: 56),
    ),
    DemoRecentRow(
      title: 'Azure Fields',
      second: 'Luna Wells',
      third: 'Better Days',
      art: CoverArtSpec(301, CoverPalette.ocean),
      duration: Duration(minutes: 4, seconds: 21),
    ),
    DemoRecentRow(
      title: 'Drift',
      second: 'Kairo',
      third: 'Still Forms',
      art: CoverArtSpec(302, CoverPalette.golden),
      duration: Duration(minutes: 4, seconds: 11),
    ),
    DemoRecentRow(
      title: 'The Calm',
      second: 'Mira Vale',
      third: 'The Calm',
      art: CoverArtSpec(303, CoverPalette.storm),
      duration: Duration(minutes: 6, seconds: 28),
    ),
  ];

  static const List<DemoRecentRow> recentArtists = [
    DemoRecentRow(
      title: 'Sonder Fields',
      second: 'Dream pop',
      third: 'Falling Light',
      art: CoverArtSpec(401, CoverPalette.rose),
    ),
    DemoRecentRow(
      title: 'Arielle',
      second: 'Synthwave',
      third: 'Parallel Skies',
      art: CoverArtSpec(402, CoverPalette.sunset),
    ),
    DemoRecentRow(
      title: 'Luna Wells',
      second: 'Indie folk',
      third: 'Azure Fields',
      art: CoverArtSpec(403, CoverPalette.ocean),
    ),
    DemoRecentRow(
      title: 'Kairo',
      second: 'Downtempo',
      third: 'Drift',
      art: CoverArtSpec(404, CoverPalette.golden),
    ),
  ];

  static const List<DemoRecentRow> recentAlbums = [
    DemoRecentRow(
      title: 'Velvet Horizon',
      second: 'Sonder Fields',
      third: '2024',
      art: CoverArtSpec(23, CoverPalette.rose),
    ),
    DemoRecentRow(
      title: 'Momentum',
      second: 'Arielle',
      third: '2025',
      art: CoverArtSpec(7, CoverPalette.sunset),
    ),
    DemoRecentRow(
      title: 'Still Forms',
      second: 'Kairo',
      third: '2023',
      art: CoverArtSpec(302, CoverPalette.golden),
    ),
  ];

  static const List<DemoRecentRow> recentPlaylists = [
    DemoRecentRow(
      title: 'Morning Light',
      second: 'Warm, bright',
      third: '86',
      art: CoverArtSpec(201, CoverPalette.sunset),
    ),
    DemoRecentRow(
      title: 'Night Drive',
      second: 'Moody, steady',
      third: '94',
      art: CoverArtSpec(203, CoverPalette.storm),
    ),
    DemoRecentRow(
      title: 'Deep Focus',
      second: 'Calm, minimal',
      third: '121',
      art: CoverArtSpec(202, CoverPalette.ocean),
    ),
  ];

  static List<DemoRecentRow> recentFor(RecentTab tab) => switch (tab) {
    RecentTab.all || RecentTab.tracks => recentTracks,
    RecentTab.artists => recentArtists,
    RecentTab.albums => recentAlbums,
    RecentTab.playlists => recentPlaylists,
  };

  static const List<DemoTaste> taste = [
    DemoTaste('Chill', Icons.spa_outlined, 0.72, NexaColors.accent),
    DemoTaste('Melodic', Icons.wb_sunny_outlined, 0.56, NexaColors.coral),
    DemoTaste('Atmospheric', Icons.nightlight_outlined, 0.48, NexaColors.sky),
  ];

  static const List<DemoCollection> discover = [
    DemoCollection(
      title: 'New Releases',
      subtitle: 'Fresh this week',
      art: CoverArtSpec(501, CoverPalette.night),
    ),
    DemoCollection(
      title: 'Mood Mixes',
      subtitle: 'Play by feeling',
      art: CoverArtSpec(502, CoverPalette.rose),
    ),
  ];
}

/// m:ss
String formatClock(Duration d) {
  final seconds = d.inSeconds.remainder(60).toString().padLeft(2, '0');
  return '${d.inMinutes}:$seconds';
}
