# Outpost-7 — GitHub Repository Structure

> The canonical file map for the Outpost-7 project. This is the structural source of truth Claude Code follows during every build session. Aligned with `07_PROJECT_STRUCTURE.md`, the Phase A–I plan in `10_BUILD_PROTOCOL.md`, and the V1 / V1.5 / V2 scope locked in `finalized-brainstorm.md`.

**Decisions baked into this layout (per kickoff Q&A):**
- Hybrid module organization — domain sub-folders for known-large areas (Economy, Combat, Raid, Player, Social, World, Monetization), flat for the rest.
- Top-level `tests/`, `tools/`, `config/`, `analytics/` folders included from day one.
- Single `main` branch — V1.5 / V2 features gated by feature flags in `src/shared/Constants.luau`. No long-lived `v1.5` branches, no premature folder stubs.
- Full GitHub setup — Actions CI for Rojo build + Selene + StyLua, PR/issue templates, CODEOWNERS.

---

## 1. Top-level tree

```
outpost-7/
├── .github/                          ← GitHub-specific config (CI, templates, CODEOWNERS)
│   ├── workflows/
│   │   ├── ci.yml                    ← Lint (Selene) + Format check (StyLua) + Rojo build on every PR
│   │   ├── docs-check.yml            ← Verify CLAUDE.md ↔ docs/01_AGENT.md drift
│   │   └── release.yml               ← Tag-triggered: build .rbxlx, attach to GitHub Release
│   ├── ISSUE_TEMPLATE/
│   │   ├── bug_report.md
│   │   ├── feature_request.md
│   │   ├── playtest_finding.md       ← Specific to "I noticed X during playtest"
│   │   └── config.yml
│   ├── PULL_REQUEST_TEMPLATE.md      ← Phase, sub-phase, audit checklist
│   ├── CODEOWNERS                    ← Solo dev now; placeholder for future contributors
│   └── dependabot.yml                ← Aftman tool updates
│
├── .vscode/                          ← Editor config (per 07_PROJECT_STRUCTURE.md)
│   ├── settings.json                 ← Luau LSP + StyLua format-on-save
│   ├── extensions.json               ← Recommended: Luau LSP, Rojo, StyLua, GitLens, Better Comments
│   └── launch.json                   ← Optional: Rojo serve task
│
├── docs/                             ← Reference markdown (your project knowledge files, plus build docs)
│   ├── 00_START_HERE.md
│   ├── 01_AGENT.md                   ← Source of truth for CLAUDE.md
│   ├── 02_ROBLOX_PLATFORM.md
│   ├── 02_11_asset_pipeline.md
│   ├── 03_GAME_GENRES.md
│   ├── 03_demand_supply_ratio_additions.md
│   ├── 04_VIRAL_MECHANICS.md
│   ├── 05_MONETIZATION.md
│   ├── 01_05_monetization_addition.md
│   ├── 06_LUAU_REFERENCE.md
│   ├── 07_PROJECT_STRUCTURE.md       ← This document references that one
│   ├── 08_MCP_SETUP.md
│   ├── finalized-brainstorm.md
│   ├── 10_BUILD_PROTOCOL.md
│   ├── finalized-brainstorm.md       ← Locked Outpost-7 concept doc
│   │
│   ├── architecture/                 ← Living design docs (Claude Code reads + updates)
│   │   ├── DATA_SCHEMA.md            ← Versioned PlayerData schema, migration log
│   │   ├── REMOTES_REGISTRY.md       ← Every Remote, its trust model, rate limit
│   │   ├── RAID_PROTOCOL.md          ← Raid match flow, MessagingService keys, snapshot rules
│   │   ├── ECONOMY_TUNING.md         ← Curve targets, tested values, why they're set
│   │   └── DECISIONS.md              ← ADR log (Architectural Decision Records)
│   │
│   ├── phases/                       ← Per-phase worklog Claude Code maintains
│   │   ├── PHASE_A_FOUNDATION.md
│   │   ├── PHASE_B_CORE_LOOP.md
│   │   ├── PHASE_C_RETENTION.md
│   │   ├── PHASE_D_MONETIZATION.md
│   │   ├── PHASE_E_SOCIAL.md
│   │   ├── PHASE_F_ANTIEXPLOIT_FTUE.md
│   │   ├── PHASE_G_AESTHETIC.md
│   │   ├── PHASE_H_SHIP_PREP.md
│   │   └── PHASE_I_LAUNCH.md
│   │
│   └── playbooks/                    ← Human-facing how-tos
│       ├── DAILY_DEV_LOOP.md         ← rojo serve → edit → F5 → audit
│       ├── PUBLISHING.md             ← Studio → publish → analytics setup
│       ├── PLAYTEST_PROTOCOL.md      ← How to run the closed-beta sessions
│       └── INCIDENT_RESPONSE.md      ← DataStore corruption / exploit reports / live ops
│
├── src/                              ← Rojo-mapped source. The only place runtime code lives.
│   ├── server/                       → ServerScriptService
│   ├── client/                       → StarterPlayerScripts
│   └── shared/                       → ReplicatedStorage
│       (full breakdown in §2 below)
│
├── assets/                           ← Binary game content synced via Rojo
│   ├── ui/                           ← .rbxm UI templates (HUD, shop, raid panel, etc.)
│   ├── world/
│   │   ├── biome_jungle/             ← Bioluminescent jungle props/terrain
│   │   ├── biome_volcanic/
│   │   └── biome_ice/
│   ├── characters/                   ← Operator skins, alien predator rigs, drone meshes
│   ├── effects/                      ← VFX templates (drone trails, turret muzzle, alien spawn)
│   ├── audio/
│   │   ├── music/                    ← 5+ synthwave tracks (build, combat, raid, victory, defeat)
│   │   ├── sfx/                      ← Extractor place, alarm, turret fire, alien growls, etc.
│   │   └── ambient/                  ← Per-biome ambient loops
│   └── icons/                        ← Game icon, thumbnails (3 minimum for Phase H)
│
├── config/                           ← Game balance & content data (separate from code Constants)
│   ├── balance/
│   │   ├── currency_curve.json       ← Credit-per-second targets per upgrade tier
│   │   ├── upgrade_costs.json        ← Wall, turret, extractor cost progression
│   │   ├── raid_rewards.json         ← Win/loss reward bands
│   │   ├── wave_scaling.json         ← Per-night alien wave HP/count/composition
│   │   └── battle_pass_tiers.json    ← Tier rewards (XP thresholds, items per tier)
│   ├── content/
│   │   ├── quests_pool.json          ← 30+ daily quest definitions (per Phase C3)
│   │   ├── blueprints.json           ← Shop blueprint catalog + rotation rarities
│   │   ├── drone_swarms.json         ← Recon / Combat / Engineering swarm configs
│   │   ├── biomes.json               ← Per-biome metadata (audio, lighting profile, hostiles)
│   │   └── battle_pass_seasons/
│   │       └── season_01.json
│   ├── monetization/
│   │   ├── game_passes.json          ← Pass IDs + effects (synced with src/shared/Constants)
│   │   └── dev_products.json         ← Product IDs + grants
│   └── README.md                     ← How to load these from Luau (HttpService:JSONDecode)
│
├── analytics/                        ← Event taxonomy + funnel definitions
│   ├── EVENT_TAXONOMY.md             ← Every analytics event, payload schema, when fired
│   ├── FUNNELS.md                    ← FTUE funnel, purchase funnel, raid funnel
│   ├── KPIs.md                       ← D1/D7/D30, ARPPU, conv %, retention curves
│   └── dashboards/
│       └── README.md                 ← Links to PlayFab / GameAnalytics dashboards
│
├── tools/                            ← Dev utilities, NOT runtime code
│   ├── scripts/
│   │   ├── build.sh                  ← rojo build → place/game.rbxlx
│   │   ├── lint.sh                   ← selene src/
│   │   ├── format.sh                 ← stylua src/
│   │   └── new-module.sh             ← Scaffolds a new Modules/<Name>.luau from template
│   ├── migrations/                   ← One-shot DataStore schema migration runners
│   │   ├── README.md
│   │   └── _template.luau            ← Template for v1.0 → v1.1 migrators
│   ├── content-validators/           ← JSON schema validators for config/
│   │   ├── validate-balance.lua
│   │   └── validate-content.lua
│   └── asset-import/                 ← Notes + helper scripts for the asset pipeline
│       └── README.md                 ← References docs/02_11_asset_pipeline.md
│
├── tests/                            ← TestEZ-style unit + integration scaffolding
│   ├── unit/
│   │   ├── shared/                   ← Mirrors src/shared/ structure
│   │   ├── server/                   ← Mirrors src/server/ structure
│   │   └── client/
│   ├── integration/                  ← Multi-module flows (run inside Studio Test Server)
│   │   ├── raid_flow.spec.luau
│   │   ├── purchase_flow.spec.luau
│   │   ├── daily_login_flow.spec.luau
│   │   └── datastore_roundtrip.spec.luau
│   ├── fixtures/                     ← Mock player profiles, mock DataStore responses
│   ├── helpers/
│   │   ├── MockPlayer.luau
│   │   ├── MockDataStore.luau
│   │   └── TimeShift.luau            ← For Phase C time-shift audits
│   ├── run-tests.server.luau         ← TestEZ runner; toggled by RunTests flag in Constants
│   └── README.md
│
├── place/                            ← Build artifacts (gitignored except .gitkeep)
│   └── .gitkeep
│
├── .gitignore
├── .gitattributes                    ← LFS rules for .rbxm/.rbxmx/.fbx/.png > 1MB
├── .editorconfig
├── aftman.toml                       ← Pinned: rojo, selene, stylua, lune (optional)
├── default.project.json              ← Rojo config (maps src/ + assets/ to Roblox tree)
├── selene.toml
├── stylua.toml
├── CLAUDE.md                         ← Auto-loaded by Claude Code; points at docs/01_AGENT.md
├── README.md                         ← Project intro + quickstart
├── CHANGELOG.md                      ← Per-version log (V1.0, V1.0.1, V1.1, V1.2, V2…)
├── ROADMAP.md                        ← V1 / V1.5 / V2 feature progression (mirrors brainstorm §2.8/2.9)
├── CONTRIBUTING.md                   ← How a future collaborator (or future-you) onboards
├── SECURITY.md                       ← Reporting exploits / vulnerabilities
└── LICENSE
```

