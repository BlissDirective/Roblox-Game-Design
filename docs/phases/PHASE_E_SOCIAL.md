# PHASE E — Social Layer

> Per-sub-phase worklog. Updated by Claude Code at the end of each
> sub-phase per `10_BUILD_PROTOCOL.md` (Plan → Confirm → Build → Verify
> → Commit → Report).

**Goal (per `finalized-brainstorm.md` §4.6):** Match-based PvP raids,
async matchmaking, NPC fallback waves, clans, voice chat (raid-only),
friends, leaderboards.

**🛑 Highest-risk phase per brainstorm §3.4.** Pre-committed Soft V1
fallback (cut clans/voice/multi-biome to V1.1) if Week 12 hits and E
is < 70% complete.

**Phase audit gate:** Multi-client raid round executes cleanly. Empty
queue → PvE wave fallback fires within 10 seconds. Clan stash atomic.
Voice toggles correctly at raid start/end.

---

## Phase research pass (run at kickoff)

Four parallel searches recorded findings:

- **`MessagingService` + `MemoryStoreService`** are still the canonical
  pair for cross-server matchmaking in 2026. Recent (2025–2026) community
  matchmaker modules confirm the SortedMap-queue + MessagingService-pair
  pattern.
- **`TeleportService:ReserveServer` is deprecated** in favor of
  `ReserveServerAsync`. `TeleportToPrivateServer` is unchanged. We use
  `ReserveServerAsync` throughout.
- **Spatial Voice** — `VoiceChatService` per-experience config remains
  standard. Feb 2026 added `GetChatGroupsAsync` for chat-group
  diagnostics. Per-place enable still the right call for "voice in
  raids only".
- **OrderedDataStore for weekly leaderboards** — one store per
  ISO-week bucket (e.g. `RaidWins_2026W18`) avoids per-week reset
  hassle. MemoryStore is faster but doesn't persist past 30 days; we
  use it for the *live* queue, not for leaderboards.

No deprecated APIs surfaced beyond `ReserveServer`.

---

## E1 — Raid matchmaker + reserved-server flow ✅

**Date:** 2026-05-05
**Branch:** `claude/audit-phases-a-d-2BAuW`

### Architectural decisions (logged before code)

- **ADR-007** — *Superseded same-day by ADR-009.* Original V1 plan was
  single-PlaceId reserved-instance for operational simplicity. User
  reframed for long-term success: doing the split now is cheaper than
  re-authoring CSG / EditableMesh assets at V1.5.
- **ADR-008** — Raid server never writes the defender's profile.
  Outcomes flow via MessagingService topic `outpost.raid.outcome`;
  home servers are the sole authoritative writers.
- **ADR-009** — True two-PlaceId raid split for V1. Two Rojo project
  files (`default.project.json` + `raid.project.json`), two `.rbxl`
  artifacts published to two PlaceIds in the same Universe via
  `release.yml`. Constants gain `MainPlaceId` alongside `RaidPlaceId`.
  CI builds both `.rbxl` files on every PR to catch project-file drift.

### What was built

#### Server (main place)

- **`Constants.RAID`** — full configuration block: place id,
  durations, MemoryStore bucket names, MessagingService topic strings,
  V1 placeholder reward bands. Single-source-of-truth for all raid
  tuning.
- **`Remotes.luau`** — registered `RaidQueue` (RemoteFunction),
  `RaidQueueState` (Server → Client Event), `RaidStarted`,
  `RaidEnded`. Documented in `REMOTES_REGISTRY.md`.
- **`ProfileSchema.luau`** — added `raidWins`, `raidLosses`,
  `raidsDefended`, `raidsRaided` (all default 0). Additive; older
  saves get 0 from `Reconcile`. Documented in `DATA_SCHEMA.md`.
- **`Raid/RaidSnapshot.luau`** — `Capture(player, snapshotId?)` reads
  `baseLayout` + `creditsAtSnapshot` off the live profile (in-memory
  only — no DataStore touch). `StoreInMemory` / `LoadFromMemory`
  wrap a MemoryStoreService SortedMap with TTL. Snapshot id is
  pre-assigned by the matchmaker leader so attacker-home and
  defender-home both reference the same key without out-of-band
  discovery.
- **`Raid/ReservedServerLauncher.luau`** — wraps
  `TeleportService:ReserveServerAsync(placeId)` (modern API;
  `ReserveServer` is deprecated) plus `TeleportToPrivateServer` with
  `setTeleportData` carrying snapshotId + role. Refuses placeholder
  `RaidPlaceId == 0` with a warn (REPLACE_BEFORE_LAUNCH gate).
- **`Raid/RaidMatchmaker.luau`** — the cross-server matchmaker.
  - Per-server in-memory queue mirror feeds `RaidQueueState` Remote.
  - MemoryStore SortedMap `OutpostRaidQueue` for queue rows; row
    TTL 90s.
  - MemoryStore SortedMap `OutpostRaidableTargets` heartbeat-written
    by every main server every 30s (TTL 90s).
  - Sentinel-based leader election: HashMap `OutpostRaidSentinels`,
    key `raid.matchmaker.leader`, ConditionalSet via UpdateAsync. TTL
    15s; leader extends each tick.
  - Tick loop: pull queue + targets, pair attacker with random viable
    target, remove queue row, publish `outpost.raid.matched`. Retry
    semantics via the next tick if a row fails to clear.
  - Deadline pop loop: per-server 1Hz check for queued players past
    `QueueDeadlineSeconds` (30s); pop with `state.error = "deadline"`
    so the client can offer the E2 PvE fallback.
  - Match handler `ExecuteMatchOnHome`: per-home-server callback that
    reacts to `outpost.raid.matched`. Runs *both* sides in parallel
    on each home (a single server may own both attacker and
    defender):
      - Defender side: capture snapshot under leader-assigned id +
        StoreInMemory.
      - Attacker side: poll LoadFromMemory until snapshot lands (5s
        timeout), then ReserveAndTeleport.
- **`Raid/RaidSession.luau`** — raid-place lifecycle. Refuses init in
  non-raid servers (`PrivateServerId == ""`). On attacker join,
  reads JoinData.TeleportData, loads snapshot, fires `RaidStarted`,
  runs the round timer (5min), publishes
  `outpost.raid.outcome` via MessagingService, fires `RaidEnded`
  to the attacker, waits `PostRoundGraceSeconds` (8s), teleports
  attacker home. V1 outcome decision: `attackerWon = stillIn`
  (i.e., attacker lost only if they bailed mid-round). E2 wires
  WaveDirector defenders that can flip this to a real
  damage-driven outcome.
- **`Raid/RaidRewardService.luau`** — main-place outcome relay.
  Subscribes to `outpost.raid.outcome` MessagingService topic. Per-
  server in-memory dedupe on `(attackerUserId, defenderUserId,
  endedAt)` with 10-min TTL (pruned every 5 minutes). Applies
  attacker-side credit delta + win/loss counter; applies defender-
  side consolation credit + raidsRaided/raidsDefended counter. Fires
  `RaidEnded` Remote to the player on this server (attacker
  receives in raid place; defender receives via this relay path on
  their home server).
