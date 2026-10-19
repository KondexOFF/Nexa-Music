# Change Requests — NEXA Music

A request written here is **NOT approved** until the project owner explicitly accepts it. Claude must not implement draft requests.

## CR-001 — YouTube listening option

- **Proposed:** 2026-10-16 (user asked whether YouTube can be a listening alternative).
- **Status:** **APPROVED by the owner on 2026-10-19** (owner message with the plan extension, see D-017), with the restrictions below. YouTube ads are allowed and must stay intact. Implementation still has to pass the feasibility gate in `ARCHITECTURE.md`.
- **Phase:** extension stage E2 (after Phase 6 and the Windows core; see `ARCHITECTURE.md`, "Extension sequence").
- **Do not modify:** Master Plan v1.0, phase 0–5 scope, local Mix Engine, Spotify restrictions.

### Desired value

Let the owner find music videos/songs on YouTube from NEXA, play videos via the official visible YouTube player in a dedicated view, save links/references in permitted local playlists (subject to provider policy), and open the original in YouTube.

### Suggested delivery (if owner approves)

**Preferred:** official YouTube IFrame Player API in a visible, unobstructed OS WebView (Windows WebView2 evaluation required); use YouTube Data API for search when configured and permitted. Display accurate YouTube attribution. Respect minimum 200×200 px viewport; target at least 480×270 px. Show clear errors and a button to open the video in YouTube/browser if embed is denied or technically blocked.

**Fallback:** search/open officially in the system browser, without embedded playback.

### Non-negotiable restrictions

- No hidden, tiny/offscreen or background-only YouTube player, including minimized/closed-window playback.
- No stripping audio from video, downloading/caching tracks, `yt-dlp`/unofficial YouTube Music extraction, ad bypass, fake Premium status, player UI obstruction or controls interception.
- No routing YouTube audio to native PlaybackEngine; **no gapless, crossfade or Smart Mix with YouTube audio**.
- No YouTube metadata blended into NEXA DNA/Wave learning or across-source datasets without separate terms/privacy approval.
- Ensure YouTube source labeling, player branding, ad behavior, client identity and credentials, WebView compatibility and proper visibility. A personal project is not exempt from provider terms.

### Acceptance tests to propose

1. Verified official embedded video starts from a deliberate user action while player is visible; controls, branding and ads remain intact.
2. Closing/minimizing/leaving the YouTube player view stops or pauses YouTube playback.
3. Embed-blocked and no-network errors show a clear external YouTube fallback.
4. Local file playback works independently; never overlaps accidentally with YouTube.
5. No extraction/download or request to undocumented endpoints; no API keys or user data committed.

### Owner decision

- [x] **2026-10-19:** approved — visible official embedded player inside NEXA, YouTube ads allowed (never blocked), no separate audio track, no circumventing background-playback limits, no changes to the official player. The feasibility gate still applies; if it fails, the fallback is opening the video in the browser.

### Official references

- https://developers.google.com/youtube/iframe_api_reference
- https://developers.google.com/youtube/terms/required-minimum-functionality
- https://developers.google.com/youtube/terms/developer-policies
- https://developers.google.com/youtube/terms/developer-policies-guide
- https://developers.google.com/youtube/v3/docs/search/list

## CR-002 — SoundCloud (official embedded player)

- **Proposed and approved:** 2026-10-19 by the owner (plan extension, D-017).
- **Phase:** extension stage E3.
- **Approach:** the official SoundCloud embedded player (Widget API) inside NEXA for SoundCloud links. The SoundCloud API (search, stream URLs) is used only with permitted access. Registering an API app currently requires an Artist Pro subscription, which the owner does not want to require, so **the first version has no SoundCloud search**: it plays a SoundCloud link in the official widget.
- **Restrictions:** credit the uploader and SoundCloud; no downloading, caching or offline access; no stream ripping; no audio modification (no Mix Engine); no ads around SoundCloud content; no SoundCloud marks in NEXA branding.
- **References:** https://developers.soundcloud.com/docs/api/terms-of-use, https://developers.soundcloud.com/docs/api/register-app

## CR-003 — Cross-platform targets

- **Proposed and approved:** 2026-10-19 by the owner (plan extension, D-017).
- **Targets, in order:** Windows (finished first), macOS, Linux, Android, iOS/iPadOS, Web.
- **Rule:** one Flutter core; platform-specific features (media keys / system media controls, file and folder access, embedded web players, background audio, window size) behind adapters. Ports start only after the Windows version has passed the final stage.
