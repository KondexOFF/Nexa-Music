# NEXA Music — Decision Log

Only record decisions that were actually tested/approved. The Master Plan controls scope.

| ID | Topic | Current state | Phase / evidence |
|---|---|---|---|
| D-001 | Windows-first Flutter/Dart, Riverpod, SQLite/Drift | Planned in Master Plan v1.0 | Approved scope |
| D-002 | Windows audio engine (`media_kit` candidate) | **APPROVED by owner on acceptance of Phase 0 (2026-10-16).** `media_kit` 1.2.6 + `media_kit_libs_audio` 1.0.7 played a local MP3 (320 kbps / 44.1 kHz) on Windows 11: open, play, pause, seek, volume all passed (automated + manual); owner confirmed audible output, silence on pause, audible seek jump and quieter volume (2026-10-16). | Phase 0 — `reports/PHASE_00_REPORT.md`, `reports/phase_00/` |
| D-003 | NEXA Design 04 visual language | Approved reference concept. Original PNGs stored in `assets/design/` (reference only, not bundled in the app). Implemented as real Flutter widgets in Phase 1. | Phase 1 |
| D-004 | YouTube as optional source | **NOT APPROVED FOR IMPLEMENTATION** | CR-001; possible Phase 6 |
| D-005 | Permission to publish code automatically | **NOT GRANTED**; explicit owner approval needed before push | Git workflow |
| D-006 | Toolchain baseline | Flutter 3.47.7 stable / Dart 3.13.5, Visual Studio Community 2022 17.14 (Desktop C++), Windows 10 SDK 10.0.26100.0. Package versions locked in `pubspec.lock`; `environment.sdk: ^3.13.5`. | Phase 0 |
| D-007 | Phase 0 prototype code (`lib/audio_probe/`) | Temporary technical screen and self-test for the engine proof only. Not the NEXA UI and not the PlaybackEngine design; to be replaced in Phase 1 (UI) / Phase 3 (engine). | Phase 0 |
| D-008 | State management | `flutter_riverpod` 3.4.3 (Notifier API only) for navigation, right-panel visibility and the Mix Engine UI preview. Stack named in Master Plan v1.0 section 3. | Phase 1 |
| D-009 | Typography | Manrope (SIL OFL 1.1, licence in `assets/fonts/OFL.txt`), bundled as 5 static weights (400-800); includes Cyrillic for the planned Russian translation; works offline. Chosen by owner ("bundle a free font"). | Phase 1 |
| D-010 | Elements of Design 04 outside the current phase | Owner decision (2026-10-16): keep them but honest. Transport/seek/volume visible but disabled with "Phase 3" tooltips; all placeholder content labelled DEMO; Lyrics tab disabled "Not in v1.0"; Smart Mix text without tempo/key claims; greeting by time of day, no avatar/account; search shown as unavailable ("Phase 2"). | Phase 1 |
| D-011 | Mix Engine panel in Phase 1 | Interactive PREVIEW only: mode, 0-12 s slider and Smart Mix switch change the visualisation and the player chip; nothing touches audio, nothing is persisted. Real MixSettings and audio arrive in Phase 4. | Phase 1 |
| D-012 | Placeholder artwork | Covers and the NEXA Wave hero are drawn in code (`CustomPainter`), original artwork; no images copied from the mockups or third parties. | Phase 1 |
| D-013 | Adaptive layout | Breakpoints: right panel collapses below 1180 px (Up Next moves into an end drawer, Mix Engine moves below the player), sidebar becomes an icon rail below 1100 px, compact player bar below 1260 px. Windows minimum window size 1024 x 640 (logical) set in the runner. | Phase 1 |
| D-014 | Phase 0 audio prototype after Phase 1 | Kept unchanged as a developer tool: Settings -> "Open audio engine test"; `NEXA_SELFTEST=true` still runs the automated self-test. | Phase 1 |

## D-002 details (Phase 0, 2026-10-16)

- **Alternatives:** none were built; the Master Plan names `media_kit` as the candidate, and it passed, so no second engine was evaluated. Requirements still unproven for later phases: two simultaneous decoders for Crossfade (Phase 4), gapless transitions (Phase 4), output-device switching and Windows media keys (Phase 3), FLAC/WAV (Phase 2/3; only MP3 tested here).
- **Audio-only libs:** `media_kit_libs_audio` (pulls `media_kit_libs_windows_audio` 1.0.9) is used instead of the video libs, because Phases 0 to 5 only need audio.
- **Known build warning:** CMake dev warning CMP0175 inside `media_kit_libs_windows_audio/windows/CMakeLists.txt` (third-party plugin); it does not fail the build.
- **Approval:** owner accepted Phase 0 and confirmed `media_kit` (2026-10-16).

For new decisions: date, owner approval, alternatives, reason, tested behavior, impact, links to report/commit. Do not silently edit the authoritative plan.
