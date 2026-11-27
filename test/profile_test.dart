import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:nexa_music/app/app.dart';
import 'package:nexa_music/app/strings.dart';
import 'package:nexa_music/app/theme/tokens.dart';
import 'package:nexa_music/core/database/app_database.dart';
import 'package:nexa_music/features/home/home_page.dart';
import 'package:nexa_music/features/profile/profile.dart';
import 'package:nexa_music/features/profile/profile_page.dart';
import 'package:nexa_music/ui/ambient_light.dart';
import 'package:path/path.dart' as p;

import 'helpers/test_app.dart';

/// D-042 Local Profile: name, picture, accent, atmosphere, animations and
/// "Reset appearance" - stored locally, no music touched.
void main() {
  late Directory temp;

  setUp(() => temp = Directory.systemTemp.createTempSync('nexa_profile_test'));
  tearDown(() {
    // The tokens are global: back to the default look for other tests.
    final a = accentChoices.first;
    NexaColors.applyAccent(color: a.color, deep: a.deep, glow: a.glow);
    NexaMotion.applyScale(1);
    try {
      temp.deleteSync(recursive: true);
    } on FileSystemException {
      // Best effort on Windows.
    }
  });

  List<Override> overrides(AppDatabase db, {String? picked}) => [
    ...testOverrides(database: db),
    profileDirProvider.overrideWith(
      (ref) async => Directory(p.join(temp.path, 'profile')),
    ),
    avatarPickerProvider.overrideWithValue(() async => picked),
  ];

  Future<void> flush() => Future<void>.delayed(const Duration(milliseconds: 20));

  group('ProfileController', () {
    test('name, accent, atmosphere and animations are saved and come back',
        () async {
      final db = memoryDatabase();
      final c1 = ProviderContainer(overrides: overrides(db));
      c1.read(profileProvider);
      await flush();
      final n = c1.read(profileProvider.notifier);
      await n.setNickname('   Dmytro    the   Listener  ');
      await n.setAccent('aqua');
      await n.setAtmosphere(false);
      await n.setMotion(MotionLevel.reduced);
      expect(c1.read(profileProvider).nickname, 'Dmytro the Listener');
      // Not disposed: the second container reads the same database.
      final c2 = ProviderContainer(overrides: overrides(db));
      c2.read(profileProvider);
      await flush();
      final s = c2.read(profileProvider);
      expect(s.loaded, isTrue);
      expect(s.nickname, 'Dmytro the Listener');
      expect(s.accentId, 'aqua');
      expect(s.atmosphere, isFalse);
      expect(s.motion, MotionLevel.reduced);
      c2.dispose();
      c1.dispose();
    });

    test('a very long name is cut; an unknown accent falls back to violet',
        () async {
      final c = ProviderContainer(overrides: overrides(memoryDatabase()));
      c.read(profileProvider);
      await flush();
      await c.read(profileProvider.notifier).setNickname('x' * 80);
      expect(c.read(profileProvider).nickname.length, nicknameMaxLength);
      await c.read(profileProvider.notifier).setAccent('nope');
      expect(c.read(profileProvider).accentId, 'violet');
      c.dispose();
    });

    test('own picture: a copy is used, the original stays; a standard '
        'picture removes only the copy', () async {
      final c = ProviderContainer(overrides: overrides(memoryDatabase()));
      c.read(profileProvider);
      await flush();
      final original = File(p.join(temp.path, 'me.png'))
        ..writeAsBytesSync(List.filled(64, 7));
      final n = c.read(profileProvider.notifier);
      expect(await n.setOwnAvatar(original.path), isNull);
      final copy = c.read(profileProvider).avatarFile!;
      expect(p.isWithin(p.join(temp.path, 'profile'), copy), isTrue);
      expect(File(copy).readAsBytesSync(), original.readAsBytesSync());

      await n.setStandardAvatar(3);
      expect(c.read(profileProvider).presetAvatar, 3);
      expect(File(copy).existsSync(), isFalse, reason: 'own copy removed');
      expect(original.existsSync(), isTrue, reason: 'user file kept');

      final text = File(p.join(temp.path, 'notes.txt'))..writeAsStringSync('x');
      expect(await n.setOwnAvatar(text.path), isNotNull);
      expect(c.read(profileProvider).presetAvatar, 3);
      c.dispose();
    });

    test('reset appearance keeps name and picture', () async {
      final c = ProviderContainer(overrides: overrides(memoryDatabase()));
      c.read(profileProvider);
      await flush();
      final n = c.read(profileProvider.notifier);
      await n.setNickname('Mira');
      await n.setStandardAvatar(5);
      await n.setAccent('coral');
      await n.setAtmosphere(false);
      await n.setMotion(MotionLevel.off);
      await n.resetAppearance();
      final s = c.read(profileProvider);
      expect(s.nickname, 'Mira');
      expect(s.presetAvatar, 5);
      expect(s.accentId, 'violet');
      expect(s.atmosphere, isTrue);
      expect(s.motion, MotionLevel.full);
      c.dispose();
    });
  });

  testWidgets('profile from the top bar: name greets on Home, accent and '
      'atmosphere apply at once', (tester) async {
    await loadNexaFonts();
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = size1920;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: overrides(memoryDatabase()),
        child: const NexaApp(ambientMotion: false),
      ),
    );
    await settle(tester);

    await tester.tap(find.byKey(const ValueKey('topbar-profile')));
    await settle(tester);
    expect(find.byType(ProfilePage), findsOneWidget);

    await tester.enterText(find.byKey(const ValueKey('profile-nickname')), 'Dmytro');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await settle(tester);

    await tester.tap(find.byKey(const ValueKey('accent-magenta')));
    await settle(tester);
    final magenta = accentChoices.firstWhere((a) => a.id == 'magenta');
    expect(NexaColors.accent, magenta.color);
    expect(NexaColors.accentStrong, magenta.deep);

    await tester.tap(find.byKey(const ValueKey('profile-atmosphere')));
    await settle(tester);
    final container = ProviderScope.containerOf(
      tester.element(find.byType(ProfilePage)),
    );
    expect(container.read(atmosphereProvider), isFalse);

    await tester.tap(find.byKey(const ValueKey('motion-off')));
    await settle(tester);
    expect(NexaMotion.normal, Duration.zero);

    await tester.tap(find.text(S.navHome));
    await settle(tester);
    expect(find.byType(HomeGreeting), findsOneWidget);
    expect(find.textContaining(', Dmytro'), findsWidgets);

    // Reset appearance: the look goes back, the name stays.
    await tester.tap(find.byKey(const ValueKey('home-greeting')));
    await settle(tester);
    await tester.ensureVisible(find.byKey(const ValueKey('profile-reset')));
    await tester.tap(find.byKey(const ValueKey('profile-reset')));
    await settle(tester);
    await tester.tap(find.widgetWithText(FilledButton, S.profileResetAction));
    await settle(tester);
    expect(NexaColors.accent, accentChoices.first.color);
    expect(NexaMotion.normal, const Duration(milliseconds: 260));
    expect(container.read(profileProvider).nickname, 'Dmytro');
    expect(tester.takeException(), isNull);
  });
}
