import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:nexa_music/core/models/listening.dart';
import 'package:nexa_music/core/models/track.dart';
import 'package:nexa_music/features/nexa_wave/wave_ranker.dart';

/// E1: catalog songs in the Wave follow the same exclusions and likes as
/// library songs. D-026: Familiar <-> New to you decides how many picks are
/// new; the library / online share decides where the new ones come from.
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

  group('compose (D-026): new vs familiar, library vs online share', () {
    WaveItem item(Track t, {required bool fresh}) =>
        WaveItem(track: t, score: 1, reason: 'test', fresh: fresh);
    final known = [for (var i = 1; i <= 10; i++) item(local(i), fresh: false)];
    final unplayed = [
      for (var i = 11; i <= 20; i++) item(local(i), fresh: true),
    ];
    final catalog = [
      for (var i = 1; i <= 10; i++) item(online('o$i'), fresh: true),
    ];

    int onlineIn(List<WaveItem> m) => m.where((i) => i.track.isOnline).length;
    int knownIn(List<WaveItem> m) =>
        m.where((i) => !i.track.isOnline && !i.fresh).length;
    int unplayedIn(List<WaveItem> m) =>
        m.where((i) => !i.track.isOnline && i.fresh).length;

    test('right end = online only: no library song at all (Full Discover)',
        () {
      final m = WaveRanker.compose(
        [...known, ...unplayed],
        catalog,
        discovery: 1,
        onlineShare: 0,
        limit: 8,
      );
      expect(m, hasLength(8));
      expect(onlineIn(m), 8);
      expect(
        WaveRanker.compose(
          [...known, ...unplayed],
          const [],
          discovery: 1,
          limit: 8,
        ),
        isEmpty,
        reason: 'no catalog songs: empty (the controller explains), not '
            'library songs',
      );
    });

    test('the share decides library vs online among new songs', () {
      List<WaveItem> at(double share) => WaveRanker.compose(
        [...known, ...unplayed],
        catalog,
        discovery: 0.75,
        onlineShare: share,
        limit: 8,
      );
      expect(onlineIn(at(0)), 0);
      expect(unplayedIn(at(0)), 6);
      expect(onlineIn(at(0.5)), 3);
      expect(onlineIn(at(1)), 6);
      expect(knownIn(at(1)), 2);
    });

    test('Familiar 0 %: only known songs, catalogs never fill in', () {
      final m = WaveRanker.compose(
        [...known.take(3), ...unplayed],
        catalog,
        discovery: 0,
        onlineShare: 1,
        limit: 8,
      );
      expect(onlineIn(m), 0);
      expect(knownIn(m), 3);
      expect(unplayedIn(m), 5); // not enough known songs: new library songs
    });

    test('in between: new and familiar parts by the slider', () {
      final m = WaveRanker.compose(
        [...known, ...unplayed],
        catalog,
        discovery: 0.5,
        limit: 8,
      );
      expect(knownIn(m), 4);
      expect(onlineIn(m) + unplayedIn(m), 4);
      expect(onlineIn(m), 2);
    });

    test('below the right end without online songs the library fills in',
        () {
      final m = WaveRanker.compose(
        [...known, ...unplayed],
        const [],
        discovery: 0.75,
        onlineShare: 1,
        limit: 8,
      );
      expect(m, hasLength(8));
      expect(unplayedIn(m), 6);
      expect(knownIn(m), 2);
      expect(onlineIn(m), 0);
    });

    test('one kind of new song runs short: the other stands in, familiar '
        'songs only when nothing new is left', () {
      final fewUnplayed = WaveRanker.compose(
        [...known, ...unplayed.take(1)],
        catalog,
        discovery: 0.75,
        limit: 8,
      );
      expect(unplayedIn(fewUnplayed), 1);
      expect(onlineIn(fewUnplayed), 5);
      expect(knownIn(fewUnplayed), 2);

      final nothingNew = WaveRanker.compose(
        [...known, ...unplayed.take(1)],
        catalog.take(1).toList(),
        discovery: 0.75,
        limit: 8,
      );
      expect(nothingNew, hasLength(8));
      expect(unplayedIn(nothingNew) + onlineIn(nothingNew), 2);
      expect(knownIn(nothingNew), 6);
    });

    test('catalog songs are spread over the batch', () {
      final m = WaveRanker.compose(
        [...known, ...unplayed],
        catalog,
        discovery: 0.5,
        onlineShare: 1,
        limit: 8,
      );
      expect([for (final i in m) i.track.isOnline], [
        false, true, false, true, false, true, false, true,
      ]);
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
