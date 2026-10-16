# NEXA Music

**Status:** Phase 0 (environment + audio-engine proof) submitted for owner review. The repository contains a minimal Flutter Windows project with a **technical audio prototype only**. There is no NEXA user interface and no music library yet.

NEXA Music is a **private, Windows-first music player** designed around:
- a personal, offline-capable library;
- **NEXA Mix Engine** (gapless, crossfade and, later, cautious smart transitions);
- **NEXA DNA** (explicit musical preferences) and **NEXA Wave** (a local-first recommendation queue);
- approved online sources in later stages.

The primary code implementer is Claude Agent on the owner's Windows PC. KondexOff approves each phase; ChatGPT reviews reports.

## Start here

1. Read [the authoritative development plan](NEXA_Music_Master_Plan_Claude.md) **in full**.
2. Claude must read [CLAUDE.md](CLAUDE.md) and respect phase gates.
3. Use [architecture](docs/ARCHITECTURE.md), [design](docs/DESIGN.md), [decision log](docs/DECISIONS.md) and [change requests](docs/CHANGE_REQUESTS.md) as supporting guidance.
4. Phases run one at a time. Each phase needs explicit owner authorization. Do **not** start later phases automatically.
5. Deliver reports according to [reporting instructions](reports/README.md). Latest: [Phase 0 report](reports/PHASE_00_REPORT.md).

## Development environment (verified in Phase 0)

| Component | Version |
|---|---|
| OS | Windows 11 x64 (build 26200) |
| Flutter | 3.47.7, channel stable (framework `abaf9c5237`) |
| Dart | 3.13.5 |
| Visual Studio | Community 2022 17.14, workload "Desktop development with C++", Windows 10 SDK 10.0.26100.0 |
| Git | 2.56.0 |
| Windows Developer Mode | On (needed for plugin symlinks) |

Exact package versions are locked in `pubspec.lock` (media_kit 1.2.6, media_kit_libs_audio 1.0.7, media_kit_libs_windows_audio 1.0.9).

## Running the Phase 0 audio prototype

The prototype is a temporary technical screen (`lib/audio_probe/`) used to prove that the Windows audio engine works. It will be replaced by the real PlaybackEngine in Phase 3.

```powershell
flutter pub get
flutter analyze
flutter test

# Interactive: paste a path to a local MP3/FLAC/WAV you own, then Open / Play / Pause / seek / volume
flutter run -d windows

# Automated self-test: plays ~15 s, checks open/play/pause/seek/volume, writes a log + PNG, then exits
flutter run -d windows --dart-define=NEXA_SELFTEST=true `
  "--dart-define=NEXA_TEST_AUDIO=<path to your own audio file>" `
  "--dart-define=NEXA_PROBE_LOG_DIR=<folder outside the repo>"
```

Test audio files and logs must stay **outside** the repository.

## External services

- **Local owned/licensed files:** primary source; Mix Engine applies where technically feasible.
- **Audius / Jamendo:** future provider adapters, subject to each service's terms and rights.
- **Spotify:** open in the official app; **not** a NEXA audio source, even with Premium.
- **YouTube:** user-requested option, **currently a proposed change request**, not an approved implementation. The potential path is an official visible embedded video player or opening YouTube externally. No audio extraction or mixing.

This private repository must **never contain copyrighted music files, secrets, private listening databases, tokens or personal history**.

## Design references

The approved visual concept is NEXA Design 04: Home and Player. The two PNG mockups are not yet committed; ask the owner for the originals before Phase 1.
