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

## A2 — DataManager + DataStore wrapper ⏳

_Pending._

## A3 — Shared scaffolds (Remotes, Constants, Types, Enums) ⏳

_Pending._

## A4 — Bootstrap wiring + Phase A audit ⏳

_Pending._
