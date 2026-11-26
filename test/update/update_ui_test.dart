import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nexa_music/core/database/app_database.dart';
import 'package:nexa_music/features/library/library_providers.dart';
import 'package:nexa_music/features/update/release.dart';
import 'package:nexa_music/features/update/update_controller.dart';
import 'package:nexa_music/features/update/update_installer.dart';
import 'package:nexa_music/features/update/update_ui.dart';
import 'package:path/path.dart' as p;

import '../helpers/fake_update_source.dart';
import '../helpers/update_package.dart';
import '../helpers/zip_builder.dart';

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  testWidgets('the notification: four actions; "What\'s new" shows the notes '
      'as readable text', (tester) async {
    final semantics = tester.ensureSemantics();
    final temp = Directory.systemTemp.createTempSync('nexa_upd_ui');
    final db = AppDatabase(NativeDatabase.memory());
    final zip = buildZip(goodEntries());
    final source = FakeUpdateSource(
      list: ReleaseInfo.listFromJson([
        {
          'tag_name': 'v1.2.0',
          'name': 'NEXA Music 1.2.0 Nocturne',
          'body': 'Night theme for every screen.',
          'assets': [
            {
              'id': 1,
              'name': '$top.zip',
              'size': zip.length,
              'digest': 'sha256:${sha256.convert(zip)}',
            },
          ],
        },
      ]),
      files: {1: zip},
    );
    final container = ProviderContainer(
      overrides: [
        appDatabaseProvider.overrideWithValue(db),
        updateSourceProvider.overrideWithValue(source),
        updatePathsProvider.overrideWith(
          (ref) async => UpdatePaths(Directory(p.join(temp.path, 'updates'))),
        ),
        autoCheckAllowedProvider.overrideWithValue(false),
      ],
    );
    try {
      await tester.runAsync(() => container.read(updateProvider.notifier).check());
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            home: Builder(
              builder: (context) => TextButton(
                onPressed: () => showUpdateDialog(context),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      for (final label in ['Update now', "What's new", 'Later', 'Skip this version']) {
        expect(find.text(label), findsOneWidget, reason: label);
      }
      await tester.tap(find.text("What's new"));
      await tester.pumpAndSettle();
      expect(find.text('Night theme for every screen.'), findsOneWidget);
      expect(
        tester.getSemantics(find.text('Night theme for every screen.')).label,
        contains('Night theme'),
      );
      await tester.tap(find.text('Close'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Later'));
      await tester.pumpAndSettle();
      expect(find.text('Update now'), findsNothing);
      expect(source.downloads, isEmpty, reason: 'nothing without a click');
    } finally {
      semantics.dispose();
      container.dispose();
      await tester.runAsync(db.close);
      temp.deleteSync(recursive: true);
    }
  });
}
