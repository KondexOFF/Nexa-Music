import 'dart:convert';

import 'package:drift/drift.dart' show Value;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:nexa_music/core/database/app_database.dart';
import 'package:nexa_music/core/models/listening.dart';
import 'package:nexa_music/core/models/track.dart';
import 'package:nexa_music/features/library/library_providers.dart';
import 'package:nexa_music/features/library/library_repository.dart';
import 'package:nexa_music/features/nexa_dna/dna_providers.dart';
import 'package:nexa_music/features/nexa_dna/taste_repository.dart';
import 'package:nexa_music/features/youtube/youtube_history.dart';
import 'package:nexa_music/features/youtube/youtube_settings.dart';
import 'package:nexa_music/features/youtube/youtube_track.dart';
import 'package:nexa_music/integrations/youtube/youtube_data_api.dart';

import 'helpers/test_app.dart';

/// E2.7b: the YouTube history rule (opt-in, made for kids, no key), Recently
/// Played / Continue Listening and NEXA Wave never seeing YouTube.
void main() {
  final now = DateTime(2026, 11, 15, 12);

  Future<int> addLocal(AppDatabase db, String name, {int? minutes}) => db
      .into(db.tracks)
      .insert(
        TracksCompanion.insert(
          pathKey: 'c:/m/$name.mp3',
          path: 'C:/m/$name.mp3',
          title: name,
          artist: 'Artist',
          album: 'Album',
          fileSize: 1,
          fileModified: now,
          searchText: name.toLowerCase(),
          addedAt: now,
          durationMs: Value(minutes == null ? null : minutes * 60000),
        ),
      );

  ListeningEvent event(
    int trackId, {
    required int minute,
    Duration listened = const Duration(minutes: 3),
    Duration? duration,
    EndReason reason = EndReason.completed,
    PlayContext context = PlayContext.library,
  }) => ListeningEvent(
    trackId: trackId,
    startedAt: now.add(Duration(minutes: minute)),
    listened: listened,
    duration: duration,
    reason: reason,
    context: context,
  );

  group('Recently Played and Continue Listening', () {
    late AppDatabase db;
    late TasteRepository taste;

    setUp(() {
      db = memoryDatabase();
      taste = TasteRepository(db);
    });
    tearDown(() => db.close());

    test('newest listening per track, newest first', () async {
      final a = await addLocal(db, 'A');
      final b = await addLocal(db, 'B');
      await taste.recordEvent(event(a, minute: 1));
      await taste.recordEvent(event(b, minute: 2));
      await taste.recordEvent(event(a, minute: 3));
      final recent = await taste.watchRecent().first;
      expect(recent.map((e) => e.track.title), ['A', 'B']);
      expect(recent.first.playedAt, now.add(const Duration(minutes: 3)));
    });

    test('only long tracks left in the middle can be continued', () {
      HistoryEntry entry(Duration listened, Duration? d, EndReason r) =>
          HistoryEntry(
            track: youtubeTrack(videoId: 'dQw4w9WgXcQ'),
            playedAt: now,
            listened: listened,
            duration: d,
            reason: r,
          );
      const long = Duration(minutes: 40);
      expect(
        entry(const Duration(minutes: 12), long, EndReason.stopped).canContinue,
        isTrue,
      );
      expect(
        entry(const Duration(minutes: 12), long, EndReason.completed)
            .canContinue,
        isFalse,
      );
      expect(
        entry(const Duration(seconds: 10), long, EndReason.stopped).canContinue,
        isFalse,
        reason: 'barely started',
      );
      expect(
        entry(const Duration(minutes: 39, seconds: 50), long, EndReason.stopped)
            .canContinue,
        isFalse,
        reason: 'almost finished',
      );
      expect(
        entry(
          const Duration(minutes: 2),
          const Duration(minutes: 4),
          EndReason.skipped,
        ).canContinue,
        isFalse,
        reason: 'a normal song starts again',
      );
      expect(
        entry(const Duration(minutes: 2), null, EndReason.stopped).canContinue,
        isFalse,
      );
    });

    test('NEXA Wave statistics never include YouTube', () async {
      final a = await addLocal(db, 'A');
      final v = await LibraryRepository(db).save(youtubeTrack(videoId: 'vvvvvvvvvvv'));
      await taste.recordEvent(event(a, minute: 1));
      await taste.recordEvent(
        event(v, minute: 2, context: PlayContext.youtube),
      );
      expect((await taste.trackStats()).keys, [a]);
      expect(await taste.recentTrackIds(), [a]);
      // Recently Played shows both.
      expect((await taste.watchRecent().first).length, 2);

      await taste.clearYouTubeHistory();
      expect(await taste.eventCount(), 1);
      // The saved video nothing refers to any more is removed.
      expect(await LibraryRepository(db).pruneOrphanYouTube(), 1);
    });
  });

  group('YouTube history rule', () {
    late ProviderContainer container;
    late List<String> asked;
    late Map<String, bool> kids;
    var apiKey = 'test-key';

    ProviderContainer make() {
      asked = [];
      final c = ProviderContainer(
        overrides: [
          ...testOverrides(),
          youtubeDataApiProvider.overrideWith(
            (ref) => YouTubeDataApi(
              MockClient((request) async {
                final ids = request.url.queryParameters['id']!.split(',');
                asked.addAll(ids);
                return http.Response(
                  jsonEncode({
                    'items': [
                      for (final id in ids)
                        if (kids.containsKey(id))
                          {
                            'id': id,
                            'status': {'madeForKids': kids[id]},
                          },
                    ],
                  }),
                  200,
                );
              }),
              apiKey: apiKey,
            ),
          ),
        ],
      );
      addTearDown(c.dispose);
      return c;
    }

    Future<YtHistoryOutcome> watch(
      String id, {
      Duration listened = const Duration(minutes: 5),
    }) => container
        .read(youtubeHistoryProvider)
        .record(
          videoId: id,
          startedAt: now,
          listened: listened,
          duration: const Duration(minutes: 20),
          reason: EndReason.stopped,
          title: 'Video $id',
          channel: 'Channel',
        );

    Future<void> allow({bool youtube = true}) async {
      final dna = container.read(dnaSettingsProvider.notifier);
      await dna.setHistoryConsent(true);
      await dna.setYouTubeHistory(youtube);
    }

    Future<int> events() =>
        container.read(tasteRepositoryProvider).eventCount();

    setUp(() {
      apiKey = 'test-key';
      kids = {'aaaaaaaaaaa': false, 'kkkkkkkkkkk': true};
      container = make();
    });

    test('off by default: nothing is written, YouTube is not asked', () async {
      await container.read(dnaSettingsProvider.notifier).setHistoryConsent(true);
      expect(await watch('aaaaaaaaaaa'), YtHistoryOutcome.off);
      expect(await events(), 0);
      expect(asked, isEmpty);
    });

    test('history switched off overrides the YouTube switch', () async {
      await allow();
      await container.read(dnaSettingsProvider.notifier).setHistoryConsent(false);
      expect(await watch('aaaaaaaaaaa'), YtHistoryOutcome.off);
      container.read(dnaSettingsProvider.notifier).setPrivateSession(true);
      expect(await watch('aaaaaaaaaaa'), YtHistoryOutcome.off);
      expect(await events(), 0);
    });

    test('a video not made for kids is kept as a YouTube listening', () async {
      await allow();
      expect(await watch('aaaaaaaaaaa'), YtHistoryOutcome.recorded);
      expect(await events(), 1);
      final recent = await container
          .read(tasteRepositoryProvider)
          .watchRecent()
          .first;
      expect(recent.single.track.source, TrackSource.youtube);
      expect(recent.single.track.title, 'Video aaaaaaaaaaa');
      expect(recent.single.canContinue, isTrue);
      // The answer is kept for the session: no second quota unit.
      await watch('aaaaaaaaaaa');
      expect(asked, ['aaaaaaaaaaa']);
    });

    test('a video made for kids is never kept', () async {
      await allow();
      expect(await watch('kkkkkkkkkkk'), YtHistoryOutcome.madeForKids);
      expect(await events(), 0);
      final saved = await container.read(appDatabaseProvider).select(
        container.read(appDatabaseProvider).tracks,
      ).get();
      expect(saved, isEmpty, reason: 'not even as a saved entry');
    });

    test('unknown status (removed video) is not kept', () async {
      await allow();
      expect(await watch('ggggggggggg'), YtHistoryOutcome.unknown);
      expect(await events(), 0);
    });

    test('without an API key nothing is kept', () async {
      apiKey = '';
      container = make();
      await allow();
      expect(await watch('aaaaaaaaaaa'), YtHistoryOutcome.noKey);
      expect(await events(), 0);
      expect(asked, isEmpty);
    });

    test('a few seconds are not a listening', () async {
      await allow();
      expect(
        await watch('aaaaaaaaaaa', listened: const Duration(seconds: 4)),
        YtHistoryOutcome.tooShort,
      );
      expect(await events(), 0);
    });

    test('local history does not depend on the YouTube switch', () async {
      await container.read(dnaSettingsProvider.notifier).setHistoryConsent(true);
      final s = container.read(dnaSettingsProvider);
      expect(s.recordsHistory, isTrue);
      expect(s.recordsYouTube, isFalse);
    });
  });
}
