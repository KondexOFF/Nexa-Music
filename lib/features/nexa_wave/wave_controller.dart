import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/strings.dart';
import '../../core/models/listening.dart';
import '../../core/models/track.dart';
import '../library/library_providers.dart';
import '../nexa_dna/dna_providers.dart';
import '../nexa_dna/taste_repository.dart';
import '../player/player_controller.dart';
import 'wave_ranker.dart';

/// The ranker (tests may replace it with a seeded one).
final waveRankerProvider = Provider<WaveRanker>((ref) => const WaveRanker());

/// Randomness of the Wave (tests use a fixed seed).
final waveRandomProvider = Provider<math.Random>((ref) => math.Random());

@immutable
class WaveState {
  const WaveState({
    this.items = const [],
    this.loading = false,
    this.message,
  });

  /// The next suggestions (preview on the Wave page).
  final List<WaveItem> items;
  final bool loading;

  /// Why there is nothing to suggest, if so.
  final String? message;

  WaveState copyWith({
    List<WaveItem>? items,
    bool? loading,
    String? message,
    bool clearMessage = false,
  }) => WaveState(
    items: items ?? this.items,
    loading: loading ?? this.loading,
    message: clearMessage ? null : (message ?? this.message),
  );
}

/// NEXA Wave v1: an endless personal queue from the user's own playable
/// songs. While the Wave plays, new picks are appended before the queue
/// runs out.
class WaveController extends Notifier<WaveState> {
  /// Picks added to the player per batch.
  static const int batchSize = 8;

  /// New picks are added when fewer songs than this are left.
  static const int refillBelow = 3;

  /// Why each song was suggested (by track id) for this app session.
  final Map<int, String> _reasons = {};

  /// Songs the Wave already queued in this session (not saved anywhere).
  final Set<int> _queued = {};
  bool _refilling = false;

  @override
  WaveState build() {
    ref.listen(playerProvider, (previous, next) {
      if (next.context == PlayContext.wave &&
          next.current != null &&
          next.upNext.length < refillBelow) {
        unawaited(_refill());
      }
    });
    return const WaveState();
  }

  /// Why [trackId] was suggested (null when it did not come from the Wave).
  String? reasonFor(int trackId) => _reasons[trackId];

  Future<List<WaveItem>> _rank({
    required Set<int> skip,
    int limit = 20,
  }) async {
    final library = ref.read(libraryRepositoryProvider);
    final taste = ref.read(tasteRepositoryProvider);
    final settings = ref.read(dnaSettingsProvider);
    final tracks = await library.getTracks();
    final choices = await taste.getItems();
    // History is only used while the user allows it.
    final useHistory = settings.historyConsent;
    final stats = useHistory
        ? await taste.trackStats()
        : const <int, TrackStats>{};
    final recent = useHistory
        ? (await taste.recentTrackIds()).toSet()
        : const <int>{};
    if (tracks.isEmpty) {
      state = state.copyWith(message: S.waveEmptyLibrary);
      return const [];
    }
    final items = ref
        .read(waveRankerProvider)
        .rank(
          tracks: tracks,
          taste: choices,
          stats: stats,
          recent: {...recent, ...skip},
          discovery: settings.discovery,
          limit: limit,
          random: ref.read(waveRandomProvider),
        );
    state = items.isEmpty
        ? state.copyWith(message: S.waveNothingLeft)
        : state.copyWith(clearMessage: true);
    return items;
  }

  /// Recomputes the preview of the next picks.
  Future<void> refresh() async {
    state = state.copyWith(loading: true);
    try {
      final items = await _rank(skip: const {});
      if (ref.mounted) {
        state = state.copyWith(items: items, loading: false);
      }
    } on Object {
      if (ref.mounted) {
        state = state.copyWith(loading: false);
      }
    }
  }

  /// Starts the Wave: replaces the queue with fresh picks.
  Future<void> start() async {
    _queued.clear();
    final items = await _rank(skip: const {}, limit: batchSize);
    if (items.isEmpty || !ref.mounted) {
      return;
    }
    _remember(items);
    await ref
        .read(playerProvider.notifier)
        .playTracks(
          [for (final i in items) i.track],
          context: PlayContext.wave,
        );
    await refresh();
  }

  void _remember(List<WaveItem> items) {
    for (final i in items) {
      _reasons[i.track.id] = i.reason;
      _queued.add(i.track.id);
    }
  }

  Future<void> _refill() async {
    if (_refilling) {
      return;
    }
    _refilling = true;
    try {
      final player = ref.read(playerProvider);
      final inQueue = {for (final e in player.queue) e.track.id};
      var items = await _rank(
        skip: {..._queued, ...inQueue},
        limit: batchSize,
      );
      if (items.isEmpty) {
        // Everything was queued once in this session: start a new round,
        // still without the songs that are already in the queue.
        _queued.clear();
        items = await _rank(skip: inQueue, limit: batchSize);
      }
      if (items.isEmpty || !ref.mounted) {
        return;
      }
      if (ref.read(playerProvider).context != PlayContext.wave) {
        return; // The user started something else meanwhile.
      }
      _remember(items);
      ref.read(playerProvider.notifier).addToQueue([
        for (final i in items) i.track,
      ]);
      await refresh();
    } on Object {
      // A failed refill only means the Wave ends with the current queue.
    } finally {
      _refilling = false;
    }
  }

  /// Explicit dislike: never suggested again; a playing Wave song is skipped.
  Future<void> dislike(Track track) async {
    await ref.read(tasteRepositoryProvider).setDisliked(track.id, true);
    final player = ref.read(playerProvider);
    if (player.context != PlayContext.wave) {
      // Library playback is the user's own choice: only remember it.
      state = state.copyWith(
        items: [
          for (final i in state.items)
            if (i.track.id != track.id) i,
        ],
      );
      return;
    }
    final upcoming = player.upNext
        .where((e) => e.track.id == track.id)
        .toList();
    if (player.current?.id == track.id) {
      await ref.read(playerProvider.notifier).next();
    }
    for (final e in upcoming) {
      ref.read(playerProvider.notifier).removeFromQueue(e.uid);
    }
    state = state.copyWith(
      items: [
        for (final i in state.items)
          if (i.track.id != track.id) i,
      ],
    );
  }
}

final waveProvider = NotifierProvider<WaveController, WaveState>(
  WaveController.new,
);
