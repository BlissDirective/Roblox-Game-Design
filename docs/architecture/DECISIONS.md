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

---

## ADR-007: Single-PlaceId reserved-instance raid architecture for V1

- **Date:** 2026-05-05 (Phase E1)
- **Status:** ⛔ **Superseded by ADR-009** (2026-05-05, same day, before any code that depended on the single-PlaceId pattern beyond a single config field had landed). Reasoning preserved below.
- **Context:** Brainstorm §4.6 calls for a "separate place" for raids
  to keep the defender's live server untouched. Two readings:
  1. **True split** — a second PlaceId in the same Universe, with its
     own `.rbxl` artifact and CI release pipeline.
  2. **Reserved-instance same-place** — `ReserveServerAsync(currentPlaceId)`
     returns a private instance of the same place; bootstrap branches on
     `game.PrivateServerId ~= ""` to enter raid mode.
  Both honor the "isolation invariant" — the defender's home server is
  always a different `ServerInstance` than the raid server.
- **Decision:** **V1 ships single-PlaceId reserved-instance pattern.**
  `default.project.json` builds one `.rbxl`. `src/server/init.server.luau`
  branches on `PrivateServerId`: empty → main bootstrap, non-empty → raid
  bootstrap (DataManager + ServerAuthorityBootstrap + RaidSession only).
- **Why over true split:**
  1. **Single CI pipeline.** `release.yml` already publishes one `.rbxl`
     to one PlaceId; doubling that requires parallel pipelines + a
     second `ROBLOX_API_KEY` scope.
  2. **CSG / EditableMesh / EditableImage assets only authored once.**
     Per `finalized-brainstorm.md` §4.1, these can't publish via Open
     Cloud and must be authored in Studio. With two PlaceIds, every
     such asset would need authoring twice.
  3. **Operational complexity vs. payoff.** True split's only benefit
     over reserved-instance is the *option* to specialize the raid
     `.rbxl` (exclude unused modules, smaller download). For V1, the
     download size delta is negligible (~93KB total today).
- **Alternatives considered:**
  - **True two-PlaceId split** — operational cost without compensating
    benefit at V1 scale. Deferred to V1.5+ if specialization justifies it.
  - **Always run main + raid stack in same bootstrap** — ambiguous trust
    boundary; raid place would also have CurrencyService.tickLoop running
    against snapshots, which makes no sense.
- **Consequences:**
  - `Constants.RAID.RaidPlaceId` placeholder = 0 in V1 dev. Phase H sets
    it to the *same* PlaceId as the main place (single-PlaceId reserved-
    instance pattern).
  - V1.1+ split: change `RaidPlaceId` to a separate id in the same
    Universe; `default.project.json` stays as the main; add a thin
    `raid.project.json` that only maps the modules the raid bootstrap
    needs. Code branching on `PrivateServerId` is unchanged.
  - The brainstorm's "separate place" wording reads as the logical
    isolation, not the build-artifact split. This ADR honors the
    invariant cheaply.

---

## ADR-008: Raid server never writes the defender's profile

- **Date:** 2026-05-05 (Phase E1)
- **Status:** Accepted.
- **Context:** A raid round resolves with credit transfers between
  attacker and defender. The simplest implementation has the raid
  server (which holds the attacker) directly write the defender's
  profile via `DataStoreService:UpdateAsync` for the credit delta.
  But the defender's home server *also* holds an active session lock
  on that profile via ProfileStore — concurrent writes from two
  servers either trigger session-lock conflicts or (worse) silently
  overwrite each other.
- **Decision:** **The raid server is never an authoritative writer of
  the defender's profile.** All defender-side state changes — credit
  delta, raid stat counters, future "Your colony was raided"
  acknowledgments — flow through MessagingService topic
  `outpost.raid.outcome`. Each main server subscribes; the one that
  holds the defender's `Player` object applies the writes via
  `CurrencyService.Add` and direct `data.raidsDefended` mutation.
- **Why this is the long-term-correct architecture:**
  1. **Single-writer-per-profile invariant maintained.** ProfileStore's
     session-lock model assumes one writer; this preserves it.
  2. **Trust boundary trivially auditable.** Searching the codebase
     for "writes to defender's profile" yields exactly one hit:
     `RaidRewardService.applyDefenderSide`, running on the home server.
     A raid-server-owned write would be invisible across multiple modules.
  3. **Linear scalability.** N raid servers + M home servers — each
     pair operates independently. No DataStore contention.
