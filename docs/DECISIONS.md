# NEXA Music — Decision Log

Only record decisions that were actually tested/approved. The Master Plan controls scope.

| ID | Topic | Current state | Phase / evidence |
|---|---|---|---|
| D-001 | Windows-first Flutter/Dart, Riverpod, SQLite/Drift | Planned in Master Plan v1.0 | Approved scope |
| D-002 | Windows audio engine (`media_kit` candidate) | **PROPOSED, awaiting owner acceptance of Phase 0.** `media_kit` 1.2.6 + `media_kit_libs_audio` 1.0.7 played a local MP3 (320 kbps / 44.1 kHz) on Windows 11: open, play, pause, seek, volume all passed (automated + manual); owner confirmed audible output, silence on pause, audible seek jump and quieter volume (2026-10-16). | Phase 0 — `reports/PHASE_00_REPORT.md`, `reports/phase_00/` |
| D-003 | NEXA Design 04 visual language | Approved reference concept; mockup PNG upload pending | Phase 1 |
| D-004 | YouTube as optional source | **NOT APPROVED FOR IMPLEMENTATION** | CR-001; possible Phase 6 |
| D-005 | Permission to publish code automatically | **NOT GRANTED**; explicit owner approval needed before push | Git workflow |
| D-006 | Toolchain baseline | Flutter 3.47.7 stable / Dart 3.13.5, Visual Studio Community 2022 17.14 (Desktop C++), Windows 10 SDK 10.0.26100.0. Package versions locked in `pubspec.lock`; `environment.sdk: ^3.13.5`. | Phase 0 |
| D-007 | Phase 0 prototype code (`lib/audio_probe/`) | Temporary technical screen and self-test for the engine proof only. Not the NEXA UI and not the PlaybackEngine design; to be replaced in Phase 1 (UI) / Phase 3 (engine). | Phase 0 |

## D-002 details (Phase 0, 2026-10-16)

- **Alternatives:** none were built; the Master Plan names `media_kit` as the candidate, and it passed, so no second engine was evaluated. Requirements still unproven for later phases: two simultaneous decoders for Crossfade (Phase 4), gapless transitions (Phase 4), output-device switching and Windows media keys (Phase 3), FLAC/WAV (Phase 2/3; only MP3 tested here).
- **Audio-only libs:** `media_kit_libs_audio` (pulls `media_kit_libs_windows_audio` 1.0.9) is used instead of the video libs, because Phases 0 to 5 only need audio.
- **Known build warning:** CMake dev warning CMP0175 inside `media_kit_libs_windows_audio/windows/CMakeLists.txt` (third-party plugin); it does not fail the build.
- **Approval:** pending owner acceptance of Phase 0.

For new decisions: date, owner approval, alternatives, reason, tested behavior, impact, links to report/commit. Do not silently edit the authoritative plan.
