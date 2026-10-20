# NEXA Music · System architecture

*Architecture snapshot · 20 October 2026*

One listening experience, multiple source types. NEXA separates its UI, playback logic, local data and provider integrations so that a provider's restrictions never silently become a promise made by the player.

## Core components

```text
Flutter experience (NEXA Design 04)
├─ Collection       local MP3 / FLAC / WAV, SQLite, metadata, playlists
├─ Playback         queue, media_kit, output selection, media controls
│  └─ Mix Engine    gapless, crossfade and cautious Smart Mix for local audio
├─ Intelligence     NEXA DNA, listening consent, local Wave ranking
└─ Discover         source-aware search and availability states
   ├─ Audius        official API search + permitted stream endpoint
   └─ Jamendo       official API v3 + owner's local client ID
```

Flutter/Dart is the shared application core. Riverpod handles application state, Drift/SQLite stores local library and preference data, and `media_kit` provides the Windows playback engine. The implementation is on [`dev/v1`](https://github.com/KondexOFF/Nexa-Music/tree/dev/v1); this page is a concise architectural overview, not an API specification.

## Different sources, different capabilities

| Source | In-app playback | Mixing | Personal Wave/history |
| :-- | :-- | :-- | :-- |
| **Local library** | Offline, native player | Gapless / Crossfade / Smart Mix | Yes, subject to consent |
| **Audius** | Permitted streams via official API | Not enabled | Not in Phase 6 |
| **Jamendo** | Permitted streams via official API and owner's client ID | Not enabled | Not in Phase 6 |
| **YouTube — E2** | Proposed official, visible IFrame player | Never | Not part of local history |
| **SoundCloud — E3** | Proposed official embedded widget for links | Never | Not part of local history |
| **Spotify** | Not an in-app audio source; external link only | Never | No Spotify data used for training |

The `MusicSource` boundary describes search, playback method, licence/attribution and error states per provider. It does not assume every catalogue provides a direct audio stream. NEXA does not extract audio, copy streamed tracks into the local library or work around provider restrictions.

## Source hand-off

Native audio (local files, permitted Audius and Jamendo streams) goes through the regular playback engine. Providers that require their **own official player** stay inside that player, not inside `media_kit`. The product should have only one active playback surface at a time; opening an embedded player pauses the native engine and returning to native audio pauses the embedded player.

For future YouTube integration, the feasibility gate must establish that a visible official player works correctly inside Windows WebView2. Branding, controls and ads remain intact; no hidden playback, audio extraction or crossfade. If the embed cannot be supported, NEXA falls back to the original provider page. SoundCloud follows the same official-widget principle, without promising API search where access has not been granted.

## Privacy and reliability

- Local media files stay where the owner put them. The player indexes them without moving or uploading them.
- Music taste, preferences and listening events stay in the user's local database. Learning history requires consent, and private sessions do not record it.
- API credentials or client IDs are supplied by the owner and kept locally; they are not included in code, reports or screenshots.
- Every online source may fail on its own. Search errors, restricted songs or lack of network access do not block the offline library.
- Track pages, artists and relevant licence information remain visible alongside online results.

## Release sequence

1. **Windows core:** Phases 0–6 reported implemented; Phase 7 packaging/performance and full manual validation still pending.
2. **E1:** extend Wave to compatible online catalogues only after provider-rights and privacy review.
3. **E2:** evaluate and, if feasible, add official YouTube embedding.
4. **E3:** add official SoundCloud widget playback for supported links.
5. **E4:** port to macOS, Linux, Android, iOS/iPadOS and Web one platform at a time, with separate platform capabilities and tests.

The approved sequence is recorded in decision **D-017** and requests **CR-001–003** on `dev/v1`. It does **not** mean these extensions are already implemented.

For detailed engineering decisions and the original source-capability matrix, see the [implementation architecture](https://github.com/KondexOFF/Nexa-Music/blob/dev/v1/docs/ARCHITECTURE.md) and the [progress journal](https://github.com/KondexOFF/Nexa-Music/blob/dev/v1/docs/PROGRESS.md).