- **Risks accepted:**
  - **Defender goes offline mid-raid.** No home server holds the
    defender; the outcome MessagingService payload is consumed by no
    listener. The defender-side reward is lost. **Acceptable for V1**
    (per RAID_PROTOCOL.md "Failure modes & recovery"). V1.5+ adds a
    `PendingRaidRewards` DataStore — a separate keyspace from
    `PlayerData_v1`, written only by the raid server, read + cleared
    by the defender's home server on next join. This avoids the
    concurrent-write problem because the home server is always the
    sole reader of pending rewards.
- **Alternatives considered:**
  - **Raid server writes defender directly** — violates ProfileStore
    invariant. Rejected.
  - **Always teleport the defender into the raid place** — turns
    asynchronous PvP into synchronous; defeats the brainstorm §2.6
    "asynchronous PvP via match-based raids" decision. Rejected.
  - **Defender's home polls for outcomes via MemoryStore** — adds a
    polling loop on every home server; less efficient than
    MessagingService's push. Rejected.
- **Consequences:**
  - The outcome payload is small (one table per raid, ≤ 7 fields).
    MessagingService quota at universe scale is comfortable.
  - Idempotency is owned by the home: per-server in-memory dedupe set
    on `(attackerUserId, defenderUserId, endedAt)` with a 10-min TTL.
    Bounded; pruned every 5 minutes.
  - Future cross-server features (clan stash transfers in E3, gift
    sending in V1.5) can reuse this MessagingService relay pattern.

---

## ADR-009: True two-PlaceId raid split for V1

- **Date:** 2026-05-05 (Phase E1, same-day supersession of ADR-007)
- **Status:** Accepted. Supersedes ADR-007.
- **Context:** ADR-007 chose the single-PlaceId reserved-instance pattern
  for V1 on the basis of operational simplicity (one CI pipeline, one
  PlaceId, one CSG/EditableMesh authoring pass). User pushed back with
  the same reframe that converted ADR-004 → ADR-005 in Phase B: *"I want
  to be as best prepared for long-term success from the start."* The
  single-PlaceId pattern is reversible; the V1.5 split would require a
  config change *plus* a re-publish of every CSG/EditableMesh asset to
  a new place — twice as much work as just doing the split now while no
  such assets exist yet.
- **Decision:** **V1 ships true two-PlaceId split.** Two Rojo project
  files, two `.rbxl` artifacts, two PlaceIds in the same Universe.
  - `default.project.json` → `Game.rbxl` → main PlaceId.
  - `raid.project.json` → `Raid.rbxl` → raid PlaceId.
  Both project files map the same `src/`, but the raid project sets
  smaller streaming radii (the raid plot is a fixed 64×64-stud square,
  no need for the 256/512 main-world streaming targets). Future Phase G
  can specialize raid-only Workspace properties (lighting, fog,
  ambient) without touching main.
  Bootstrap branching on `game.PrivateServerId` is unchanged from
  ADR-007 — same code, two PlaceIds. The branching now correctly
  matches the deployment topology: main place servers are public
  (`PrivateServerId == ""`), raid place servers are reserved
  (`PrivateServerId ~= ""`).
