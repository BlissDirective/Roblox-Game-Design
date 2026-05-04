# PHASE B — Core Loop

> Per-sub-phase worklog. Updated by Claude Code at the end of each
> sub-phase per `10_BUILD_PROTOCOL.md` (Plan → Confirm → Build → Verify
> → Commit → Report).

**Goal (per `finalized-brainstorm.md` §4.3):** A player can land on a
planet, scout for nodes, place an extractor, watch credits accrue, and
build their first wall.

**Phase audit gate:** Two-client Studio playtest. Both players scout,
place extractors, watch Credits accrue. Both players rejoin and base
state + Credits persist. Camera swap (TP↔FP) feels smooth.

---

## Phase research pass (run at kickoff)

Four parallel searches recorded findings:
- **Server Authority Studio Beta (2026, new).** Adopted for V1 per
  ADR-005 (supersedes ADR-004 same-day on user reframe).
- **StreamingEnabled** is tycoon-friendly with a footgun: bulk destroys
  cause ping spikes. Mitigation in `Constants.STREAMING`
  (BulkDestroyBatchSize / Delay) — Phase E plot-reset code honors it.
- **Poisson disk sampling** — Bridson's algorithm; community examples
  validate the seeded-deterministic approach we use in B1.
- **Camera TP↔FP via TweenService** — standard. Mobile-safe at 60Hz.

---

## B1 — World scaffold + resource node spawner + placement Remote ✅

**Date:** 2026-05-04
**Branch:** `claude/review-claude-docs-LiZZS`

### Architectural decisions (logged before code)

- **ADR-004** — Defer Server Authority Beta to V1.5/V2. *Superseded
  same-day by ADR-005.*
- **ADR-005** — Adopt Server Authority Beta for V1. User reframed the
  cost: foundational changes are cheaper at A/B than V1.5 retrofit.
  Reversibility is real (rolling back is a project-file revert).

### What was built

- **`default.project.json`** — Workspace properties added:
  `StreamingEnabled = true`, `StreamingMinRadius = 256`,
  `StreamingTargetRadius = 512`. The Server-Authority-Beta-only
  properties (`AuthorityMode`, `NextGenerationReplication`,
  `UseFixedSimulation`, `PlayerScriptsUseInput`, `SignalBehavior`)
  aren't in Rojo's reflection database yet, so they're applied at
  runtime by `ServerAuthorityBootstrap` (below). Discovered when
  `rojo build` rejected `Workspace.UseFixedSimulation` as
  "Unresolvable property".
- **`src/server/Modules/Lifecycle/ServerAuthorityBootstrap.luau`** —
  applies the five SA Beta Workspace properties at server boot. Each
  set is `pcall`-wrapped: if the runtime doesn't recognize a property
  (Beta disabled in Studio, or property renamed), the bootstrap skips
  it and logs which ones didn't take. This is the single chokepoint
  for SA Beta enablement; rollback per ADR-005 is "comment out the
  Apply() call".
- **`docs/playbooks/DAILY_DEV_LOOP.md`** — added the one-time-setup
  step for enabling **Beta Features → Server Authority Core API** in
  Studio. Without it, the new Workspace properties don't apply
  correctly.
- **`Constants.luau`** — added `WORLD` (plot grid layout), `NODES`
  (Poisson disk params), `BUILD` (placement validation), `STREAMING`
  (radii + bulk-destroy throttle). `FEATURES.debugModeToggle` flag
  added for B5's testing keybind.
- **`src/shared/Modules/Math/PoissonDisk.luau`** — Bridson's algorithm,
  cell-grid accelerated. Seeded `Random.new(seed)`. Deterministic.
- **`src/shared/Modules/Math/GridMath.luau`** — `SnapToCell`,
  `CellToWorld`, `SnapVector`, `IsInsidePlot`, `CellKey` helpers used
  by both server (PlacementService) and client (B4 preview).
- **`src/server/Modules/World/PlotManager.luau`** — builds a 2×2 grid
  of 64×64 plots (plus 32-stud gaps), allocates one plot per player
  on join, releases on leave. Idempotent (handles Studio script
  reload). Tints each plot floor differently for visual debugging.
- **`src/server/Modules/World/ResourceNodeSpawner.luau`** — per-plot
  Poisson disk distribution of resource nodes. Seed derived from
  `game.JobId` (or `os.time()` in Studio sessions). Snaps node
  positions to the placement grid so a node-cell maps 1:1 to a
  placement-cell.
- **`src/server/Modules/Build/BuildableRegistry.luau`** — catalog of
  two starter buildables: extractor (requires node, 1 Credit/sec
  income, 50 Credits cost) and wall (free placement, 20 Credits
  cost). Builds visual Parts directly — Phase G replaces with real
  models.
