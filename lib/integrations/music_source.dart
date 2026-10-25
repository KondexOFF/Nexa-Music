import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart' show immutable;
import 'package:http/http.dart' as http;

import '../core/models/listening.dart' show tasteKey;
import '../core/models/track.dart';

/// Why a catalog request failed.
enum CatalogErrorKind {
  /// No network / the provider cannot be reached.
  offline,

  /// The provider limits how often it may be asked.
  rateLimited,

  /// A key / client id is missing or was rejected.
  notConfigured,

  /// Anything else the provider answered with.
  provider,
}

class CatalogException implements Exception {
  const CatalogException(this.kind, [this.detail]);

  final CatalogErrorKind kind;
  final String? detail;

  @override
  String toString() => 'CatalogException($kind${detail == null ? '' : ': $detail'})';
}

/// An official online catalog (Master Plan v1.0, Phase 6; D-017).
///
/// Implementations return [Track]s whose [Track.path] is the stream URL the
/// provider's API hands out for playback, and mark tracks the provider does
/// not allow to stream as unavailable with a reason - they are shown, never
/// promised.
abstract interface class MusicSource {
  TrackSource get source;

  /// False when the source needs a key the owner has not entered.
  bool get configured;

  Future<List<Track>> search(String query, {int limit = 20});

  /// Songs this catalog offers to NEXA Wave (E1), each with the basis the
  /// catalog chose it on. Only what [request] holds is sent to the
  /// provider: explicitly liked genres and artists - never the listening
  /// history, local files or excluded items. Without liked genres or
  /// artists the catalog's own popular songs are used.
  Future<List<WaveCandidate>> waveCandidates(WaveRequest request);
}

/// What NEXA Wave asks a catalog for (E1).
@immutable
class WaveRequest {
  const WaveRequest({
    this.genres = const [],
    this.artists = const [],
    this.limit = 12,
  });

  /// Liked genres (at most [maxTerms] are sent).
  final List<String> genres;

  /// Liked artists (at most [maxTerms] are sent).
  final List<String> artists;

  /// Wanted songs in total.
  final int limit;

  /// Each list is cut to this many words: few requests per refill.
  static const int maxTerms = 3;

  bool get hasTaste => genres.isNotEmpty || artists.isNotEmpty;
}

/// A catalog song offered to NEXA Wave and why the catalog returned it.
@immutable
class WaveCandidate {
  const WaveCandidate(this.track, this.basis);

  final Track track;

  /// Plain explanation shown as "why this song" when nothing in the user's
  /// own taste explains it better, e.g. "Popular on Audius in Electronic".
  final String basis;
}

/// Runs [requests] one after another and keeps what succeeded. Throws the
/// first error only when every request failed (so one bad word does not
/// hide the rest).
Future<List<WaveCandidate>> collectCandidates(
  List<Future<List<WaveCandidate>> Function()> requests,
) async {
  final found = <WaveCandidate>[];
  CatalogException? firstError;
  var succeeded = 0;
  for (final request in requests) {
    try {
      found.addAll(await request());
      succeeded++;
    } on CatalogException catch (e) {
      firstError ??= e;
      if (e.kind == CatalogErrorKind.offline ||
          e.kind == CatalogErrorKind.rateLimited ||
          e.kind == CatalogErrorKind.notConfigured) {
        break; // The next request would fail the same way.
      }
    }
  }
  if (succeeded == 0 && firstError != null) {
    throw firstError;
  }
  final seen = <int>{};
  return [
    for (final c in found)
      if (seen.add(c.track.id)) c,
  ];
}

/// Shared JSON GET with the error mapping every catalog uses.
Future<Object?> getJson(
  http.Client client,
  Uri uri, {
  Map<String, String> headers = const {},
  Duration timeout = const Duration(seconds: 12),
}) async {
  final http.Response response;
  try {
    response = await client.get(uri, headers: headers).timeout(timeout);
  } on SocketException catch (e) {
    throw CatalogException(CatalogErrorKind.offline, e.message);
  } on TimeoutException {
    throw const CatalogException(CatalogErrorKind.offline, 'timeout');
  } on http.ClientException catch (e) {
    throw CatalogException(CatalogErrorKind.offline, e.message);
  }
  switch (response.statusCode) {
    case 200:
      break;
    case 429:
      throw const CatalogException(CatalogErrorKind.rateLimited);
    case 401 || 403:
      throw CatalogException(
        CatalogErrorKind.notConfigured,
        'HTTP ${response.statusCode}',
      );
    default:
      throw CatalogException(
        CatalogErrorKind.provider,
        'HTTP ${response.statusCode}',
      );
  }
  try {
    return jsonDecode(utf8.decode(response.bodyBytes));
  } on FormatException {
    throw const CatalogException(CatalogErrorKind.provider, 'invalid JSON');
  }
}

/// Small JSON helpers (provider answers are untrusted input).
String? jsonString(Object? v) => v is String && v.trim().isNotEmpty ? v.trim() : null;

int? jsonInt(Object? v) => switch (v) {
  int i => i,
  double d => d.round(),
  String s => int.tryParse(s),
  _ => null,
};

/// Shortest and longest catalog song NEXA Wave plays: no snippets, no
/// hour-long DJ sets or radio shows in a song queue.
const Duration waveMinLength = Duration(seconds: 30);
const Duration waveMaxLength = Duration(minutes: 15);

/// Catalog "genres" that are not music.
const Set<String> nonMusicGenres = {
  'podcasts',
  'podcast',
  'audiobooks',
  'audiobook',
  'spoken word',
  'comedy',
};

/// Whether a catalog song may go into NEXA Wave: playable now (not removed,
/// gated or without a stream), a song-like length and music.
bool waveSuitable(Track t) {
  if (!t.available || t.path.isEmpty) {
    return false;
  }
  final d = t.duration;
  if (d != null && (d < waveMinLength || d > waveMaxLength)) {
    return false;
  }
  final genre = tasteKey(t.genre ?? '');
  return !nonMusicGenres.contains(genre);
}
