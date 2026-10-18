import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';

/// Test binding that records every semantics update the framework sends to
/// the engine and checks it the way the Windows accessibility bridge
/// (ui::AXTree) does: after each update, every node in that update must be
/// reachable from the root node 0. A node that is not reachable is rejected
/// by Windows with "N will not be in the tree and is not the new root"; the
/// accessibility tree is then inconsistent and NEXA Music crashed in
/// flutter_windows.dll (Phase 1 manual check, see PHASE_01_REPORT.md).
///
/// Create it at the top of `main()` of a test file, before any test runs.
class SemanticsCheckingBinding extends AutomatedTestWidgetsFlutterBinding {
  final SemanticsTreeChecker checker = SemanticsTreeChecker();

  @override
  ui.SemanticsUpdateBuilder createSemanticsUpdateBuilder() =>
      _RecordingSemanticsUpdateBuilder(
        super.createSemanticsUpdateBuilder(),
        checker,
      );
}

/// Model of the engine-side accessibility tree.
class SemanticsTreeChecker {
  final Map<int, List<int>> _children = {};
  final Map<int, List<int>> _hitTestChildren = {};
  final Map<int, String> _describe = {};

  /// Rejected updates, one line per orphan node.
  final List<String> errors = [];

  /// Number of semantics updates checked.
  int updates = 0;

  /// What the test was doing (shown in error messages).
  String step = '';

  void reset() {
    _children.clear();
    _parent.clear();
    _hitTestChildren.clear();
    _describe.clear();
    errors.clear();
    updates = 0;
    step = '';
  }

  String _parentsOf(int id) {
    final hitParents = [
      for (final e in _hitTestChildren.entries)
        if (e.value.contains(id)) e.key,
    ];
    return hitParents
        .map((p) => 'hit-test parent $p: ${_describe[p]}')
        .join('; ');
  }

  /// Parent of every node currently in the modelled engine tree.
  final Map<int, int> _parent = {};

  void _deleteSubtree(int id) {
    for (final child in _children.remove(id) ?? const <int>[]) {
      if (_parent[child] == id) {
        _deleteSubtree(child);
      }
    }
    _parent.remove(id);
  }

  void _apply(
    Map<int, List<int>> update,
    Map<int, List<int>> hitTest,
    Map<int, String> describe,
  ) {
    updates++;
    _hitTestChildren.addAll(hitTest);
    _describe.addAll(describe);

    // Step 1, as in AccessibilityBridge::CommitUpdates: a node that moves to
    // a new parent is first removed from its old parent. ui::AXTree deletes
    // a removed node together with its whole subtree.
    for (final entry in update.entries) {
      for (final child in entry.value) {
        final oldParent = _parent[child];
        if (!_children.containsKey(child) ||
            oldParent == null ||
            oldParent == entry.key) {
          continue;
        }
        if (!update.containsKey(child)) {
          errors.add(
            '[$step] update $updates: node $child moved from $oldParent to '
            '${entry.key} without its own update',
          );
        }
        _children[oldParent]?.remove(child);
        _deleteSubtree(child);
      }
    }

    // Step 2: apply the update.
    _children.addAll({
      for (final e in update.entries) e.key: [...e.value],
    });
    final reachable = <int>{};
    _parent.clear();
    void walk(int id) {
      if (!reachable.add(id)) {
        return;
      }
      for (final child in _children[id] ?? const <int>[]) {
        _parent[child] = id;
        walk(child);
      }
    }

    if (_children.containsKey(0)) {
      walk(0);
    }
    // A child id that Windows has no data for: "Nodes left pending by the
    // update".
    for (final id in reachable) {
      for (final child in _children[id] ?? const <int>[]) {
        if (!_children.containsKey(child)) {
          errors.add(
            '[$step] update $updates: node $id lists child $child that '
            'Windows has no data for (pending) - parent: ${_describe[id]} '
            '- child: ${_describe[child]}',
          );
        }
      }
    }
    // A node in the update that no parent lists: "N will not be in the
    // tree and is not the new root".
    for (final id in update.keys) {
      if (!reachable.contains(id)) {
        errors.add(
          '[$step] update $updates: node $id will not be in the tree '
          '(${_describe[id]}) ${_parentsOf(id)}',
        );
      }
    }
    // Windows drops nodes that are no longer reachable.
    _children.removeWhere((id, _) => !reachable.contains(id));
  }
}

