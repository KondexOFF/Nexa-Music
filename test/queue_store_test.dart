import 'package:flutter_test/flutter_test.dart';
import 'package:nexa_music/core/models/track.dart';
import 'package:nexa_music/features/player/queue_store.dart';
import 'package:nexa_music/features/youtube/youtube_track.dart';

/// E2.8: the saved queue - every source, removed songs left out, YouTube
/// data dropped after 30 days.
void main() {
  final saved = DateTime(2026, 11, 1);
  final local = Track(
    id: 7,
    source: TrackSource.local,
    sourceTrackId: 'c:/m/a.mp3',
    path: 'C:/m/a.mp3',
    title: 'A',
    artist: 'Artist',
    album: 'Album',
    addedAt: saved,
  );
  final catalog = Track(
    id: Track.onlineId(TrackSource.jamendo, '42'),
    source: TrackSource.jamendo,
    sourceTrackId: '42',
    path: 'https://example.org/stream/42',
    title: 'Catalog',
    artist: 'Someone',
    album: 'Jamendo',
    duration: const Duration(minutes: 3),
    addedAt: saved,
    license: 'CC BY',
  );
  final video = youtubeTrack(
    videoId: 'dQw4w9WgXcQ',
    title: 'Video',
    channel: 'Channel',
    thumbnail: 'https://i.ytimg.com/vi/dQw4w9WgXcQ/hqdefault.jpg',
  );

  Future<Track?> library(int id) async => id == 7 ? local : null;

  test('every source comes back, in order, with the position', () async {
    final text = QueueSnapshot(
      tracks: [local, catalog, video],
      cursor: 2,
      savedAt: saved,
    ).encode();
    final back = (await QueueSnapshot.decode(
      text,
      library,
      now: saved.add(const Duration(days: 1)),
    ))!;
    expect(back.tracks.map((t) => t.title), ['A', 'Catalog', 'Video']);
    expect(back.cursor, 2);
    expect(back.tracks[1].license, 'CC BY');
    expect(back.tracks[1].id, catalog.id);
    expect(back.tracks[2].artist, 'Channel');
    expect(back.tracks[2].rights.play, isFalse);
  });

  test('removed library songs are left out; the position follows', () async {
    final gone = Track(
      id: 8,
      source: TrackSource.local,
      sourceTrackId: 'c:/m/b.mp3',
      path: 'C:/m/b.mp3',
      title: 'B',
      artist: '',
      album: '',
      addedAt: saved,
    );
    final text = QueueSnapshot(
      tracks: [gone, local, video],
      cursor: 2,
      savedAt: saved,
    ).encode();
    final back = (await QueueSnapshot.decode(text, library, now: saved))!;
    expect(back.tracks.map((t) => t.title), ['A', 'Video']);
    expect(back.cursor, 1);
  });

  test('YouTube data older than 30 days is dropped, the video stays',
      () async {
    final text = QueueSnapshot(
      tracks: [video, catalog],
      cursor: 0,
      savedAt: saved,
    ).encode();
    final back = (await QueueSnapshot.decode(
      text,
      library,
      now: saved.add(const Duration(days: 31)),
    ))!;
    final v = back.tracks.first;
    expect(v.sourceTrackId, 'dQw4w9WgXcQ');
    expect(v.title, 'YouTube video');
    expect(v.artist, isEmpty);
    expect(v.artworkPath, isNull);
    expect(back.tracks[1].title, 'Catalog', reason: 'catalog data kept');
  });

  test('unreadable data gives no queue', () async {
    expect(await QueueSnapshot.decode('not json', library), isNull);
    expect(await QueueSnapshot.decode(null, library), isNull);
  });
}