- **`src/server/Modules/Build/PlacementService.luau`** — single
  chokepoint for placement requests. Validates: plot allocation,
  buildable id, cell bounds, cell occupancy, node requirement.
  Affordability (B2) and reach raycast (F1) deferred. Wires the
  `PlaceBuilding` Remote.
- **`src/shared/Remotes.luau`** — first registration:
  `PlaceBuilding = getOrCreate("PlaceBuilding", "RemoteEvent")`.
  Removed the `selene: allow(unused_variable)` directive on
  `getOrCreate` since it has a caller now.
- **`src/server/init.server.luau`** — wired Init() chain in order:
  DataManager → PlotManager → ResourceNodeSpawner → PlacementService.
- **`docs/architecture/DECISIONS.md`** — ADR-004 + ADR-005 logged.
- **`docs/architecture/REMOTES_REGISTRY.md`** — `PlaceBuilding` row
  added.

### Audit (B1-scope, sandbox-side)

- All `.luau` files start with `--!strict`
- Tab-indented per `stylua.toml`
- `default.project.json` valid JSON (manual inspection — Workspace
  Beta property names per Roblox 2026 docs; CI's `rojo build` will
  flag any property-name drift)
- All require paths resolve through Rojo's tree mapping
- BuildableRegistry catalog vs `BUILD.ExtractorRequiresNode` cross-check

### Audit (B1-scope, Studio-side — pending your local run)

After `rojo serve` + Studio Connect (with Beta Features → Server
Authority Core API enabled — see DAILY_DEV_LOOP.md):
1. Press F5. Output should include, in this order:
   ```
   [ServerAuthorityBootstrap] Applied 5/5 SA Beta Workspace properties.
   [DataManager] Loaded <YourName> — session #N, ...
   [PlotManager] Built 4 plots (64x64 studs each)
   [PlotManager] Allocated Plot1 to <YourName>
   [ResourceNodeSpawner] Plot1: ~10 nodes (seed=<int>)
   [ResourceNodeSpawner] Plot2: ~10 nodes (seed=<int>)
   ...
   [Outpost-7] Server bootstrap complete. ... plots=4
   ```
   If `[ServerAuthorityBootstrap] Applied N/5` shows fewer than 5,
   the named skipped properties either need the Studio Beta enabled
   or have been renamed in a Roblox release. Log the names in
   `DECISIONS.md` and update `ServerAuthorityBootstrap.luau`.
2. World shows 4 colored plot floors in a 2×2 grid centered on origin.
   Each plot has ~10 emissive teal node spheres scattered across it.
3. **Command Bar (Server context) — placement smoke test:**
   ```luau
   local PlacementService = require(game.ServerScriptService.Server.Modules.Build.PlacementService)
   local PlotManager = require(game.ServerScriptService.Server.Modules.World.PlotManager)
   local player = game.Players:GetPlayers()[1]
   local plot = PlotManager.GetPlot(player)
   local firstNode = plot.nodes:GetChildren()[1]
   local cellX = firstNode:GetAttribute("CellX")
   local cellZ = firstNode:GetAttribute("CellZ")
   print(PlacementService.TryPlace(player, "extractor", cellX, cellZ))
   print(PlacementService.TryPlace(player, "extractor", cellX, cellZ)) -- expect "node already claimed"
   print(PlacementService.TryPlace(player, "wall", cellX + 2, cellZ))   -- expect ok
   print(PlacementService.TryPlace(player, "wall", 9999, 9999))          -- expect "cell outside plot"
   ```
4. Visual: extractor and wall Parts appear on the plot at the expected
   cells. Node where extractor was placed has `Claimed = true`
   attribute.

### Tech debt / deferred

- **No client UI for placement** — B4 wires the build palette + ghost
  preview. Until then, audit is via Command Bar. **B1 audit must run
  before B2 starts** to confirm placement works end-to-end.
- **Affordability check is a no-op** at B1. B2 wires
  `CurrencyService.TrySpend` into the validation chain.
- **Reach raycast is a no-op** at B1. F1 hardens with server-side
  raycast from character position to placement target.
- **Persistent base state** (saving placements to DataStore) is B3.
  Currently every server restart wipes all placements.
- **`PlacementResult` Remote** for UI feedback is not registered. B4
  decides whether to add it or convert `PlaceBuilding` to a
  `RemoteFunction`.
- **Plot character spawning** — players spawn at the world default
  origin, not their plot. B4 sets `RespawnLocation` per plot.
- **Visuals are debug-grade** — colored plot floors and emissive node
  spheres. Phase G replaces with real biome-themed assets.

### What's next

B2 — `CurrencyService` (1Hz tick) + extractor income aggregation +
`CreditsLedger` audit log + `Signal` library for shared event class.
First server→client Remote (`CreditsChanged`).

---

## B2 — Currency tick + extractor income ⏳

_Pending._

## B3 — Persistent base state ⏳

_Pending._

## B4 — Build mode UI ⏳

_Pending._

## B5 — Camera transition (TP↔FP) ⏳

_Pending._
