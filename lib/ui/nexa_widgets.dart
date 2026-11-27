import 'package:flutter/material.dart';

import '../app/theme/nexa_theme.dart';
import '../app/theme/tokens.dart';

/// Tooltip that owns its semantics node.
///
/// Flutter's [Tooltip] shows its bubble through an OverlayPortal, which
/// registers an "overlay anchor" on the nearest semantics node above it. When
/// two anchors (two tooltips, or a tooltip and a Slider) end up on the same
/// node, Flutter keeps only one; the other overlay node becomes an orphan,
/// Windows rejects the accessibility update ("N will not be in the tree and
/// is not the new root") and the app later crashes in flutter_windows.dll
/// while an accessibility client is active (flutter/flutter#182444,
/// #190357). The outer container gives this tooltip its own node; the inner
/// one keeps any anchor inside [child] off that node.
///
/// Every tooltip in NEXA Music must use this widget instead of [Tooltip].
class NexaTooltip extends StatelessWidget {
  const NexaTooltip({super.key, required this.message, required this.child});

  /// Tooltip text; null or empty shows no tooltip.
  final String? message;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final text = message;
    if (text == null || text.isEmpty) {
      return child;
    }
    return Semantics(
      container: true,
      child: Tooltip(
        message: text,
        child: Semantics(container: true, child: child),
      ),
    );
  }
}

/// Hover / focus / click surface that paints its highlight above the parent
/// decoration. A null [onTap] means the surface is inert (no hover, no focus).
class NexaTappable extends StatelessWidget {
  const NexaTappable({
    super.key,
    required this.child,
    this.onTap,
    this.borderRadius = const BorderRadius.all(Radius.circular(NexaRadius.md)),
    this.hoverColor,
    this.tooltip,
    this.semanticLabel,
  });

  final Widget child;
  final VoidCallback? onTap;
  final BorderRadius borderRadius;
  /// Null: the accent (faint).
  final Color? hoverColor;
  final String? tooltip;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    Widget result = Material(
      type: MaterialType.transparency,
      child: InkWell(
        onTap: onTap,
        borderRadius: borderRadius,
        hoverColor: hoverColor ?? NexaColors.accentFaint,
        focusColor: NexaColors.accentSoft,
        child: child,
      ),
    );
    if (semanticLabel != null) {
      result = Semantics(
        button: true,
        enabled: onTap != null,
        label: semanticLabel,
        child: result,
      );
    }
    if (tooltip != null) {
      result = NexaTooltip(message: tooltip, child: result);
    }
    return result;
  }
}

/// Icon button. When [onPressed] is null the button is visibly disabled and
/// its tooltip explains why ([disabledReason]).
class NexaIconButton extends StatelessWidget {
  const NexaIconButton({
    super.key,
    required this.icon,
    required this.label,
    this.onPressed,
    this.disabledReason,
    this.iconSize = 20,
    this.boxSize = 36,
    this.color = NexaColors.textPrimary,
    this.selected = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onPressed;
  final String? disabledReason;
  final double iconSize;
  final double boxSize;
  final Color color;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null;
    final message = enabled || disabledReason == null
        ? label
        : '$label - $disabledReason';
    return NexaTooltip(
      message: message,
      child: SizedBox.square(
        dimension: boxSize,
        child: IconButton(
          onPressed: onPressed,
          icon: Icon(icon),
          iconSize: iconSize,
          padding: EdgeInsets.zero,
          color: selected ? NexaColors.accent : color,
          disabledColor: NexaColors.textDisabled,
          style: IconButton.styleFrom(
            hoverColor: NexaColors.accentFaint,
            shape: const CircleBorder(),
            minimumSize: Size.zero,
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
        ),
      ),
    );
  }
}

enum PillVariant { primary, secondary }

/// Rounded pill button (Play Wave, Shuffle, chips).
class NexaPillButton extends StatelessWidget {
  const NexaPillButton({
    super.key,
    required this.label,
    this.icon,
    this.onPressed,
    this.disabledReason,
    this.variant = PillVariant.primary,
    this.height = 48,
  });

  final String label;
  final IconData? icon;
  final VoidCallback? onPressed;
  final String? disabledReason;
  final PillVariant variant;
  final double height;

  @override
  Widget build(BuildContext context) {
    final primary = variant == PillVariant.primary;
    final style = ButtonStyle(
      minimumSize: WidgetStatePropertyAll(Size(0, height)),
      padding: const WidgetStatePropertyAll(
        EdgeInsets.symmetric(horizontal: 26),
      ),
      shape: const WidgetStatePropertyAll(StadiumBorder()),
      textStyle: const WidgetStatePropertyAll(NexaText.button),
      side: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.disabled)) {
          return const BorderSide(color: Color(0x1FFFFFFF));
        }
        return primary
            ? BorderSide.none
            : const BorderSide(color: Color(0x33FFFFFF));
      }),
      backgroundColor: WidgetStateProperty.resolveWith((states) {
        // Disabled buttons are clearly muted (no accent fill), so they never
        // look like working ones.
        if (states.contains(WidgetState.disabled)) {
          return primary ? const Color(0x14AD9AFF) : const Color(0x05FFFFFF);
        }
        if (!primary) {
          return states.contains(WidgetState.hovered)
              ? const Color(0x14FFFFFF)
              : const Color(0x0AFFFFFF);
        }
        return states.contains(WidgetState.hovered)
            ? NexaColors.accentStrong
            : NexaColors.accent;
      }),
      foregroundColor: WidgetStateProperty.resolveWith(
        (states) => states.contains(WidgetState.disabled)
            ? NexaColors.textDisabled
            : Colors.white,
      ),
      overlayColor: const WidgetStatePropertyAll(Colors.transparent),
    );
    final child = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (icon != null) ...[Icon(icon, size: 22), const SizedBox(width: 10)],
        Text(label),
      ],
    );
    final button = TextButton(onPressed: onPressed, style: style, child: child);
    if (onPressed == null && disabledReason != null) {
      return NexaTooltip(message: disabledReason, child: button);
    }
    return button;
  }
}

