# REMOTES_REGISTRY.md

> Every `RemoteEvent` and `RemoteFunction` exposed by the server. Each row
> lives in `src/shared/Remotes.luau`; this doc records the **trust model** and
> **rate limit** so the table stays auditable.

**Status:** Stub. Phase A3 sets up the typed registry; subsequent phases append
rows as Remotes are introduced.

---

## Registry

| Remote | Direction | Args (validated server-side) | Rate limit (per player) | Phase introduced | Notes |
|---|---|---|---|---|---|
| _(none yet)_ | | | | | |

---

## Conventions

- Every inbound (Client → Server) Remote passes through
  `Security.AntiExploit:RateCheck` + `Security.RemoteValidator` before any
  game-state mutation.
- Default rate limit: **10 calls/sec/player**. Per-Remote overrides live in
  `Constants.RATE_LIMITS` and are documented in this table.
- Outbound (Server → Client) Remotes are notification-only. Clients never trust
  outbound payloads as sources of truth — they're display hints.
- Adding a Remote: add row here in the same PR that adds the registry entry,
  or CI fails the docs check.
