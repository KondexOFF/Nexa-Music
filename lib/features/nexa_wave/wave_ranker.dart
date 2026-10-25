import 'dart:math' as math;

import 'package:flutter/foundation.dart';

import '../../app/strings.dart';
import '../../core/models/listening.dart';
import '../../core/models/track.dart';
import '../nexa_dna/taste_repository.dart';

/// One NEXA Wave suggestion with the main reason it was chosen.
@immutable
class WaveItem {
  const WaveItem({
    required this.track,
    required this.score,
    required this.reason,
    required this.fresh,
  });

  final Track track;
  final double score;

  /// "Why this track" - shown in the Wave list and on Now Playing.
  final String reason;

  /// Never played before (a discovery rather than a familiar track).
  final bool fresh;
}

/// NEXA Wave v1 ranker: a small, explainable, local scoring of the user's
/// own playable tracks (Master Plan v1.0, Phase 5).
///
/// Signals, strongest first:
/// * explicit dislike, excluded genre / artist, unavailable file - never
///   suggested;
/// * liked artist (+3), liked genre (+2), favorite (+2.5);
/// * history (only with consent): finished listenings (+0.6 each), fast
///   skips (-0.9 each, a weaker signal than a dislike, which excludes),
///   later skips (-0.3 each), each capped at 5;
/// * familiar <-> discovery: unplayed tracks get up to +3 (discovery 1),
///   played ones up to +1.5 (discovery 0);
/// * a little randomness so the Wave does not repeat itself.
/// Recently played tracks are left out while anything else is available.
///
/// E1: catalog songs (Audius, Jamendo) are ranked by the same rules - the
/// same exclusions, liked artists and genres - but they never have history,
/// so they always count as discoveries; their "why" is the catalog's basis
/// unless the user's own taste explains them. [merge] then mixes them into
/// the local picks by the Familiar <-> Discovery setting.
class WaveRanker {
  const WaveRanker();

  static const double likedArtist = 3;
  static const double likedGenre = 2;
  static const double favorite = 2.5;
  static const double perCompletion = 0.6;
  static const double perFastSkip = -0.9;
  static const double perLateSkip = -0.3;
  static const int signalCap = 5;
  static const double newMax = 3;
  static const double familiarMax = 1.5;

  /// Whether [track] may be suggested at all.
  static bool excluded(Track track, List<TasteChoice> taste) {
    if (!track.available || track.disliked || !track.rights.play) {
      return true;
    }
    final artist = tasteKey(track.artist);
    final genres = genreTokens(track.genre).map(tasteKey).toSet();
    for (final c in taste) {
      if (!c.excluded) {
        continue;
      }
      if (c.kind == TasteKind.artist && c.key == artist) {
        return true;
      }
      if (c.kind == TasteKind.genre && genres.contains(c.key)) {
        return true;
      }
    }
    return false;
  }

