import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme/tokens.dart';
import 'profile.dart';

/// The built-in avatars: a glyph on an original two-colour gradient.
const List<(IconData, Color, Color)> standardAvatars = [
  (Icons.graphic_eq_rounded, Color(0xFF8B5CF6), Color(0xFFE15FED)),
  (Icons.nightlight_round, Color(0xFF3B4CCA), Color(0xFF8B5CF6)),
  (Icons.bolt_rounded, Color(0xFFF26B57), Color(0xFFFFC56E)),
  (Icons.spa_rounded, Color(0xFF14B8A6), Color(0xFF60A5FA)),
  (Icons.headphones_rounded, Color(0xFF1F2937), Color(0xFF8B5CF6)),
  (Icons.auto_awesome_rounded, Color(0xFFD946EF), Color(0xFFFF8FB3)),
  (Icons.music_note_rounded, Color(0xFF65A30D), Color(0xFF34D399)),
  (Icons.waves_rounded, Color(0xFF0EA5E9), Color(0xFF6366F1)),
];

/// A standard avatar by number.
class StandardAvatar extends StatelessWidget {
  const StandardAvatar({super.key, required this.index, this.size = 40});

  final int index;
  final double size;

  @override
  Widget build(BuildContext context) {
    final (icon, from, to) = standardAvatars[index % standardAvatars.length];
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [from, to],
        ),
      ),
      child: Icon(icon, size: size * 0.5, color: Colors.white.withValues(alpha: 0.92)),
    );
  }
}

/// The user's avatar (own picture or a standard one), round, with a thin
/// accent ring.
class ProfileAvatar extends ConsumerWidget {
  const ProfileAvatar({super.key, this.size = 40, this.ring = true});

  final double size;
  final bool ring;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(profileProvider);
    final file = profile.avatarFile;
    final Widget picture = file != null
        ? ClipOval(
            child: Image.file(
              File(file),
              width: size,
              height: size,
              fit: BoxFit.cover,
              cacheWidth: (size * 2).round(),
              errorBuilder: (context, error, stack) =>
                  StandardAvatar(index: 0, size: size),
            ),
          )
        : StandardAvatar(index: profile.presetAvatar ?? 0, size: size);
    if (!ring) {
      return picture;
    }
    return Container(
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          colors: [NexaColors.accentStrong, NexaColors.accentGlow],
        ),
      ),
      child: picture,
    );
  }
}
