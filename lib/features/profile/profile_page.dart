import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/navigation.dart';
import '../../app/shell/top_bar.dart' show greetingFor;
import '../../app/strings.dart';
import '../../app/theme/nexa_theme.dart';
import '../../app/theme/tokens.dart';
import '../../ui/nexa_widgets.dart';
import '../library/library_dialogs.dart' show confirmAction;
import '../nexa_dna/dna_picker.dart' show showDnaPicker;
import 'profile.dart';
import 'profile_avatar.dart';

/// Chooses a picture for the avatar (system dialog). Tests override this.
final avatarPickerProvider = Provider<Future<String?> Function()>(
  (ref) => () async {
    final result = await FilePicker.pickFiles(
      dialogTitle: S.profilePickPicture,
      type: FileType.image,
    );
    return result.isEmpty ? null : result.first.path;
  },
);

/// "Good evening, Dmytro" (or only the greeting without a name).
String greetingWithName(DateTime time, String nickname) =>
    nickname.isEmpty ? greetingFor(time) : '${greetingFor(time)}, $nickname';

/// D-042 Local Profile: name, picture, accent, atmosphere, animations,
/// NEXARYVE DNA and "Reset appearance". Everything stays on this computer.
class ProfilePage extends ConsumerWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return LayoutBuilder(
      builder: (context, box) {
        final wide = box.maxWidth >= 980;
        final left = [
          const _IdentityCard(),
          const SizedBox(height: NexaSpace.md),
          const _AvatarCard(),
        ];
        final right = [
          const _AccentCard(),
          const SizedBox(height: NexaSpace.md),
          const _MotionCard(),
          const SizedBox(height: NexaSpace.md),
          const _DnaAndResetCard(),
        ];
        return SingleChildScrollView(
          key: const PageStorageKey('page-profile'),
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(S.profileTitle, style: NexaText.display),
              const SizedBox(height: 4),
              const Text(S.profileLocalNote, style: NexaText.bodySecondary),
              const SizedBox(height: NexaSpace.lg),
              if (wide)
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: Column(children: left)),
                    const SizedBox(width: NexaSpace.md),
                    Expanded(child: Column(children: right)),
                  ],
                )
              else
                Column(
                  children: [
                    ...left,
                    const SizedBox(height: NexaSpace.md),
                    ...right,
                  ],
                ),
            ],
          ),
        );
      },
    );
  }
}

class _Card extends StatelessWidget {
  const _Card({required this.title, required this.child, this.subtitle});

  final String title;
  final String? subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return NexaPanel(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: NexaText.h3),
          if (subtitle != null) ...[
            const SizedBox(height: 4),
            Text(subtitle!, style: NexaText.bodySecondary),
          ],
          const SizedBox(height: NexaSpace.md),
          child,
        ],
      ),
    );
  }
}

class _IdentityCard extends ConsumerStatefulWidget {
  const _IdentityCard();

  @override
  ConsumerState<_IdentityCard> createState() => _IdentityCardState();
}

class _IdentityCardState extends ConsumerState<_IdentityCard> {
  final TextEditingController _name = TextEditingController();
  final FocusNode _focus = FocusNode();
  bool _filled = false;

  @override
  void initState() {
    super.initState();
    _focus.addListener(() {
      if (!_focus.hasFocus) {
        _save();
      }
    });
  }

  @override
  void dispose() {
    _name.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _save() {
    final profile = ref.read(profileProvider);
    if (_name.text.trim() != profile.nickname) {
      ref.read(profileProvider.notifier).setNickname(_name.text);
    }
  }

  @override
  Widget build(BuildContext context) {
    final profile = ref.watch(profileProvider);
    if (!_filled && profile.loaded) {
      _filled = true;
      _name.text = profile.nickname;
    }
    return NexaPanel(
      padding: const EdgeInsets.all(20),
      child: Row(
        children: [
          const ProfileAvatar(size: 84),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  greetingWithName(DateTime.now(), profile.nickname),
                  style: NexaText.h2,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 12),
                TextField(
                  key: const ValueKey('profile-nickname'),
                  controller: _name,
                  focusNode: _focus,
                  maxLength: nicknameMaxLength,
                  style: NexaText.body,
                  decoration: const InputDecoration(
                    labelText: S.profileNickname,
                    hintText: S.profileNicknameHint,
                    counterText: '',
                    isDense: true,
                  ),
                  onSubmitted: (_) => _save(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AvatarCard extends ConsumerStatefulWidget {
  const _AvatarCard();

  @override
  ConsumerState<_AvatarCard> createState() => _AvatarCardState();
}

class _AvatarCardState extends ConsumerState<_AvatarCard> {
  String? _error;

  Future<void> _pickOwn() async {
    final path = await ref.read(avatarPickerProvider)();
    if (path == null) {
      return;
    }
    final error = await ref.read(profileProvider.notifier).setOwnAvatar(path);
    if (mounted) {
      setState(() => _error = error);
    }
  }

  @override
  Widget build(BuildContext context) {
    final profile = ref.watch(profileProvider);
    final selected = profile.presetAvatar;
    return _Card(
      title: S.profileAvatar,
      subtitle: S.profileAvatarNote,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              for (var i = 0; i < standardAvatarCount; i++)
                _Choice(
                  key: ValueKey('avatar-$i'),
                  selected: selected == i,
                  label: '${S.profileStandardAvatar} ${i + 1}',
                  onTap: () {
                    setState(() => _error = null);
                    ref.read(profileProvider.notifier).setStandardAvatar(i);
                  },
                  child: StandardAvatar(index: i, size: 48),
                ),
            ],
          ),
          const SizedBox(height: NexaSpace.md),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              NexaPillButton(
                key: const ValueKey('profile-own-picture'),
                label: '${S.profileOwnPicture}...',
                icon: Icons.add_photo_alternate_outlined,
                variant: PillVariant.secondary,
                height: 40,
                onPressed: _pickOwn,
              ),
              if (profile.avatarFile != null)
                const Text(S.profileOwnPictureInUse, style: NexaText.caption),
            ],
          ),
          if (_error != null) ...[
            const SizedBox(height: 8),
            Text(
              _error!,
              style: NexaText.caption.copyWith(color: NexaColors.coral),
            ),
          ],
        ],
      ),
    );
  }
}

/// A round choice with a ring when selected.
class _Choice extends StatelessWidget {
  const _Choice({
    super.key,
    required this.selected,
    required this.label,
    required this.onTap,
    required this.child,
  });

