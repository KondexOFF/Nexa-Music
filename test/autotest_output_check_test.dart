import 'package:flutter_test/flutter_test.dart';

import '../integration_test/support/autotest_support.dart';

/// NEXA AutoTest: a recording made while the Windows output was muted or at
/// 0 % must be reported as "not measurable" (BLOCKED), never as a result.
void main() {
  test('recorder lines are split into fields, quoted values included', () {
    final f = Loopback.fields(
      'mode=process rate=48000 device="Speakers (Realtek Audio)" endpoint_mute=0',
    );
    expect(f['mode'], 'process');
    expect(f['rate'], '48000');
    expect(f['device'], 'Speakers (Realtek Audio)');
    expect(f['endpoint_mute'], '0');
  });

  test('normal output: the recording can be used', () {
    expect(
      Loopback.outputProblem(
        'mode=process frames=1 muted_seen=0 min_endpoint_volume=0.420 session_seen=1 min_session_volume=1.000',
      ),
      isNull,
    );
    // NEXA had no audio session yet: only the device counts.
    expect(
      Loopback.outputProblem('muted_seen=0 min_endpoint_volume=0.300 session_seen=0 min_session_volume=-1.000'),
      isNull,
    );
  });

  test('mute or 0 % at any moment makes the recording unusable', () {
    expect(
      Loopback.outputProblem('muted_seen=1 min_endpoint_volume=0.500 session_seen=1 min_session_volume=1.000'),
      contains('muted'),
    );
    expect(
      Loopback.outputProblem('muted_seen=0 min_endpoint_volume=0.000 session_seen=1 min_session_volume=1.000'),
      contains('Windows volume was at 0 %'),
    );
    expect(
      Loopback.outputProblem('muted_seen=0 min_endpoint_volume=0.600 session_seen=1 min_session_volume=0.000'),
      contains('Volume mixer'),
    );
  });

  test('an old recorder without these fields is not blocked by this check', () {
    expect(Loopback.outputProblem('mode=process frames=10 packets=3'), isNull);
    expect(Loopback.outputProblem(''), isNull);
  });
}