---

## 2. `src/` — the Rojo-mapped source tree (full detail)

This is where the **hybrid** structure shows up. Domain folders for the systems we know will grow large; flat files for everything else. The file naming follows `07_PROJECT_STRUCTURE.md` (`.luau`, PascalCase, `init.server.luau` bootstraps).

### 2.1 `src/server/` → ServerScriptService

```
src/server/
├── init.server.luau                  ← Bootstrap: requires + Init()s all manager modules
└── Modules/
    │
    ├── Player/                       ← Per-player lifecycle & persistence
    │   ├── DataManager.luau          ← Phase A2. ProfileService-style wrapper.
    │   ├── ProfileSchema.luau        ← Versioned schema (v1.0). Default profile factory.
    │   ├── PlayerSession.luau        ← Per-session in-memory state (not persisted)
    │   ├── PlayerJoined.luau         ← Coordinates load order across managers
    │   └── PlayerLeaving.luau        ← Coordinates flush order on disconnect
    │
    ├── Economy/                      ← Currency, shop, blueprint rotation
    │   ├── CurrencyService.luau      ← Phase B2. Tick at 1Hz, applies multipliers.
    │   ├── CreditsLedger.luau        ← Audit log for large currency events
    │   ├── ShopService.luau          ← Phase C2. 6h restocking shop.
    │   ├── BlueprintRegistry.luau    ← Loads config/content/blueprints.json
    │   └── PricingRules.luau         ← Curve evaluation (cost = base × multiplier^tier)
    │
    ├── World/                        ← Map, biomes, resource nodes, environment
    │   ├── BiomeManager.luau         ← Loads correct biome on server start
    │   ├── ResourceNodeSpawner.luau  ← Phase B1. Poisson disk distribution.
    │   ├── PlotManager.luau          ← Per-player plot allocation + bounds
    │   └── EnvironmentService.luau   ← Day/night cycle, weather hooks
    │
    ├── Build/                        ← Placement, base state, serialization
    │   ├── PlacementService.luau     ← Phase B1/B3. Server-validated placement.
    │   ├── BaseSerializer.luau       ← Compact dictionary (positions + ids) for DataStore
    │   ├── GridSnap.luau             ← 4-stud grid math (server-side validation)
    │   └── BuildableRegistry.luau    ← Walls, turrets, extractors, decor catalog
    │
    ├── Combat/                       ← PvE waves, damage, drones, weapons
    │   ├── WaveDirector.luau         ← Phase E2. Spawns alien waves, scales by night.
    │   ├── AlienAI.luau              ← Behavior trees for alien predators
    │   ├── DamageService.luau        ← Single chokepoint for all damage application
    │   ├── DroneSwarmService.luau    ← Server-authoritative drone unit logic
    │   ├── TurretService.luau        ← Auto-targeting turret logic
    │   └── WeaponRegistry.luau       ← Weapon stats catalog
    │
    ├── Raid/                         ← Match-based PvP raids (Phase E1)
    │   ├── RaidMatchmaker.luau       ← MessagingService cross-server queue
    │   ├── RaidSession.luau          ← 5-min round lifecycle, reward distribution
    │   ├── RaidSnapshot.luau         ← Loads attacker into snapshot of target's base
    │   ├── ReservedServerLauncher.luau ← TeleportService:ReserveServer for raid instance
    │   └── RaidRewardService.luau    ← Win/loss reward calc (loads config/balance/raid_rewards)
    │
    ├── Social/                       ← Clans, friends, leaderboards (Phase E3, E5)
    │   ├── ClanService.luau          ← 4-person squads, role-based stash access
    │   ├── ClanStashLedger.luau      ← Atomic deposit/withdraw audit log
    │   ├── FriendsService.luau       ← Cached Players:GetFriendsAsync per session
    │   ├── LeaderboardService.luau   ← OrderedDataStore for global Credits + weekly raid wins
    │   └── ObserveColonyService.luau ← Visit friend's colony in read-only mode
    │
    ├── Retention/                    ← Daily-return mechanics (Phase C)
    │   ├── DailyLoginManager.luau    ← 7-day rolling streak, 24h grace
    │   ├── DailyQuestManager.luau    ← Picks 3 from quest pool, resets 00:00 UTC
    │   ├── QuestObjectives.luau      ← Hooks into Combat/Build/Economy events
    │   └── OfflineProgression.luau   ← 12h cap, calculates on rejoin
    │
    ├── Monetization/                 ← Passes, dev products, battle pass (Phase D)
    │   ├── MonetizationService.luau  ← Top-level orchestration
    │   ├── GamePassService.luau      ← UserOwnsGamePassAsync caching, prompt flow
    │   ├── DevProductService.luau    ← MarketplaceService.ProcessReceipt handler
    │   ├── PurchaseLedger.luau       ← Idempotency ledger (playerId, productId, receiptId)
    │   ├── PassEffects.luau          ← Wires 2x Credits, Auto-Collect, VIP into game state
    │   └── BattlePass/
    │       ├── BattlePassService.luau ← XP system, tier unlock, free vs premium
    │       ├── BattlePassXP.luau     ← XP grant rules (quests, raids, waves)
    │       └── ClaimService.luau     ← Tier reward claim Remote handler
    │
    ├── Voice/                        ← Spatial Voice (Phase E4)
    │   └── VoiceGate.luau            ← Enables only during raid sessions
    │
    ├── Analytics/                    ← Server-side event emission
    │   ├── AnalyticsService.luau     ← Public API: Track(player, event, props)
    │   ├── FunnelTracker.luau        ← FTUE funnel, purchase funnel
    │   └── EventBuffer.luau          ← Batch + flush to external sink
    │
    ├── Security/                     ← Anti-exploit (Phase F1, F2)
    │   ├── AntiExploit.luau          ← Token-bucket rate limiter, per-player per-Remote
    │   ├── RemoteValidator.luau      ← Type + range checks, single chokepoint
    │   ├── AuditLog.luau             ← Suspicious activity log, persisted
    │   └── TrustBoundary.luau        ← Helpers: assertOwnsPlot, assertCanAfford, etc.
    │
    ├── Networking/                   ← RemoteEvent dispatch & replication
    │   ├── RemoteRouter.luau         ← All inbound Remote handlers register here
    │   ├── ReplicationService.luau   ← Server-driven state pushes to client
    │   └── MessagingBridge.luau      ← MessagingService topic registry (cross-server)
    │
    └── Lifecycle/                    ← Server-level lifecycle
        ├── ServerBootstrap.luau      ← Used by init.server.luau; ordered Init() chain
        ├── ShutdownHandler.luau      ← BindToClose orchestration
        └── HealthCheck.luau          ← Self-diagnostic on boot (DataStore reachable, etc.)
```

