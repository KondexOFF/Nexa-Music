# NEXA Music — progress journal

Compact log required by owner decision D-015 (2026-10-18): what is done, what is left, known problems.
Full manual testing, visual polish and non-critical defects are handled in the **final stage** after Phase 7.

## Status

| Phase | State | Branch / commit |
|---|---|---|
| 0 — Diagnostics, audio proof | Accepted by owner (2026-10-16) | `phase/00-review` `eb9fcbd` |
| 1 — Design system, Home, Now Playing | Implemented; crash fix 2026-10-18; owner acceptance pending (final stage) | `phase/01-review` |
| 2 — Local library and database | Implemented 2026-10-18 (automated checks PASS; manual check in final stage) | `dev/v1` |
| 3 — Playback Engine | In progress | `dev/v1` |
| 4 — NEXA Mix Engine | Not started | |
| 5 — NEXA DNA and NEXA Wave v1 | Not started | |
| 6 — Allowed online catalogues (Audius, Jamendo) | Not started | |
| 7 — Polish, performance, Windows build | Not started | |
| Final stage — full Windows testing and fixes | Not started | |

## Technical debt / known problems (for the final stage)

| ID | Found | Severity | Problem | State |
|---|---|---|---|---|
| TD-01 | Phase 1, owner check 2026-10-17 | High | App closed itself (access violation in `flutter_windows.dll`) on queue button, Settings → audio test, Play/Pause tooltip while a Windows accessibility client was active. | **Fixed in code, not yet accepted:** cause and fix in D-016; 20 accessibility-tree tests pass; on the owner's PC the crash sequence (tooltip → Mix chip), queue wide + narrow, audio test open/back and maximise no longer crashed (run 32, 0 crash records). Owner re-check: final stage. |
| TD-02 | Phase 1, run 32 (2026-10-18) | Medium | After resizing / maximising the window, Windows still logged `Failed to update ui::AXTree, error: Nodes left pending by the update` (one node, repeated). No crash, UI kept working, but the screen-reader tree stops updating. Not reproduced by the widget tests yet. | Open — investigate with Narrator in the final stage (Phase 7 accessibility). |
| TD-03 | Phase 1 | Low | Manual checklist items г–е (queue button, audio test, Play/Pause tooltip) not re-confirmed by the owner after the fix. | Final stage |
| TD-04 | Phase 2 | Low | WAV files: RIFF INFO tags are decoded as Latin-1 by `audio_metadata_reader`, so Cyrillic WAV tags look garbled (MP3/FLAC tags are fine; untagged files use the file name). | Open |
| TD-05 | Phase 2 | Medium | Import of the owner's real music folder through the Windows folder dialog not yet tried by hand (covered by tests with 35 generated WAV files). | Final stage |

## Log

- 2026-10-18 — **Phase 2** (local library): Drift/SQLite database (schema v1 with migration strategy), folder and file import (MP3/FLAC/WAV, recursive, never copies/moves/deletes files), metadata and covers (embedded or cover.jpg/folder.jpg, cached in the app-data folder), duplicate-free rescans, missing files kept and marked with a clear reason, startup rescan, search (case-insensitive incl. Cyrillic), favorites, playlists (create, rename, delete, add, remove, reorder), Library page (songs, favorites, albums, artists, folders), playlist page, real sidebar playlists, real top-bar search. Checks: analyze 0 issues, 60/60 tests, `flutter build windows` OK.
- 2026-10-18 — Phase 1 crash fix (D-016), capture harness: a screenshot that fails to save now makes the run FAIL. Owner decision D-015 recorded. Phase 2 started.