/// Small uppercase status label, e.g. DEMO or "Phase 4".
class StatusBadge extends StatelessWidget {
  const StatusBadge({
    super.key,
    required this.label,
    required Color this.color,
    this.tooltip,
  });

  /// In the accent colour (e.g. "Playing").
  const StatusBadge.phase(this.label, {super.key, this.tooltip}) : color = null;

  final String label;

  /// Null: the accent.
  final Color? color;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    final color = this.color ?? NexaColors.accent;
    final badge = Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.45)),
      ),
      child: Text(label.toUpperCase(), style: NexaText.badge.copyWith(color: color)),
    );
    if (tooltip == null) {
      return badge;
    }
    return NexaTooltip(message: tooltip, child: badge);
  }
}

/// Rounded panel used for right-side cards and Mix Engine.
class NexaPanel extends StatelessWidget {
  const NexaPanel({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(NexaSpace.md),
  });

  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: NexaColors.panel,
        borderRadius: BorderRadius.circular(NexaRadius.lg),
        border: Border.all(color: NexaColors.border),
      ),
      child: child,
    );
  }
}

/// Text link such as "See all". Disabled links show [disabledReason].
class NexaTextLink extends StatelessWidget {
  const NexaTextLink({
    super.key,
    required this.label,
    this.onTap,
    this.disabledReason,
    this.showArrow = true,
  });

  final String label;
  final VoidCallback? onTap;
  final String? disabledReason;
  final bool showArrow;

  @override
  Widget build(BuildContext context) {
    final color = onTap == null ? NexaColors.textTertiary : NexaColors.textSecondary;
    return NexaTappable(
      onTap: onTap,
      borderRadius: BorderRadius.circular(NexaRadius.sm),
      tooltip: onTap == null ? disabledReason : null,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(label, style: NexaText.caption.copyWith(color: color)),
            if (showArrow) ...[
              const SizedBox(width: 6),
              Icon(Icons.arrow_forward_rounded, size: 14, color: color),
            ],
          ],
        ),
      ),
    );
  }
}

/// Section title with optional subtitle, badges and trailing action.
class SectionHeader extends StatelessWidget {
  const SectionHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.badges = const [],
    this.trailing,
    this.style = NexaText.h2,
  });

  final String title;
  final String? subtitle;
  final List<Widget> badges;
  final Widget? trailing;
  final TextStyle style;

  @override
  Widget build(BuildContext context) {
    // NEXARYVE 1.2 (less noise): the explanation is a tooltip on the title,
    // not a line of small text beside it.
    final titleText = NexaTooltip(
      message: subtitle,
      child: Text(
        title,
        style: style,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
    );
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Row(
            children: [
              Flexible(child: titleText),
              for (final badge in badges) ...[
                const SizedBox(width: NexaSpace.sm),
                badge,
              ],
            ],
          ),
        ),
        if (trailing != null) ...[
          const SizedBox(width: NexaSpace.xs),
          trailing!,
        ],
      ],
    );
  }
}

/// NEXARYVE 1.2 hover for artwork cards: a soft light in [glow] under the
/// card and a 1.5 % lift; press scales to 98 %. Purely visual.
class HoverLift extends StatefulWidget {
  const HoverLift({
    super.key,
    required this.child,
    this.glow,
    this.radius = NexaRadius.md,
  });

  final Widget child;
  /// Null: the accent.
  final Color? glow;
  final double radius;

  @override
  State<HoverLift> createState() => _HoverLiftState();
}

class _HoverLiftState extends State<HoverLift> {
  bool _hover = false;
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    final scale = _down ? 0.98 : (_hover ? 1.015 : 1.0);
    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() {
        _hover = false;
        _down = false;
      }),
      child: Listener(
        onPointerDown: (_) => setState(() => _down = true),
        onPointerUp: (_) => setState(() => _down = false),
        onPointerCancel: (_) => setState(() => _down = false),
        child: AnimatedScale(
          scale: scale,
          duration: NexaMotion.fast,
          curve: NexaMotion.curve,
          child: AnimatedContainer(
            duration: NexaMotion.normal,
            curve: NexaMotion.curve,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(widget.radius),
              boxShadow: [
                BoxShadow(
                  color: (widget.glow ?? NexaColors.accent).withValues(alpha: _hover ? 0.32 : 0),
                  blurRadius: 30,
                  spreadRadius: -6,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: widget.child,
          ),
        ),
      ),
    );
  }
}

/// NEXARYVE 1.2 (less noise): a title with a small info mark; the long
/// explanation is its tooltip and its screen-reader hint instead of a
/// paragraph under the title.
class InfoTitle extends StatelessWidget {
  const InfoTitle({
    super.key,
    required this.title,
    required this.info,
    this.style = NexaText.title,
  });

  final String title;
  final String info;
  final TextStyle style;

  @override
  Widget build(BuildContext context) => Semantics(
    hint: info,
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Flexible(child: Text(title, style: style)),
        const SizedBox(width: 6),
        NexaTooltip(
          message: info,
          child: const Icon(
            Icons.info_outline_rounded,
            size: 16,
            color: NexaColors.textTertiary,
          ),
        ),
      ],
    ),
  );
}
