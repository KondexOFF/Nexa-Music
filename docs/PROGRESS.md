# NEXA Music — progress journal

Compact log required by owner decision D-015 (2026-10-18): what is done, what is left, known problems.
Full manual testing, visual polish and non-critical defects are handled in the **final stage** after Phase 7.

## Status

| Phase | State | Branch / commit |
|---|---|---|
| 0 — Diagnostics, audio proof | Accepted by owner (2026-10-16) | `phase/00-review` `eb9fcbd` |
| 1 — Design system, Home, Now Playing | Implemented; crash fix 2026-10-18; owner acceptance pending (final stage) | `phase/01-review` |
| 2 — Local library and database | In progress | `dev/v1` |
| 3 — Playback Engine | Not started | |
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

## Log

- 2026-10-18 — Phase 1 crash fix (D-016), capture harness: a screenshot that fails to save now makes the run FAIL. Owner decision D-015 recorded. Phase 2 started.
