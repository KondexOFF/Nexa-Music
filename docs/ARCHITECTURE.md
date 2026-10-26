# NEXA Music — Architecture

**Authority:** `../NEXA_Music_Master_Plan_Claude.md` (v1.0) plus the owner-approved extension D-017 (2026-10-19, `DECISIONS.md`) and change requests CR-001 (YouTube), CR-002 (SoundCloud), CR-003 (platforms). This file describes how the extension fits the existing code; it does not authorise anything beyond those decisions.

## Layers

```text
Flutter UI (app/, ui/, features/*)                  one core for all platforms
  ├── Local library, playlists, search        features/library      (Phase 2)
  ├── Player + queue                          features/player       (Phase 3)
  │   └── PlaybackEngine (media_kit)          core/audio            (Phase 3)
  │       └── Mix Engine: gapless/crossfade   features/mix_engine   (Phase 4)
  ├── NEXA DNA + NEXA Wave                    features/nexa_dna, nexa_wave (Phase 5)
  ├── Discover: one search over catalogs      features/discover     (Phase 6)
  │   └── MusicSource adapters                integrations/*
  │       ├── Audius   - stream URL  -> PlaybackEngine        (Phase 6)
  │       ├── Jamendo  - stream URL  -> PlaybackEngine        (Phase 6)
  │       ├── YouTube  - visible official embed (no PlaybackEngine) (E2)
  │       └── SoundCloud - official widget embed (no PlaybackEngine) (E3)
  └── Platform adapters                       platform/*            (E4, ports)
      media keys / system media controls, file & folder access,
      embedded web view, background audio, window size
```

Rules:

- A `MusicSource` declares its capabilities; nothing assumes a source behaves like a local file.
- Sources that return a permitted audio stream (local files, Audius, Jamendo) go through `PlaybackEngine`. Sources that only allow an official player (YouTube, SoundCloud) are shown in that player, visibly, and never routed into `PlaybackEngine`.
- Exactly one thing plays at a time: starting an embedded player pauses `PlaybackEngine` and vice versa.
- Online results are never stored as files; no download, offline copy or cache beyond what playback needs.
- API keys / client ids are entered by the owner in Settings and stored in the local database only - never in the repository, screenshots or reports.

## Source capabilities

| Source | Search | Playback in NEXA | Mix Engine (gapless / crossfade) | Listening history / Wave | Attribution |
|---|---|---|---|---|---|
| Personal library | Local database | `PlaybackEngine`, offline | Yes | Yes, with consent | - |
| Audius | Official REST API | Stream URL from the API in `PlaybackEngine` | **No** (no explicit right to process the audio; plain cut between tracks) | Wave picks since E1 (opt-in, trending by liked genre / the liked artist's songs, session memory only); **no** history (terms review 2026-10-25, `E1_PLAN.md`) | Artist name + "Audius", link to the track page |
| Jamendo | Official API v3 with the owner's own `client_id` | API stream URL in `PlaybackEngine`, non-commercial use only | **No** (Creative Commons licences differ; no audio processing) | Wave picks since E1 (opt-in, `fuzzytags` / `artist_name`, session memory only); **no** history | Artist + "Jamendo", link to the track page, licence shown |
| YouTube (CR-001, E2) | YouTube Data API with the owner's own key, if configured; otherwise pasted links | Official IFrame player, visible, ads untouched; pauses when hidden or minimised | **Never** | **No** (kept separate) | YouTube branding inside the official player |
| SoundCloud (CR-002, E3) | None without permitted API access (Artist Pro needed for API apps) | Official widget for pasted links | **Never** | **No** | Uploader + "SoundCloud" |
| Spotify | - | Not a source (official "open in Spotify" link at most) | Never | Never | - |

## Extension sequence (D-017)

1. **Phase 6** — Audius and Jamendo: `MusicSource` interface, both adapters, Discover search across catalogs, source and playback labels, attribution links, settings for the Jamendo `client_id`, offline / rate-limit handling. Local mode unaffected.
2. **Phase 7** — Windows polish, performance, accessibility, `flutter build windows`.
3. **Final stage** — full manual Windows testing and fixes (incl. the open technical debt).
4. **E1** — NEXA Wave across catalogs where permitted (online picks clearly labelled; no history of online tracks without a terms review). Implemented on `feature/e1-wave-catalogs` (2026-10-25): plan, terms review and tests in `E1_PLAN.md`.
5. **E2** — YouTube (CR-001) after the feasibility gate below.
6. **E3** — SoundCloud widget (CR-002).
7. **E4** — ports, one platform at a time: macOS, Linux, Android, iOS/iPadOS, Web. Each port: platform adapters, build, smoke test; features a platform cannot support are disabled with an explanation.

## YouTube feasibility gate (E2)

1. Embedded web view on Windows (WebView2) inside the app window; official IFrame Player API.
2. Check that embedding works for a desktop app (player configuration / referrer errors), sizes ≥ 200×200 px (target 480×270), events, blocked embeds and the browser fallback.
3. Ads, branding and controls untouched; the player stays visible while playing; leaving or minimising pauses it.
4. Search only with the owner's own YouTube Data API key and quota; otherwise pasted links.
5. Never `yt-dlp`, unofficial endpoints, audio extraction, download or a hidden player. If the gate fails: browser fallback only, and the owner is told.

Gate result (2026-10-26): `E2_FEASIBILITY.md` - feasible with conditions; prototype E2.0 first (Referer / error 153, WebView2 texture rendering, media keys, pause on hide, package build).

References: https://developers.google.com/youtube/iframe_api_reference, https://developers.google.com/youtube/terms/required-minimum-functionality, https://developers.google.com/youtube/terms/developer-policies

## Privacy and offline guarantees

Local files, taste choices and listening events stay on the device. History only with consent; private session and paused learning record nothing. The local library keeps working without network; online sources fail with a clear message and never block local playback. Online catalog data is not mixed into the local listening history. E1: online Wave picks are off until the user switches them on; then only liked genre / artist names are sent to the catalogs as search words, and the picks live in memory for the session.