### 2.2 `src/client/` → StarterPlayerScripts

```
src/client/
├── init.client.luau                  ← Bootstrap: requires + Init()s all controllers
└── Modules/
    │
    ├── Core/                         ← Always-on client systems
    │   ├── ClientBootstrap.luau
    │   ├── InputRouter.luau          ← Mouse/touch/gamepad → action mapping
    │   ├── CameraController.luau     ← Phase B5. TP↔FP transition.
    │   ├── ModeController.luau       ← Build mode vs Combat mode state machine
    │   └── NotificationController.luau
    │
    ├── HUD/                          ← On-screen heads-up display
    │   ├── HudController.luau        ← Top-level HUD orchestrator
    │   ├── CreditsDisplay.luau
    │   ├── HealthDisplay.luau
    │   ├── DroneSwarmDisplay.luau
    │   ├── WaveTimerDisplay.luau
    │   └── MinimapDisplay.luau
    │
    ├── Build/                        ← Build mode UI + input
    │   ├── BuildController.luau      ← Phase B4. Snap-to-grid placement preview.
    │   ├── BuildPalette.luau         ← Wall/turret/extractor/decor picker
    │   ├── PlacementPreview.luau     ← Ghost preview of pending placement
    │   └── BlueprintInventory.luau
    │
    ├── Combat/                       ← Combat mode UI + input
    │   ├── CombatController.luau     ← FP camera, weapon input
    │   ├── WeaponController.luau
    │   ├── DroneSwarmController.luau ← Player commands to drone swarm
    │   └── CrosshairController.luau
    │
    ├── Raid/                         ← Raid UI + flow
    │   ├── RaidController.luau
    │   ├── RaidQueueUI.luau
    │   ├── RaidHUD.luau              ← In-raid timer, objectives, voice indicator
    │   └── RaidResultsScreen.luau
    │
    ├── Social/                       ← Clans, friends, leaderboards UI
    │   ├── ClanController.luau
    │   ├── ClanPanel.luau
    │   ├── FriendsController.luau
    │   ├── FriendsPanel.luau
    │   ├── LeaderboardController.luau
    │   └── ObserveColonyController.luau
    │
    ├── Shop/                         ← Shop & monetization UI
    │   ├── ShopController.luau
    │   ├── ShopPanel.luau            ← Restocking blueprint shop
    │   ├── GamePassPanel.luau
    │   ├── DevProductPanel.luau
    │   └── BattlePassPanel.luau
    │
    ├── Retention/                    ← Daily-return UI
    │   ├── DailyLoginPopup.luau
    │   ├── DailyQuestsPanel.luau
    │   ├── WelcomeBackPopup.luau     ← Offline progression result
    │   └── StreakDisplay.luau
    │
    ├── Tutorial/                     ← FTUE (Phase F4)
    │   ├── FTUEController.luau       ← Drives the 30-second first-run sequence
    │   ├── TutorialHints.luau
    │   └── TutorialGates.luau        ← First 3 quests are tutorial-style
    │
    ├── VFX/                          ← Client-side visual effects
    │   ├── DroneTrails.luau
    │   ├── TurretMuzzleFlash.luau
    │   ├── AlienSpawnEffect.luau
    │   └── BiomeAmbientVFX.luau
    │
    ├── Audio/                        ← Music + SFX dispatch
    │   ├── MusicController.luau      ← Cross-fades by mode (build/combat/raid/victory/defeat)
    │   ├── SFXController.luau
    │   └── AmbientController.luau    ← Per-biome ambient loop manager
    │
    └── Lib/                          ← Pure client-side helpers
        ├── HudFormat.luau            ← Number formatting (1.5K, 2.5M)
        ├── TweenHelpers.luau
        └── UIFactory.luau            ← Themed UI element constructor (neon-tactical)
```

