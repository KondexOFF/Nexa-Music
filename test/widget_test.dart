import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nexa_music/audio_probe/audio_self_test.dart';
import 'package:nexa_music/audio_probe/probe_results_view.dart';

void main() {
  testWidgets('results view shows PASS/FAIL lines and overall FAIL', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: ProbeResultsView(
            running: false,
            steps: [
              ProbeStep('open', ProbeOutcome.pass, 'duration 3:00.000'),
              ProbeStep('play', ProbeOutcome.fail, 'no progress'),
            ],
          ),
        ),
      ),
    );

    expect(find.textContaining('PASS  open'), findsOneWidget);
    expect(find.textContaining('FAIL  play'), findsOneWidget);
    expect(find.text('RESULT: FAIL'), findsOneWidget);
  });

  testWidgets('results view shows running state before any step', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: ProbeResultsView(running: true, steps: [])),
      ),
    );

    expect(find.text('Self-test running...'), findsOneWidget);
  });
}
