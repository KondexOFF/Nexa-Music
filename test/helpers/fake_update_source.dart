import 'dart:async';

import 'package:nexa_music/features/update/release.dart';
import 'package:nexa_music/features/update/update_source.dart';

/// No releases at all (widget tests: no network).
class NoReleasesSource implements UpdateSource {
  const NoReleasesSource();

  @override
  String get label => 'test';

  @override
  Future<List<ReleaseInfo>> releases() async => const [];

  @override
  Future<(Stream<List<int>>, int?)> download(ReleaseAsset asset) =>
      throw const UpdateException(UpdateProblem.notFound);
}

/// Releases and files from memory.
class FakeUpdateSource implements UpdateSource {
  FakeUpdateSource({
    this.list = const [],
    this.files = const {},
    this.error,
    this.chunk = 4096,
  });

  List<ReleaseInfo> list;

  /// Asset id -> bytes.
  Map<int, List<int>> files;
  UpdateException? error;
  final int chunk;
  int checks = 0;
  final List<int> downloads = [];

  @override
  String get label => 'fake';

  @override
  Future<List<ReleaseInfo>> releases() async {
    checks++;
    if (error != null) {
      throw error!;
    }
    return list;
  }

  @override
  Future<(Stream<List<int>>, int?)> download(ReleaseAsset asset) async {
    downloads.add(asset.id);
    final bytes = files[asset.id];
    if (bytes == null) {
      throw const UpdateException(UpdateProblem.notFound);
    }
    Stream<List<int>> chunks() async* {
      for (var i = 0; i < bytes.length; i += chunk) {
        yield bytes.sublist(i, i + chunk > bytes.length ? bytes.length : i + chunk);
      }
    }

    return (chunks(), bytes.length);
  }
}
