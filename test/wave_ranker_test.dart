import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:nexa_music/app/strings.dart';
import 'package:nexa_music/core/models/listening.dart';
import 'package:nexa_music/core/models/track.dart';
import 'package:nexa_music/features/nexa_dna/taste_repository.dart';
import 'package:nexa_music/features/nexa_wave/wave_ranker.dart';

/// NEXA Wave v1 ranker (Master Plan v1.0, Phase 5 acceptance: preferences
/// change the queue, a dislike excludes a track, recent and unavailable
/// tracks are left out).
void main() {
  Track track(
    int id, {
    String artist = 'Artist',
    String? genre,
    bool favorite = false,
    bool disliked = false,
    bool available = true,
  }) => Track(
    id: id,
    source: TrackSource.local,
    sourceTrackId: 't$id',
    path: 'C:/music/$id.mp3',
    title: 'Song $id',
    artist: artist,
    album: 'Album $id',
    genre: genre,
    favorite: favorite,
    disliked: disliked,
    available: available,
    addedAt: DateTime(2026),
  );

  const ranker = WaveRanker();

  List<int> ids(List<WaveItem> items) => [for (final i in items) i.track.id];

  List<WaveItem> rank(
    List<Track> tracks, {
    List<TasteChoice> taste = const [],
    Map<int, TrackStats> stats = const {},
    Set<int> recent = const {},
    double discovery = 0.3,
  }) => ranker.rank(
    tracks: tracks,
    taste: taste,
    stats: stats,
    recent: recent,
    discovery: discovery,
    jitter: 0,
    random: math.Random(1),
  );

  final library = [
    track(1, artist: 'Aurora', genre: 'Pop'),
    track(2, artist: 'Bonobo', genre: 'Electronic'),
    track(3, artist: 'Cinematic Orchestra', genre: 'Jazz'),
    track(4, artist: 'Bonobo', genre: 'Electronic; Downtempo'),
    track(5, artist: 'Daft Punk', genre: 'Electronic'),
  ];

  test('a liked artist and a liked genre move their songs up', () {
    final before = ids(rank(library));
    final liked = rank(
      library,
      taste: const [
        TasteChoice(kind: TasteKind.artist, value: 'bonobo'),
        TasteChoice(kind: TasteKind.genre, value: 'Jazz'),
      ],
    );
    expect(ids(liked).take(3).toSet(), {2, 3, 4});
    expect(ids(liked), isNot(equals(before)));
    final bonobo = liked.firstWhere((i) => i.track.id == 2);
    expect(bonobo.reason, S.reasonLikedArtist('Bonobo'));
    final jazz = liked.firstWhere((i) => i.track.id == 3);
    expect(jazz.reason, S.reasonLikedGenre('Jazz'));
  });

  test('a genre inside a multi-genre tag matches', () {
    final items = rank(
      library,
      taste: const [TasteChoice(kind: TasteKind.genre, value: 'downtempo')],
    );
    expect(items.first.track.id, 4);
  });

  test('a disliked song is never suggested, even if it is a favorite '
      'of a liked artist', () {
    final tracks = [
      ...library,
      track(6, artist: 'Bonobo', favorite: true, disliked: true),
    ];
    final items = rank(
      tracks,
      taste: const [TasteChoice(kind: TasteKind.artist, value: 'Bonobo')],
    );
    expect(ids(items), isNot(contains(6)));
  });

  test('excluded artists / genres and unavailable files are left out', () {
    final tracks = [...library, track(7, available: false)];
    final items = rank(
      tracks,
      taste: const [
        TasteChoice(kind: TasteKind.artist, value: 'Aurora', excluded: true),
        TasteChoice(kind: TasteKind.genre, value: 'jazz', excluded: true),
      ],
    );
    expect(ids(items).toSet(), {2, 4, 5});
  });

  test('a fast skip lowers a song but is weaker than a dislike', () {
    final tracks = [track(1), track(2)];
    const stats = {
      1: TrackStats(plays: 2, fastSkips: 2),
      2: TrackStats(plays: 2, completions: 2),
    };
    final items = rank(tracks, stats: stats);
    expect(ids(items), [2, 1], reason: 'skipped song still suggested, lower');

    final disliked = rank([track(1, disliked: true), track(2)], stats: stats);
    expect(ids(disliked), [2], reason: 'dislike excludes completely');
  });

  test('recently played songs are left out while others are available', () {
    final items = rank(library, recent: {1, 2});
    expect(ids(items).toSet(), {3, 4, 5});
  });

  test('if only recent songs remain, they are repeated with a reason', () {
    final items = rank([track(1), track(2)], recent: {1, 2});
    expect(ids(items).toSet(), {1, 2});
    expect(items.every((i) => i.reason == S.reasonRepeat), isTrue);
  });

  test('Familiar <-> Discovery: discovery prefers unplayed songs, familiar '
      'prefers songs that are finished', () {
    final tracks = [track(1, artist: 'A'), track(2, artist: 'B')];
    const stats = {1: TrackStats(plays: 3, completions: 3)};
    final familiar = rank(tracks, stats: stats, discovery: 0);
    expect(ids(familiar).first, 1);
    final discovery = rank(tracks, stats: stats, discovery: 1);
    expect(ids(discovery).first, 2);
    expect(discovery.first.fresh, isTrue);
    expect(discovery.first.reason, S.reasonNew);
  });

  test('favorites are explained and the same artist is not repeated when '
      'an alternative is close', () {
    final tracks = [
      track(1, artist: 'Same', favorite: true),
      track(2, artist: 'Same', favorite: true),
      track(3, artist: 'Other', favorite: true),
    ];
    final items = rank(tracks);
    expect(items.first.reason, S.reasonFavorite);
    for (var i = 1; i < items.length; i++) {
      expect(
        items[i].track.artist == items[i - 1].track.artist,
        isFalse,
        reason: 'artists alternate: ${ids(items)}',
      );
    }
  });

  test('genre tags are split into single genres', () {
    expect(genreTokens('Rock; Indie / Pop'), ['Rock', 'Indie', 'Pop']);
    expect(genreTokens(null), isEmpty);
  });
}
