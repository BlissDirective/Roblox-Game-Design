# Changelog

All notable changes to Outpost-7 are tracked here. Format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/); versions follow [SemVer](https://semver.org/) once V1.0 ships.

Pre-launch: each Phase A–I sub-phase gets its own entry under `[Unreleased]`.

---

## [Unreleased]

### Added
- **Phase A1 — Project scaffolding** ([commit](../../commit/f3c685c))
  - Hybrid `src/{server,client,shared}/` tree with all 32 domain subfolders
    (`.gitkeep` placeholders) per `docs/REPO_STRUCTURE.md` §1
  - `assets/`, `config/`, `analytics/`, `tools/`, `tests/`, `place/` trees
  - Empty bootstraps: `src/server/init.server.luau`, `src/client/init.client.luau`
  - Empty shared scaffolds: `Remotes.luau`, `Constants.luau` (with FEATURES
    flag table), `Types.luau`, `Enums.luau`
  - `docs/architecture/`: `DATA_SCHEMA.md`, `REMOTES_REGISTRY.md`,
    `RAID_PROTOCOL.md`, `ECONOMY_TUNING.md`, `DECISIONS.md` (with ADR-001
    + ADR-002)
  - `docs/phases/PHASE_A_FOUNDATION.md` (worklog; B–I created at their
    phase start, not pre-stubbed)
  - `docs/playbooks/{DAILY_DEV_LOOP,PLAYTEST_PROTOCOL,INCIDENT_RESPONSE}.md`
  - `analytics/{EVENT_TAXONOMY,FUNNELS,KPIs}.md`, `analytics/dashboards/README.md`
  - `config/README.md`, `tests/README.md`, `tools/migrations/README.md`,
    `tools/asset-import/README.md`

- **Phase A2 — DataManager + DataStore wrapper** ([commit](../../commit/fab0c9f))
  - `wally.toml`: `ProfileStore = "lm-loleris/profilestore@1.0.3"` in
    `[server-dependencies]`
  - `src/server/Modules/Player/ProfileSchema.luau`: v1.0 schema +
    versioned migration step-table
  - `src/server/Modules/Player/DataManager.luau`: ProfileStore-backed
    façade (`Init / LoadPlayer / SavePlayer / GetData / WaitForData`).
    Studio `Mock` toggle. Distinguishes intentional session-end from
    cross-server steal. `BindToClose` waits up to 25s for flush.
  - `init.server.luau` wired `DataManager.Init()`
  - **ADR-003** (DECISIONS.md): adopt ProfileStore. Supersedes ADR-001.

- **Phase A3 — Shared scaffolds** ([commit](../../commit/4bdac8c))
  - `Constants.luau` expanded: `DATASTORE`, `RATE_LIMITS`, `TICK`, `GRID`
    sections (placeholders downstream phases extend)
  - `Types.luau`: `Result<T>` generic
  - `Remotes.luau`: `getOrCreate` + `ensureContainer` helpers; empty
    registry awaiting Phase B
  - `Enums.luau`: `Mode`, `Biome`
  - `DataManager.luau` refactor: `STORE_NAME` + BindToClose timeout
    moved to `Constants.DATASTORE.*`

- **Phase A4 — Bootstrap wiring + audit harness**
  - `init.server.luau`: boot print extended with Constants verification
  - `init.client.luau`: requires `Constants` + `Enums` to verify
    replication; audit-ready diagnostic print
  - `DataManager.luau`: lifecycle prints (load / save / shutdown
    flush start + end)
  - Phase A audit checklist in `docs/phases/PHASE_A_FOUNDATION.md`
    (four-step Studio recipe: place loads → mid-session mutation →
    rejoin round-trip → BindToClose flush)

### Deferred (tracked, not blocking)
- `wally.lock` commit (CI generates; revisit in Phase B if reproducibility
  matters)
- `PlayerSession.luau`, `PlayerJoined.luau`, `PlayerLeaving.luau` (no
  caller yet — ship at first multi-manager phase)
- TestEZ / `[dev-dependencies]` (manual audit recipe sufficient through
  Phase A)
- `AssetIds.luau` (lands when first first-party asset is uploaded — Phase
  G/H per `playbooks/PUBLISHING.md`)
- `tools/scripts/*.sh` (lands when needed — manual `rojo build` /
  `selene` / `stylua` work for now)
- `docs/phases/PHASE_{B..I}_*.md` (created at the start of each phase)

---

## [0.0.0] — 2026-05-03

Initial knowledge base committed (Phase 1 docs).
