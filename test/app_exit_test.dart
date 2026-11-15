import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nexa_music/app/app.dart';

import 'helpers/fake_engine.dart';
import 'helpers/test_app.dart';

/// Closing the window (Windows sends "System.requestAppExit" to Flutter):
/// NEXA releases its audio players before it agrees to exit, so libmpv
/// cannot deliver events into a stopped engine (crash on exit, 2026-10-29).
void main() {
  testWidgets('an exit request releases the playback engine, then exits',
      (tester) async {
    final engine = FakeEngine();
    await loadNexaFonts();
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = size1280;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: testOverrides(engine: engine),
        child: const NexaApp(ambientMotion: false),
      ),
    );
    await settle(tester);
    ByteData? reply;
    await tester.binding.defaultBinaryMessenger.handlePlatformMessage(
      'flutter/platform',
      const JSONMethodCodec().encodeMethodCall(
        const MethodCall('System.requestAppExit', <String, Object?>{
          'type': 'cancelable',
        }),
      ),
      (data) => reply = data,
    );
    await settle(tester);
    expect(engine.disposed, isTrue);
    final answer = const JSONMethodCodec().decodeEnvelope(reply!);
    expect(answer, {'response': 'exit'});
  });
}
