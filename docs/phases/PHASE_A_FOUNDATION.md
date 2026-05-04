# PHASE A — Foundation

> Per-sub-phase worklog. Updated by Claude Code at the end of each sub-phase
> per `10_BUILD_PROTOCOL.md` (Plan → Confirm → Build → Verify → Commit →
> Report).

**Goal (per `10_BUILD_PROTOCOL.md`):** Project loads in Studio, DataStore
round-trips work, Remotes scaffolding ready.

**Phase audit gate:** Place loads, no Output errors, DataStore round-trip
succeeds, `BindToClose` flushes on shutdown.

---

## A1 — Project scaffolding ✅

**Date:** 2026-05-04
**Branch:** `claude/review-claude-docs-LiZZS`

### What was built

- Full directory tree per `REPO_STRUCTURE.md` §1 with `.gitkeep` placeholders
  in every empty leaf folder (58 dirs).
- `src/server/init.server.luau` — empty server bootstrap, ready to wire
  managers in A4.
- `src/client/init.client.luau` — empty client bootstrap, ready to wire
  controllers in A4.
- `src/shared/Remotes.luau`, `Constants.luau`, `Types.luau`, `Enums.luau` —
  empty scaffolds. A3 fills them with the typed registry, FEATURES/tunables,
  shared types, and string enums.
- `Constants.luau` — populated with the V1.5/V2 `FEATURES` feature-flag table
  per ADR-002.
- `docs/architecture/` — `DATA_SCHEMA.md`, `REMOTES_REGISTRY.md`,
  `RAID_PROTOCOL.md`, `ECONOMY_TUNING.md`, `DECISIONS.md` (with ADR-001 and
  ADR-002 logged).
- `docs/playbooks/` — `DAILY_DEV_LOOP.md`, `PLAYTEST_PROTOCOL.md`,
  `INCIDENT_RESPONSE.md` stubs.
- `config/README.md`, `tests/README.md`, `tools/migrations/README.md`,
  `tools/asset-import/README.md` — short loader/usage notes.
- `analytics/EVENT_TAXONOMY.md`, `FUNNELS.md`, `KPIs.md` — stubs.

### What was *not* yet built (deferred to later sub-phases)

- DataStore wrapper (A2).
- Typed Remotes registry + helper (A3).
- Bootstrap Init() chain wiring (A4).
- Phase B–I worklog files — created when their phase begins.

### Audit (A1-scope)

- Directory tree matches `REPO_STRUCTURE.md` §1.
- Lua files contain `--!strict` headers.
- Tab-indented per `stylua.toml`.
- No `local` shadowing or unscoped variables (Selene-clean).

> Full Studio-load + Rojo-build audit deferred until A4 (need bootstraps
> wired before the place is meaningfully testable).

### Architectural decisions made

- ADR-001: Hand-rolled DataStore wrapper over ProfileService.
- ADR-002: Feature flags > long-lived branches for V1.5/V2 work.

### Tech debt logged

- `wally.lock` not yet generated (no deps declared). CI may surface this when
  `wally install` runs against an empty `wally.toml`. Watch first CI run.
- Phase B–I worklog files not pre-created. Will land at the start of each
  phase to avoid stale skeletons.

### What's next

Phase A2 — `DataManager` module + DataStore wrapper. Pre-A2 research pass
covers: `UpdateAsync` semantics 2026, ProfileService comparison sanity check,
Rojo 7.4 schema, Aftman vs Rokit current.

---

## A2 — DataManager + DataStore wrapper ✅

**Date:** 2026-05-04
**Branch:** `claude/review-claude-docs-LiZZS`

### Research pass (per build protocol)

Four parallel web searches before coding. Surfaced findings:

- **ProfileService is no longer maintained.** Successor `ProfileStore` (same
  author) is the recommended modern lib. Better cross-server conflict
  handling via `MessagingService`, 5-min auto-save default. → ADR-003.
- **2026 per-Experience DataStore limits** rolling out — friendlier at scale.
- **`UpdateAsync` + exponential backoff** still canonical (`SetAsync` only
  for first creation).
- **Session locks (JobId + timestamp)** remain the production-data-integrity
  win. ProfileStore implements them.
- **`BindToClose` 30s yield window** unchanged.

### Architectural decision

**ADR-001 superseded by ADR-003.** Adopt ProfileStore via Wally, wrap in a
thin `DataManager` façade. Surfaced the decision to the user and waited for
explicit approval before touching code (option B picked).

### What was built

- `wally.toml` — added `ProfileStore = "lm-loleris/profilestore@1.0.3"` to
  `[server-dependencies]`.
- `src/server/Modules/Player/ProfileSchema.luau` — v1.0 schema, default data
  factory, versioned migration table (empty for v1.0).
- `src/server/Modules/Player/DataManager.luau` — public façade:
  `Init`, `LoadPlayer`, `SavePlayer`, `GetData`, `WaitForData`. Mocks
  ProfileStore in Studio so the audit loop matches live behavior. Tracks
  intentional vs. cross-server-claim session ends. `BindToClose` waits up
  to 25s for all profiles to flush.
