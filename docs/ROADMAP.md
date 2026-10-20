# NEXA Music · Development record

*Updated 20 October 2026 · Private development*

NEXA Music is a Windows-first personal player in active development. **Implementation progress is not the same as release acceptance:** the owner moved full manual testing, visual polish and non-blocking fixes to a final stage after Phase 7 (decision D-015).

The latest published development snapshot is [`dev/v1` at `52b76c6`](https://github.com/KondexOFF/Nexa-Music/tree/dev/v1). The default `main` branch carries the project presentation and documentation, not the app's current source tree.

## Core roadmap

| Phase | Scope | Status at the latest owner report |
| :-- | :-- | :-- |
| **00** | Environment and Windows audio proof | Accepted by owner (16 Oct); [`phase/00-review`](https://github.com/KondexOFF/Nexa-Music/tree/phase/00-review) |
| **01** | Design 04, Home and Now Playing | Implemented; accessibility crash fix reported, owner re-check pending; [`phase/01-review`](https://github.com/KondexOFF/Nexa-Music/tree/phase/01-review) |
| **02** | Local MP3/FLAC/WAV library, metadata and playlists | Implemented on `dev/v1`; real music-folder import pending |
| **03** | Playback Engine, queue, media keys and devices | Implemented on `dev/v1`; long real-audio run pending |
| **04** | Gapless, Crossfade and Smart Mix v1 | Implemented on `dev/v1`; listening checks pending |
| **05** | NEXA DNA and personal NEXA Wave | Implemented on `dev/v1`; recommendations await human evaluation |
| **06** | Audius and Jamendo catalogues | Implemented on `dev/v1`, commit [`52b76c6`](https://github.com/KondexOFF/Nexa-Music/commit/52b76c6); reported automated and API checks passed |
| **07** | Windows polish, performance and packaging | Not started |
| **Final** | Full Windows test, fixes and owner acceptance | Not started |

### Phase 6: what is in scope

- **Discover:** one search across Audius and Jamendo, with source labels, availability notices and links to the original track pages.
- **Playback:** permitted catalogue streams pass through the regular player. The Mix Engine does **not** crossfade online sources; catalog tracks do not enter personal listening history at this stage.
- **Resilience:** online providers can fail independently without breaking local playback. Jamendo needs the owner's own client ID, stored locally rather than committed to GitHub.
- **Verification reported:** `flutter analyze` returned no issues and 126/126 automated tests passed; live Audius and Jamendo API checks were reported successful. A person has not yet listened through the streaming scenarios.

The owner's latest journal also reports a Jamendo live check with 10 playable results and an HTTP 206 audio response. This confirms API accessibility in that test, not the quality of a complete listening session.

## Approved extensions — after the Windows core

| Step | Direction | Boundary |
| :-- | :-- | :-- |
| **E1** | NEXA Wave across permitted catalogues | New source capabilities and privacy/terms review first |
| **E2** | YouTube in an official visible embedded player | Feasibility gate; official branding, controls and ads intact; no audio extraction or Mix Engine |
| **E3** | SoundCloud official widget | Permitted links and widget playback; no promise of unrestricted API search |
| **E4** | macOS, Linux, Android, iOS/iPadOS and Web | Ports one by one after Windows acceptance, with platform-specific adapters |

These extensions were approved as a direction under D-017 and CR-001–003; **none is shipped**. Availability of individual songs depends on provider access and rights, not on NEXA alone.

## Final validation priorities

1. **Real Windows audio:** long mixed-format queue, seek/pause, device change, missing files, repeat/shuffle and media keys.
2. **Transitions:** crossfade/gapless without clipped or abrupt boundaries, album continuity, short tracks and the 0-second setting.
3. **Accessibility:** re-check the fixed `flutter_windows.dll` crash and investigate the remaining AXTree update warning after window resizing.
4. **Real library and personalization:** Windows folder picker, Cyrillic metadata, NEXA DNA/Wave selection quality, privacy consent and private sessions.
5. **Online listening:** Audius/Jamendo stream start, errors, attribution, client ID handling and no unauthorized online audio mixing.
6. **Release:** Windows package, performance, final visual review, documented limitations and owner acceptance.

The most consequential open checks are the **real-audio playback/crossfade tests** and **Windows accessibility validation**. Automated tests with fake engines or generated libraries do not close those items.

## Source of truth

- [Development progress and technical debt (`dev/v1`)](https://github.com/KondexOFF/Nexa-Music/blob/dev/v1/docs/PROGRESS.md)
- [Implementation architecture and source-capability rules (`dev/v1`)](https://github.com/KondexOFF/Nexa-Music/blob/dev/v1/docs/ARCHITECTURE.md)
- [Phase 0 report](https://github.com/KondexOFF/Nexa-Music/blob/phase/00-review/reports/PHASE_00_REPORT.md)
- [Phase 1 report](https://github.com/KondexOFF/Nexa-Music/blob/phase/01-review/reports/PHASE_01_REPORT.md)

*Milestone and test statements reflect the owner-provided development journal, not an independent test run of the Windows application.*
