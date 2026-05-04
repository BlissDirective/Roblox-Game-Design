# DATA_SCHEMA.md

> Versioned `PlayerData` schema and migration log. Source of truth for what's
> persisted per player. Read before touching `DataManager` or `ProfileSchema`.

**Status:** Stub. Populated by Phase A2.

---

## Current schema version

`v1.0` — TBD when Phase A2 lands. Saved blob shape:

```luau
{
    _version = 1,
    -- fields land here as systems require persistence
}
```

## Migration log

| From | To | Reason | Migrator | Audited |
|---|---|---|---|---|
| (none yet) | | | | |

---

## Field add/remove protocol

- **Adding a field:** safe. Default it in `ProfileSchema.luau`, no migration
  needed. Old saves auto-fill on next `LoadPlayer`.
- **Removing a field:** soft-deprecate first (stop writing, leave reads
  ignoring). Hard-remove in a versioned migration.
- **Renaming a field:** never rename in place. Add new, dual-write for one
  release, migrate old saves, drop old in next release.

Per `10_BUILD_PROTOCOL.md`: any rename/remove after Phase A escalates to
human approval before merging.
