import 'package:drift/drift.dart';

import '../../core/database/app_database.dart';
import '../../core/models/listening.dart';

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
          'FROM listening_events GROUP BY track_id',
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
