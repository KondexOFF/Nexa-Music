# NEXA Music

**Status:** planning and repository preparation. No playable Windows build exists yet.

NEXA Music is a **private, Windows-first music player** designed around:
- a personal, offline-capable library;
- **NEXA Mix Engine** (gapless, crossfade and, later, cautious smart transitions);
- **NEXA DNA** (explicit musical preferences) and **NEXA Wave** (a local-first recommendation queue);
- approved online sources in later stages.

The primary code implementer is Claude Agent on the owner's Windows PC. KondexOff approves each phase; ChatGPT reviews reports.

## Start here

1. Read [the authoritative development plan](NEXA_Music_Master_Plan_Claude.md) **in full**.
2. Claude must read [CLAUDE.md](CLAUDE.md) and respect phase gates.
3. Use [architecture](docs/ARCHITECTURE.md), [design](docs/DESIGN.md), [decision log](docs/DECISIONS.md) and [change requests](docs/CHANGE_REQUESTS.md) as supporting guidance.
4. The **first stage is Phase 0**. The owner must explicitly authorize its execution. Do **not** start later phases automatically.
5. Deliver reports according to [reporting instructions](reports/README.md).

This repository currently contains planning documents **only**; the Flutter project and its dependencies must be created/verified in Phase 0, not pretended to exist now.

## External services

- **Local owned/licensed files:** primary source; Mix Engine applies where technically feasible.
- **Audius / Jamendo:** future provider adapters, subject to each service's terms and rights.
- **Spotify:** open in the official app; **not** a NEXA audio source, even with Premium.
- **YouTube:** user-requested option, **currently a proposed change request**, not an approved implementation. The potential path is an official visible embedded video player or opening YouTube externally. No audio extraction or mixing.

This private repository must **never contain copyrighted music files, secrets, private listening databases, tokens or personal history**.

## Design references

The approved visual concept is NEXA Design 04: Home and Player. The two PNG mockups are not yet committed; ask the owner for the originals before Phase 1.