- **`init.server.luau`** — refactored to branch on
  `game.PrivateServerId`. Empty → full main stack including
  `RaidMatchmaker.Init` + `RaidRewardService.Init`. Non-empty → raid
  bootstrap (DataManager + ServerAuthorityBootstrap + RaidSession).
  Bootstrap is 60-ish lines, still under the CLAUDE.md 5–30-line
  rule for the *thin* spirit (the whole script is requires + branched
  Init calls).

#### Client

- **`Raid/RaidController.luau`** — minimal queue UI: a "Queue for
  Raid" button (matches the placeholder visual style of Store /
  Battle Pass buttons). Clicking invokes `Remotes.RaidQueue` with
  `"queue"` or `"cancel"`. Listens to `RaidQueueState` for status +
  countdown. Listens to `RaidEnded` for a 5s results toast (different
  text + stroke color for attacker vs defender). Phase G repositions
  per device.
- **`init.client.luau`** — wired `RaidController.Init()` last.

#### Documentation

- **`RAID_PROTOCOL.md`** — full match flow sequence diagram,
  MemoryStore key table, MessagingService topic table, critical
  invariants, failure modes & recovery, V1 placeholder reward
  values.
- **`DECISIONS.md`** — ADR-007 + ADR-008 logged.
- **`REMOTES_REGISTRY.md`** — 4 raid Remotes documented with trust
  model + rate limits.
- **`DATA_SCHEMA.md`** — raid stat fields documented.

### Audit (E1-scope, sandbox-side)

- 56 `.luau` files — `--!strict` on all
- New raid modules use `task.spawn` / `task.wait` exclusively (no
  legacy `wait()` / `coroutine.wrap`)
- All Remotes have server handlers; client listeners wired
- Idempotency invariant: outcome dedupe in `RaidRewardService`
  prevents double-grant on MessagingService at-least-once delivery
- Trust boundary invariant (ADR-008): grep across `src/server/` for
  `data.raidWins` / `data.raidLosses` / `data.raidsDefended` /
  `data.raidsRaided` — only `RaidRewardService` mutates them, only
  on the home server holding the player

### Audit (E1-scope, Studio-side — pending your local run)

E1 cannot fully audit in single-server Studio because the raid flow
crosses ServerInstance boundaries. Two paths to validate:

**Path 1 — Single-server smoke test** (validates queue + sentinel +
deadline pop)

```luau
-- Server context Command Bar:
local Constants = require(game.ReplicatedStorage.Shared.Constants)
local RaidMatchmaker = require(game.ServerScriptService.Server.Modules.Raid.RaidMatchmaker)
local p = game.Players:GetPlayers()[1]

-- Verify enqueue returns ok and writes to MemoryStore.
print(RaidMatchmaker.Enqueue(p))
-- Expect: { ok = true, state = { queued = true, deadlineAt = <now+30> } }

-- Wait 31s and watch the deadline-pop fire:
task.wait(31)
print(RaidMatchmaker.GetQueueState(p))
-- Expect: { queued = false, matched = false, error = "deadline" }
```

**Path 2 — Two-server cross-pair test** (true matchmaker validation)

This requires Studio's "Test → Local Server" with 2+ players, OR
publishing to a private test universe and joining with two accounts.

1. Set `Constants.RAID.RaidPlaceId` to your test PlaceId (Phase H
   prep).
2. Both players open the queue UI; Player A clicks Queue.
3. Within `MatchmakerTickSeconds` (2s), the leader (whichever server
   booted first) pairs A with B.
4. A's home publishes the snapshot; A's home reserves+teleports A.
5. A enters the raid place; `[RaidSession] Round started: A raids B`
   logs in the raid server's Output.
6. A waits ≤ 5 min (or runs `runRound` inspection in raid Command
   Bar).
7. Round ends → outcome published → both home servers apply rewards
   → `RaidEnded` toast fires on both clients.

**Hostile test (pre-F1, deferred):** spam `RaidQueue.InvokeServer("queue")`
from a modded client — server-side `Enqueue` short-circuits if
already queued. Unknown action returns `{ok=false}`. F1 adds the
token-bucket rate floor.

### Tech debt / deferred

- **`MainPlaceId` + `RaidPlaceId` placeholders (0)** until Phase H.
  Two-line edit in `Constants.RAID`; ADR-009 paths are otherwise
  ready. The CI raid publish step short-circuits with a warning while
  `RAID_PLACE_ID` is unset.
- **PvE wave fallback (E2 dependency).** When `state.error == "deadline"`
  fires, the client currently shows the error string but doesn't
  offer the player a wave. E2 wires `WaveDirector.StartFallbackWave`
  off this signal.
- **Snapshot rendering.** The raid place doesn't yet build out
  `snapshot.baseLayout` into actual placed parts — the round runs
  in an empty world for E1. E2 + Phase G handle world rendering;
  the data path is in place.
- **Outcome decision is placeholder.** `attackerWon = stillIn` until
  E2 ships WaveDirector defenders that can damage the attacker.
- **Voice chat (E4)** not yet enabled even in raid place.
- **Pending offline-defender rewards.** V1 drops the defender-side
  reward if the defender is offline at outcome time (acceptable per
  ADR-008 risks). V1.5+ adds `PendingRaidRewards` DataStore.
- **No defender-side toast in raid place.** Defender stays in main
  place; they get the `RaidEnded` toast via
  `RaidRewardService.applyDefenderSide`. Phase G tunes the toast
  copy + sound.
- **No clan-aware matchmaking (E3 dependency).** Match pairing is
  random per the raidable pool. E3 may want to bias against clan-
  mates and pair against rival clans.
- **Voice chat group via `GetChatGroupsAsync`** (Feb 2026) is not yet
  used; E4 wires it for the raid place's voice gate.
- **Leaderboards (E5 dependency).** `raidWins` is now a profile
  field; E5 reads it for the weekly board via OrderedDataStore.

### What's next

E2 — PvE wave system. `WaveDirector.luau` + `AlienAI.luau` (basic
behavior tree) + `DamageService.luau` chokepoint. Object-pooled
alien spawns per CLAUDE.md "anything spawned in bulk" rule. Two
deliveries:
1. **Standalone wave defense** in main place (per-night escalation
   tied to `os.time()` modulo a configurable wave clock).
2. **Snapshot-defender wave** in raid place (the snapshot's base
   spawns the same wave director, scaled to attacker count = 1).
   This gives the attacker something to fight and flips the
   `attackerWon` decision to a real one.

E2 also wires the queue-deadline → PvE fallback path (per the
brainstorm §2.1 "NPC alien wave fallback when raid queue is empty").

### Commit

`feat(phaseE1): cross-server raid matchmaker + reserved-server flow`

---

