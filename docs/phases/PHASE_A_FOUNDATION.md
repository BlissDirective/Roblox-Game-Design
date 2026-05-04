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

## A3 — Shared scaffolds (Remotes, Constants, Types, Enums) ⏳

_Pending._

## A4 — Bootstrap wiring + Phase A audit ⏳

_Pending._