class _RecordingSemanticsUpdateBuilder implements ui.SemanticsUpdateBuilder {
  _RecordingSemanticsUpdateBuilder(this._inner, this._checker);

  final ui.SemanticsUpdateBuilder _inner;
  final SemanticsTreeChecker _checker;
  final Map<int, List<int>> _nodes = {};
  final Map<int, List<int>> _hitTest = {};
  final Map<int, String> _describe = {};

  @override
  void updateNode({
    required int id,
    required ui.SemanticsFlags flags,
    required int actions,
    required int maxValueLength,
    required int currentValueLength,
    required int textSelectionBase,
    required int textSelectionExtent,
    required int platformViewId,
    required int scrollChildren,
    required int scrollIndex,
    required int traversalParent,
    required double scrollPosition,
    required double scrollExtentMax,
    required double scrollExtentMin,
    required ui.Rect rect,
    required String identifier,
    required String label,
    required List<ui.StringAttribute> labelAttributes,
    required String value,
    required List<ui.StringAttribute> valueAttributes,
    required String increasedValue,
    required List<ui.StringAttribute> increasedValueAttributes,
    required String decreasedValue,
    required List<ui.StringAttribute> decreasedValueAttributes,
    required String hint,
    required List<ui.StringAttribute> hintAttributes,
    required String tooltip,
    required ui.TextDirection? textDirection,
    required Float64List transform,
    required Float64List hitTestTransform,
    required Int32List childrenInTraversalOrder,
    required Int32List childrenInHitTestOrder,
    required Int32List additionalActions,
    int headingLevel = 0,
    String linkUrl = '',
    ui.SemanticsRole role = ui.SemanticsRole.none,
    required List<String>? controlsNodes,
    ui.SemanticsValidationResult validationResult =
        ui.SemanticsValidationResult.none,
    ui.SemanticsHitTestBehavior hitTestBehavior =
        ui.SemanticsHitTestBehavior.defer,
    required ui.SemanticsInputType inputType,
    required ui.Locale? locale,
    required String minValue,
    required String maxValue,
  }) {
    _nodes[id] = childrenInTraversalOrder.toList();
    _hitTest[id] = childrenInHitTestOrder.toList();
    _describe[id] =
        'label="$label" tooltip="$tooltip" value="$value" role=$role '
        'traversalParent=$traversalParent rect=$rect '
        'children=${childrenInTraversalOrder.toList()} '
        'hitTestChildren=${childrenInHitTestOrder.toList()}';
    _inner.updateNode(
      id: id,
      flags: flags,
      actions: actions,
      maxValueLength: maxValueLength,
      currentValueLength: currentValueLength,
      textSelectionBase: textSelectionBase,
      textSelectionExtent: textSelectionExtent,
      platformViewId: platformViewId,
      scrollChildren: scrollChildren,
      scrollIndex: scrollIndex,
      traversalParent: traversalParent,
      scrollPosition: scrollPosition,
      scrollExtentMax: scrollExtentMax,
      scrollExtentMin: scrollExtentMin,
      rect: rect,
      identifier: identifier,
      label: label,
      labelAttributes: labelAttributes,
      value: value,
      valueAttributes: valueAttributes,
      increasedValue: increasedValue,
      increasedValueAttributes: increasedValueAttributes,
      decreasedValue: decreasedValue,
      decreasedValueAttributes: decreasedValueAttributes,
      hint: hint,
      hintAttributes: hintAttributes,
      tooltip: tooltip,
      textDirection: textDirection,
      transform: transform,
      hitTestTransform: hitTestTransform,
      childrenInTraversalOrder: childrenInTraversalOrder,
      childrenInHitTestOrder: childrenInHitTestOrder,
      additionalActions: additionalActions,
      headingLevel: headingLevel,
      linkUrl: linkUrl,
      role: role,
      controlsNodes: controlsNodes,
      validationResult: validationResult,
      hitTestBehavior: hitTestBehavior,
      inputType: inputType,
      locale: locale,
      minValue: minValue,
      maxValue: maxValue,
    );
  }

  @override
  void updateCustomAction({
    required int id,
    String? label,
    String? hint,
    int overrideId = -1,
  }) {
    _inner.updateCustomAction(
      id: id,
      label: label,
      hint: hint,
      overrideId: overrideId,
    );
  }

  @override
  ui.SemanticsUpdate build() {
    _checker._apply(_nodes, _hitTest, _describe);
    return _inner.build();
  }
}