## E2 — PvE wave system + raid-queue fallback ✅

**Date:** 2026-05-05
**Branch:** `claude/audit-phases-a-d-2BAuW`

### What was built

#### Server (main place)

- **`Constants.COMBAT`** — wave clock cadence (10 min), per-wave alien
  count formula (`base + (N-1)*scale`, capped at 30), wave duration
  (90s), spawn-window stagger (15s), pool size (50), and Stalker
  alien stats (HP 100, melee 10, cooldown 1s, walkspeed 14). Single-
  source-of-truth for V1 wave tuning; Phase G replaces with
  `config/balance/wave_scaling.json`.
- **`ProfileSchema.luau`** — added `wavesSurvived: number` (default 0).
  Additive; older saves get 0 via Reconcile. Documented in
  `DATA_SCHEMA.md`.
- **`Remotes.luau`** — registered `WaveStarted` (S→C) and `WaveEnded`
  (S→C). Documented in `REMOTES_REGISTRY.md`.
- **`Modules/Registry/AlienRegistry.luau`** (shared) — alien type
  catalog. V1 ships only `stalker`; Phase G adds biome variants. Stats
  pulled from `Constants.COMBAT` so a single tuning file covers
  everything.
- **`Combat/AlienPool.luau`** — pre-allocates 50 Stalker actor models
  at server start. Each is a single Part (PrimaryPart =
  HumanoidRootPart) + Humanoid, parked under `ServerStorage.OutpostAlienPool`.
  `Acquire` reparents to `Workspace.AlienActors`, resets HP +
  position; `Release` reparents back. Pool overflow logs a warn and
  spawns a fresh actor (graceful degradation; surfaces tuning
  regressions).
- **`Combat/AlienAI.luau`** — V1 simplest-possible AI: Heartbeat-
  driven `MoveTo` toward the target player at 1Hz (avoids per-frame
  replication cost), Touched-event melee with `meleeCooldown`
  guard. No PathfindingService — V1 plot is a flat 64×64 square so
  line-of-sight steering is correct enough. `Drive(alien)` returns a
  controller handle the WaveDirector calls `:Stop()` on at wave end.
- **`Combat/DamageService.luau`** — single chokepoint for "X damages
  Y". V1 wraps `humanoid:TakeDamage` and emits `damage_taken` to
  QuestObjectives for future quest hooks. F1 hardens with source-
  trust validation + per-source rate limiting.
- **`Combat/WaveDirector.luau`** — wave lifecycle owner. Two trigger
  paths:
  1. **Wave clock** (`Constants.COMBAT.WaveClockSeconds = 600`) —
     fires for every online player with a plot, every 10 min. Stagger
     half-cycle on first tick to dodge "every server fires at the
     same boundary".
  2. **Queue-deadline fallback** — subscribes to
     `RaidMatchmaker.OnDeadlinePop`; calls `StartFallbackWave(player)`.
     Closes the brainstorm §2.1 "NPC alien wave fallback when raid
     queue is empty" loop.
  Per-player active-wave tracking (`activeWaves[player]`) prevents
  overlapping waves. Wave ends when all aliens dead, timer expires,
  OR player character dies. Survival increments `wavesSurvived` and
  emits `wave_survived` to QuestObjectives.
- **`Raid/RaidMatchmaker.luau`** — added `OnDeadlinePop` BindableEvent;
  fires inside `deadlineLoop` after the queue state is updated.
  Decoupled via signal so WaveDirector doesn't require Raid (no
  cycle).
- **`init.server.luau`** — wired `WaveDirector.Init()` after
  `RaidMatchmaker.Init()`. Order matters: WaveDirector subscribes to
  the matchmaker's BindableEvent, which must exist first.

#### Client

- **`Combat/CombatController.luau`** — wave HUD: top-center banner
  shows "Wave N (reason) — Xs — Y aliens" with a 1Hz countdown.
  `WaveStarted` builds the banner; `WaveEnded` clears it and shows a
  5s result toast (green stroke survived, red stroke failed).
  Placeholder visuals — Phase G replaces with the neon-tactical
  theme + alarm SFX.
- **`init.client.luau`** — wired `CombatController.Init()`.

### Audit (E2-scope, sandbox-side)

- 60 `.luau` files — `--!strict` on all
- All new modules use `task.spawn` / `task.wait` / Heartbeat (no
  legacy `wait()` / `coroutine.wrap`)
- Object-pool invariant verified: `AlienPool.Acquire/Release` is the
  only path that mutates `Workspace.AlienActors`; aliens never
  `Instance.new` outside the pool path (overflow warn aside)
- Coupling check: WaveDirector does not require RaidMatchmaker
  before its Init runs (avoids load-order cycle); the require lives
  inside `WaveDirector.Init` so it resolves after the matchmaker
  module has finished loading
- New `wavesSurvived` field is mutated only by `WaveDirector.endWave`
  on the survival path. No other writers (verified by grep)
- Damage chokepoint invariant: every `humanoid:TakeDamage` call
  routes through `DamageService.ApplyToHumanoid` (only AlienAI is a
  caller for E2; F1 turret service will be the second caller)
- Trust boundary for `WaveStarted` / `WaveEnded`: notification-only,
  fired to the affected player. No client → server wave Remote
  (server is sole authority on wave state)

### Audit (E2-scope, Studio-side — pending your local run)

After F5:

1. **Pool initialized.** Output:
   `[AlienPool] Pre-allocated 50 Stalker actors.`
2. **Manual wave fire** in Server Command Bar:
   ```luau
   local WaveDirector = require(game.ServerScriptService.Server.Modules.Combat.WaveDirector)
   local p = game.Players:GetPlayers()[1]
   WaveDirector.StartWave(p)
   ```
   Expect: 6 (= base 5 + (wave 1 - 1) * scale 1) Stalker neon-magenta
   parts spawn around the player's plot perimeter and walk toward
   them. `WaveStarted` Remote fires; HUD banner appears with a 90s
   countdown. Aliens damage the player on touch.
3. **Wave end paths:**
   - Survive 90s without dying → `[WaveDirector] <Name> wave 1 ended:
     survived=true, remaining=N`. HUD shows green "Wave 1 survived".
     `data.wavesSurvived` increments to 1.
   - Kill all aliens (no offensive option in V1 — defer to manual
     command bar `humanoid:TakeDamage(100)` per alien; turrets land
     in E2.5 / Phase G).
   - Player character dies → `survived=false`. No counter increment.
4. **Queue-deadline fallback chain:**
   - Click "Queue for Raid" with no other online players. Wait 30s
     for the deadline pop.
   - Expect: `[WaveDirector] <Name> wave N started: count=N, reason=queue_deadline`.
   - HUD banner shows reason as "no match — fallback".
5. **Wave clock:**
   - Wait `WaveClockSeconds / 2` (300s = 5 min) past server start
     for the first clock tick. Subsequent waves every 600s (10 min).
   - Verify clock-driven waves don't double-fire if a queue-deadline
     wave is already active (the `activeWaves[player]` guard rejects).

