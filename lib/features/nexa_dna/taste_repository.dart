import 'package:drift/drift.dart';

import '../../core/database/app_database.dart';
import '../../core/models/listening.dart';
import '../../core/models/track.dart';
import '../library/library_repository.dart' show LibraryRepository;

/// What the listening history says about one track.
class TrackStats {
  const TrackStats({
    this.plays = 0,
    this.completions = 0,
    this.fastSkips = 0,
    this.lateSkips = 0,
    this.lastPlayed,
  });

  final int plays;
  final int completions;

  /// Skipped within [TasteRepository.fastSkipLimit]: a weak negative signal.
  final int fastSkips;

  /// Skipped after that: a very weak negative signal.
  final int lateSkips;
  final DateTime? lastPlayed;
}

/// Local NEXA DNA data: listening history, explicit taste choices and
/// dislikes. Nothing leaves the device.
class TasteRepository {
  TasteRepository(this.db);

  final AppDatabase db;

  /// A skip before this point counts as a fast skip.
  static const Duration fastSkipLimit = Duration(seconds: 30);

  // ---- listening history ----

  Future<void> recordEvent(ListeningEvent event) => db
      .into(db.listeningEvents)
      .insert(
        ListeningEventsCompanion.insert(
          trackId: event.trackId,
          startedAt: event.startedAt,
          listenedMs: event.listened.inMilliseconds,
          durationMs: Value(event.duration?.inMilliseconds),
          endReason: event.reason.name,
          mode: event.context.name,
        ),
      );

  Stream<int> watchEventCount() {
    final count = db.listeningEvents.id.count();
    return (db.selectOnly(db.listeningEvents)..addColumns([count]))
        .watchSingle()
        .map((row) => row.read(count) ?? 0);
  }

  Future<int> eventCount() async {
    final count = db.listeningEvents.id.count();
    final row = await (db.selectOnly(
      db.listeningEvents,
    )..addColumns([count])).getSingle();
    return row.read(count) ?? 0;
  }

  /// Per-track summary of the whole history.
  Future<Map<int, TrackStats>> trackStats() async {
    final fast = fastSkipLimit.inMilliseconds;
    final rows = await db
        .customSelect(
          'SELECT track_id, COUNT(*) AS plays, '
          "SUM(CASE WHEN end_reason = 'completed' THEN 1 ELSE 0 END) "
          'AS completions, '
          "SUM(CASE WHEN end_reason = 'skipped' AND listened_ms < $fast "
          'THEN 1 ELSE 0 END) AS fast_skips, '
          "SUM(CASE WHEN end_reason = 'skipped' AND listened_ms >= $fast "
          'THEN 1 ELSE 0 END) AS late_skips, '
          'MAX(started_at) AS last_played '
          'FROM listening_events '
          "WHERE mode NOT IN ('youtube', 'soundcloud') GROUP BY track_id",
          readsFrom: {db.listeningEvents},
        )
        .get();
    return {
      for (final r in rows)
        r.read<int>('track_id'): TrackStats(
          plays: r.read<int>('plays'),
          completions: r.read<int>('completions'),
          fastSkips: r.read<int>('fast_skips'),
          lateSkips: r.read<int>('late_skips'),
          lastPlayed: r.readNullable<DateTime>('last_played'),
        ),
    };
  }

  /// Tracks of the last [limit] listenings, newest first (without repeats).
  Future<List<int>> recentTrackIds({int limit = 15}) async {
    final rows =
        await (db.select(db.listeningEvents)
              ..where(
                (e) => e.mode.isNotIn([
                  PlayContext.youtube.name,
                  PlayContext.soundcloud.name,
                ]),
              )
              ..orderBy([
                (e) => OrderingTerm.desc(e.startedAt),
                (e) => OrderingTerm.desc(e.id),
              ])
              ..limit(limit))
            .get();
    final ids = <int>[];
    for (final r in rows) {
      if (!ids.contains(r.trackId)) {
        ids.add(r.trackId);
      }
    }
    return ids;
  }

  /// Deletes the whole listening history.
  Future<int> clearHistory() => db.delete(db.listeningEvents).go();

  /// Deletes only the YouTube part of the history (E2.7b).
  Future<int> clearYouTubeHistory() => (db.delete(
    db.listeningEvents,
  )..where((e) => e.mode.equals(PlayContext.youtube.name))).go();

  // ---- Recently Played / Continue Listening (E2.7b) ----

