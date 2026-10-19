import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models/track.dart';
import '../../integrations/music_source.dart';
import 'catalog_providers.dart';

/// Results of one catalog for the current query.
@immutable
class SourceResults {
  const SourceResults({
    this.loading = false,
    this.tracks = const [],
    this.error,
  });

  final bool loading;
  final List<Track> tracks;
  final CatalogException? error;
}

@immutable
class DiscoverState {
  const DiscoverState({
    this.query = '',
    this.filter,
    this.results = const {},
  });

  final String query;

  /// Only this catalog (null: all).
  final TrackSource? filter;
  final Map<TrackSource, SourceResults> results;

  bool get searching => results.values.any((r) => r.loading);
}

/// One search over the permitted catalogs. Each catalog is asked on its
/// own, so one failing provider (offline, rate limit, missing key) never
/// hides the others or affects the local library.
class DiscoverController extends Notifier<DiscoverState> {
  int _generation = 0;

  @override
  DiscoverState build() => const DiscoverState();

  void setFilter(TrackSource? source) {
    state = DiscoverState(
      query: state.query,
      filter: source,
      results: state.results,
    );
  }

  Future<void> search(String query) async {
    final q = query.trim();
    final generation = ++_generation;
    final sources = [
      for (final s in ref.read(musicSourcesProvider))
        if (state.filter == null || state.filter == s.source) s,
    ];
    if (q.isEmpty) {
      state = DiscoverState(filter: state.filter);
      return;
    }
    state = DiscoverState(
      query: q,
      filter: state.filter,
      results: {
        for (final s in sources)
          s.source: s.configured
              ? const SourceResults(loading: true)
              : const SourceResults(
                  error: CatalogException(CatalogErrorKind.notConfigured),
                ),
      },
    );
    await Future.wait([
      for (final s in sources)
        if (s.configured) _searchOne(s, q, generation),
    ]);
  }

  Future<void> _searchOne(MusicSource s, String q, int generation) async {
    SourceResults result;
    try {
      result = SourceResults(tracks: await s.search(q));
    } on CatalogException catch (e) {
      result = SourceResults(error: e);
    } on Object catch (e) {
      result = SourceResults(
        error: CatalogException(CatalogErrorKind.provider, '$e'),
      );
    }
    if (!ref.mounted || generation != _generation) {
      return; // A newer search replaced this one.
    }
    state = DiscoverState(
      query: state.query,
      filter: state.filter,
      results: {...state.results, s.source: result},
    );
  }
}

final discoverProvider = NotifierProvider<DiscoverController, DiscoverState>(
  DiscoverController.new,
);
