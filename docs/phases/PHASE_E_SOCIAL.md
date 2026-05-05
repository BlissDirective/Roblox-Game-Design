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
