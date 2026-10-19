# NEXA Music — progress journal

Compact log required by owner decision D-015 (2026-10-18): what is done, what is left, known problems.
Full manual testing, visual polish and non-critical defects are handled in the **final stage** after Phase 7.

## Status

| Phase | State | Branch / commit |
|---|---|---|
| 0 — Diagnostics, audio proof | Accepted by owner (2026-10-16) | `phase/00-review` `eb9fcbd` |
| 1 — Design system, Home, Now Playing | Implemented; crash fix 2026-10-18; owner acceptance pending (final stage) | `phase/01-review` |
| 2 — Local library and database | Implemented 2026-10-18 (automated checks PASS; manual check in final stage) | `dev/v1` |
| 3 — Playback Engine | Implemented 2026-10-18 (automated checks PASS; 20-track manual run in final stage) | `dev/v1` |
| 4 — NEXA Mix Engine | Implemented 2026-10-18 (automated checks PASS; listening test in final stage) | `dev/v1` |
| 5 — NEXA DNA and NEXA Wave v1 | Implemented 2026-10-19 (automated checks PASS; real listening check in final stage) | `dev/v1` |
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
| TD-06 | Phase 3 | Medium | Windows media keys use `RegisterHotKey`: while NEXA runs, other players (browser, Spotify) do not receive Play/Pause/Next. System Media Transport Controls would be the cleaner integration. | Open — decide in Phase 7 |
| TD-07 | Phase 3 | Medium | Real audio of Phase 3 (20 tracks in a row, pause/resume, repeat/shuffle, output-device change, media keys) only tested with a fake engine; real Windows run with the owner's files pending. | Final stage |
| TD-08 | Phase 4 | Medium | Smart Mix v1 uses track length and album order only; silence and signal-level analysis are not implemented (needs decoded audio levels). The UI says so. | Open |
| TD-09 | Phase 4 | High | Crossfade/gapless only verified with fake decks; listening test on Windows (no clipping, no abrupt cut, 0 s = no overlap, album tracks not mixed, several formats, short files) pending. | Final stage |
| TD-10 | Phase 5 | Medium | NEXA Wave ranking checked on generated test libraries only; whether the picks feel right on the owner's real library (and the weights in `wave_ranker.dart`) is not yet judged by a person. | Final stage |
| TD-11 | Phase 5 | Low | "Listened" time of a history event is the playback position when the track ended, so seeking forward counts as listening. Good enough for skip / finish signals. | Open |
| TD-12 | Phase 5 | Low | The NEXA DNA picker only offers genres and artists that exist in the library tags; a library without genre tags offers artists only. | Open |

## Log

- 2026-10-19 — **Phase 5** (NEXA DNA and NEXA Wave v1): schema v3 (dislikes on tracks, `listening_events`, `taste_items`; migration from v2 tested); listening history written only with consent and never in a private session or while learning is paused (event: track, start, listened time, completed / skipped / stopped, Library or Wave); NEXA DNA picker with the library's genres and artists (like / exclude / clear, can be skipped, history consent asked there); like and dislike (a like clears a dislike, a dislike clears the like; a dislike skips a playing Wave song); Familiar <-> Discovery slider; private session (not saved, ends with the app); "why this song" in the Wave list and on Now Playing; own explainable ranker (liked artist / genre, favorites, finished listenings, fast skips weaker than a dislike, recently played left out, unavailable and excluded never); endless Wave that refills itself; Home "Play Wave" / "Shuffle" and the My Taste card now real; Settings: consent, pause learning, private session, delete history, reset NEXA DNA. All local, no network.

- 2026-10-18 — **Phase 4** (NEXA Mix Engine): two media_kit decks (`MixingEngine`); Gapless via preloaded mpv playlist entry (`prefetch-playlist`); Crossfade 0–12 s with preloading and equal-power (cos/sin) gains, safe fallback to a normal transition when preloading fails; Smart Mix v1 (shortens the overlap for short tracks, never lengthens); the next track of the same album is never mixed (switchable); sources without mix rights never overlap; MixSettings saved; panel explains the next transition. Checks: analyze 0 issues, 82/82 tests.
- 2026-10-18 — **Phase 3** (Playback Engine): `PlaybackEngine` interface + media_kit engine, queue (play now / next / add / remove / clear), play/pause, seek bar, next/previous (restart after 3 s), shuffle (keeps every track once, restores order), repeat off/all/one, volume and mute, output-device choice, missing files skipped with a notice, engine errors shown, settings saved (schema v2: settings table), Windows media keys (runner hot keys + `WM_APPCOMMAND`). Checks: analyze 0 issues, 70/70 tests, `flutter build windows` OK.
- 2026-10-18 — **Phase 2** (local library): Drift/SQLite database (schema v1 with migration strategy), folder and file import (MP3/FLAC/WAV, recursive, never copies/moves/deletes files), metadata and covers (embedded or cover.jpg/folder.jpg, cached in the app-data folder), duplicate-free rescans, missing files kept and marked with a clear reason, startup rescan, search (case-insensitive incl. Cyrillic), favorites, playlists (create, rename, delete, add, remove, reorder), Library page (songs, favorites, albums, artists, folders), playlist page, real sidebar playlists, real top-bar search. Checks: analyze 0 issues, 60/60 tests, `flutter build windows` OK.
- 2026-10-18 — Phase 1 crash fix (D-016), capture harness: a screenshot that fails to save now makes the run FAIL. Owner decision D-015 recorded. Phase 2 started.