- `src/server/init.server.luau` — wired `DataManager.Init()`. Bootstrap is
  still 5–30 lines per CLAUDE.md.

### Audit (A2-scope)

> **Studio audit deferred** — the sandbox here doesn't run Roblox Studio.
> The Phase A audit gate (place loads, DataStore round-trip, `BindToClose`
> flush) runs at end of A4 once Studio has access. CI on the PR runs Selene
> + StyLua + `rojo build` against this commit.

Static checks completed in this environment:
- `--!strict` headers present on both new modules
- Tab-indented per `stylua.toml`
- `default.project.json` still validates (no schema change needed)
- `wally.toml` syntax valid (manual inspection)

### Architectural decisions made

- **ADR-003** — Adopt ProfileStore (`lm-loleris/profilestore@1.0.3`) over
  hand-rolled wrapper. Supersedes ADR-001.

### Tech debt logged

- `wally.lock` will be generated by CI's `wally install` step. If it ends
  up needing to be committed for reproducibility, do so in A3 or A4.
- `PlayerSession.luau`, `PlayerJoined.luau`, `PlayerLeaving.luau` (listed
  in `REPO_STRUCTURE.md` §2.1) **deliberately not built in A2** — no
  caller for them yet. Will land at the first phase that needs ordering
  across multiple managers (likely A4 or B1).
- `tests/unit/server/Player/DataManager.spec.luau` deferred — TestEZ is
  not yet a Wally dep. Add in A3 if we wire `[dev-dependencies]`, otherwise
  in F1 with the rest of the test scaffolding.

### What's next

A3 — Shared scaffolds. Populate `Remotes.luau` with the typed
`getOrCreate` helper, expand `Constants.luau` with the rate-limit and
tunable tables, populate `Types.luau` with `PublicProfile` + a few core
shared types, and seed `Enums.luau` with `Mode` (Build / Combat).

---

## A3 — Shared scaffolds (Remotes, Constants, Types, Enums) ✅

**Date:** 2026-05-04
**Branch:** `claude/review-claude-docs-LiZZS`

### What was built

- `src/shared/Constants.luau` — expanded structurally:
  - `FEATURES` (already present)
  - `DATASTORE` — `StoreName`, `BindToCloseTimeoutSeconds`
  - `RATE_LIMITS` — `Default`, `Placement`, `Purchase` (Phase F1 tunes)
  - `TICK` — `Currency` (Phase B2)
  - `GRID` — `Size` (Phase B4)
- `src/shared/Types.luau` — added `Result<T>` (universal success/failure
  shape for Remotes and any operation that fails in a typed way).
- `src/shared/Remotes.luau` — `getOrCreate` helper + `ensureContainer`
  pattern. Lazy folder creation under `ReplicatedStorage.OutpostRemotes`.
  Empty registry at the bottom; phases B+ register Remotes by appending.
  `selene: allow(unused_variable)` directive on the helper since no caller
  exists yet (resolves naturally on first registration).
- `src/shared/Enums.luau` — `Mode { Build, Combat, Raid }`,
  `Biome { Jungle, Volcanic, Ice }`. String identity intentional for
  Remote-safe transport.
- `src/server/Modules/Player/DataManager.luau` — refactored to read
  `STORE_NAME` and `BindToCloseTimeoutSeconds` from `Constants`. No
  hardcoded magic numbers in the persistence module anymore.

### Audit (A3-scope, sandbox-side)

- All 8 `.luau` files start with `--!strict`
- `default.project.json` valid JSON
- Tab-indented per `stylua.toml`
- DataManager grep confirms the two old hardcoded values (`"PlayerData_v1"`,
  `25`) are gone — both call sites read `Constants.DATASTORE.*`

### Architectural decisions made

None — A3 was structural follow-through on ADR-002 (no magic numbers in
modules) and ADR-003 (DataManager façade stays narrow).

### Tech debt logged

- `Remotes.getOrCreate` is unused locally (warns under selene's default
  `unused_variable`). The `selene: allow` directive suppresses it; first
  Remote registration in Phase B will remove the directive.
- `Types.Result<T>` introduced ahead of any caller — flagged. Used in B+ as
  Remote response type. Acceptable per the "shared scaffolds" purpose of A3.

### What's next

A4 — wire bootstraps end-to-end. Bootstraps already require modules; A4's
job is to **run the Phase A audit** (Studio load, DataStore round-trip,
`BindToClose` flush, multi-client basic check) and add a thin
`init.client.luau` flow that proves replication. If audits pass, Phase A
is done and we propose the Phase B kickoff.

---

## A4 — Bootstrap wiring + Phase A audit ⏳ (sandbox-side complete; awaiting Studio audit)

**Date:** 2026-05-04
**Branch:** `claude/review-claude-docs-LiZZS`

### What was built

- `src/server/init.server.luau` — boot print now includes
  `Constants.DATASTORE.StoreName` and `BindToCloseTimeoutSeconds` so the
  audit gets a one-line "did the server load and see Constants" signal.