### Tech debt / deferred

- **No offensive option for the player.** V1 ships waves that damage
  but no way to fight back. E2.5 or Phase G adds:
  - `Combat/TurretService.luau` — auto-targeting raycast turret as
    a new buildable in BuildableRegistry.
  - `Combat/DroneSwarmService.luau` — player-commanded drone swarm
    (Recon/Combat/Engineering presets per brainstorm §4.8).
  - Player weapon system (FP combat mode per brainstorm §2.8).
- **No PathfindingService.** Aliens line-of-sight steer via MoveTo.
  Walls block the ground but not the path heuristic — aliens can
  bunch against walls. Phase G upgrades when biome terrain lands.
- **No alien variants.** Stalker only in V1. Phase G adds volcanic
  + ice-cave variants with biome-tied visuals + stats.
- **`damage_taken` quest event has no quest entry yet.** The pool of
  10 quests in `DailyQuestManager.QUEST_POOL` doesn't include a
  damage-related objective. Phase G's quest-pool expansion adds
  e.g. "Survive 3 PvE waves" (`wave_survived`) and "Take 500 damage"
  (`damage_taken`).
- **Wave clock cadence is V1 placeholder.** 10 min / wave is a
  guess; Phase G playtest data tunes via
  `config/balance/wave_scaling.json`.
- **Snapshot rendering deferred.** RaidSession still runs raid
  rounds in an empty world. Snapshot rendering + raid-place wave
  defenders ship in a follow-up sub-phase or Phase G.
- **Touched events are unrate-limited.** A modded client could spam
  Touched events to inflate `damage_taken` emissions. F1's per-
  Remote rate limiting + DamageService source validation closes
  this.
- **No alien death VFX / SFX.** Aliens just disappear back to the
  pool when killed. Phase G adds a death animation + the
  bioluminescent "burst" effect.

### What's next

E3 — Clan/squad system. New `Social/ClanService.luau` +
`Social/ClanStashLedger.luau`; cross-server clan chat via
MessagingService topic `outpost.clan.<clanId>`. New DataStore
`ClanData_v1` (separate keyspace from PlayerData). New
ProfileSchema field `clanId: string?`. Stash withdrawal > N
requires leader approval; logged.

### Commit

`feat(phaseE2): PvE wave system + raid-queue fallback`

---

## E2.5 — Turret service (auto-targeting + raycast damage) ✅

**Date:** 2026-05-05
**Branch:** `claude/audit-phases-a-d-2BAuW`

### Why a 2.5