- **Why over ADR-007:**
  - **CSG / EditableMesh authoring cost is zero today, infinite later.**
    Outpost-7 currently has no such assets. Splitting now means the
    future raid-place CSG geometry is authored once into the raid
    PlaceId. Splitting at V1.5 (after a season of raid CSG has shipped
    to the single PlaceId) means re-authoring every asset.
  - **CI complexity is low.** `release.yml` adds a parallel build +
    publish step for the raid place; the steps already exist for main
    and just need duplication with raid-scoped vars/secrets.
  - **Workspace specialization unlocked.** Raid-only lighting, fog, and
    StreamingEnabled radii live in `raid.project.json`. Main-only
    config (day/night cycle, biome ambient, retention popups that
    shouldn't replicate to raid clients) lives in
    `default.project.json`. The place files own their place-shaped
    concerns.
  - **Asset isolation.** Raid-only `assets/world/raid_arena/` won't
    bloat the main `.rbxl`; main-only `assets/world/biome_jungle/`
    won't bloat the raid `.rbxl`. V1 size delta is small but compounds
    as Phase G assets land.
- **Risks accepted:**
  1. **Two CI pipelines to maintain.** Mitigation: single `release.yml`
     with two parallel build/publish steps (DRY via shared setup
     steps); a `workflow_dispatch` input lets a contributor target one
     place at a time if needed.
  2. **Two PlaceIds to provision in Phase H.** Mitigation: Open Cloud
     `place:create` (or manual dashboard creation) for the raid place
     when `Constants.RAID.RaidPlaceId` is replaced. Documented in
     `docs/playbooks/PUBLISHING.md`.
  3. **API key scope.** Mitigation: a single key scoped to both
     places in the same Universe is sufficient — Open Cloud key
     permissions are universe-level for the relevant grants.
  4. **Code drift between project files.** Mitigation: both
     `.project.json` files map the same `src/` paths; the only
     legitimate divergence is `$properties` on Workspace and a few
     other top-level services. PR review catches drift.
- **Alternatives considered:**
  - **Stay on ADR-007 (single PlaceId)** — strictly worse for V1.5+
    asset migration.
  - **Two project files, single PlaceId** — defeats the purpose; you
    build two `.rbxl` files but publish only one. Rejected.
  - **Single project file, runtime PlaceId switch** — impossible; Rojo
    builds one tree per project file, and each tree gets one PlaceId
    at upload.
- **Consequences:**
  - `Constants.RAID` gains `MainPlaceId` (new) alongside `RaidPlaceId`.
    `RaidSession.teleportAttackerHome` reads `MainPlaceId` to know
    where to send the attacker after the round. Both are 0
    placeholders until Phase H.
  - `default.project.json` unchanged. New `raid.project.json` lives
    at repo root, mirroring the main project shape with raid-tuned
    Workspace properties (smaller streaming radii — Phase G adds
    lighting + ambient differentiators).
  - `.github/workflows/ci.yml` builds *both* `.rbxl` files and uploads
    them as separate artifacts — catches `raid.project.json` schema
    drift on every PR.
  - `.github/workflows/release.yml` extends to publish both places in
    parallel jobs. Required new GitHub var: `RAID_PLACE_ID`. The
    single `ROBLOX_API_KEY` (universe-scoped) covers both publishes.
  - `docs/playbooks/PUBLISHING.md` updated for the two-place flow,
    including the §3 CSG inventory table gaining a "place" column.
  - First commit of any raid-only CSG/EditableMesh/EditableImage
    asset goes to the raid place via Studio publish — never the main
    `.rbxl`.

---

## ADR-010: One OrderedDataStore per ISO-week bucket for weekly leaderboards

- **Date:** 2026-05-05 (Phase E5)
- **Status:** Accepted.
- **Context:** Brainstorm §2.6 calls for a "weekly raid wins" leaderboard
  alongside the lifetime "global Credits" board. Two implementation
  shapes were considered:
  1. **Single perpetual `WeeklyRaidWins` OrderedDataStore + per-week
     reset.** Every Monday 00:00 UTC, sweep all entries and reset
     scores to 0 (or delete + recreate the store). Simple to read,
     painful to reset (OrderedDataStore has no bulk-delete API; you'd
     iterate every entry and SetAsync to nil, hitting throttle limits
     for any sizeable game).
  2. **One OrderedDataStore per ISO-week bucket.** Store name is
     `Outpost_RaidWins_v1_<isoYear>W<isoWeek>` (e.g.
     `Outpost_RaidWins_v1_2026W18`). The "current week" is whichever
     bucket is active right now; reads address that bucket. Old
     buckets stay read-only and addressable for "last week's
     winners" displays. No reset; the boundary is a server-time
     compute, not a DataStore mutation.
- **Decision:** **One OrderedDataStore per ISO-week bucket.** ISO 8601
  week is computed server-side from `os.time()` via the standard
  Thursday-of-the-week algorithm (week 1 = the week containing the
  first Thursday of the calendar year). The bucket key is computed
  on every score write + every read, so the rollover happens
  implicitly at 00:00 UTC Monday with zero special-case code.
- **Why:**
  - **No reset operation needed.** The "weekly reset" is a property of
    which bucket the server is reading/writing — it's just a key
    change, not a state mutation. This is the canonical pattern in
    the Roblox community 2024+; the alternative (sweep + reset) is
    too expensive at scale.
  - **History preserved for free.** "Last week's top 10" is a `GetSortedAsync`
    against `Outpost_RaidWins_v1_2026W17` while we write to W18. UI
    surfaces this when desired (Phase G); no migration required.
  - **Storage cost is bounded.** Each bucket stores up to MaxEntries
    rows (~100K active players in extreme case); old buckets are
    never deleted but consume sub-MB per week. 52 weeks/year × <1MB
    = <50MB/year storage cost — well within DataStore quota.
- **Risks accepted:**
  1. **Bucket key drift across servers.** If two servers compute ISO
     week differently (timezone bug, system clock drift), they could
     write to different bucket keys for the "same" week. Mitigation:
     `os.time()` is UTC-canonical on Roblox; the server clock is
     authoritative; the ISO-week algorithm is deterministic.
  2. **Discoverability of old buckets.** Reading "last week's winners"
     requires the client (or server) to know the previous bucket key.
     Mitigation: server computes both current + previous bucket keys
     on the same code path; client never needs to guess.
- **Alternatives considered:**
  - **Per-week sweep + reset** (option 1) — operational nightmare at
    scale; rejected.
  - **MemoryStoreService SortedMap with 30-day expiration** — would
    auto-expire old data but caps weekly history at one week.
    Rejected: MemoryStoreService doesn't persist beyond 30 days, so
    week-over-week comparisons are impossible.
  - **External database (Firebase, Supabase via HttpService)** —
    overkill for V1; introduces another platform dependency. Rejected.
- **Consequences:**
  - `Constants.LEADERBOARD` adds `WeeklyRaidWinsStorePrefix =
    "Outpost_RaidWins_v1"`. The full store name is computed by
    appending `_<isoYear>W<isoWeek>` at write/read time.
  - `LeaderboardService.weeklyStoreName(t)` is the canonical computation;
    other modules never derive bucket keys themselves.
  - Phase G's "Last week's top 10" UI reads
    `LeaderboardService.GetPreviousWeekBoard()` (to be added when the
    UI ships).
  - Schema migration if needed (e.g., switching to monthly buckets in
    V2): bump `WeeklyRaidWinsStorePrefix` to `_v2`, leave `_v1`
    historical buckets read-only-archive. No data loss.

---

## ADR-011: Shared raid-place reserved-instance dispatch (no separate Expedition / BossArena PlaceIds)

- **Date:** 2026-05-05 (Phase F0 — pre-Phase-F foundational decision)
- **Status:** Accepted.
- **Context:** Two V1.5/V2 expansions need reserved-server-instance
  architecture similar to E1's raid system:
  1. **Expedition pockets** (V1.5 — `V1_5_SCOUTING_EXPEDITIONS.md`) —
     procedural 200×200 stud pockets per mission; player teleports via
     `ReserveServerAsync` + teleport data; round duration 3–15 min.
  2. **Boss arenas** (V2 — `V2_LIVING_JUNGLE.md`) — 4-player co-op
     dedicated arenas; same `ReserveServerAsync` + teleport data; round
     up to 30 min.
  Both follow the exact same architectural shape as raid:
  reserved-server-with-teleport-data + bootstrap-branches-on-context.
  Question: do these get their own PlaceIds (4 total: main + raid +
  expedition + boss), or do they share the raid PlaceId with bootstrap
  dispatch on teleport-data type (still 2 PlaceIds)?
- **Decision:** **Shared raid-place reserved-instance dispatch.** The
  raid place's bootstrap (`src/server/init.server.luau` raid branch)
  extends to dispatch further on `joinData.placeMode` carried in
  teleport data:
  - `placeMode = "raid"` → existing `RaidSession.Init()` flow
  - `placeMode = "expedition"` → V1.5 `PocketSession.Init()` flow
  - `placeMode = "boss"` → V2 `BossArenaSession.Init()` flow
  Same `.rbxl`, same PlaceId, same Roblox dashboard place entry. The
  reserved instance's behavior depends on the teleport data, not on
  the place identity.
- **Why over per-feature PlaceIds:**
  1. **Operational simplicity.** 2 PlaceIds instead of 4 means one
     CI publish per place, one Open Cloud upload per release, half
     the dashboard provisioning at Phase H, half the moderation
     surface area.
  2. **CSG / EditableMesh consolidation.** Per `PUBLISHING.md` §3,
     these asset types must be authored manually per-PlaceId. With
     shared reserved-instance: any raid/expedition/boss CSG asset is
     authored once into the raid place. With 4 PlaceIds: the asset
     pipeline 4× the manual work.
  3. **Already-proven pattern.** `init.server.luau` already branches
     on `game.PrivateServerId` per ADR-009. Adding a sub-branch on
     `joinData.placeMode` is the same architectural shape, one level
     deeper.
  4. **Easy to split later.** If V2 boss arenas grow specialization
     needs (different lighting, different streaming radii, different
     audio profile), promote one mode to its own PlaceId as a
     surgical change: split `raid.project.json` per-mode + add a new
     PlaceId. The dispatch code stays; only the place mapping moves.
- **Risks accepted:**
  1. **Boot-time bloat.** All raid/expedition/boss server modules
     load into the raid place's `ServerScriptService` even when only
     one mode runs. **Mitigation:** server modules require lazily
     (only the dispatched mode's modules `require()` on boot); other
     modules' source sits dormant in the .rbxl tree. Roblox lazy-
     loads ModuleScripts on first require; runtime memory cost is
     ~zero for unused modules.
  2. **Streaming radius compromise.** Raid place currently uses
     128/256 (per `raid.project.json`). Expeditions use 200×200
     pockets (fits within 256 streaming target); boss arenas may
     want different radii. **Mitigation:** runtime override via
     `Workspace.StreamingMinRadius = ...` on bootstrap dispatch.
     Values per mode tuned in V1.5 / V2 prep.
  3. **PlaceId teleport routing.** `ReserveServerAsync` returns an
     access code scoped to the source PlaceId. Same PlaceId for
     raid/expedition/boss = same access-code scope. **No issue.**
- **Alternatives considered:**
  - **Separate PlaceIds per mode (4 total).** Strictly worse for V1.5
    operational cost; only justifies if mode specialization becomes
    severe. Defer to that future if/when. Rejected for V1.5/V2
    foundation.
  - **Same place + shared bootstrap (no dispatch on placeMode).**
    Raid + expedition + boss code all run simultaneously in any
    reserved instance — wasteful, possibly conflicting. Rejected.
  - **Single Place reserved-instance pattern (no raid place at all,
    same as ADR-007's superseded approach).** Would dispatch at the
    main-place level on PrivateServerId. Reverts ADR-009; rejected
    on the same long-term-success grounds that drove ADR-009.
- **Consequences:**
  - V1.5 Expedition place teleport carries `joinData.placeMode = "expedition"`
    + procedural seed + pocket type. `ReservedServerLauncher.luau`
    extends to accept a `placeMode` parameter; raid path defaults to
    `"raid"`.
  - V2 BossArena teleport carries `joinData.placeMode = "boss"` +
    boss id + 4-player team list.
  - `src/server/init.server.luau` raid branch extends to a dispatch
    table:
    ```luau
    local mode = (player:GetJoinData() :: any).TeleportData.placeMode or "raid"
    if mode == "raid" then RaidSession.Init()
    elseif mode == "expedition" then PocketSession.Init()
    elseif mode == "boss" then BossArenaSession.Init()
    end
    ```
    (Uses the *first* joining player's teleport data — all four boss
    co-op players carry identical placeMode; dispatch is consistent.)
  - `Constants.RAID.MainPlaceId` and `Constants.RAID.RaidPlaceId`
    remain the only Place ID constants. No new `ExpeditionPlaceId`
    or `BossArenaPlaceId` constants.
  - Phase H provisioning: still 2 PlaceIds in the dashboard.
  - V1.5/V2 documentation cross-references this ADR for the
    place-mode dispatch mechanism.