### 2.3 `src/shared/` → ReplicatedStorage

```
src/shared/
├── Remotes.luau                      ← Phase A3. Typed RemoteEvent/RemoteFunction registry.
├── Constants.luau                    ← All tunables. Feature flags for V1.5/V2 live here.
├── Types.luau                        ← Phase A3. Shared type definitions.
├── Enums.luau                        ← String enums (Mode, Biome, ItemRarity, etc.)
└── Modules/
    │
    ├── Lib/                          ← Stateless utility libraries
    │   ├── Signal.luau               ← Lightweight event class
    │   ├── Promise.luau              ← Async chaining (optional)
    │   ├── Maid.luau                 ← Connection cleanup helper
    │   └── Spring.luau               ← Spring-based UI animation math
    │
    ├── Math/                         ← Pure math helpers
    │   ├── PoissonDisk.luau          ← Phase B1. Resource node distribution.
    │   ├── GridMath.luau             ← Snap-to-grid, cell ↔ world conversions
    │   └── NumberFormat.luau         ← Shared between server logs and client HUD
    │
    ├── Schemas/                      ← Shared data shape definitions
    │   ├── PlayerProfile.luau        ← Type definition, used by server + client display
    │   ├── BaseLayout.luau
    │   ├── Quest.luau
    │   ├── Blueprint.luau
    │   └── Buildable.luau
    │
    ├── Config/                       ← Loaders for /config JSON files
    │   ├── ConfigLoader.luau         ← HttpService:JSONDecode with caching
    │   ├── BalanceConfig.luau
    │   ├── ContentConfig.luau
    │   └── MonetizationConfig.luau
    │
    └── Registry/                     ← Cross-context lookups
        ├── ItemRegistry.luau         ← Walls, turrets, extractors, decor — shared catalog
        ├── PassRegistry.luau         ← Pass IDs + display data
        └── BiomeRegistry.luau        ← Biome metadata (display name, ambient track id)
```

