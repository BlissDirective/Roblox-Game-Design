# Changelog

All notable changes to Outpost-7 are tracked here. Format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/); versions follow [SemVer](https://semver.org/) once V1.0 ships.

Pre-launch: each Phase A–I sub-phase gets its own entry under `[Unreleased]`.

---

## [Unreleased]

### Added
- **Phase R1 — Fortify (structure combat)** — makes walls/turrets/extractors
  mechanically real; closes audit finding §4.2 ("aliens never attack the base").
  - `src/server/Modules/Combat/StructureHealthService.luau` — new module owning
    structure HP, damage, destruction, repair, and the switchable wave-loss
    policy. Canonical HP mirrored to Part `CurrentHp`/`MaxHp` attributes for the
    client damage-state renderer.
  - `BuildableRegistry`: additive `maxHp` field (wall 300, turret 250,
    extractor 150); `BuildPart` stamps `MaxHp`/`CurrentHp` attributes.
  - `AlienAI`: retargeted from "always the player" to marching on the base —
    aliens chew through the nearest wall/turret within range, then press on to
    the extractors; they fall back to hunting the player only when no structures
    remain. The breach fantasy from brainstorm §2.5 is now possible.
  - `CurrencyService`: extractor disable/re-enable (`SetExtractorDisabled`) so a
    downed extractor stops earning until repaired; `Drain` for the wave-loss
    credit skim (no "spend" quest emission).
  - `PlacementService`: registers structure HP on placement (fresh + restore);
    stamps `CellX`/`CellZ`; new `RemoveStructure` frees occupancy + unclaims the
    node + unregisters currency/turret + drops the `baseLayout` entry on death.
  - Remotes: `StructureHealth` (S→C) + `RepairStructure` (C→S, 10/s bucket).
  - **R1b client** — `src/client/Modules/Combat/StructureHealthController.luau`:
    damage-state tint driven off the replicated `CurrentHp` attribute (walls
    redden as they're chewed, snap back on repair; downed extractors dim),
    event toasts off the `StructureHealth` Remote (extractor down / breached /
    repaired), and tap-to-repair (raycast → owned damaged structure →
    `RepairStructure`; one tap fully repairs). Server re-validates everything.
  - `Constants`: `WORLD.PlotCount` 4→8 (+ `PlotGridCols` for a 4-wide strip);
    `COMBAT` structure/repair tunables + `WaveLossMode` (soft/medium/hard,
    default medium) with per-mode profiles.
- **Latent runtime-bug fixes** (never-run-in-Studio class, audit §4.7): changed
  `part.SetAttribute(...)` dot-calls to `part:SetAttribute(...)` in
  `BuildableRegistry.BuildPart` and `ResourceNodeSpawner` — the dot form passes
  the attribute name as `self` and throws at runtime; the node-attribute bug
  would have broken extractor-on-node validation outright.

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

- **Phase A4 — Bootstrap wiring + audit harness** ([commit](../../commit/be3de51))
  - `init.server.luau`: boot print extended with Constants verification
  - `init.client.luau`: requires `Constants` + `Enums` to verify
    replication; audit-ready diagnostic print
  - `DataManager.luau`: lifecycle prints (load / save / shutdown
    flush start + end)
  - Phase A audit checklist in `docs/phases/PHASE_A_FOUNDATION.md`
    (four-step Studio recipe: place loads → mid-session mutation →
    rejoin round-trip → BindToClose flush)

- **CI hardening — empty Packages/DevPackages dirs before rojo build**
  ([commit](../../commit/5813d36)). Caught during Phase A audit-run:
  Wally only creates a packages dir for realms with declared deps;
  empty realms broke `rojo build` with "$path could not be turned into
  a Roblox Instance". Fixed in both `ci.yml` and `release.yml`.

- **`wally.lock` committed for reproducible CI cache**
  ([commit](../../commit/29bf443)). Pins
  `lm-loleris/profilestore@1.0.3` (no transitive deps yet).

- **Phase B1 — World scaffold + node spawner + placement Remote**
  ([commit](../../commit/80bedb4))
  - **ADR-004 → ADR-005** (same-day): adopt Server Authority Beta for
    V1 (user reframe — foundational change is cheaper at A/B than at
    V1.5 retrofit, with revert as a project-file diff)
  - `default.project.json`: `StreamingEnabled = true`, conservative
    `StreamingMinRadius=256` / `StreamingTargetRadius=512`
  - `Lifecycle/ServerAuthorityBootstrap.luau`: applies the 5 SA Beta
    Workspace properties at boot, pcall-wrapped per-property so the
    bootstrap is resilient to Beta-disable or property-rename
  - `shared/Modules/Math/{PoissonDisk,GridMath}.luau`: Bridson
    seeded sampler + grid math (single source of truth for client/
    server snap parity)
  - `World/PlotManager.luau`: 2×2 grid of 64×64 plots, allocate-on-
    join, color-tinted floors
  - `World/ResourceNodeSpawner.luau`: per-plot Poisson distribution,
    seed = `JobId` hash (or `os.time` in Studio)
  - `Build/BuildableRegistry.luau`: extractor + wall catalog
  - `Build/PlacementService.luau`: server-validated placement
    chokepoint (5 validation steps; 2 placeholders for B2/F1)
  - `Remotes`: first registration — `PlaceBuilding`
  - `Constants`: `WORLD`, `NODES`, `BUILD`, `STREAMING` sections;
    `FEATURES.debugModeToggle` for B5 testing
  - `DAILY_DEV_LOOP.md`: required step to enable Studio Beta Features
    → Server Authority Core API

- **Phase B2 — Currency tick + extractor income + CreditsChanged**
  ([commit](../../commit/389eacc))
  - `Economy/CurrencyService.luau`: 1Hz income tick, per-player
    extractor registry, atomic `TrySpend`, `Add`, `SetMultiplier`
    (clamped to (0, 10] with warn)
  - `PlacementService`: affordability gate wired via
    `CurrencyService.TrySpend`; income-bearing buildables auto-
    register with CurrencyService
  - `Remotes`: `CreditsChanged` (Server → Client)

- **Phase B3 — Persistent base state**
  ([commit](../../commit/67abbe1))
  - `ProfileSchema`: `baseLayout: { SerializedBuilding }` (additive)
  - `PlotManager`: `WaitForPlot` helper for ordered post-allocation
    work
  - `Build/BaseSerializer.luau`: thin façade over
    `profile.baseLayout` (Append/Remove/Get/Clear)
  - `Build/BuildRestorer.luau`: replays saved layout via
    `PlacementService.TryPlace(..., trusted=true)` on plot allocation
  - `PlacementService`: `trusted: boolean?` parameter — restoration
    skips affordability deduction + skips persistence-back

- **Phase B4 — Build-mode UI**
  ([commit](../../commit/cf84a34))
  - `BuildableRegistry` **moved** from `server/Modules/Build/` to
    `shared/Modules/Registry/` so client UI can read catalog data
    without duplication
  - `PlotManager`: per-plot `SpawnLocation`,
    `player:SetAttribute("PlotId", N)`, character teleport on allocate
  - `shared/Modules/Lib/HudFormat.luau`: `Abbreviated` (1.5K) +
    `WithCommas`
  - `client/HUD/{HudController,CreditsDisplay}.luau`: top-right HUD
  - `client/Build/{BuildController,BuildPalette,PlacementPreview}.luau`:
    bottom-center palette, ghost preview via camera raycast,
    `processed=true` filter on inputs

- **Phase B5 — TP↔FP camera transition + mode state machine**
  ([commit](../../commit/ebb7491))
  - `client/Core/ModeController.luau`: state machine
    (Build / Combat / Raid)
  - `client/Core/CameraController.luau`: TweenService transition
    (~0.3s `Quad.Out`); cancels in-flight tween on rapid toggles;
    re-applies on respawn
  - `client/Core/InputRouter.luau`: M key cycles Build ↔ Combat,
    gated by `Constants.FEATURES.debugModeToggle`
  - `BuildPalette`: `Show()` / `Hide()`
  - `BuildController`: subscribes to mode changes; hides palette +
    clears selection out of Build mode

- **Phase C1 — Daily login + 7-day streak (server-authoritative)**
  ([commit](../../commit/94faf80))
  - `ProfileSchema`: `lastDailyClaim: string?` (UTC YYYY-MM-DD) +
    `dailyStreak: number`
  - `Constants.RETENTION`: `DailyRewards` table
    (1→500..7→5000, 14→15K, 30→50K), `StreakGraceDays = 1`
  - `Retention/DailyLoginManager.luau`: streak rules (today=no-op,
    yesterday=streak+1, older=reset). All time logic via server
    `os.time()` with UTC noon anchor for DST-safe `daysBetween`
  - `Remotes`: `DailyLoginState` + `ClaimDailyReward`
  - `client/Retention/DailyLoginPopup.luau`: centered modal

- **Phase C2 — Restocking blueprint shop (deterministic 6h rotation)**
  ([commit](../../commit/8e63afc))
  - `ProfileSchema`: `shopRotationSeen` + `shopBuysThisRotation`
  - `Economy/BlueprintRegistry.luau`: V1 catalog of 6 placeholder
    items (3 Common, 2 Uncommon, 1 Rare)
  - `Economy/ShopService.luau`: weighted-without-replacement sampling
    via `Random.new(rotationIndex)`. 60s background poll detects
    rotation rollover and pushes fresh state
  - `Remotes`: `ShopState` + `BuyShopItem`
  - `client/Shop/{ShopPanel,ShopController}.luau`: slide-up panel +
    top-left toggle button

- **Phase C3 — Daily quests + cross-service event bus**
  ([commit](../../commit/29ac845))
  - `ProfileSchema`: `dailyQuests` + `lastQuestReset`
  - `Retention/QuestObjectives.luau`: singleton pub-sub event bus
    (decouples emitters from manager — avoids cycles)
  - `Retention/DailyQuestManager.luau`: V1 pool of 10 quests covering
    Build / Economy. 3 picked deterministically per UTC day via
    Fisher-Yates with `Random.new(daySeed)`. Pool sorted pre-shuffle
    for cross-server alignment
  - `Economy/CurrencyService`: added `AddCores` + `GetCores`. Fixed
    a leftover B4 bug — `BuildableRegistry` import was still pointing
    at the old server-side location and would have failed at first
    runtime use
  - Quest emissions wired into PlacementService, CurrencyService,
    ShopService, DailyLoginManager, DailyQuestManager 60s tick
  - `Remotes`: `DailyQuestState` + `ClaimQuest`
  - `client/Retention/DailyQuestsPanel.luau`: slide-in panel with
    live progress bars; "Quests" toggle button

- **Phase C4 — Offline progression — closes Phase C**
  ([commit](../../commit/bd4ae7c))
  - `DataManager`: per-player `sessionMeta` table tracks
    `previousLastJoinAt` captured before the bookkeeping write.
    Cleared on PlayerRemoving. New API: `GetSessionMeta(player)`
  - `BuildRestorer`: exposes `OnRestoreComplete: RBXScriptSignal`.
    Fires after Restore (success-or-fail, including the empty path)
  - `CurrencyService`: `GetTotalIncomePerSecond(player)` sums
    currently-registered extractor income
  - `Retention/OfflineProgression.luau`: `GrantOnJoin` reads previous
    timestamp, computes capped (12h) elapsed × income, grants via
    `CurrencyService.Add`, fires `WelcomeBack` to client
  - `Remotes`: `WelcomeBack` (Server → Client Event)
  - `client/Retention/WelcomeBackPopup.luau`: centered modal

### Deferred (tracked, not blocking)
- **Phase D dependencies**: `AddCores` works server-side but no client
  Cores HUD readout yet; `CoresChanged` Remote + display land in D.
- **Phase E dependencies**: combat / raid quest events
  (`survive_wave`, `raid_won`, `raid_attended`); wave damage during
  offline; PvP raid rate-limiting strategy.
- **Phase F dependencies**: `AntiExploit.RateCheck` for all Remotes
  (currently each Remote enforces semantic limits — e.g.
  `lastDailyClaim == today` blocks daily-claim spam — but no
  per-Remote per-second rate-limiter); reach-raycast for placement;
  client-claimed-mode check via TrustBoundary; `play_session`
  persistence within the day; `CreditsLedger` audit log;
  `PlacementResult` Remote for failed-placement toasts; popup
  ordering when multiple eligibilities trigger on join.
- **Phase G dependencies**: aesthetic polish across all UI (visuals
  are debug-grade); live countdown ticking; spring tweens; mobile UX
  collisions; quest pool expansion (10 → 30); icon / category tagging;
  rarity-driven item value distribution tuning.
- **`wally.lock` committed** ([commit](../../commit/29bf443)) — was
  previously listed here.
- `PlayerSession.luau`, `PlayerJoined.luau`, `PlayerLeaving.luau` —
  the per-player coordinator pattern is no longer strictly needed
  given pub-sub via `BuildRestorer.OnRestoreComplete` and
  `PlotManager.WaitForPlot`. May be revived in Phase E if multi-
  manager ordering grows beyond what direct signals can cover.
- TestEZ / `[dev-dependencies]` — manual Studio audit recipes
  sufficient through Phase C; revisit in F1.
- `AssetIds.luau` — lands when first first-party asset is uploaded
  (Phase G/H per `playbooks/PUBLISHING.md`).
- `tools/scripts/*.sh` — lands when needed; manual toolchain works.
- `docs/phases/PHASE_{D..I}_*.md` — created at the start of each phase.

---

## [0.0.0] — 2026-05-03

Initial knowledge base committed (Phase 1 docs).
