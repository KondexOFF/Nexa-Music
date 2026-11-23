import 'package:flutter_test/flutter_test.dart';
import 'package:nexa_music/core/audio/transition.dart';
import 'package:nexa_music/core/models/track.dart';
import 'package:nexa_music/features/library/tag_reader.dart' show unknownAlbum;
import 'package:nexa_music/features/mix_engine/mix_settings.dart';
import 'package:nexa_music/features/mix_engine/transition_planner.dart';
import 'package:nexa_music/features/nexa_wave/wave_ranker.dart';

/// Regression investigation 2026-10-29 (owner: "Crossfade stopped
/// working", E2-07 FAIL). The owner's settings: 6 local songs without album
/// tags, Smart Mix 12 s, NEXA Wave with online picks at Discovery 100 %.
/// Up to E2, catalog streams were never mixed and the Wave alternates local
/// and catalog songs, so no transition of such a Wave was a crossfade.
/// D-025 (2026-11-15): catalog streams crossfade too - every transition of
/// that Wave crossfades.
void main() {
  Track local(int id) => Track(
    id: id,
    source: TrackSource.local,
    sourceTrackId: 'l$id',
    path: 'C:/music/$id.mp3',
    title: 'Local $id',
    artist: 'Artist $id',
    album: unknownAlbum,
    duration: const Duration(minutes: 3, seconds: 30),
    addedAt: DateTime(2026),
  );
  Track online(int n) => Track(
    id: Track.onlineId(TrackSource.audius, 'a$n'),
    source: TrackSource.audius,
    sourceTrackId: 'a$n',
    path: 'https://stream.example/a$n',
    title: 'Online $n',
    artist: 'Online artist $n',
    album: 'Audius',
    duration: const Duration(minutes: 3),
    addedAt: DateTime(2026),
  );
  // Library songs not played yet and catalog songs: all new to the user.
  WaveItem item(Track t) =>
      WaveItem(track: t, score: 1, reason: 'test', fresh: true);

  const settings = MixSettings(
    mode: TransitionMode.smartMix,
    crossfadeSeconds: 12,
  );

  Map<TransitionKind, int> transitions(double discovery) {
    final wave = WaveRanker.compose(
      [for (var i = 1; i <= 6; i++) item(local(i))],
      [for (var i = 1; i <= 10; i++) item(online(i))],
      discovery: discovery,
      limit: 12,
    );
    final kinds = <TransitionKind, int>{};
    for (var i = 0; i + 1 < wave.length; i++) {
      final k = planTransition(settings, wave[i].track, wave[i + 1].track).kind;
      kinds[k] = (kinds[k] ?? 0) + 1;
    }
    return kinds;
  }

  test('Familiar (online picks not mixed in): every transition crossfades', () {
    expect(transitions(0), {TransitionKind.crossfade: 5});
  });

  test('Discovery 100 % with online picks: local and catalog songs alternate '
      'and every transition crossfades 12 s (D-025)', () {
    expect(transitions(1), {TransitionKind.crossfade: 11});
  });

  test('two local songs without album tags crossfade 12 s (not gapless)', () {
    final plan = planTransition(settings, local(1), local(2));
    expect(plan.kind, TransitionKind.crossfade);
    expect(plan.fade, const Duration(seconds: 12));
  });
}
