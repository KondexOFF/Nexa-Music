import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/strings.dart';
import '../../core/models/listening.dart';
import '../../core/models/track.dart';
import '../../integrations/music_source.dart';
import '../discover/catalog_providers.dart';
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
    this.onlineNote,
    this.onlineReady = 0,
  });

  /// The next suggestions (preview on the Wave page).
  final List<WaveItem> items;
  final bool loading;

  /// Why there is nothing to suggest, if so.
  final String? message;

  /// E1: why online picks are missing or incomplete (offline, no catalog,
  /// rate limit), shown under the Wave settings.
  final String? onlineNote;

  /// E1: catalog songs ready for the Wave in this session.
  final int onlineReady;

  WaveState copyWith({
    List<WaveItem>? items,
    bool? loading,
    String? message,
    bool clearMessage = false,
    String? onlineNote,
    bool clearOnlineNote = false,
    int? onlineReady,
  }) => WaveState(
    items: items ?? this.items,
    loading: loading ?? this.loading,
    message: clearMessage ? null : (message ?? this.message),
    onlineNote: clearOnlineNote ? null : (onlineNote ?? this.onlineNote),
    onlineReady: onlineReady ?? this.onlineReady,
  );
}

/// NEXA Wave: an endless personal queue from the user's own playable songs.
/// While the Wave plays, new picks are appended before the queue runs out.
///
/// E1: when the user switches on online picks, songs from the permitted
/// catalogs (Audius, Jamendo, through [MusicSource]) join the same queue.
/// They are kept in memory for this session only (never saved, never in
/// the history); when the catalogs cannot be reached the Wave simply goes
/// on with the library.
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

  /// Catalog songs per catalog and request.
  static const int onlinePerSource = 12;

  /// The whole catalog lookup may take this long; then the Wave goes on
  /// without (new) online picks.
  static const Duration onlineTimeout = Duration(seconds: 8);

  /// Online picks are asked for again after this time (or when used up,
  /// or when the taste or the catalog settings change).
  static const Duration onlineMaxAge = Duration(minutes: 30);

  /// After a failed lookup the catalogs are asked again after this time.
  static const Duration onlineRetry = Duration(minutes: 2);

  /// Catalog songs offered to the Wave in this session (memory only).
  List<WaveCandidate> _onlinePool = const [];
  DateTime? _onlineAt;
  Duration _onlineValid = onlineMaxAge;
  Future<void>? _onlineLoading;

  /// Catalog songs the user hid with "Not for me" (this session only).
  final Set<int> _hiddenOnline = {};

  @override
  WaveState build() {
    ref.listen(playerProvider, (previous, next) {
      if (next.context == PlayContext.wave &&
          next.current != null &&
          next.upNext.length < refillBelow) {
        unawaited(_refill());
      }
    });
    // New taste or catalog choices: ask the catalogs again next time.
    ref.listen(tasteItemsProvider, (_, _) => _onlineAt = null);
    ref.listen(catalogSettingsProvider, (_, _) => _onlineAt = null);
    ref.listen(dnaSettingsProvider.select((s) => s.waveOnline), (_, on) {
      _onlineAt = null;
      if (!on) {
        _onlinePool = const [];
        state = state.copyWith(clearOnlineNote: true, onlineReady: 0);
      }
    });
    return const WaveState();
  }

  /// Fills the session pool of catalog songs when online picks are on.
  Future<void> _loadOnline({bool force = false}) {
    final running = _onlineLoading;
    if (running != null) {
      return running;
    }
    final settings = ref.read(dnaSettingsProvider);
    final at = _onlineAt;
    if (!settings.waveOnline) {
      return Future<void>.value();
    }
    if (!force && at != null && DateTime.now().difference(at) < _onlineValid) {
      return Future<void>.value();
    }
    // A failing lookup must never stop the Wave: it goes on with the library.
    final future = _fetchOnline()
        .catchError((Object _) {})
        .whenComplete(() => _onlineLoading = null);
    _onlineLoading = future;
    return future;
  }

  Future<void> _fetchOnline() async {
    final sources = [
      for (final s in ref.read(musicSourcesProvider))
        if (s.configured) s,
    ];
    _onlineAt = DateTime.now();
    if (sources.isEmpty) {
      _onlinePool = const [];
      _onlineValid = onlineRetry;
      state = state.copyWith(onlineNote: S.waveOnlineNoSource, onlineReady: 0);
      return;
    }
    final taste = await ref.read(tasteRepositoryProvider).getItems();
    // Only explicit likes are sent - never excluded items or the history.
    final request = WaveRequest(
      genres: [
        for (final c in taste)
          if (!c.excluded && c.kind == TasteKind.genre) c.value,
      ],
      artists: [
        for (final c in taste)
          if (!c.excluded && c.kind == TasteKind.artist) c.value,
      ],
      limit: onlinePerSource,
    );
    final answers = await Future.wait([
      for (final s in sources) _ask(s, request),
    ]);
    if (!ref.mounted) {
      return;
    }
    final pool = <WaveCandidate>[];
    final failed = <(MusicSource, CatalogException)>[];
    for (var i = 0; i < sources.length; i++) {
      final (found, error) = answers[i];
      pool.addAll(found);
      if (error != null) {
        failed.add((sources[i], error));
      }
    }
    _onlinePool = pool;
    _onlineValid = failed.isEmpty ? onlineMaxAge : onlineRetry;
    String? note;
    if (failed.isNotEmpty) {
      final why = _why(failed.first.$2.kind);
      note = failed.length == sources.length
          ? S.waveOnlineUnavailable(why)
          : S.waveOnlinePartly(
              failed.map((f) => f.$1.source.label).join(', '),
              why,
            );
    }
    state = state.copyWith(
      onlineNote: note,
      clearOnlineNote: note == null,
      onlineReady: pool.length,
    );
  }

  Future<(List<WaveCandidate>, CatalogException?)> _ask(
    MusicSource source,
    WaveRequest request,
  ) async {
    try {
      final found = await source.waveCandidates(request).timeout(onlineTimeout);
      return (found, null);
    } on CatalogException catch (e) {
      return (const <WaveCandidate>[], e);
    } on TimeoutException {
      return (
        const <WaveCandidate>[],
        const CatalogException(CatalogErrorKind.offline, 'timeout'),
      );
    } on Object catch (e) {
      return (
        const <WaveCandidate>[],
        CatalogException(CatalogErrorKind.provider, '$e'),
      );
    }
  }

  static String _why(CatalogErrorKind kind) => switch (kind) {
    CatalogErrorKind.offline => S.waveOnlineWhyOffline,
    CatalogErrorKind.rateLimited => S.waveOnlineWhyRateLimited,
    CatalogErrorKind.notConfigured => S.waveOnlineWhyKey,
    CatalogErrorKind.provider => S.waveOnlineWhyError,
  };

  /// Catalog songs not yet queued or hidden in this session.
  bool _onlineLeft(Set<int> skip) => _onlinePool.any(
    (c) => !skip.contains(c.track.id) && !_hiddenOnline.contains(c.track.id),
  );

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
    final ranker = ref.read(waveRankerProvider);
    final local = ranker.rank(
      tracks: tracks,
      taste: choices,
      stats: stats,
      recent: {...recent, ...skip},
      discovery: settings.discovery,
      limit: limit,
      random: ref.read(waveRandomProvider),
    );
    var items = local;
    if (settings.waveOnline && _onlinePool.isNotEmpty) {
      // Catalog songs: same exclusions and likes, no history, no repeats
      // within the session, hidden ones left out.
      final online = ranker.rank(
        tracks: [for (final c in _onlinePool) c.track],
        taste: choices,
        recent: {...skip, ..._hiddenOnline},
        discovery: settings.discovery,
        limit: limit,
        random: ref.read(waveRandomProvider),
        basis: {for (final c in _onlinePool) c.track.id: c.basis},
        repeatWhenEmpty: false,
      );
      items = WaveRanker.merge(
        local,
        online,
        discovery: settings.discovery,
        limit: limit,
      );
    }
    state = items.isEmpty
        ? state.copyWith(message: S.waveNothingLeft)
        : state.copyWith(clearMessage: true);
    return items;
  }

  /// Recomputes the preview of the next picks.
  Future<void> refresh() async {
    state = state.copyWith(loading: true);
    try {
      await _loadOnline();
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
    await _loadOnline();
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
      if (!_onlineLeft({..._queued, ...inQueue})) {
        await _loadOnline(force: true); // Used up: ask the catalogs again.
      }
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
  /// A catalog song is only hidden for this session ("Not for me"): online
  /// songs are not saved, so nothing about it is stored.
  Future<void> dislike(Track track) async {
    if (track.isOnline) {
      _hiddenOnline.add(track.id);
    } else {
      await ref.read(tasteRepositoryProvider).setDisliked(track.id, true);
    }
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
