# E1 — NEXA Wave across catalogs: plan

Authority: owner message 2026-10-25 ("Private Release v1.0.0 + начало E1"), D-017, `ARCHITECTURE.md` (extension E1). Branch `feature/e1-wave-catalogs` from `dev/v1` (after the v1.0.0 release). Tag and release v1.0.0 are not touched; E2–E4 are not started.

## 1. Terms review (2026-10-25)

| Question | Audius | Jamendo | Decision for E1 |
|---|---|---|---|
| Official API for picks | REST API v1: `/tracks/trending` (filters `genre`, `time`), `/tracks/search`, `/tracks/{id}/stream`; free plan 10 req/s, 500 000 req/month; works with `app_name`, an API key is optional (docs.audius.co/sdk) | API v3 `/tracks/` with `fuzzytags`, `artist_name`, `boost=popularity_*`, `groupby`, `include=musicinfo` (developer.jamendo.com/v3.0/tracks); owner's own `client_id` | Only these documented endpoints; at most 3 genres + 3 artists per lookup, one lookup per 30 min (2 min after a failure) |
| Personalisation / sending taste | Not addressed by the Terms of Use / Open Music License; scraping and collecting user data are forbidden | "Must not request more personal data than needed"; actions on behalf of a member only via Jamendo Connect | NEXA sends only liked genre / artist names as search words, **opt-in** switch, default off; never history, files, excluded items or any account data; no accounts used |
| Storing data | API content is for "active streaming use only", not for downloading or local serving (Audius ToU) | "Must not be specifically designed to cache the content nor offering an offline access"; caching only as reasonably necessary; reflect content changes promptly | Picks kept **in memory for the session only**; nothing written to the database; stream URLs are re-asked every 30 min |
| History / user actions | — | Member actions only by the member | Catalog songs are **not** written to the listening history (D-017 rule kept); "Not for me" hides a catalog song for the session only |
| Processing audio (crossfade) | No explicit right; Creators may restrict use; CC-ND licences forbid derivatives | Depends on each track's CC licence | Unchanged: no Mix Engine for catalog songs (plain cut) |
| Attribution | Credit artists; track page link | Credit the member, Jamendo and a backlink to the track page; licence shown | Existing source badge, artist, licence and "Open page" link; the Wave row shows the source badge |
| Commercial use | Personal, non-commercial use | Free only for non-commercial use | Personal, non-commercial player (unchanged) |

Sources: https://audius.co/documents/TermsOfUse.pdf, https://openaudiofoundation.org/open-music-license.pdf, https://docs.audius.co/sdk/, https://devportal.jamendo.com/api_terms_of_use, https://developer.jamendo.com/v3.0/tracks. A live request to `api.audius.co/v1/tracks/trending?genre=Electronic&time=month` answered without a key (2026-10-25).

Not done because the terms do not clearly allow it: storing catalog songs, likes or history of catalog songs; offline copies; crossfade of catalog songs; Jamendo account features.

## 2. Changes

| Area | Change |
|---|---|
| `integrations/music_source.dart` | `MusicSource.waveCandidates(WaveRequest)` → `WaveCandidate(track, basis)`; `collectCandidates` (one failing request does not hide the others); `waveSuitable` (available, has a stream, 30 s–15 min, music) |
| `integrations/audius` | Trending by mapped Audius genre (no guessed genres), the liked artist's own songs via search, popular this week without taste |
| `integrations/jamendo` | `fuzzytags` for liked genres, `artist_name` for liked artists, popularity without taste; genres from `musicinfo` (so excluded genres work) |
| `nexa_wave/wave_ranker.dart` | Same exclusions and likes for catalog songs; catalog basis as "why" when the user's taste does not explain it; `onlineSlots` / `merge`: 0 at Familiar, up to half at Discovery, starts local, spread evenly |
| `nexa_wave/wave_controller.dart` | Session pool of catalog picks (timeout 8 s, refresh 30 min / when used up / when taste or catalog settings change); offline / rate limit / key → note, Wave continues with the library; "Not for me" for catalog songs (session only) |
| `nexa_dna/dna_providers.dart` | `waveOnline` setting (saved, default off; reset turns it off) |
| `player/player_controller.dart` | A catalog stream that fails is skipped once after 0.5 s (not when it recovers or the engine already moved on); a queue of only dead streams stops |
| `nexa_wave/wave_page.dart`, `dislike_button.dart` | Switch with the privacy text, note / count, source badge on catalog rows; "Not for me" on catalog songs |

Unchanged: Local Wave when the switch is off; Mix Engine; history rules; Discover; version 1.0.0 code paths for local playback.

## 3. Tests

| Level | File | What |
|---|---|---|
| Unit | `test/catalog_wave_test.dart` | Requests per adapter (only likes, genre mapping, max terms, popular without taste), filtering of removed / gated / stream-less / non-music / odd-length songs, offline and partial failure, Jamendo genres |
| Unit | `test/wave_merge_test.dart` | Online share by Familiar ↔ Discovery, even spread, fill when one side is short, exclusions and reasons for catalog songs, no repeats |
| Unit (controller + player, fake engine) | `test/wave_online_test.dart` | Off by default (no request), only likes sent, Familiar = no online, offline and partial failure, "Not for me", local ↔ online cut transitions, history only for library songs, dead stream skipped once, dead queue stops, reset |
| Widget | `test/wave_page_online_test.dart` | Switch, source badge, count, offline note |
| Windows integration (real media_kit, SQLite, HTTP) | `integration_test/wave_online_test.dart` | One Wave queue local → catalog → local through the real engine with a local fake Audius server; a 404 stream skipped exactly once; history only for library songs; unreachable catalog → local Wave plays; live Audius API (skipped offline). Silent (volume 0) |
| Regression | full `flutter test`, NEXA AutoTest on a Portable build of the branch | No change for v1.0 behaviour |