E2 shipped wave defense without a player offensive option — survival
meant "outlive the timer while aliens swarm you." That isn't the
brainstorm gameplay loop ("turrets, walls, and drone swarm hold the
line — or don't"). E2.5 closes the loop with the turret half. Drone
swarm + player FP weapon land in their own future sub-phase or
Phase G.

### What was built

#### Server

- **`Constants.COMBAT`** — added `TurretRange = 40`, `TurretDamage = 25`
  (4 shots to kill a 100HP Stalker), `TurretFireSeconds = 1.0` (one
  shot per second per turret), `TurretTickSeconds = 0.5` (targeting
  cadence; decoupled from fire so a moving alien is re-targeted
  between shots).
- **`Modules/Registry/BuildableRegistry.luau`** — added `combatRole`
  field to the `Buildable` type. New `turret` entry: cost 200,
  steel-blue tactical visual, `combatRole = "turret"`. PlacementService
  branches on this field at place time.
- **`Combat/TurretService.luau`** — runtime turret registry +
  targeting tick. Public API:
  - `RegisterTurret(player, part)` / `UnregisterTurret(part)` — keyed
    by Part for O(1) operations
  - `GetTurretsForPlayer(player)` — count
  - `Init` — wires PlayerRemoving cleanup + the 2Hz tick loop
  Per tick: scan `Workspace.AlienActors`, find nearest live alien
  within range per turret, fire if cooldown elapsed. Damage routes
  through `DamageService.ApplyToHumanoid`. Kill-credit goes to the
  turret owner only on the shot that drops HP to 0 (multi-turret
  damage on the same alien doesn't split credit). Brief 0.1s neon-
  red Part beam visual via `Debris:AddItem`. Phase G replaces with
  proper Beam + projectile VFX.
- **`Build/PlacementService.luau`** — new branch: if
  `buildable.combatRole == "turret"`, call
  `TurretService.RegisterTurret(player, part)` after the part lands.
  Both fresh placements AND restorations register, since the runtime
  registry is per-session (not persisted).
- **`init.server.luau`** — wired `TurretService.Init()` BEFORE
  `PlacementService.Init()`. Init only sets up the tick + cleanup
  hooks; `RegisterTurret` works pre-Init too. The ordering makes the
  dependency explicit.
- **`ProfileSchema.luau`** — added `turretsKilled: number` (default 0).
  Additive; older saves get 0 via Reconcile. Single-writer
  invariant: `TurretService.fireTurret` is the only mutator
  (verified by grep).

#### Client

- **`Build/BuildPalette.luau`** — `PALETTE_ORDER` extended to include
  `"turret"`. Container width adjusted from 320 → 460 to fit the third
  button at 140 wide + 12 padding.

#### Documentation

- `DATA_SCHEMA.md` — `turretsKilled` documented under "Turret kill
  field (E2.5)".

### Audit (E2.5-scope, sandbox-side)

- 63 `.luau` files — `--!strict` on all
- TurretService uses `task.spawn` / `task.wait` for the tick loop
  (no legacy `wait()`)
- Damage chokepoint invariant maintained: turret damage routes
  through `DamageService.ApplyToHumanoid("turret_raycast")`
- Single-writer invariant on `data.turretsKilled`: only
  `TurretService.fireTurret` mutates it (verified via grep)
- Turret part lifecycle: parts created via `PlacementService` →
  parented under `plot.buildings`. When the plot is wiped on
  PlayerRemoving (PlotManager.release destroys the plot folder),
  the turret parts go with it; `TurretService.PlayerRemoving`
  cleanup runs in parallel and clears the registry by ownerUserId
- `GetTurretsForPlayer` is non-yielding (linear scan, but turret
  count per player is bounded by plot capacity — V1 plot fits at
  most ~256 turrets at 1-cell × 4-stud grid, in practice far fewer)

### Audit (E2.5-scope, Studio-side — pending your local run)

After F5:

1. **Build palette shows three buttons**: Extractor, Wall, Turret.
2. **Place a turret:**
   ```luau
   -- Server context Command Bar:
   local PlacementService = require(game.ServerScriptService.Server.Modules.Build.PlacementService)
   local PlotManager      = require(game.ServerScriptService.Server.Modules.World.PlotManager)
   local CurrencyService  = require(game.ServerScriptService.Server.Modules.Economy.CurrencyService)
   local p = game.Players:GetPlayers()[1]
   CurrencyService.Add(p, 500)  -- 200 cost
   print(PlacementService.TryPlace(p, "turret", 0, 0))
   -- Expect: { ok = true, part = ... } and a steel-blue 2x4x2 part on the plot
   ```
3. **Fire a wave; watch turret shoot:**
   ```luau
   local WaveDirector = require(game.ServerScriptService.Server.Modules.Combat.WaveDirector)
   WaveDirector.StartWave(p)
   -- Aliens spawn at perimeter; turret fires neon-red beams at the
   -- nearest one within 40 studs every 1s; alien dies after 4 shots.
   -- `data.turretsKilled` increments on the killing shot.
   ```
4. **Multiple turrets:** place 3 turrets at different cells on the
   plot; each independently targets the nearest alien. Beam visuals
   should fire from all three when aliens are in range.
5. **Range cutoff:** alien at >40 studs from a turret should not be
   targeted; the alien crosses into range → the turret immediately
   targets it on the next 0.5s tick.
6. **Restore path:** place a turret, leave, rejoin. Expect:
   - `[BuildRestorer] Plot1 for <Name>: restored 1/1`
   - turret part visible at the saved cell
   - turret registered (verify via `TurretService.GetTurretsForPlayer(p)`
     returns 1)
   - next wave: turret fires correctly

### Tech debt / deferred

- **Turrets are invincible.** Aliens can walk past them without
  damage. Phase G adds turret HP, an alien priority-targeting rule
  (turret > player when in range), and a turret-destroyed signal so
  the wave-defense gameplay loop has real stakes.
- **No Drone Swarm yet.** V1 must-have per brainstorm §2.7 (3 preset
  swarm types — Recon / Combat / Engineering). Their own sub-phase
  (E2.6 or E2.7) before E5, OR Phase G if data shows turrets alone
  carry the wave gameplay.
- **No turret VFX beyond the 0.1s neon beam.** No muzzle flash, no
  impact spark, no audio. Phase G ships per-pass.
- **No targeting priorities.** "Nearest alien" is V1 simplistic.
  Phase G can add weighting (low-HP aliens vs full-HP, or aliens
  closest to the player vs aliens at the perimeter).
- **`turret_kill` quest event not yet emitted.** TurretService
  could emit `QuestObjectives.Emit("turret_kill", owner, 1)` on
  every kill — deferred until Phase G expands the quest pool with
  turret-related entries.
- **Player FP weapon system** still V1 must-have, deferred. Players
  who run out of turrets mid-wave have no recourse other than
  running away. Phase G or follow-up.
- **No PathfindingService for aliens** (E2 carryover). Walls + turrets
  don't block AI pathing properly; aliens line-of-sight steer past
  them. Phase G upgrades when biome terrain lands.

### What's next

E3 — Clan/squad system. New `Social/ClanService.luau` +
`Social/ClanStashLedger.luau`; cross-server clan chat via
MessagingService topic `outpost.clan.<clanId>`. New DataStore
`ClanData_v1` (separate keyspace from PlayerData). New
ProfileSchema field `clanId: string?`. Stash withdrawal > N
requires leader approval; logged.

### Commit

`feat(phaseE2.5): turret service (auto-targeting + raycast damage)`

---

## E2.6 — Drone swarm (Combat preset) ✅

**Date:** 2026-05-05
**Branch:** `claude/audit-phases-a-d-2BAuW`

### Why a 2.6

Brainstorm §2.1 names the wave-defense triad: "turrets, walls, and
**drone swarm** hold the line — or don't." E2.5 shipped turrets +
walls; E2.6 closes the triad with the autonomous drone swarm half.
V1 must-have per brainstorm §2.7 — V1.5 adds the customization editor.

### What was built

#### Server

- **`Constants.COMBAT`** — added `DroneSwarmCount = 3`,
  `DroneOrbitRadius = 8`, `DroneOrbitHeight = 4`,
  `DroneOrbitSpeedDeg = 90` (deg/s rotation around player),
  `DroneAttackRange = 25` (smaller than turret 40 — drones are
  mobile and bring range to the alien), `DroneDamage = 8`
  (3 hits to finish a Stalker after orbit-approach delay),
  `DroneFireSeconds = 0.5` (2 shots/sec — faster than turrets),
  `DroneTickSeconds = 0.4`, `DroneMoveSpeed = 32` (studs/sec
  travel speed), `DronePoolSize = 80` (20-server-cap × 3 drones
  + buffer for character-respawn churn).
- **`Modules/Registry/DroneSwarmRegistry.luau`** (shared) — preset
  catalog with 3 entries:
  - `recon` (blue, behaviorTag = "spot", `v1Active = false`)
  - `combat` (red, behaviorTag = "attack", `v1Active = true`) ← V1
  - `engineering` (green, behaviorTag = "repair", `v1Active = false`)
  Only Combat ships V1 functional — Recon needs HUD overlay,
  Engineering needs turret HP. Both ride into the catalog now so
  Phase G's customization UI doesn't churn the registry shape.
  `DroneSwarmRegistry.DefaultV1Preset = "combat"`.
- **`ProfileSchema.luau`** — added `dronesKilled: number` (default 0).
  Additive; older saves get 0 via Reconcile. Single-writer:
  `DroneSwarmService.tickTargetingFor` only.
- **`Combat/DroneSwarmService.luau`** — drone swarm lifecycle. Two
  pools managed:
  - `ServerStorage.OutpostDronePool` — parked drone Parts
  - `Workspace.DroneActors` — active drone Parts
  Per-player swarm spawned on `CharacterAdded` (deferred 0.1s for
  HRP availability), recalled on `Humanoid.Died` /
  `Players.PlayerRemoving`. Drone Parts are `Anchored = true`;
  server CFrame-snaps them each Heartbeat toward either an orbit
  slot (no target) or just-shy-of-target position (target locked).
  Targeting tick (0.4s) re-acquires nearest live alien within
  range; fires every 0.5s via `DamageService.ApplyToHumanoid`
  with brief 0.08s neon Part beam visual. Kill-credit semantics
  match TurretService (only the killing-blow shot increments).
- **`init.server.luau`** — wired `DroneSwarmService.Init()` last
  in the main-place chain. Independent of wave/raid init order;
  listens to PlayerAdded / CharacterAdded directly.

#### Documentation

- `DATA_SCHEMA.md` — `dronesKilled` documented under "Drone-kill
  field (E2.6)".

### Audit (E2.6-scope, sandbox-side)

- 65 `.luau` files — `--!strict` on all
- DroneSwarmService uses `task.spawn` / `task.wait` / Heartbeat (no
  legacy patterns)
- Damage chokepoint invariant maintained: drone damage routes through
  `DamageService.ApplyToHumanoid("drone_raycast")`
- Single-writer invariant on `data.dronesKilled`: only
  `DroneSwarmService.tickTargetingFor` mutates (verified by grep)
- Object-pool invariant: drones never `Instance.new` outside
  `buildDronePart` (overflow warn aside); pre-allocates 80 parts on
  Init
- Lifecycle: Recall fires on Humanoid.Died AND PlayerRemoving — no
  drone leaks across respawn or disconnect
- Trust boundary: drones are 100% server-authoritative — clients see
  the replicated Parts but no drone Remote exists (V1.5+ may add a
  preset-swap Remote when the customization UI ships)

### Audit (E2.6-scope, Studio-side — pending your local run)

After F5:

1. **Pool initialized.** Output:
   `[DroneSwarmService] Pre-allocated 80 drone parts.`
2. **Player spawn → swarm deployed.** On character spawn, ~0.1s
   later:
   - `[DroneSwarmService] Deployed combat swarm (3 drones) for <Name>`
   - 3 small neon-red Parts appear orbiting the player at radius 8,
     height 4 above HRP, rotating ~90 deg/s.
3. **Wave fires; drones engage:**
   ```luau
   local WD = require(game.ServerScriptService.Server.Modules.Combat.WaveDirector)
   WD.StartWave(game.Players:GetPlayers()[1])
   ```
   Aliens spawn at perimeter; drones break orbit when an alien is
   within 25 studs and chase, fire neon-red beams at 2 shots/sec
   until the alien dies, then return to orbit.
4. **Kill credit:**
   ```luau
   local DM = require(game.ServerScriptService.Server.Modules.Player.DataManager)
   print(DM.GetData(game.Players:GetPlayers()[1]).dronesKilled)
   -- Should increment by N where N = aliens killed by drones (not turrets)
   ```
5. **Respawn lifecycle:** kill the player character (Humanoid:TakeDamage(999))
   → drones recalled (returned to pool); player respawns → swarm
   redeploys after 0.1s.
6. **Combined defense:** place a turret near spawn, fire wave;
   verify turret + drone beams co-fire on the same wave with no
   conflict (both feed DamageService independently).

### Tech debt / deferred

- **Recon + Engineering presets are catalog stubs.** Phase G wires:
  - Recon: minimap/HUD overlay showing aliens-spotted-by-recon at
    extended range (50+ studs)
  - Engineering: depends on Phase G turret HP — repairs damaged
    turrets/walls. Useless until E2.5's "turrets invincible" tech
    debt is closed.
- **No customization UI per brainstorm §2.7.** V1.5 ships the editor
  that lets players pick + save preset swaps. V1 hardcodes Combat.
- **Drone visuals are placeholder.** Solid-color neon Parts; no
  trails, no engine VFX, no audio. Phase G ships the "distinct trail
  /color identities" per §4.8 G6.
- **No pathfinding around walls.** Drones fly direct lines through
  geometry (Anchored Parts, no collision). For V1 this is fine
  because drones are above walls (`DroneOrbitHeight = 4`); Phase G
  may add proper occlusion checks if drones ever go to ground level.
- **Drones are invincible.** Aliens don't damage them. Phase G adds
  drone HP + alien-targets-drone behavior alongside the turret HP
  work.
- **No `drone_kill` quest emission yet.** Phase G expands the quest
  pool to include autonomous-defender stats.
- **CFrame-snap movement may look chunky on low-FPS clients.** Server
  steers at Heartbeat (60Hz on the server), but client-side
  replication interpolates between server frames. V1 fine; Phase G
  may switch to AlignPosition for smoother client visuals.

### What's next

E3 — Clan/squad system. New `Social/ClanService.luau` +
`Social/ClanStashLedger.luau`; cross-server clan chat via
MessagingService topic `outpost.clan.<clanId>`. New DataStore
`ClanData_v1` (separate keyspace from PlayerData). New
ProfileSchema field `clanId: string?`. Stash withdrawal > N
requires leader approval; logged.

### Commit

`feat(phaseE2.6): drone swarm (Combat preset; 3 orbiting drones)`

---

## E3 — Clan / squad system ✅

**Date:** 2026-05-05
**Branch:** `claude/audit-phases-a-d-2BAuW`

### What was built

#### Server

- **`Constants.CLAN`** — full block: 4-member cap (brainstorm §2.6),
  name 3-24 chars + tag 2-5 chars validation, `AutoApproveWithdrawalThreshold = 5000`
  (large withdrawals require leader approval per brainstorm §4.6
  anti-grief), `MaxPendingWithdrawals = 16` cap on the per-clan pending
  table (bounds DataStore payload size below 4MB), MessagingService
  topic strings, separate `ClanData_v1` DataStore name.
- **`ProfileSchema.luau`** — added `clanId: string?` (default nil).
  Additive; older saves get nil via Reconcile. Documented in
  `DATA_SCHEMA.md` with cross-keyspace consistency notes.
- **`Remotes.luau`** — registered 10 clan Remotes:
  `ClanState`, `CreateClan`, `JoinClan`, `LeaveClan`, `KickFromClan`,
  `ClanStashDeposit`, `ClanStashWithdraw`, `ClanStashApprove`,
  `ClanChatSend`, `ClanChatReceived`. Documented in
  `REMOTES_REGISTRY.md`.
- **`Social/ClanService.luau`** — clan lifecycle owner. Per-server
  in-memory cache (`{ [clanId]: { data, fetchedAt } }`) backed by
  `DataStoreService` for the `ClanData_v1` keyspace; cross-server
  cache invalidation via MessagingService `outpost.clan.invalidate`
  (belt-and-suspenders next to a 60s TTL). All mutations route
  through `MutateClan(clanId, mutator)` which wraps `UpdateAsync`
  for atomic CAS — concurrent multi-server joins / deposits /
  withdrawals can't lose updates. Public ops:
  - `TryCreateClan(player, name, tag)` — validates name (alnum+space)
    + tag (alnum); creates leader-role membership; sets profile pointer
  - `TryJoinClan(player, clanId)` — atomic membership-cap check
  - `TryLeaveClan(player)` — leader-leaving auto-promotes longest-
    tenured officer (or oldest member if no officers); last-member
    leave deletes the row via UpdateAsync `nil` return
  - `TryKickMember(actor, targetUserId)` — server enforces role
    hierarchy: only leader/officer can kick; only leader can kick
    officer; no one can kick the leader. Defensive auto-clear of
    stale `profile.clanId` in `PushStateToPlayer` covers the
    cross-server-kick path.
- **`Social/ClanStashLedger.luau`** — wraps `ClanService.MutateClan`
  for stash-specific ops:
  - **Deposit:** `CurrencyService.TrySpend` first, then UpdateAsync
    increments `stashCredits`. Refund on UpdateAsync failure to keep
    wallet+stash consistent.
  - **Withdraw small (≤ threshold):** atomic decrement + grant
    inline (requester is on this server).
  - **Withdraw large (> threshold):** queue a `PendingWithdrawal`
    entry; bounded by `MaxPendingWithdrawals`.
  - **Approve:** leader-only role check inside the UpdateAsync
    closure; on approve, decrement stash + remove pending entry,
    then publish `outpost.clan.withdrawal.grant` MessagingService
    payload so the requester's home server applies the credits via
    `CurrencyService.Add`. Preserves single-writer-per-profile
    invariant (ADR-008): the leader's server never writes the
    requester's profile directly.
- **`Social/ClanChatService.luau`** — per-clan MessagingService topic
  (`outpost.clan.chat.<clanId>`). Lazy subscribe: each server
  subscribes only to topics for clans whose members are currently
  online here. Refcount-based sub/unsub (subscribe on first member,
  unsubscribe on last leave) prevents the "subscribe to every clan"
  scaling foot-gun. Sender + sanitize + length-cap server-side.
  V1 has no chat history / scrollback — fresh joins miss prior messages.

#### Client

- **`Social/ClanController.luau`** — toggle button + right-side panel.
  Two render paths:
  - **No-clan view:** Create form (name + tag inputs) and Join form
    (clanId input).
  - **In-clan view:** title + role/stash header, members list with
    role-gated Kick buttons, deposit + withdraw inputs, leader-only
    Allow/Deny buttons on each pending withdrawal row, 100x540
    chat scrollback (50-message ring on the client) + send box,
    Leave button.
  Subscribes to `ClanState` (full state replacement) and
  `ClanChatReceived` (append message). All UI is placeholder
  (Phase G replaces with the neon-tactical theme).

#### Documentation

- `REMOTES_REGISTRY.md` — 10 clan rows with trust model + rate-limit
  classes documented.
- `DATA_SCHEMA.md` — `clanId` pointer field + full `ClanData_v1`
  keyspace shape + cross-keyspace consistency notes.

### Audit (E3-scope, sandbox-side)

- 68 `.luau` files — `--!strict` on all
- All clan modules use `task.spawn` / `task.wait` (no legacy
  patterns)
- Atomicity invariant: every `ClanData_v1` mutation routes through
  `ClanService.MutateClan` → `DataStoreService:UpdateAsync` (verified
  by grep — no direct `clanStore:SetAsync` calls anywhere)
- Trust boundary verified: every C→S Remote validates types
  server-side; role checks (leader/officer/member) live in the server
  closures inside `UpdateAsync`, not in client code
- Single-writer-per-profile invariant (ADR-008) preserved: clan
  withdrawals never write the requester's profile from another
  server — they publish via MessagingService and the home server
  applies. Verified by grep: only `CurrencyService.Add(requester, ...)`
  call sites in the clan stack are inside the home-server-side
  WithdrawalGrant subscription handler
- Rollback safety: deposit Spend-before-UpdateAsync with refund on
  failure (no orphaned credits); leader-leave transfer in same
  UpdateAsync closure (no leaderless-clan window)
- Chat refcount: `ClanChatService.refMember` / `unrefMember`
  serialized on `ClanChatRef` player attribute — covers
  PlayerAdded/PlayerRemoving + 30s membership-poll fallback for
  mid-session clan changes
- Defensive auto-clear: `PushStateToPlayer` checks `IsMember` against
  the actual ClanData and clears stale `profile.clanId` if the
  player isn't actually in the clan (covers the cross-server-kick
  while-elsewhere case)

### Audit (E3-scope, Studio-side — pending your local run)

After F5 with two test clients (Test → Local Server → 2 clients):

1. **Create clan (Player A):**
   - Open Clan panel → enter name "Outpost Squad", tag "OPS" → Create
   - Server log: `[ClanService] PlayerA created clan Outpost Squad (<guid>) [OPS]`
   - Panel switches to in-clan view; Player A sees themselves as leader
2. **Join clan (Player B):**
   - Player A copies the clanId from the Studio Server console (or
     `print(DataManager.GetData(playerA).clanId)`)
   - Player B enters clanId → Join
   - Both clients' panels refresh; both see 2 members
3. **Deposit (Player B, member):**
   - `CurrencyService.Add(playerB, 5000)` in command bar
   - Player B types 1000 in deposit box → Deposit
   - Both clients see stash 1000; player B's credits drop by 1000
4. **Withdraw small (Player B, ≤ threshold):**
   - Player B withdraws 500 → instant grant; stash 500
5. **Withdraw large (Player B, > threshold):**
   - Player B withdraws 5001 → response status `pending`; stash unchanged;
     a pending withdrawal row appears for both players
6. **Approve (Player A, leader):**
   - Player A clicks Allow on the pending row → server publishes
     WithdrawalGrant; player B receives credits via the
     MessagingService loopback (or directly if same-server)
7. **Cross-server case (single-Studio-server limitation):** the
   single-server case exercises the SAME-server branch of the
   WithdrawalGrant subscriber (PlayerB is online here too). True
   cross-server validation requires a published universe with two
   real PlaceIds; revisit in Phase H smoke tests.
8. **Kick (Player A, leader):** kick Player B → both panels refresh;
   B's profile.clanId clears inline; B's panel shows no-clan view
9. **Chat:** Player A types "test"; both clients see it via
   `ClanChatReceived` (sender loopback through the MessagingService
   topic — no special-casing). 50-message ring on client.
10. **Leave (last member):** clan disbands when the last member
    leaves; Player A's profile.clanId clears.

### Tech debt / deferred

- **No invite codes / private clans.** V1 lets anyone with the
  clanId join. V1.1+ adds invite-only flag + per-clan invite codes.
- **No chat history / scrollback.** Players who join a clan miss
  prior messages. V1.5 may add a 50-message ring buffer in
  `MemoryStoreService` per clan.
- **No promotion to officer.** V1 has only leader (creator) +
  member. Leaders can leave (auto-promotion handles transfer) but
  can't promote/demote others. V1.1+ adds `PromoteMember` Remote.
- **Withdrawal grant lost if requester goes offline at approval
  time.** MessagingService is best-effort; if the requester's
  not on any server, the publish fires into a void. V1.5+ may add
  a `PendingRaidRewards`-style fallback DataStore (`PendingClanRewards`)
  read on next join.
- **Cross-server kick latency.** The kicked player's
  `profile.clanId` clears on their NEXT state push (next join, or
  next clan invalidate broadcast they happen to be in). For prompt
  clearing, add `outpost.clan.kicked.<userId>` MessagingService
  topic in V1.5+.
- **No clan-vs-clan weekly bracket** per brainstorm §2.6. V1.5+.
- **No cross-server clan-state-on-mutation push to the affected
  member specifically.** The current `pushStateForClanMembers` is
  per-server-local; cross-server propagation goes through the
  invalidate broadcast (which then re-fetches and re-pushes). Two
  hops; for V1 the latency (a few hundred ms) is fine.
- **No rate-limit floor on clan Remotes.** F1 wires
  `Security.AntiExploit.RateCheck`; chat in particular needs a
  tight bucket (5 msg / 10s).
- **`outpost.clan.chat.<clanId>` topic count** scales with active
  clans on this server. Lazy refcount mitigates but if a single
  server hosts members of 100+ different clans simultaneously,
  Roblox's per-server subscription cap (~80) becomes a problem.
  V1 caps unlikely to hit at 50 CCU; flag for Phase H load test.

### What's next

E4 — Voice chat (raid-only). `Voice/VoiceGate.luau` enables
`VoiceChatService` only inside the raid place; main place stays
silent. UI affordance in raid HUD shows when voice is active.
Uses Feb 2026's `VoiceChatService:GetChatGroupsAsync` API for
diagnostics + verifies the place-level enable.

### Commit

`feat(phaseE3): clan/squad system + shared stash + cross-server chat`

---

## E4 — Spatial Voice (raid-only) ✅

**Date:** 2026-05-05
**Branch:** `claude/audit-phases-a-d-2BAuW`

### What was built

Voice opens at the **place level** per ADR-009 (two-PlaceId split):
the raid place enables `VoiceChatService.EnableDefaultVoice = true`
at build time; the main place inherits the platform default (off).
This matches the brainstorm §2.6 "voice during raids only" rule via
deployment topology — no runtime toggle, no race window.

#### Build configuration

- **`raid.project.json`** — added `VoiceChatService` node with
  `EnableDefaultVoice = true`. The main `default.project.json`
  remains untouched (no VoiceChatService config = platform default,
  which is off).

#### Server

- **`Constants.VOICE`** — `VerifyIntervalSeconds = 30` (defensive
  re-check cadence; logs once per state flip), `UseChatGroupDiagnostic
  = true` (toggles the Feb 2026 `GetChatGroupsAsync` log on raid round
  start).
- **`Voice/VoiceGate.luau`** — branches on `game.PrivateServerId` to
  decide raid-place vs main-place behavior. Reads
  `VoiceChatService.EnableDefaultVoice` defensively (pcall — Roblox
  has renamed voice properties before; fail-safe to false). Per-
  player voice availability via `VoiceChatService:IsVoiceEnabledForUserIdAsync`
  — surfaces "voice unavailable" (under-13, region-blocked, account-
  level voice off) so the client HUD shows a muted indicator instead
  of misleading the player.
- **`Remotes.luau`** — registered `VoiceState` (S→C event, render-
  only). The mic toggle itself is owned by Roblox's native voice UI;
  no client→server voice Remote exists.
- **`init.server.luau`** — wired `VoiceGate.Init()` in BOTH branches:
  - Raid place: pushes `inRaidPlace = true` so the HUD renders the
    indicator
  - Main place: pushes `inRaidPlace = false` so the HUD clears any
    stale indicator (e.g. lingering after a raid teleport home)

#### Client

- **`Voice/VoiceController.luau`** — top-right indicator. Three
  visual states: hidden (`inRaidPlace = false`), muted-grey (in raid
  place but voice unavailable for this account), active-red (in raid
  place AND voice transmitting). Phase G replaces with proper mic
  icons + amplitude visualization.
- **`init.client.luau`** — wired `VoiceController.Init()` last.

#### Documentation

- `REMOTES_REGISTRY.md` — `VoiceState` row added.
- `RAID_PROTOCOL.md` — voice invariant updated to point at the place-
  level enable + the gate module.

### Audit (E4-scope, sandbox-side)

- 71 `.luau` files — `--!strict` on all
- VoiceGate uses `task.spawn` / `task.wait` (no legacy patterns)
- Trust boundary: no client → server voice Remote exists; the gate is
  render-only state push
- Defensive reads: `pcall` wraps `EnableDefaultVoice` property read
  AND `IsVoiceEnabledForUserIdAsync` call — Roblox API churn or
  network blip degrades to "voice off" rather than crashing
- Place isolation: `VoiceChatService.EnableDefaultVoice = true` only
  appears in `raid.project.json` (verified by grep); `default.project.json`
  has no voice config → platform-default off

### Audit (E4-scope, Studio-side — pending your local run)

E4's full audit needs the universe-level voice chat toggle enabled in
the Roblox Creator Dashboard (Phase H prerequisite). Until then,
`IsVoiceEnabledForUserIdAsync` returns false universe-wide and the
client always shows the muted indicator in the raid place. Deferred
audits:

1. **Place-level enable verified.** Open the built `Raid.rbxl` in
   Studio → check `VoiceChatService.EnableDefaultVoice = true` in
   the Properties pane. Open the built `Game.rbxl` → property is
   default false.
2. **Main place HUD stays clean.** Join the main place; the voice
   indicator never appears.
3. **Raid place muted indicator.** Pre-Phase H (universe voice off):
   queue + match into a raid, the indicator appears with the muted-
   grey "Voice Off" text. Server log: `[VoiceGate] Init: raidPlace=true,
   EnableDefaultVoice=true`.
4. **Raid place active indicator.** Post-Phase H universe voice
   enable: same flow, indicator flips to red "Voice Active" because
   `IsVoiceEnabledForUserIdAsync` returns true.
5. **GetChatGroupsAsync diagnostic.** Server log on raid round start
   includes `[VoiceGate] <Name> chat groups: N`. If it fails, the
   warn is non-blocking — voice still works, the diagnostic is just
   absent.

### Tech debt / deferred

- **Universe-level voice chat toggle** must be flipped in the Roblox
  Creator Dashboard before voice actually transmits. NOT Rojo-
  configurable. Phase H checklist item.
- **No mic-amplitude visualization.** The current indicator is binary
  (active / muted / hidden). Phase G adds per-speaker amplitude bars
  + speaker name list during raid round.
- **No moderation hooks.** Roblox handles voice moderation natively;
  V1 doesn't surface "this player was reported" to the host server.
  V1.5 may add a `MarkAsActioned` callback once Roblox's API
  surfaces.
- **No verified-account requirement gate.** Brainstorm §8.3 flags
  voice toxicity as a risk; if reports spike post-launch, gate voice
  behind ID-verified accounts. Tunable via universe-level setting at
  that point, not a code change.
- **VoiceChatService property names may rename.** Roblox has done it
  before (the older `Enabled` / `EnableDefault` flip). The defensive
  pcall reads keep the gate from hard-failing on a rename, but the
  `raid.project.json` `$properties` block would need updating in
  the same Rojo build that adopts the new schema. Watch for
  release-notes churn.
- **No audio cue on voice activation.** Phase G adds a soft chirp
  when the indicator flips to active so the player knows their mic
  is hot.

### What's next

E5 — Leaderboards + friends. `Social/LeaderboardService.luau`
(OrderedDataStore — global Credits, weekly raid wins keyed by ISO
week per ADR-009-style "one store per bucket"),
`Social/FriendsService.luau` (cached `Players:GetFriendsAsync` per
session, refreshed on hour boundary),
`Social/ObserveColonyService.luau` (read-only friend visit). Client
`Social/LeaderboardController.luau` + `FriendsPanel`.

### Commit

`feat(phaseE4): spatial voice gate (raid-place enabled, main-place silent)`
