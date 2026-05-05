# tools/migrations/

> One-shot DataStore schema migration runners. Each migration takes a player
> profile from version `N` to version `N+1`.

**Status:** Stub. First migration lands when `DataManager`'s schema crosses
v1.0 → v1.1 (likely Phase B3 or later).

---

## Pattern

A migration is a pure function: `(profile_v_n) -> profile_v_n_plus_1`. It
runs lazily on `LoadPlayer` — never as a batch sweep. The schema header
(`_version`) tells `DataManager` whether a migration is needed; old saves
get migrated on next login and re-saved on `PlayerRemoving`.

```
migrations/
├── _template.luau        ← Copy this to start a new migration
├── v1_to_v2.luau         ← Example: v1.0 → v1.1
└── README.md             ← This file
```

## Authoring a migration

1. Copy `_template.luau` to `vN_to_vM.luau`.
2. Implement the transform. **Do not lose data** — if a field is being
   removed, log it to the audit ledger before dropping.
3. Add a row to `docs/architecture/DATA_SCHEMA.md` migration log.
4. Bump `CURRENT_SCHEMA_VERSION` in `ProfileSchema.luau`.
5. Add a unit test in `tests/unit/server/migrations/`.

Per `10_BUILD_PROTOCOL.md`, schema changes after Phase A escalate to human
approval before merging.
