# DECISIONS.md — Architectural Decision Records

> Append-only log of significant architectural choices. Each entry is short
> (status, context, decision, alternatives, consequences). Add a row when a
> non-trivial trade-off is made; never edit a closed entry — supersede it.

---

## ADR-001: Hand-rolled DataStore wrapper, not ProfileService

- **Date:** 2026-05-04 (Phase A1)
- **Status:** ⛔ **Superseded by ADR-003** (2026-05-04, Phase A2 research pass).
- **Context:** V1 needs durable per-player saves. ProfileService was the
  community standard at the time of ADR; a hand-rolled wrapper looked
  appealing for control + learning value.
- **Decision (now superseded):** Implement a thin ProfileService-style
  wrapper inside `src/server/Modules/Player/DataManager.luau`.
- **Why superseded:** Phase A2 research surfaced that **ProfileService is
  no longer maintained**, and its successor **ProfileStore** (same author)
  is the recommended modern path with materially better cross-server
  conflict handling via `MessagingService`. The "hand-rolled for control"
  rationale weakens once you realize the thing being rolled is
  ProfileStore's session-lock dance, badly. See ADR-003.

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

---

## ADR-003: Adopt ProfileStore (Wally) as DataStore wrapper

- **Date:** 2026-05-04 (Phase A2)
- **Status:** Accepted. Supersedes ADR-001.
- **Context:** Phase A2 pre-coding research surfaced two facts that
  changed the calculus from ADR-001:
  1. **ProfileService is no longer supported** — the project's own README
     directs new users to ProfileStore.
  2. **2026 per-Experience DataStore limits** are rolling out; ProfileStore's
     5-minute auto-save default produces ~10× fewer DataStore calls than
     ProfileService's 30s default, which buys real headroom under the new
     quota model.
- **Decision:** Add `lm-loleris/profilestore@1.0.3` to
  `wally.toml [server-dependencies]`. Wrap it in a thin `DataManager.luau`
  façade that exposes `Init / LoadPlayer / SavePlayer / GetData /
  WaitForData` to the rest of the codebase.
- **Alternatives considered:**
  - **Hand-rolled wrapper (ADR-001)** — full control, but we'd be
    re-implementing ProfileStore's MessagingService-based session-lock
    conflict resolution. High risk of subtle dataloss bugs. Rejected.
  - **Hand-rolled with ProfileStore as fallback** — worst of both worlds
    for a solo dev. Rejected.
- **Consequences:**
  - One external dependency on a community-maintained library. We own
    `ProfileSchema.luau` and `tools/migrations/`, so swapping out
    ProfileStore later (if it falls out of maintenance) is a façade-only
    rewrite.
  - The `DataManager` public API stays narrow on purpose. Other modules
    never call ProfileStore directly — they go through the façade. Keeps
    the swap path open.
  - Schema additions stay free (ProfileStore `:Reconcile()` merges
    template defaults). Renames/removals still require versioned
    migrations and human approval per build protocol.