  /// Newest listening per track, newest first (from the last [scan]
  /// listenings).
  Stream<List<HistoryEntry>> watchRecent({int limit = 20, int scan = 400}) {
    final q =
        db.select(db.listeningEvents).join([
            innerJoin(
              db.tracks,
              db.tracks.id.equalsExp(db.listeningEvents.trackId),
            ),
          ])
          ..orderBy([
            OrderingTerm.desc(db.listeningEvents.startedAt),
            OrderingTerm.desc(db.listeningEvents.id),
          ])
          ..limit(scan);
    return q.watch().map((rows) {
      final seen = <int>{};
      final list = <HistoryEntry>[];
      for (final r in rows) {
        final e = r.readTable(db.listeningEvents);
        if (!seen.add(e.trackId)) {
          continue;
        }
        list.add(
          HistoryEntry(
            track: LibraryRepository.toTrack(r.readTable(db.tracks)),
            playedAt: e.startedAt,
            listened: Duration(milliseconds: e.listenedMs),
            duration: e.durationMs == null
                ? null
                : Duration(milliseconds: e.durationMs!),
            reason: EndReason.values.asNameMap()[e.endReason] ??
                EndReason.stopped,
          ),
        );
        if (list.length >= limit) {
          break;
        }
      }
      return list;
    });
  }


  // ---- explicit taste ----

  static TasteChoice _toChoice(TasteItemRow row) => TasteChoice(
    kind: TasteKind.values.byName(row.kind),
    value: row.value,
    excluded: row.excluded,
    weight: row.weight,
  );

  Stream<List<TasteChoice>> watchItems() =>
      (db.select(db.tasteItems)..orderBy([
            (t) => OrderingTerm.asc(t.kind),
            (t) => OrderingTerm.asc(t.valueKey),
          ]))
          .watch()
          .map((rows) => rows.map(_toChoice).toList());

  Future<List<TasteChoice>> getItems() async =>
      (await db.select(db.tasteItems).get()).map(_toChoice).toList();

  /// Likes ([excluded] false) or excludes a genre / artist.
  Future<void> setItem(
    TasteKind kind,
    String value, {
    bool excluded = false,
  }) => db
      .into(db.tasteItems)
      .insert(
        TasteItemsCompanion.insert(
          kind: kind.name,
          value: value.trim(),
          valueKey: tasteKey(value),
          excluded: Value(excluded),
          updatedAt: DateTime.now(),
        ),
        onConflict: DoUpdate(
          (_) => TasteItemsCompanion(
            value: Value(value.trim()),
            excluded: Value(excluded),
            updatedAt: Value(DateTime.now()),
          ),
          target: [db.tasteItems.kind, db.tasteItems.valueKey],
        ),
      );

  Future<void> removeItem(TasteKind kind, String value) =>
      (db.delete(db.tasteItems)..where(
            (t) => t.kind.equals(kind.name) & t.valueKey.equals(tasteKey(value)),
          ))
          .go();

  // ---- dislikes ----

  /// An explicit dislike also removes the track from favorites.
  Future<void> setDisliked(int trackId, bool disliked) =>
      (db.update(db.tracks)..where((t) => t.id.equals(trackId))).write(
        TracksCompanion(
          disliked: Value(disliked),
          dislikedAt: Value(disliked ? DateTime.now() : null),
          favorite: disliked ? const Value(false) : const Value.absent(),
          favoritedAt: disliked ? const Value(null) : const Value.absent(),
        ),
      );

  /// Removes all taste choices and dislikes (history is cleared separately).
  Future<void> resetTaste() => db.transaction(() async {
    await db.delete(db.tasteItems).go();
    await (db.update(db.tracks)..where((t) => t.disliked.equals(true))).write(
      const TracksCompanion(disliked: Value(false), dislikedAt: Value(null)),
    );
  });
}

/// The newest listening of a track (Recently Played, Continue Listening).
class HistoryEntry {
  const HistoryEntry({
    required this.track,
    required this.playedAt,
    required this.listened,
    required this.reason,
    this.duration,
  });

  final Track track;
  final DateTime playedAt;
  final Duration listened;
  final Duration? duration;
  final EndReason reason;

  /// Long tracks and videos (mixes, talks, podcasts) left in the middle -
  /// worth continuing from [listened]. Short songs simply start again.
  static const Duration continueMinLength = Duration(minutes: 8);
  static const Duration _margin = Duration(seconds: 30);

  bool get canContinue {
    final d = duration;
    return reason != EndReason.completed &&
        d != null &&
        d >= continueMinLength &&
        listened >= _margin &&
        listened <= d - _margin;
  }
}
