import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:nexa_music/core/models/listening.dart';
import 'package:nexa_music/core/models/track.dart';
import 'package:nexa_music/features/nexa_wave/wave_ranker.dart';

/// E1: catalog songs in the Wave follow the same exclusions and likes as
/// library songs, and Familiar <-> Discovery decides how many join a batch.
void main() {
  Track local(int id, {String artist = 'Local', String? genre}) => Track(
    id: id,
    source: TrackSource.local,
    sourceTrackId: 'l$id',
    path: 'C:/music/$id.mp3',
    title: 'Local $id',
    artist: artist,
    album: 'Album',
    genre: genre,
    addedAt: DateTime(2026),
  );

  Track online(
    String id, {
    TrackSource source = TrackSource.audius,
    String artist = 'Online',
    String? genre,
    bool available = true,
  }) => Track(
    id: Track.onlineId(source, id),
    source: source,
    sourceTrackId: id,
    path: 'https://stream.example/$id',
    title: 'Online $id',
    artist: artist,
    album: source.label,
    genre: genre,
    available: available,
    addedAt: DateTime(2026),
  );

  const ranker = WaveRanker();

  List<WaveItem> rank(
    List<Track> tracks, {
    List<TasteChoice> taste = const [],
    Map<int, String> basis = const {},
    Set<int> recent = const {},
    bool repeat = true,
    double discovery = 0.5,
  }) => ranker.rank(
    tracks: tracks,
    taste: taste,
    recent: recent,
    discovery: discovery,
    jitter: 0,
    random: math.Random(1),
    basis: basis,
    repeatWhenEmpty: repeat,
  );

  group('online slots by Familiar <-> Discovery', () {
    test('none at Familiar, at least one above it, half at Discovery', () {
      expect(WaveRanker.onlineSlots(0, 8), 0);
      expect(WaveRanker.onlineSlots(0.05, 8), 1);
      expect(WaveRanker.onlineSlots(0.3, 8), 1);
      expect(WaveRanker.onlineSlots(0.5, 8), 2);
      expect(WaveRanker.onlineSlots(1, 8), 4);
      expect(WaveRanker.onlineSlots(1, 0), 0);
    });
  });

  group('merge', () {
    final localItems = rank([for (var i = 1; i <= 10; i++) local(i)]);
    final onlineItems = rank([for (var i = 1; i <= 10; i++) online('o$i')]);

    List<bool> pattern(List<WaveItem> items) => [
      for (final i in items) i.track.isOnline,
    ];

    test('Familiar keeps the Wave local', () {
      final m = WaveRanker.merge(
        localItems,
        onlineItems,
        discovery: 0,
        limit: 8,
      );
      expect(pattern(m), everyElement(isFalse));
      expect(m, hasLength(8));
    });

    test('Discovery spreads catalog songs evenly, starting local', () {
      final m = WaveRanker.merge(
        localItems,
        onlineItems,
        discovery: 1,
        limit: 8,
      );
      expect(pattern(m), [false, true, false, true, false, true, false, true]);
      final some = WaveRanker.merge(
        localItems,
        onlineItems,
        discovery: 0.3,
        limit: 8,
      );
      expect(pattern(some).where((o) => o), hasLength(1));
      expect(pattern(some).first, isFalse);
    });

    test('when one side runs short, the other fills the batch', () {
      final fewLocal = WaveRanker.merge(
        localItems.take(2).toList(),
        onlineItems,
        discovery: 0.3,
        limit: 8,
      );
      expect(fewLocal, hasLength(8));
      expect(pattern(fewLocal).where((o) => !o), hasLength(2));

      final fewOnline = WaveRanker.merge(
        localItems,
        onlineItems.take(1).toList(),
        discovery: 1,
        limit: 8,
      );
      expect(fewOnline, hasLength(8));
      expect(pattern(fewOnline).where((o) => o), hasLength(1));

      expect(
        WaveRanker.merge(const [], onlineItems, discovery: 0.5, limit: 8),
        hasLength(8),
      );
    });
  });

  group('catalog songs in the ranker', () {
    test('excluded genres and artists and unavailable songs never appear',
        () {
      final items = rank(
        [
          online('a', genre: 'Rock'),
          online('b', artist: 'Blocked'),
          online('c', available: false),
          online('d', source: TrackSource.jamendo, genre: 'pop; indie'),
        ],
        taste: const [
          TasteChoice(kind: TasteKind.genre, value: 'rock', excluded: true),
          TasteChoice(kind: TasteKind.genre, value: 'Indie', excluded: true),
          TasteChoice(kind: TasteKind.artist, value: 'blocked', excluded: true),
        ],
      );
      expect(items, isEmpty);
    });

    test('the reason is the user\'s own taste when it matches, else the '
        'catalog\'s basis', () {
      final liked = online('l', artist: 'Kasbo');
      final other = online('o');
      final items = rank(
        [liked, other],
        taste: const [TasteChoice(kind: TasteKind.artist, value: 'Kasbo')],
        basis: {
          liked.id: 'Popular on Audius in Electronic',
          other.id: 'Popular on Audius in Electronic',
        },
      );
      expect(items.first.track.id, liked.id);
      expect(items.first.reason, contains('Kasbo'));
      expect(items.last.reason, 'Popular on Audius in Electronic');
      expect(items.every((i) => i.fresh), isTrue);
    });

    test('catalog songs are not repeated when all were used', () {
      final t = online('x');
      expect(rank([t], recent: {t.id}, repeat: false), isEmpty);
      expect(rank([t], recent: {t.id}), hasLength(1));
    });
  });
}
