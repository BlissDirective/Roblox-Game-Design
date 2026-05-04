# DECISIONS.md — Architectural Decision Records

> Append-only log of significant architectural choices. Each entry is short
> (status, context, decision, alternatives, consequences). Add a row when a
> non-trivial trade-off is made; never edit a closed entry — supersede it.

---

## ADR-001: Hand-rolled DataStore wrapper, not ProfileService

- **Date:** 2026-05-04 (Phase A1)
- **Status:** Accepted
- **Context:** V1 needs durable per-player saves. ProfileService is the
  community standard; a hand-rolled wrapper requires more discipline.
- **Decision:** Implement a thin ProfileService-style wrapper inside
  `src/server/Modules/Player/DataManager.luau` (Phase A2). Use
  `pcall + UpdateAsync + retry-with-backoff + session lock`. Versioned schema
  header from day one.
- **Alternatives considered:**
  - **ProfileService (Wally dep)** — battle-tested but adds an external
    dependency surface and obscures the persistence model from a beginner
    learning Roblox. Rejected for V1; revisit at V2 if the wrapper accrues
    bug debt.
- **Consequences:** We own every line of the persistence path. If
  Roblox changes DataStore semantics, we update one module. If we need a
  ProfileService feature later, we either port it or migrate.

---

## ADR-002: Feature flags > long-lived feature branches for V1.5/V2 work

- **Date:** 2026-05-04 (Phase A1)
- **Status:** Accepted
- **Context:** V1.5 and V2 features (trading, auto-clip, co-op) will land in
  parallel with V1 hotfixes. Long-lived branches drift; rebasing eats hours.
- **Decision:** All V1.5/V2 features land on `main` behind
  `Constants.FEATURES.*` flags. Flip false → true when audit-ready.
- **Alternatives considered:**
  - **`v1.5` long-lived branch** — simpler mental model, but creates merge
    debt. Rejected.
- **Consequences:** Production code carries dead-on-default branches until
  a flag flips. We pay this cost in exchange for never paying merge tax.
