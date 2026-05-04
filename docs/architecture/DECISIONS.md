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

---

## ADR-004: Defer Server Authority Beta to V1.5/V2

- **Date:** 2026-05-04 (Phase B kickoff)
- **Status:** ⛔ **Superseded by ADR-005** (2026-05-04, same day, before
  any code that depended on this decision was written). Reasoning
  preserved below for the trail.
- **Context:** Roblox shipped a Server-Authority + Latency-Compensation
  Studio Beta in 2026 (`AuthorityMode = Server`,
  `NextGenerationReplication`, `UseFixedSimulation`,
  `Deferred SignalBehavior`, `PlayerScriptsUseInput`). Adopting it
  would replace our manual server-authoritative pattern with engine-level
  enforcement plus built-in lag compensation.
- **Decision:** **Do not adopt for V1.** Continue with the manual
  server-authoritative pattern from `06_LUAU_REFERENCE.md`
  (client requests via Remote → `AntiExploit.RateCheck` →
  `RemoteValidator` → server mutation). Revisit at V1.5/V2 once the
  Beta graduates **and** V1 launch data shows raid hit-reg or
  movement-cheat is a player-facing problem.
- **Why:**
  - Benefit is concentrated in Phase E (raid hit-reg) and F (anti-exploit)
    — but the opt-in requires foundational changes at A/B that we'd
    carry for 14–18 weeks of Beta-API churn risk.
  - Studio Team's "APIs finalized and not set to change significantly"
    leaves non-zero churn risk, and a Beta can be platform-disabled
    with little notice.
  - Documentation is thin; community examples sparse. Stalls in Phase E
    (already the highest-risk phase per `finalized-brainstorm.md` §3.4
    risk #1) compound.
  - Top 2026 tycoons (Steal a Brainrot, Grow a Garden, etc.) ship on
    the manual pattern without competitive issues. Outpost-7 is
    tycoon-with-raids, not shooter-with-tycoon — the 5-min raid is the
    only window where Server Authority would help.
- **Alternatives considered:**
  - **Adopt for V1** — rejected (above).
  - **Adopt only for the raid-reserved-server place** — would let us
    isolate Beta exposure to Phase E. Rejected because: two
    architectures to maintain, Beta-risk in our highest-risk phase,
    and the migration in V1.5 (if needed) is no harder than
    starting from manual now.
- **Consequences:**
  - We hand-roll any latency compensation needed in Phase E. For V1,
    we accept some hit-reg slop (5-min matches, low stakes per match,
    not a competitive shooter).
  - Anti-exploit (Phase F1) stays on `AntiExploit.RateCheck` +
    `RemoteValidator`.
  - V1.5/V2 migration to Server Authority is a façade-protected swap
    in the same spirit as ADR-003 (DataManager). Trust boundary already
    routes through one validator chokepoint (`Security.RemoteValidator`,
    Phase F2), so the migration surface is finite.

---

## ADR-005: Adopt Server Authority Beta for V1

- **Date:** 2026-05-04 (Phase B kickoff). Supersedes ADR-004 same day,
  before code that locked us out had landed.
- **Status:** Accepted.
- **Context:** The user pushed back on ADR-004 with: *"You said the
  opt-in needs to happen at the foundation layer (Phases A/B) so the
  architecture matches end-to-end. Let's add it to V1. We can adjust
  later if needed."* That reframe converts the "carry Beta-API risk
  for 14–18 weeks" cost into the cost of *not* paying a V1.5/V2
  retrofit, which is larger.
- **Decision:** Enable Server Authority Beta in V1. Set the
  Beta-required `Workspace` properties via `default.project.json`:
  `NextGenerationReplication = true`, `UseFixedSimulation = true`,
  `StreamingEnabled = true`, `PlayerScriptsUseInput = true`,
  `SignalBehavior = Deferred`, `AuthorityMode = Server`.
  Each contributor enables **Beta Features → Server Authority Core
  API** in their Studio install (recipe in
  `docs/playbooks/DAILY_DEV_LOOP.md`).
- **Why the reframe holds up:**
  - **Reversibility is real.** Rolling back is a `git revert` of the
    project-file changes — no code in B1 depends on the auth model.
    The cost asymmetry is *adopting now and rolling back* < *not
    adopting and retrofitting later*.
  - **Carry cost is concentrated, not spread.** Most of Phase A–D
    (persistence, build mode, currency, monetization) doesn't interact
    with the humanoid auth model. The places that do are B5 (camera
    transitions need to respect `PlayerScriptsUseInput`), E1 (raid
    hit-reg benefits), E2 (PvE wave hit-reg benefits), and F1
    (anti-exploit leans on engine-level auth).
  - **The Beta is opt-in, not experimental.** Studio Team's "APIs
    finalized and not set to change significantly before final release"
    is a real-but-bounded risk. Worst case: a breaking API change forces
    a 1–2-day fix during Phase E.
- **Risks accepted:**
  1. **Beta API churn before launch.** Mitigation: pin API surface use
     behind helpers in `Security/TrustBoundary.luau` so a breaking
     change is one file to update.
  2. **Platform-side disable.** Roblox could disable the Beta with little
     notice. Mitigation: keep the manual server-authoritative pattern
     intact in `06_LUAU_REFERENCE.md` as a documented fallback. If the
     Beta gets pulled, we revert the project-file changes and the manual
     pattern still works.
  3. **Documentation thinness.** Mitigation: log every Beta-API
     workaround we discover in `docs/architecture/DECISIONS.md` (or a
     dedicated `SERVER_AUTHORITY_NOTES.md` if it grows past 5 entries).
  4. **Studio version skew.** Each contributor must enable the Beta
     locally. Documented in `DAILY_DEV_LOOP.md`. CI runners build via
     Rojo only — no Studio dependency — so CI is unaffected.
- **Alternatives reconsidered:**
  - **Stay on ADR-004 (defer)** — the 14–18-week carry cost the user
    surfaced makes this strictly worse than adopting now with
    reversibility intact.
  - **Adopt only for raid place** — would isolate Beta exposure but
    creates two architectures. The user's "match end-to-end" framing
    rejects this implicitly.
- **Consequences:**
  - `default.project.json` carries the Beta Workspace property block.
  - First commit using these properties (B1) lands the project-file
    change. CI's `rojo build` will validate the property names match
    Roblox's current schema; if they fail, the property names have
    drifted and we update.
  - All contributors must enable **Beta Features → Server Authority
    Core API** in Studio. Recipe in `docs/playbooks/DAILY_DEV_LOOP.md`.
  - Phase E1 (raid hit-reg) and F1 (anti-exploit) plans simplify —
    we lean on engine-level lag compensation instead of hand-rolling.
  - If Roblox disables the Beta, revert this ADR + the project-file
    changes; the manual pattern in `06_LUAU_REFERENCE.md` is still
    correct.

---

## ADR-006: Local ownership cache; trust `PromptGamePassPurchaseFinished` over re-querying `UserOwnsGamePassAsync`

- **Date:** 2026-05-04 (Phase D1)
- **Status:** Accepted.
- **Context:** Roblox `MarketplaceService:UserOwnsGamePassAsync` caches
  ownership results internally and **does not refresh after a
  mid-session purchase**. A long-standing issue (still open as of
  Dec 2025 per DevForum) where after `PromptGamePassPurchase` returns
  `wasPurchased = true`, calling `UserOwnsGamePassAsync` for the same
  pass continues to return `false` until the player rejoins. We need
  pass effects (2× Credits, Auto-Collect, VIP) to apply mid-session
  immediately on purchase — players who paid 200+ Robux expect
  instant effect.
- **Decision:**
  1. `GamePassService` maintains its own per-session ownership map:
     `ownership[playerUserId][passId] = bool`.
  2. On player join: call `UserOwnsGamePassAsync` once per pass, cache
     the result. (This is the only time we trust the API.)
  3. Listen to `MarketplaceService.PromptGamePassPurchaseFinished`.
     When `wasPurchased == true`, **set the cache to true directly**
     without re-querying — the purchase prompt's positive return is
     authoritative for the current session.
  4. All pass-effect application (`PassEffects.ApplyAll`) reads from
     our local cache, not from `UserOwnsGamePassAsync`.
- **Why:**
  - Forum-confirmed bug. Workaround is community-standard.
  - Trust boundary intact: a cheating client can't fake
    `wasPurchased = true` because the event fires from
    `MarketplaceService` server-side, not from a client Remote.
  - Stale-cache risk on the OTHER direction (player owns the pass
    from a prior session but we incorrectly cache "not owned") is
    mitigated by always re-querying on fresh join. A player who
    rejoins a server gets fresh ownership data.
- **Alternatives considered:**
  - **Trust `UserOwnsGamePassAsync` only** — would force the player
    to rejoin to see effects of a mid-session purchase. Bad UX,
    rejected.
  - **Persist ownership in `profile.Data`** — would add a sync layer
    between Roblox's source of truth and ours. Rejected; ownership
    lives in Roblox.
- **Consequences:**
  - One canonical chokepoint for "does player X own pass Y" —
    `GamePassService.Owns(player, passId)`. Phase D3+ reads only
    from this.
  - If Roblox eventually fixes the cache bug (unlikely soon), this
    ADR can be revisited and the local cache removed; `Owns` becomes
    a thin wrapper over `UserOwnsGamePassAsync`.