  final bool selected;
  final String label;
  final VoidCallback onTap;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      selected: selected,
      child: NexaTappable(
        onTap: onTap,
        tooltip: label,
        semanticLabel: label,
        borderRadius: BorderRadius.circular(40),
        child: AnimatedContainer(
          duration: NexaMotion.fast,
          padding: const EdgeInsets.all(3),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: selected ? NexaColors.accent : Colors.transparent,
              width: 2,
            ),
          ),
          child: child,
        ),
      ),
    );
  }
}

class _AccentCard extends ConsumerWidget {
  const _AccentCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(profileProvider);
    return _Card(
      title: S.profileAccent,
      subtitle: S.profileAccentNote,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              for (final a in accentChoices)
                _Choice(
                  key: ValueKey('accent-${a.id}'),
                  selected: profile.accentId == a.id,
                  label: a.name,
                  onTap: () =>
                      ref.read(profileProvider.notifier).setAccent(a.id),
                  child: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [a.deep, a.glow],
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: NexaSpace.md),
          Row(
            children: [
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(S.profileAtmosphere, style: NexaText.body),
                    SizedBox(height: 2),
                    Text(S.profileAtmosphereNote, style: NexaText.caption),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Switch(
                key: const ValueKey('profile-atmosphere'),
                value: profile.atmosphere,
                onChanged: (v) =>
                    ref.read(profileProvider.notifier).setAtmosphere(v),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MotionCard extends ConsumerWidget {
  const _MotionCard();

  static const Map<MotionLevel, (String, String)> _labels = {
    MotionLevel.full: (S.motionFull, S.motionFullNote),
    MotionLevel.reduced: (S.motionReduced, S.motionReducedNote),
    MotionLevel.off: (S.motionOff, S.motionOffNote),
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final motion = ref.watch(profileProvider.select((p) => p.motion));
    return _Card(
      title: S.profileMotion,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final entry in _labels.entries)
                ChoiceChip(
                  key: ValueKey('motion-${entry.key.name}'),
                  label: Text(entry.value.$1),
                  selected: motion == entry.key,
                  showCheckmark: false,
                  selectedColor: NexaColors.navSelected,
                  backgroundColor: NexaColors.panel,
                  side: const BorderSide(color: NexaColors.border),
                  labelStyle: NexaText.body.copyWith(fontSize: 13.5),
                  onSelected: (_) =>
                      ref.read(profileProvider.notifier).setMotion(entry.key),
                ),
            ],
          ),
          const SizedBox(height: 10),
          Text(_labels[motion]!.$2, style: NexaText.caption),
        ],
      ),
    );
  }
}

class _DnaAndResetCard extends ConsumerWidget {
  const _DnaAndResetCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return _Card(
      title: S.profileDna,
      subtitle: S.profileDnaNote,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              NexaPillButton(
                key: const ValueKey('profile-open-dna'),
                label: S.profileOpenDna,
                icon: Icons.fingerprint_rounded,
                height: 40,
                onPressed: () => showDnaPicker(context),
              ),
              NexaPillButton(
                label: S.navWave,
                icon: Icons.graphic_eq_rounded,
                variant: PillVariant.secondary,
                height: 40,
                onPressed: () => ref
                    .read(navigationProvider.notifier)
                    .go(NexaDestination.wave),
              ),
            ],
          ),
          const SizedBox(height: NexaSpace.lg),
          const Divider(color: NexaColors.divider, height: 1),
          const SizedBox(height: NexaSpace.md),
          const Text(S.profileReset, style: NexaText.title),
          const SizedBox(height: 4),
          const Text(S.profileResetNote, style: NexaText.caption),
          const SizedBox(height: 12),
          NexaPillButton(
            key: const ValueKey('profile-reset'),
            label: '${S.profileReset}...',
            icon: Icons.restart_alt_rounded,
            variant: PillVariant.secondary,
            height: 40,
            onPressed: () async {
              final ok = await confirmAction(
                context,
                title: '${S.profileReset}?',
                body: S.profileResetNote,
                action: S.profileResetAction,
              );
              if (ok) {
                await ref.read(profileProvider.notifier).resetAppearance();
              }
            },
          ),
        ],
      ),
    );
  }
}