---

## 3. Why this layout (the rationale, kept short)

- **Domain folders only where scale is known.** Economy, World, Build, Combat, Raid, Social, Retention, Monetization, Security each have ≥3 files at V1 — they earn their folder. Voice, Analytics, Networking, Lifecycle stay tight (1–3 files each) but get folders because they're conceptually distinct trust/lifecycle boundaries. Anything else stays flat in `Modules/`.
- **`config/` is separate from `src/shared/Constants.luau` on purpose.** Constants = code-shaped tunables Claude reads/writes (rate limits, tick rate, feature flags). `config/` = content-shaped data (quest pools, blueprint catalogs, balance curves) that you want to tweak without a code review and that grows fast. Both load through `src/shared/Modules/Config/` so the runtime sees a single API.
- **Feature flags > branches** for V1.5/V2. Per your call: a single `Constants.FEATURES.tradingMarketplace = false` flag in `Constants.luau` lets V1.5 features land in `main` behind a gate. No long-lived feature branches. The `ROADMAP.md` and `CHANGELOG.md` are the human-readable record.
- **`tests/` mirrors `src/`.** Even if you don't write 100% coverage, the structure makes it obvious where a new test goes. Critical paths to cover from Phase A: DataStore round-trip, ProcessReceipt idempotency, Remote rate limiting, raid snapshot isolation.
- **`docs/architecture/`, `docs/phases/`, `docs/playbooks/`** are the three Claude-Code-facing doc surfaces. Architecture = living design. Phases = worklog Claude updates per sub-phase. Playbooks = human recipes.
- **`.github/` is full but not bloated.** CI runs lint + format + Rojo build (catches "this won't even compile" before it reaches Studio). PR template forces phase/sub-phase tagging. CODEOWNERS exists so the file is there when you do bring on a contributor.

