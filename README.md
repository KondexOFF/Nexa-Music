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

NEXA Music brings a personal collection, thoughtful recommendations and fluid playback into a single, calm interface. It starts with music you own and expands through supported online catalogues—without turning listening habits into someone else's data product.

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
| **Connected sources** | Discover music from providers that permit search and in-app playback. Source rights determine which controls are available. |

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
└─ Sources          Local audio · rights-aware online adapters
```

**Stack:** Flutter / Dart, Riverpod, Drift / SQLite and media_kit. The architecture keeps the playback engine, recommendation logic and provider-specific rules separate.

## Development status

The project is an **in-progress private alpha**, not a finished download. Published GitHub code and the current local working copy are at different stages:

| Milestone | Current state |
| :-- | :-- |
| Audio proof | Accepted; Windows prototype on [`phase/00-review`](https://github.com/KondexOFF/Nexa-Music/tree/phase/00-review). |
| Design system and player shell | Implemented on [`phase/01-review`](https://github.com/KondexOFF/Nexa-Music/tree/phase/01-review); final owner validation pending. |
| Library, playback, Mix Engine, DNA and Wave | Reported implemented in the local `dev/v1` working copy; **not yet published to this repository**. |
| Online catalogues, release hardening, other platforms | Planned / in development; not represented as finished features. |

Read the [development roadmap](docs/ROADMAP.md) for the dated milestone record and outstanding validation work.

### Build the available Windows preview

The **default `main` branch contains project documentation**, not the current Flutter application. To inspect the code that is already available on GitHub:

```powershell
git clone https://github.com/KondexOFF/Nexa-Music.git
cd Nexa-Music
git switch phase/01-review
flutter pub get
flutter analyze
flutter test
flutter run -d windows
```

The Phase 1 interface includes demonstration content; its transport controls are intentionally disabled until the real playback implementation is integrated. A newer local development build may differ from this preview.

## Explore the project

- [Roadmap and development notes](docs/ROADMAP.md)
- [Architecture](docs/ARCHITECTURE.md)
- [Design language](docs/DESIGN.md)
- [Technical decisions](docs/DECISIONS.md)
- [Phase 0 engineering report](https://github.com/KondexOFF/Nexa-Music/blob/phase/00-review/reports/PHASE_00_REPORT.md)
- [Phase 1 engineering report](https://github.com/KondexOFF/Nexa-Music/blob/phase/01-review/reports/PHASE_01_REPORT.md)

## A note on sources and privacy

NEXA is designed for privately owned or appropriately licensed local music and provider-approved streams. No bundled copyrighted audio, streaming credentials or personal listening database belongs in this repository. Integration with a music service does not imply access to its raw audio or permission to modify it.

Listening history and taste data are intended to remain local and user-controlled. Online sources are optional; the personal library should still work without a connection.

<p align="center"><sub>Designed to get out of the way when the music starts.</sub></p>
