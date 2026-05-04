<!-- One sub-phase per PR. Tag the title `[A2] DataManager: ...` -->

## Phase

- **Phase / sub-phase:** <!-- e.g. A2 -->
- **Linked issue / brainstorm reference:** <!-- e.g. closes #12, finalized-brainstorm.md §2.8 -->

## Summary

<!-- 1–3 bullets. What changed and why. -->
-
-

## Audit checklist (per `docs/10_BUILD_PROTOCOL.md`)

- [ ] **Functional** — happy path tested in Studio with `rojo serve`
- [ ] **Persistence** — DataStore round-trip verified (save → leave → rejoin → load)
- [ ] **Multi-client** — tested with ≥2 Studio clients (Test → Start → 2 players)
- [ ] **Hostile** — Remote inputs spammed / out-of-range / wrong type → server rejects
- [ ] **Performance** — no `Instance.new` in hot loops; pooled where bulk-spawned
- [ ] **`--!strict`** at top of every new module
- [ ] **Types** on every public function signature
- [ ] **No magic numbers** — all tunables in `src/shared/Constants.luau` or `config/`
- [ ] **Selene + StyLua** clean (`./tools/scripts/lint.sh && ./tools/scripts/format.sh`)
- [ ] **Tests added / updated** in `tests/`
- [ ] **Architecture doc updated** if a new Remote, DataStore key, or schema field landed (`docs/architecture/`)
- [ ] **Phase worklog updated** in `docs/phases/PHASE_*.md`

## Out of scope (explicit non-goals)

<!-- Anything you considered but deferred. Helps reviewer not nitpick. -->
-

## Test plan

<!-- Steps the reviewer (or future-you) can run to verify -->
1.
2.
3.

## Risk / known issues

<!-- Anything brittle, anything to monitor post-merge. -->
-