---

## 4. Files to populate first (Phase A1 checklist)

When Claude Code kicks off Phase A1 ("Project scaffolding"), these are the files that must exist before A2:

- [ ] `.gitignore`, `.gitattributes`, `.editorconfig`
- [ ] `aftman.toml` with rojo + selene + stylua pinned
- [ ] `default.project.json`
- [ ] `selene.toml`, `stylua.toml`
- [ ] `CLAUDE.md` (mirrors `docs/01_AGENT.md`)
- [ ] `README.md` (project intro + `rojo serve` quickstart)
- [ ] `ROADMAP.md` (copy V1/V1.5/V2 lists from `finalized-brainstorm.md` §2.8/2.9)
- [ ] `CHANGELOG.md` (with V1.0-pre placeholder)
- [ ] `.github/workflows/ci.yml` (Selene + StyLua + `rojo build`)
- [ ] `.github/PULL_REQUEST_TEMPLATE.md`
- [ ] `.github/ISSUE_TEMPLATE/*.md`
- [ ] `.github/CODEOWNERS`
- [ ] `.vscode/settings.json`, `.vscode/extensions.json`
- [ ] `src/server/init.server.luau` (empty bootstrap, ready to wire managers)
- [ ] `src/client/init.client.luau` (empty bootstrap)
- [ ] `src/shared/Remotes.luau`, `Constants.luau`, `Types.luau`, `Enums.luau` (empty scaffolds)
- [ ] All directories above with a `.gitkeep` so the structure exists in Git from commit 1

A2 starts populating `src/server/Modules/Player/DataManager.luau` and `ProfileSchema.luau`. A3 populates the shared scaffolds. A4 wires the bootstraps. Audit at end of A: place loads, no errors, DataStore round-trips work.

---

## 5. The kickoff prompt for Claude Code

Once this structure is approved, paste this into a fresh Claude Code session:

```
Initialize the Outpost-7 repo per docs/REPO_STRUCTURE.md.

Read in order:
1. CLAUDE.md
2. docs/01_AGENT.md
3. docs/07_PROJECT_STRUCTURE.md
4. docs/10_BUILD_PROTOCOL.md
5. docs/finalized-brainstorm.md
6. docs/REPO_STRUCTURE.md (this file)

Then execute Phase A1: create every file/folder in §4 above.
Use .gitkeep for empty directories so the full tree is committed.
Stop after A1 is committed and report what was created. Do not start A2 yet.
```

That's it. Phase A2 onward follows `10_BUILD_PROTOCOL.md` — Plan → Confirm → Build → Verify → Commit → Report.