  List<WaveItem> rank({
    required List<Track> tracks,
    List<TasteChoice> taste = const [],
    Map<int, TrackStats> stats = const {},
    Set<int> recent = const {},
    Set<int> skip = const {},
    double discovery = 0.3,
    int limit = 20,
    double jitter = 0.75,
    math.Random? random,
    Map<int, String> basis = const {},
    bool repeatWhenEmpty = true,
  }) {
    final rnd = random ?? math.Random();
    final d = discovery.clamp(0.0, 1.0).toDouble();
    final likedArtists = {
      for (final c in taste)
        if (!c.excluded && c.kind == TasteKind.artist) c.key,
    };
    final likedGenres = {
      for (final c in taste)
        if (!c.excluded && c.kind == TasteKind.genre) c.key,
    };

    final eligible = [
      for (final t in tracks)
        if (!skip.contains(t.id) && !excluded(t, taste)) t,
    ];
    var pool = eligible.where((t) => !recent.contains(t.id)).toList();
    final onlyRecent = pool.isEmpty && repeatWhenEmpty;
    if (onlyRecent) {
      pool = eligible; // Small library: repeat rather than stop.
    }

    final scored = <WaveItem>[];
    for (final t in pool) {
      var score = 0.0;
      final reasons = <(double, String)>[];
      void add(double value, String reason) {
        score += value;
        reasons.add((value, reason));
      }

      if (likedArtists.contains(tasteKey(t.artist))) {
        add(likedArtist, S.reasonLikedArtist(t.artist));
      }
      final genre = genreTokens(
        t.genre,
      ).where((g) => likedGenres.contains(tasteKey(g))).firstOrNull;
      if (genre != null) {
        add(likedGenre, S.reasonLikedGenre(genre));
      }
      if (t.favorite) {
        add(favorite, S.reasonFavorite);
      }
      final st = stats[t.id];
      final played = st != null && st.plays > 0;
      if (played) {
        final affinity =
            math.min(st.completions, signalCap) * perCompletion +
            math.min(st.fastSkips, signalCap) * perFastSkip +
            math.min(st.lateSkips, signalCap) * perLateSkip;
        add(affinity, S.reasonOftenFinished);
        add((1 - d) * familiarMax, S.reasonFamiliar);
      } else {
        add(
          d * newMax,
          t.isOnline
              ? basis[t.id] ?? S.basisPopular(t.source.label)
              : S.reasonNew,
        );
      }
      score += rnd.nextDouble() * jitter;

      reasons.sort((a, b) => b.$1.compareTo(a.$1));
      final best = reasons.firstOrNull;
      final reason = onlyRecent
          ? S.reasonRepeat
          : (best == null || best.$1 <= 0
                ? (t.isOnline
                      ? basis[t.id] ?? S.basisPopular(t.source.label)
                      : S.reasonFromLibrary)
                : best.$2);
      scored.add(
        WaveItem(track: t, score: score, reason: reason, fresh: !played),
      );
    }
    scored.sort((a, b) => b.score.compareTo(a.score));
    return _spreadArtists(scored, limit);
  }

  /// At most this share of a Wave batch comes from the catalogs (at
  /// Discovery 100 %).
  static const double maxOnlineShare = 0.5;

  /// How many of [limit] picks may come from the catalogs: none at
  /// Familiar (0), growing to [maxOnlineShare] at Discovery (1), at least
  /// one as soon as Discovery is above 0.
  static int onlineSlots(double discovery, int limit) {
    final d = discovery.clamp(0.0, 1.0).toDouble();
    if (d <= 0 || limit <= 0) {
      return 0;
    }
    return math.max(1, (limit * maxOnlineShare * d).round());
  }

  /// One Wave batch from the local and the catalog picks (each already
  /// ranked): [onlineSlots] catalog songs spread evenly between the local
  /// ones, starting with a local song. When one side runs short the other
  /// fills the batch; a "Familiar" setting (0) never adds catalog songs.
  static List<WaveItem> merge(
    List<WaveItem> local,
    List<WaveItem> online, {
    required double discovery,
    required int limit,
  }) {
    if (onlineSlots(discovery, limit) == 0 || online.isEmpty) {
      return local.take(limit).toList();
    }
    var onlineCount = math.min(onlineSlots(discovery, limit), online.length);
    final localCount = math.min(local.length, limit - onlineCount);
    onlineCount = math.min(online.length, limit - localCount);
    final total = localCount + onlineCount;
    final result = <WaveItem>[];
    var li = 0;
    var oi = 0;
    for (var i = 0; i < total; i++) {
      // Catalog songs wanted after i + 1 picks, spread over the batch.
      final wanted = ((i + 1) * onlineCount) ~/ total;
      if ((oi < wanted && oi < onlineCount) || li >= localCount) {
        result.add(online[oi++]);
      } else {
        result.add(local[li++]);
      }
    }
    return result;
  }

  /// Avoids the same artist twice in a row when a close alternative exists.
  static List<WaveItem> _spreadArtists(List<WaveItem> sorted, int limit) {
    final pool = [...sorted];
    final result = <WaveItem>[];
    while (result.length < limit && pool.isNotEmpty) {
      final last = result.isEmpty ? null : tasteKey(result.last.track.artist);
      var pick = 0;
      for (var i = 0; i < math.min(5, pool.length); i++) {
        if (tasteKey(pool[i].track.artist) != last) {
          pick = i;
          break;
        }
      }
      result.add(pool.removeAt(pick));
    }
    return result;
  }
}
