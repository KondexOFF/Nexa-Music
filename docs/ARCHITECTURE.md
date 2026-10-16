# NEXA Music — Architecture Notes (planning only)

**Authority:** `../NEXA_Music_Master_Plan_Claude.md`. These notes explain its intent; they do **not** authorize code or extra features.

## Target

Flutter/Dart desktop (Windows 11 x64). Riverpod manages state; Drift/SQLite persists *local* user data. The Phase 0 audio experiment selects a backend only after real Windows playback tests.

## Planned boundaries

```text
Flutter UI / navigation / design tokens
  ├── Local library + metadata + playlists (Phase 2)
  ├── Playback Engine + queue (Phase 3)
  │   └── Mix Engine: Gapless / Crossfade / cautious Smart Mix (Phase 4)
  ├── NEXA DNA + NEXA Wave local recommendations (Phase 5)
  └── Providers: Audius / Jamendo (Phase 6)
      └── Optional YouTube proposal (CR-001; NOT APPROVED)
```

No feature directories or empty stubs should be created before their phase.

## Provider safety model

The internal `MusicSource` abstraction must **not** imply all providers return a playable audio URL. Before any provider integration, document capabilities separately:

| Source | Playback approach | Gapless / Crossfade | Background playback in NEXA | Recommendation-data use |
|---|---|---|---|---|
| User-owned local files | Native audio engine | Phase 4, if proven | Phase 3, if supported | Local consent-based listening history |
| Audius | Official API, subject to terms | Only after explicit source-rights review | Provider-specific | Requires a terms/privacy review |
| Jamendo | Official API, license-sensitive | Only after explicit source-rights review | Provider-specific | Requires a terms/privacy review |
| Spotify | Open official Spotify app | **Never with Spotify audio** | Handled by Spotify | Do not use Spotify Content/API for NEXA training |
| YouTube (CR-001 only) | Visible official IFrame player in OS WebView, or external browser | **Never with YouTube audio** | **No** hidden/minimized/background playback in NEXA embed | Keep YouTube metadata separate; policy review required |

When changing source, maintain exclusive active playback: stop or pause the previous provider before starting the next. A YouTube video must not be routed as an audio stream into `PlaybackEngine`. UI should clearly label the active source. An embedded YouTube player must remain visible while playing and respect all official controls, branding and ads.

## YouTube technical feasibility gate (future Phase 6 only, if CR approved)

1. Evaluate Microsoft's OS-provided WebView2 within Flutter Windows; validate YouTube IFrame Player API in an actual app window.
2. Verify embedded-player client identification and credentials for **non-store Windows apps**, playback availability, sizing, visibility, event handling, blocked embeds and error fallback.
3. Support user-initiated play/pause/seek only within documented IFrame API capabilities, not through media interception.
4. Search via YouTube Data API **only if** the user configures a properly secured project and quota permits it; otherwise a supported YouTube link or browser handoff may be the first deliverable.
5. Never use `yt-dlp`, unofficial YouTube Music endpoints, audio extraction, download/caching, ads bypass or a hidden video to imitate a native music source.
6. If feasibility or policy compliance cannot be demonstrated, **do not implement**: present the official browser handoff alternative for owner decision.

Official policy references:
- https://developers.google.com/youtube/iframe_api_reference
- https://developers.google.com/youtube/terms/developer-policies
- https://developers.google.com/youtube/terms/required-minimum-functionality
- https://developers.google.com/youtube/terms/developer-policies-guide

## Privacy and offline guarantees

Local files, taste preferences and listening events stay on the user's PC. No collection without consent; private session disables logging. Offline playback must remain usable even when providers fail. Never persist unreviewed third-party metadata in a combined recommendation history.

## Still undecided

Exact Windows audio engine (Phase 0), optional YouTube wrapper/credential approach (CR-001), post-1.0 additions. Record real decisions in `DECISIONS.md`.
