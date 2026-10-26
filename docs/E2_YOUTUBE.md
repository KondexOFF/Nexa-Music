# YouTube in NEXA Music (E2)

How YouTube works in NEXA, what is shared, the API key, quotas and updates. Decision D-022; built on the accepted prototype E2.0 (`reports/E2_0_PROTOTYPE_REPORT.md`) and the gate `E2_FEASIBILITY.md`.

## What it is

- **Off by default.** Settings → YouTube → "Use YouTube". Turning it on first shows the consent screen: what YouTube / Google receive, what NEXA keeps (nothing about watching), links to the YouTube Terms of Service and the Google Privacy Policy. Turning it on again shows it again.
- **Discover → YouTube** is a section of its own, marked "YouTube". It is never mixed into the Audius / Jamendo results.
  - Paste a link (watch, youtu.be, Shorts, embed, live, music.youtube.com or an 11-character video id) → **Watch**. No key needed.
  - With your own YouTube Data API key: search → results with thumbnail, title, channel, length and the YouTube mark → **Watch in NEXA** or **Open on YouTube**.
- **The YouTube page** shows YouTube's own official player (IFrame Player API in Microsoft Edge WebView2), 16:9, at least 480 × 270, with YouTube's controls, branding and ads. Nothing is drawn over it.
  - Full screen and Esc are YouTube's own.
  - "Open on YouTube" and any link inside the player open in the system browser.
  - Errors 2, 5, 100, 101 / 150, 153, no WebView2 and no internet are explained in plain text.
- **One sound at a time** (`PlaybackArbiter`): starting a video pauses NEXA; starting NEXA pauses the video. The Play / Pause media key and the Windows media overlay belong to the player started last; Next / Previous do nothing for YouTube.
- **No background play:** the video pauses when NEXA is minimised or hidden and stops when you leave the YouTube page or close NEXA.

## What NEXA never does with YouTube

- No download, caching or offline copies; no audio extraction; YouTube's sound never goes through NEXA's PlaybackEngine, Crossfade or Mix Engine.
- No hidden or background player, no ad blocking, no changes to the player.
- No history, NEXA Wave, NEXA DNA or playlists for YouTube; no viewing statistics, analytics or tracking of any kind — also for videos made for kids (Developer Policies III.E.4: API clients must not track viewing of "made for kids" content; NEXA tracks nothing at all).
- Search results live in memory for the session only (Developer Policies III.E.4: API data is not stored beyond what is needed). Nothing is written to disk by NEXA.

## Your YouTube Data API key (only for search)

1. In the Google Cloud Console create a project, enable **YouTube Data API v3**, create an **API key**.
2. Restrict the key: *API restrictions → YouTube Data API v3 only*. (An application restriction by website or IP does not fit a desktop app.)
3. Settings → YouTube → paste the key → **Save** → **Check key** (uses 1 quota unit).
4. **Delete key** removes it from NEXA's database.

The key is stored only in NEXA's local database (`nexa_library.sqlite` in NEXA's data folder), never in the repository, reports or logs; error texts never include it. Like any key inside a desktop app it cannot be perfectly protected from someone with access to this PC — use a key only for NEXA and delete it in Google Cloud if in doubt.

### Quota

Google's default quota is **10,000 units per day** per project (resets at midnight Pacific Time). A search costs **100 units** (`search.list`) plus **1 unit** for the lengths (`videos.list`): about **99 searches a day**. NEXA searches only when you press Search or Enter (never while typing) and repeats of a recent query come from memory. When the quota is used up, NEXA says so; pasting links keeps working.

## Privacy: what YouTube and Google receive

The same as any YouTube player: the videos you open, your IP address and the cookies YouTube sets in NEXA's built-in web view. Searches send your search words with your key to Google. The web view's data (cookies, cache) is in the `webview2` folder inside NEXA's data folder (`%APPDATA%\com.kondexoff\nexa_music\webview2`), not next to the exe. To clear it, close NEXA and delete that folder.

## Updates

- **YouTube player:** loaded from YouTube every time the YouTube page opens, so it is always the current version (Developer Policies III.B.1).
- **Microsoft Edge WebView2 Runtime:** part of Windows 11 and updated by Windows Update / Microsoft Edge automatically (Evergreen). If it is missing, NEXA says so on the YouTube page and everything else works; it can be installed from Microsoft ("WebView2 Runtime, Evergreen Standalone Installer").
- **NEXA Music (Portable):** NEXA has no automatic update. To update: close NEXA, replace the Portable folder with the new one (or unpack it next to the old one and start the new `nexa_music.exe`). Your library, settings, key and WebView2 data stay in NEXA's data folder and are kept. Check `SHA256SUMS.txt` of the new folder.

## Developer notes

- Code: `lib/integrations/youtube/` (link parser, Data API client, WebView2 embed), `lib/features/youtube/` (player controller, page, Discover section, settings), `lib/features/player/playback_arbiter.dart`, `assets/youtube/player.html`.
- Client identity: the player page is served from the WebView2 virtual host `https://com.kondexoff.nexamusic`; YouTube receives it as Referer (without it: error 153, verified in E2.0).
- Tests: `test/youtube_*_test.dart`; Windows with real WebView2: `flutter test integration_test/youtube_test.dart -d windows` (needs the internet; silent; the Data API is a local stand-in).
