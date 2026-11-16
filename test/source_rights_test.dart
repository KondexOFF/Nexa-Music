import 'package:flutter_test/flutter_test.dart';
import 'package:nexa_music/core/audio/transition.dart';
import 'package:nexa_music/core/models/track.dart';
import 'package:nexa_music/features/mix_engine/mix_settings.dart';
import 'package:nexa_music/features/mix_engine/transition_planner.dart';

/// Crossfade audit (owner 2026-11-16, item 5): which sources NEXA's engine
/// may play and mix. Local files and Audius / Jamendo streams (D-025):
/// play + crossfade. YouTube and SoundCloud: never NEXA's engine, never an
/// overlap - their own visible players play them in their turn.
void main() {
  Track make(TrackSource source, String id, {String album = 'A'}) => Track(
    id: source == TrackSource.local ? id.hashCode & 0xffff : Track.onlineId(source, id),
    source: source,
    sourceTrackId: id,
    path: source == TrackSource.local ? 'C:/m/$id.flac' : 'https://x/$id',
    title: id,
    artist: 'Artist',
    album: album,
    duration: const Duration(minutes: 4),
    addedAt: DateTime(2026),
  );

  test('rights per source', () {
    for (final s in [TrackSource.local, TrackSource.audius, TrackSource.jamendo]) {
      final r = make(s, 'a').rights;
      expect(r.play, isTrue, reason: '$s plays in NEXA');
      expect(r.mix, isTrue, reason: '$s may be crossfaded');
      expect(s.isExternal, isFalse);
    }
    for (final s in [TrackSource.youtube, TrackSource.soundcloud]) {
      final r = make(s, 'a').rights;
      expect(r.play, isFalse, reason: '$s never in NEXA engine');
      expect(r.mix, isFalse, reason: '$s never mixed');
      expect(s.isExternal, isTrue);
    }
  });

  test('crossfade between every pair of engine sources, a cut next to '
      'YouTube / SoundCloud', () {
    const settings = MixSettings(albumGapless: false);
    final engine = [TrackSource.local, TrackSource.audius, TrackSource.jamendo];
    for (final a in engine) {
      for (final b in engine) {
        final plan = planTransition(settings, make(a, '1'), make(b, '2'));
        expect(plan.kind, TransitionKind.crossfade, reason: '$a -> $b');
        expect(plan.fade, const Duration(seconds: 6));
      }
    }
    for (final external in [TrackSource.youtube, TrackSource.soundcloud]) {
      for (final other in [...engine, external]) {
        expect(
          planTransition(settings, make(other, '1'), make(external, '2')).kind,
          TransitionKind.cut,
          reason: '$other -> $external',
        );
        expect(
          planTransition(settings, make(external, '1'), make(other, '2')).kind,
          TransitionKind.cut,
          reason: '$external -> $other',
        );
      }
    }
  });
}
