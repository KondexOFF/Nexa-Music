import 'package:flutter/widgets.dart';

/// Hosts a Material [Slider] (or anything containing one) in its own small
/// overlay and semantics node.
///
/// A Slider keeps its value-indicator OverlayPortal open all the time. When a
/// Slider appears after the first frame (another page, a pushed route), its
/// overlay child is sent to Windows as an empty node that no parent lists
/// ("N will not be in the tree and is not the new root"); with an
/// accessibility client active, the Windows accessibility tree then breaks
/// and NEXA Music crashed (flutter/flutter#190357). A local overlay keeps
/// that overlay child inside the slider's own subtree.
class IsolatedSlider extends StatelessWidget {
  const IsolatedSlider({super.key, required this.child});

  /// Usually a [Slider].
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      child: Overlay.wrap(
        alwaysSizeToContent: true,
        clipBehavior: Clip.none,
        child: child,
      ),
    );
  }
}