- `src/client/init.client.luau` — replaced the placeholder print with a
  diagnostic that requires `Constants` + `Enums` from
  `ReplicatedStorage.Shared` and prints values from each. If this line
  doesn't land in Studio's Output, replication is broken.
- `src/server/Modules/Player/DataManager.luau` — added lifecycle prints:
  - on successful `LoadPlayer`: player name, session count, credits,
    firstJoinAt
  - on `SavePlayer`: player name, session count
  - on `BindToClose` start: count of profiles flushing
  - on `BindToClose` complete: confirmation
  These prints are intentionally always-on (not Studio-gated) — the
  signal is valuable in production for tracing data-related issues.

### Phase A audit gate (you run this in Studio)

The audit gate cannot run in this sandbox. **Execute in Studio when you
sync the branch via Rojo.** Pass = all four steps log the expected
output without errors.

#### Pre-flight

1. `aftman install && wally install` from the project root (first time
   only; or after `wally.toml` changed).
2. `rojo serve` in a terminal.
3. Open a fresh Roblox Studio place. Click the Rojo plugin → **Connect**.
4. **Game Settings → Security → Enable Studio Access to API Services** (so
   ProfileStore can use the live DataStore for the round-trip test;
   ProfileStore's `Mock` is also auto-engaged in Studio per
   `DataManager` line 41 — either path is fine for A audit).

#### Step 1 — Place loads, no errors

Press F5 (Play). In **View → Output**, expect the following lines, in
roughly this order, with no red error lines anywhere:

```
[Outpost-7] Server bootstrap complete. store=PlayerData_v1, bindToCloseTimeout=25s
[DataManager] Loaded <YourName> — session #1, credits=0, firstJoinAt=<unix-ts>
[Outpost-7] Client bootstrap complete. tickRate=1s, gridSize=4, defaultRateLimit=10, defaultMode=Build, defaultBiome=Jungle
```

If the client line is missing, replication is broken. If the
`[DataManager] Loaded` line is missing, persistence is broken. If the
server line is missing, the bootstrap didn't run.

#### Step 2 — Mid-session mutation

In Studio's **Command Bar** (in Server context), run:

```luau
local DataManager = require(game:GetService("ServerScriptService"):WaitForChild("Server"):WaitForChild("Modules"):WaitForChild("Player"):WaitForChild("DataManager"))
local player = game:GetService("Players"):GetPlayers()[1]
local data = DataManager.GetData(player)
data.credits = 12345
print("[Audit] credits set to", data.credits)
```

Expect: `[Audit] credits set to 12345`.

#### Step 3 — Round-trip persistence

Stop play (Shift+F5). Press F5 again. In Output, expect:

```
[DataManager] Loaded <YourName> — session #2, credits=12345, firstJoinAt=<same-unix-ts-as-step-1>
```

`session` should be `#2` (incremented), `credits` should be `12345` (the
mid-session mutation persisted), `firstJoinAt` should match step 1
(sticky). **This is the core A audit gate.**

#### Step 4 — `BindToClose` flush

While playing in Studio, run in the Command Bar (Server context):

```luau
print("[Audit] requesting shutdown...")
game:Shutdown()
```

In Output, expect:

```
[DataManager] Saving <YourName> (sessions=2)
[DataManager] BindToClose: flushing 1 profile(s)
[DataManager] BindToClose: flush complete
```

Press F5 one more time to confirm `session #3` loads with the same
`credits=12345`. Final pass: that load happens cleanly.

#### Multi-client basic check (optional, recommended)

In Studio: **Test → Local Server → 2 clients**. Each client should print
its own `[Outpost-7] Client bootstrap complete` line; server should
print one `[DataManager] Loaded` per player. Stopping the test should
surface `[DataManager] BindToClose: flushing 2 profile(s)`.

### Architectural decisions made

None. A4 is integration work on top of A1–A3.

### Tech debt logged

- The Studio Command Bar audit (Step 2) is verbose. Once we have a real
  in-game UI in Phase B, the audit will be runnable through gameplay
  (place a building → buy something → leave → rejoin). Until then, the
  Command Bar recipe is the canonical Phase A audit.
- No `tests/integration/datastore_roundtrip.spec.luau` yet — TestEZ is
  not wired (no `[dev-dependencies]` in `wally.toml`). Add when we wire
  TestEZ; for now the manual audit recipe is sufficient.

### Phase A status

**Sandbox-side: complete.** All four sub-phases shipped, committed, and
pushed. CI on the PR will run Selene + StyLua + `rojo build`.

**Studio audit: pending the user's run** of the four-step recipe above.
On audit pass, Phase A is closed. On audit fail, log findings here under
"Audit failures" and we triage per `10_BUILD_PROTOCOL.md`'s
three-attempts-then-escalate rule.

### What's next

Phase B kickoff. The hybrid extractor system + currency tick + persistent
base state + build-mode UI + camera transition. I'll do the Phase B
research pass before the sub-phase plan (per build protocol — phase-level
research, not sub-phase).
