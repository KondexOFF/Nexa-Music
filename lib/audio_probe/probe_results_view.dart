import 'package:flutter/material.dart';

import 'audio_self_test.dart';

/// Lists self-test steps as PASS/FAIL lines.
class ProbeResultsView extends StatelessWidget {
  const ProbeResultsView({
    super.key,
    required this.steps,
    required this.running,
  });

  final List<ProbeStep> steps;
  final bool running;

  @override
  Widget build(BuildContext context) {
    if (steps.isEmpty) {
      return Text(running ? 'Self-test running...' : 'Self-test not run.');
    }
    final allPassed = steps.every((step) => step.passed);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final step in steps)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 2),
            child: Text(
              '${step.passed ? 'PASS' : 'FAIL'}  ${step.name} - ${step.detail}',
              style: TextStyle(
                color: step.passed ? Colors.greenAccent : Colors.redAccent,
              ),
            ),
          ),
        if (!running)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              allPassed
                  ? 'RESULT: PASS (player-state checks; audible sound must be '
                        'confirmed by a person)'
                  : 'RESULT: FAIL',
            ),
          ),
      ],
    );
  }
}
