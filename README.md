<p align="right"><a href="docs/README.ru.md">Читать на русском</a></p>

<p align="center">
  <img src="assets/brand/nexa-banner.svg" width="100%" alt="NEXA Music — Find your frequency" />
</p>

<p align="center">
  <strong>One place for the music that feels like yours.</strong><br />
  <sub>A personal music player. Built around listening, not collecting clicks.</sub>
</p>

<p align="center">
  <a href="#the-idea">The idea</a> ·
  <a href="#the-system">The system</a> ·
  <a href="#development-status">Development</a> ·
  <a href="#explore-the-project">Explore</a>
</p>

---

## The idea

NEXA Music brings a personal collection, thoughtful recommendations and fluid playback into a single, calm interface. It starts with music you own and connects to supported online catalogues—without treating listening habits as someone else's data product.

The visual language is **NEXA Design 04**: graphite surfaces, quiet lavender accents, confident typography and motion that has a purpose.

> **Personal project · Private development · Windows-first**  
> The broader direction includes macOS, Linux, Android, iOS/iPadOS and Web. Those ports are targets, not completed builds.

## The system

| Experience | What it is designed to do |
| :-- | :-- |
| **Library** | Keep local MP3, FLAC and WAV collections organized, searchable and playable offline. |
| **NEXA Mix Engine** | Manage gapless playback and configurable crossfades for compatible audio sources. |
| **NEXA DNA** | Build a taste profile from explicit likes, exclusions and optional listening history. |
| **NEXA Wave** | Create a personal discovery queue and explain *why* each track appears. |
| **Discover** | Search Audius and Jamendo together, with clear source labels, playable-state feedback and links to the original tracks. |
| **Connected sources** | Stream supported Audius and Jamendo tracks in NEXA. Source rights determine which controls are available; online audio is not crossfaded. |

<p align="center">
  <a href="https://github.com/KondexOFF/Nexa-Music/blob/phase/01-review/assets/design/NEXA_Design_04_Home.png">Home concept</a> ·
  <a href="https://github.com/KondexOFF/Nexa-Music/blob/phase/01-review/assets/design/NEXA_Design_04_Player.png">Player concept</a> ·
  <a href="https://github.com/KondexOFF/Nexa-Music/tree/phase/01-review/reports/phase_01">Windows UI captures</a>
</p>

## Under the hood

```text
NEXA Music
├─ Experience       Flutter UI · responsive shell · NEXA Design 04
├─ Collection       Local files · metadata · search · playlists
├─ Playback         media_kit · queue · device controls
├─ Mixing           Gapless · crossfade · source-aware transitions
├─ Intelligence     NEXA DNA · NEXA Wave · local preferences
└─ Sources          Local audio · Audius · Jamendo · rights-aware adapters
```

**Stack:** Flutter / Dart, Riverpod, Drift / SQLite and media_kit. The architecture keeps the playback engine, recommendation logic and provider-specific rules separate.

## Development status

The project is an **in-progress private alpha**, not a finished download. The latest development code lives on `dev/v1`; `main` remains the project's documentation and presentation branch.

| Milestone | Current state |
| :-- | :-- |
| Audio proof | Accepted; Windows prototype on [`phase/00-review`](https://github.com/KondexOFF/Nexa-Music/tree/phase/00-review). |
| Design system and player shell | Implemented on [`phase/01-review`](https://github.com/KondexOFF/Nexa-Music/tree/phase/01-review); final owner validation pending. |
| Library, playback, Mix Engine, DNA and Wave | Reported implemented and pushed on [`dev/v1`](https://github.com/KondexOFF/Nexa-Music/tree/dev/v1); final real-world listening checks pending. |
| Audius and Jamendo | Phase 6 reported implemented on [`dev/v1`](https://github.com/KondexOFF/Nexa-Music/tree/dev/v1) (`52b76c6`); API-level checks reported passed. Human listening check pending. |
| Windows packaging and final validation | Phase 7 and the subsequent manual test stage have not started in the latest journal. |
| Beyond Windows | Cross-catalog Wave, YouTube, SoundCloud and other platforms are approved directions, **not shipped features**. |

Read the [development roadmap](docs/ROADMAP.md) for the dated milestone record and outstanding validation work.

### Try the Windows development build

The **default `main` branch contains project documentation**, not the current Flutter application. For the most recent implementation, use the development branch:

```powershell
git clone https://github.com/KondexOFF/Nexa-Music.git
cd Nexa-Music
git switch dev/v1
flutter pub get
flutter analyze
flutter test
flutter run -d windows
```

Requires a configured Flutter Windows toolchain. The latest journal reports 126 passing automated tests; a complete manual Windows run has **not** been accepted yet. For Jamendo playback, enter your own `client_id` in Settings → Online catalogs. The original UI-only preview remains on [`phase/01-review`](https://github.com/KondexOFF/Nexa-Music/tree/phase/01-review).

## Explore the project

- [Roadmap and development notes](docs/ROADMAP.md)
- [Architecture](docs/ARCHITECTURE.md)
- [Implementation branch and progress journal](https://github.com/KondexOFF/Nexa-Music/blob/dev/v1/docs/PROGRESS.md)
- [Design language](docs/DESIGN.md)
- [Technical decisions](docs/DECISIONS.md)
- [Phase 0 engineering report](https://github.com/KondexOFF/Nexa-Music/blob/phase/00-review/reports/PHASE_00_REPORT.md)
- [Phase 1 engineering report](https://github.com/KondexOFF/Nexa-Music/blob/phase/01-review/reports/PHASE_01_REPORT.md)

## A note on sources and privacy

NEXA is designed for privately owned or appropriately licensed local music and provider-approved streams. No bundled copyrighted audio, streaming credentials or personal listening database belongs in this repository. Integration with a music service does not imply access to its raw audio or permission to modify it.

Listening history and taste data remain local and user-controlled. Online sources are optional; the personal library still works without a connection. Cross-catalog recommendations and embedded video/audio widgets come later, subject to provider policies and platform feasibility.

<p align="center"><sub>Designed to get out of the way when the music starts.</sub></p>
