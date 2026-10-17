import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nexa_music/app/app.dart';

bool _fontsLoaded = false;

/// Loads the bundled Manrope font so layout tests measure real text widths
/// (the default test font is much wider and would distort overflow checks).
Future<void> loadNexaFonts() async {
  if (_fontsLoaded) {
    return;
  }
  final loader = FontLoader('Manrope');
  for (final weight in [
    'Regular',
    'Medium',
    'SemiBold',
    'Bold',
    'ExtraBold',
  ]) {
    loader.addFont(rootBundle.load('assets/fonts/Manrope-$weight.ttf'));
  }
  await loader.load();
  _fontsLoaded = true;
}

/// Pumps the full app at a logical window [size] with looping decoration
/// animations disabled.
Future<void> pumpNexaApp(WidgetTester tester, Size size) async {
  await loadNexaFonts();
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = size;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    const ProviderScope(child: NexaApp(ambientMotion: false)),
  );
  await settle(tester);
}

/// Lets transitions and entry animations finish (the app has no endless
/// animation when ambientMotion is false, but pumpAndSettle is avoided to
/// keep the tests deterministic).
Future<void> settle(WidgetTester tester) async {
  for (var i = 0; i < 12; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

const Size size1280 = Size(1280, 720);
const Size size1920 = Size(1920, 1080);
const Size size1024 = Size(1024, 640);
