# 09 — FINALIZED BRAINSTORM: OUTPOST-7

> **Status:** Locked. Concept selection complete. Ready to feed into `10_BUILD_PROTOCOL.md` Phase 3 (build).
>
> **North Star sentence:** *Build, fortify, raid — in a bioluminescent alien jungle.*
>
> **Genre:** Sci-fi colonization tycoon × wave defense × competitive PvP raids
>
> **Last updated:** 2026-05-03

---

## 0. How to read this document

This file is the single source of truth for Outpost-7's V1 design and build plan. It is structured to:

1. Satisfy every required input field listed in `10_BUILD_PROTOCOL.md` so Claude Code can begin Phase A immediately on kickoff.
2. Document the full reasoning trail behind every decision, so future-you (or a collaborator) can see *why* each choice was made — not just what it was.
3. Serve as a comprehensive V1→V2 build playbook with phase budgets, tool recommendations, coding strategy, and launch plan.

If any section conflicts with `01_AGENT.md` or `10_BUILD_PROTOCOL.md`, those files win. This document fills in the *concept-specific* details only.

---

## 1. Decision trail (the answers that produced this doc)

This section records every input that drove the final concept. Preserved verbatim so future-you can see the reasoning.

### Phase 1 — Constraints

| Question | Answer |
|---|---|
| Hours per week available | **10–20 hrs/week** (serious side project) — ~100–240 total hours over 14–18 weeks |
| Original V1 timeline | 6 weeks (later extended to 14–18 weeks; see §3) |
| Budget for V1 | **$300+** (willing to invest in assets, music, marketplace) |
| Audience preference | **No preference** — let the concept decide |
| Aesthetic preference | **Mix of Modern + Horror + Chaotic/Brainrot + Realistic** |
| Cultural moment / trend ride | **No** — build something timeless |

### Phase 2 — Unfair advantages

| Question | Answer |
|---|---|
| Domain expertise / themes | **Tycoon, RPG, Shooter, Sci-Fi, Planetary Colonization, Surviving on New Planet, Building Space Habitats, Surviving/Fighting Alien Attacks, Futuristic** |
| Audiences/communities | **Real-life friend group who games together** (playtest pool) + **active in subreddit communities** (launch reach potential) |
| Stamina check | **B — Mainly the building/tycoon part. Combat is secondary fun.** "Heavily invested in development." |
| Spectacle moment preference | **Combo of A + B** — defense moment ("oh shit" alien wave overwhelms base) + transformation moment (timelapse from rubble to fortress) |

### Phase 3 — Multiplayer & inspiration

| Question | Answer |
|---|---|
| Multiplayer structure | **Competitive** — each player has own colony, leaderboards + PvP raids |
| Sci-fi inspiration | **Hint at recognizable franchises** (Aliens, Helldivers, Starship Troopers vibes) — but build own universe |

### Phase 4 — Concept shortlist & decision

Seven concepts were generated and scored. Top 3 advanced to head-to-head:

- **Outpost-7** (sci-fi colonization tycoon + raid layer) — 8/8 viral, 3/5 build, ⭐⭐⭐⭐⭐ personal fit
- **Steal an Alien** (steal-genre with sci-fi skin) — 8/8 viral, 3/5 build, ⭐⭐⭐⭐ fit
- **Black Site** (asymmetric tycoon-stealth-PvP) — 7/8 viral, 4/5 build, ⭐⭐⭐⭐ fit, most distinctive

| Question | Answer |
|---|---|
| Decision frame | **C — Most personally meaningful > fastest ship.** "Distinctly mine" matters more than speed. |
| Asymmetric role preference | **Defender (the spider).** Building, fortifying, watching alarms trip — that's the fantasy. |

**Outcome:** Decision frame eliminated Steal an Alien (too derivative). Defender preference eliminated Black Site (asymmetric games require both roles to thrill the designer; you only love one). **Outpost-7 won.**

### Phase 5 — V1 mechanics

| Question | Answer |
|---|---|
| Extractor mechanic | **Hybrid** — scout the planet to find resource nodes, then place extractors on them |
| Raid structure | **Match-based** — queue into someone else's colony for a 5-min raid round, then leave |
| Daily-return stack | **Full** — offline progression + restocking shop + daily quests + login bonus |
| Camera/viewpoint | **Mixed** — third-person for build, first-person for combat/raid |
| Combat mode | **Both** — PvE alien waves + queued human raiders, toggleable per session |
| Monetization scope | **Full stack** — 2x Credits, Auto-Collect, VIP passes + battle pass + dev product (Emergency Shield) |

### Phase 6 — Aesthetic identity

| Question | Answer |
|---|---|
| Biome (V1 launches with one) | **Bioluminescent jungle** — dark, alive, glowing flora, hostile wildlife (Avatar/Subnautica vibe) |
| Player tone | **Military operator** — sleek tech, drone swarms, sci-fi clean (Helldivers feel) |
| Audio/music vibe | **Synthwave / electronic / driving** — energetic, action-forward |

### Phase 7 — Scope, success, & launch

| Question | Answer |
|---|---|
| Scope reality response | **B — Extend timeline to 14–18 weeks**, keep full vision |
| Deferred to V1.5+ | **Trading marketplace** only |
| In V1 (kept despite scope cost) | Voice chat (Spatial Voice for raids), clans/friends system, **multiple biomes at launch** |
| Empty raid queue handling | **NPC alien wave fallback** (also doubles as the PvE wave system) |
| North Star sentence | **A — *"Build, fortify, raid — in a bioluminescent alien jungle."*** |
| Success target (90 days) | **B — 500 CCU + $2K/mo by month 2** (real success — requires viral hit) |
| Launch strategy | **Friends first → social media (TikTok, X, subreddits)** |
| Pre-launch testing | **No staged rollout** — full launch when V1 is ready ⚠️ flagged as highest-risk decision; see §10 |
| Doc scope requested | **Full V1→V2 build playbook** with tools, coding strategy, deployment, marketing |

---

## 2. The locked concept — Outpost-7

### 2.1 The 60-second pitch

You're a corporate military operator dropped onto **OP-7**, a hostile bioluminescent jungle planet teeming with predatory wildlife and rival corporate operators. Your job: scout the terrain, claim alien resource nodes, build extractors that auto-generate Credits, and fortify your perimeter against escalating threats.

By day, you scout deeper into the jungle — finding rarer nodes, exotic specimens, and abandoned tech caches. By night, the jungle moves. Aggressive alien fauna swarm your perimeter. Your turrets, walls, and drone swarm hold the line — or don't.

When you want action, queue into a **raid round** — a 5-minute match where you infiltrate another player's colony to steal Credits and rare materials. Your colony is simultaneously raidable. Successful defenders earn defense rewards. Successful raiders earn ranking.

Every session ends with your colony bigger than it started. That's the loop.

### 2.2 The one-sentence core loop

> *Scout the jungle for resource nodes → place extractors on them → reinvest Credits into walls, turrets, and drone swarm upgrades → defend against PvE waves OR queue into PvP raid rounds → return to a bigger colony tomorrow.*

### 2.3 Genre + retention-genre blend

- **Primary genre:** Tycoon (Roblox's most monetizable genre)
- **Retention layer:** Wave defense / survival
- **Social/viral layer:** Match-based PvP raids + leaderboards + clans
- **Aesthetic layer:** Sci-fi neon-tactical + bioluminescent horror

This blend is unclaimed on Roblox. Tycoon is dominant; sci-fi tycoon with PvP raids and a synthwave/jungle aesthetic does not exist at scale. The closest comp is *Steal a Brainrot* (raid mechanic) crossed with generic tycoon shells. Outpost-7 occupies a wider thematic lane with a much more distinctive identity.

### 2.4 Daily-return mechanics (≥2 required by build protocol — Outpost-7 ships with 4)

1. **Offline progression** — Extractors continue producing Credits while offline, capped at **12 hours**. Logging in after a long absence shows a "Welcome Back" reward sequence with the credits collected. (Hard cap prevents whales from never logging in.)
2. **Restocking blueprint shop** — Rotates inventory every **6 hours**. Rare blueprints appear in 24-hour rotations. Drives players to log in 4x/day at ideal cadence.
3. **Daily quests** — 3 daily quests reset at server reset (00:00 UTC). Mix of build, defend, and raid objectives. Reward: Credits + premium currency (Cores).
4. **Login bonus + streak** — 7-day rolling streak. Day 7 reward is a unique cosmetic (drone skin, turret skin, or armor). Streak resets if a day is missed (24hr grace window).

**Why all four:** Per `04_VIRAL_MECHANICS.md`, the strongest tycoons stack 3+ daily-return mechanics. Outpost-7 stacks 4 because PvP raid retention has a higher floor — players need reasons to log in *between* raids.

### 2.5 Clippable spectacle moments (the TikTok/Shorts engine)

Per the spectacle answer (A + B combo), Outpost-7 has **two distinct spectacle types** that feed each other:

**Spectacle A — The "oh shit" defense moment**
- Wave 12 hits at night. Bioluminescent alien predators swarm the eastern wall. Player's drone swarm activates, neon trails carving through the dark. Walls breach. Last turret holds. Player survives by ~5 HP. Cinematic music swells, victory screen shows colony saved.
- *Designed to be filmed.* Auto-clip system (V1.5) captures the last 30 seconds of any wave-21+ defense.

**Spectacle B — The transformation moment**
- Time-lapse: drop pod lands in empty jungle clearing. Day 1 = single tent. Day 7 = walled compound. Day 30 = sprawling neon-lit colony with drone swarms patrolling. Before/after thumbnail.
- *Designed to be filmed.* In-game "Photo Mode" + "Replay From Drop Pod" feature lets players record their own transformation video.

Both spectacles are **mobile-recordable** (the player can capture them with their phone's screen recorder while playing). This matters because TikTok-driven Roblox growth depends on player-recorded clips, not dev-recorded marketing footage.

### 2.6 Social interaction layer

- **Asynchronous PvP via match-based raids** — queue into a 5-min round against another player's colony. Rewards both sides.
- **Leaderboards** — Global Credits leaderboard, weekly raid wins, seasonal battle pass tier
- **Clans (Squad)** — 4-person squads. Shared Credits stash for clan-wide upgrades. Clan vs clan weekly bracket.
- **Voice chat (Spatial Voice)** — enabled during raids only (not in build mode). Adds drama to raid moments. Roblox handles moderation.
- **Friends system** — invite friends, see their colony coordinates on a personal "system map", visit their colony in observe mode (no raid).

### 2.7 Monetization stack (V1)

Per `05_MONETIZATION.md` recommended stack + your battle pass addition.

**Game Passes (one-time purchase):**
| Pass | Price | Effect | Conv % target |
|---|---|---|---|
| **2x Credits** | 199 R$ | Doubles all Credit gains permanently | 4–7% of payers |
| **Auto-Collect** | 299 R$ | Extractors auto-deposit; no manual collection | 3–5% of payers |
| **VIP Operator** | 499 R$ | Exclusive armor skin, drone trail, +1 daily quest slot, VIP-only blueprints | 2–4% of payers |

**Developer Products (consumable):**
| Product | Price | Effect |
|---|---|---|
| **Emergency Shield (5min)** | 49 R$ | 5-minute raid immunity. Cannot be raided during this window. |
| **Credit Pack (Small)** | 99 R$ | +10K Credits |
| **Credit Pack (Large)** | 499 R$ | +75K Credits |
| **Core Pack** | 199 R$ | +50 Cores (premium currency for cosmetics) |

**Battle Pass (Season 1 ships in V1; Season 2 in V1.1):**
- Free track + Premium track (799 R$, ~$10)
- 30 tiers, 30-day season
- Premium includes exclusive operator skins, drone swarm visual variants, base nameplate flairs
- **Designed to be cosmetic-only** (no power) so V1 doesn't introduce pay-to-win risk
- Daily quests grant battle pass XP — direct retention loop

**Estimated revenue:**
- At 100 CCU avg: **$300–800/mo**
- At 500 CCU avg: **$1,500–4,000/mo** (success target territory)
- At 2,000 CCU avg: **$6,000–18,000/mo**

These are honest ranges. Per `04_VIRAL_MECHANICS.md`, sci-fi/competitive games tend to monetize 10–30% above pure cozy tycoons because spend per payer is higher (battle pass + skins are sticky).

### 2.8 V1 must-haves (the locked feature list)

This is the **definitive V1 feature list.** Anything not on this list is V1.5+ unless explicitly approved.

**Core systems:**
- [ ] Hybrid extractor system (scout nodes → place extractors → auto-generate Credits)
- [ ] Tycoon currency (Credits) + premium currency (Cores)
- [ ] Build mode (third-person camera, snap-to-grid placement of walls, turrets, extractors, decor)
- [ ] Combat mode (first-person camera, weapon system, drone swarm controls)
- [ ] Camera transition system (smooth swap between TP build and FP combat)
- [ ] Match-based raid queue + matchmaking
- [ ] PvE alien wave system (also serves as fallback when raid queue is empty)
- [ ] Three biomes at launch: bioluminescent jungle (primary), volcanic, ice cave (per "multiple biomes at launch" answer)
- [ ] Per-player base saving/loading (DataStore)
- [ ] Anti-exploit pass on every Remote
- [ ] FTUE (first 30 seconds tuned per `01_AGENT.md` rule)

**Retention systems:**
- [ ] Offline progression (12hr cap)
- [ ] Restocking blueprint shop (6hr rotation)
- [ ] Daily quests (3 quests, server reset)
- [ ] Login streak (7-day rolling, 24hr grace)

**Monetization systems:**
- [ ] 3 game passes (2x Credits, Auto-Collect, VIP Operator)
- [ ] 4 developer products (Emergency Shield, Credit Pack S, Credit Pack L, Core Pack)
- [ ] Battle Pass infrastructure (Season 1 content can ship in V1.1 if behind)
- [ ] Receipt processing (idempotent, per `10_BUILD_PROTOCOL.md`)

**Social systems:**
- [ ] Asynchronous PvP raid matchmaking
- [ ] Leaderboards (global, weekly raid wins)
- [ ] Clan/squad system (4-person, shared stash)
- [ ] Voice chat enabled during raids only
- [ ] Friends system (invite, observe colonies)

**Content & polish:**
- [ ] 3 biomes (jungle, volcanic, ice)
- [ ] Synthwave music tracks (5 tracks min — combat, build, raid, victory, defeat)
- [ ] Lighting/atmosphere pass per biome
- [ ] UI polish (consistent fonts, neon-tactical theme)
- [ ] Game icon + 3 thumbnails (per `02_ROBLOX_PLATFORM.md` discovery best practices)
- [ ] Game description + tags

### 2.9 V1.5+ deferred list

- Trading marketplace between players (V1.5 or V2)
- Drone swarm customization (advanced editor) — V1 ships with 3 preset swarm types
- Cross-biome resource trading (V1.5)
- Player-built PvP arenas (V2)
- Seasonal events (V1.1+)
- 4th–6th biomes (V1.2)
- Battle Pass Season 2+ content (V1.1+)
- Auto-clip / replay system (V1.5)
- Mobile UI overhaul if data shows mobile retention is below desktop (V1.1)

---

## 3. Timeline & phase budget

### 3.1 Total budget

- **Available time:** 10–20 hrs/week × 14–18 weeks = **140–360 hours** (we plan against 200 hrs midpoint)
- **V1 ship target:** Week 14–18
- **Money budget:** $300+

### 3.2 Phase-by-phase week budget

This budget is calibrated to the V1 must-haves list above and the `10_BUILD_PROTOCOL.md` phase plan, with adjustments for the larger scope.

| Weeks | Phase | Sub-phases | Estimated hours | Notes |
|---|---|---|---|---|
| **W1** | **Phase A — Foundation** | A1–A4 | 12–18 | Rojo, DataStore wrapper, Remotes scaffold, bootstrap |
| **W2–W4** | **Phase B — Core Loop** | B1–B4 + B5 (camera swap) | 30–45 | Hybrid extractor + currency + base build mode + camera system |
| **W5** | **Phase C — Retention** | C1–C4 | 12–18 | All four daily-return mechanics |
| **W6** | **Phase D — Monetization** | D1–D5 (incl. battle pass infra) | 14–20 | Passes, dev products, battle pass scaffolding |
| **W7–W9** | **Phase E — Social Layer** | E1–E5 (raid queue + clans + voice + friends + leaderboards) | 35–55 | The hardest phase. Match-based raids, clans, async PvP |
| **W10–W11** | **Phase F — Anti-exploit + Polish** | F1–F5 | 18–28 | Trust boundary hardening + FTUE polish |
| **W12–W14** | **Phase G — Aesthetic Pass** | G1–G6 (3 biomes, audio, lighting, UI, drone swarm VFX) | 35–55 | Aesthetic is the moat. Don't shortchange. |
| **W15** | **Phase H — Ship Prep** | H1–H4 | 12–18 | Icon, thumbnails, description, soft listing test |
| **W16–W18** | **Phase I — Launch buffer** | I1–I3 | 15–30 | Friend playtest, bug-fix sprint, marketing asset prep, launch |

**Total estimated hours:** 183–267 hrs
**Calendar weeks:** 16–18 (with 2 weeks of buffer baked in for life events, week-long stalls, motivational dips)

### 3.3 The "Soft V1" fallback gate

If by **end of Week 12** you are behind schedule (e.g., Phase E isn't complete), the doc commits to a **Soft V1** fallback:

- **Cut from V1 (move to V1.1):** Multiple biomes (ship with jungle only), clans/squads, voice chat
- **Keep:** Match-based raids, full monetization, daily-return stack, single-biome polish
- **Calendar:** Soft V1 ships at week 14, full vision lands as V1.1 over weeks 15–22

This is a **pre-committed fallback**, not a panic cut. Having it documented now means at week 12 you don't have to make an emotional decision under pressure. You execute the pre-committed plan.

**Trigger for Soft V1:** End of Week 12 — Phase E (Social Layer) is not at least 70% complete.

### 3.4 Risk register (top 5 likely slippage points)

| # | Risk | Probability | Impact | Mitigation |
|---|---|---|---|---|
| 1 | **Phase E (Social/Raids) takes 50%+ longer than budget** | High | High | Pre-committed Soft V1 fallback. Match-based architecture chosen specifically because it's more contained than always-on PvP. |
| 2 | **Camera swap (TP↔FP) creates UX paper cuts** | Medium | Medium | Prototype the camera transition in Phase B5 *before* committing to mixed camera; if it feels bad, fall back to TP-only with FP zoom for combat (cheaper). |
| 3 | **Aesthetic phase (G) consumes more time than budgeted** | High | Medium | $300+ budget is allocated to marketplace assets + audio license. Don't model from scratch where a $20 marketplace asset works. |
| 4 | **DataStore schema needs change late in build** | Medium | High | Phase A4 includes a versioned schema header. New fields are backward-compatible by design. Renaming requires migration plan per build protocol. |
| 5 | **Motivation dip at week 8–10** ("the dip") | Medium-High | High | Pre-commit to a 30-min friend playtest at end of Phase E. External validation breaks the dip. |

---

## 4. The build playbook — phase-by-phase technical strategy

This section translates each phase into concrete tool/code recommendations grounded in your project docs (`06_LUAU_REFERENCE.md`, `07_PROJECT_STRUCTURE.md`, `08_MCP_SETUP.md`).

### 4.1 Tooling stack (locked, do not relitigate)

| Layer | Tool | Why |
|---|---|---|
| Language | **Luau** with strict type annotations, `.luau` extension | Per `10_BUILD_PROTOCOL.md` — non-negotiable. Strict mode catches 60% of bugs at edit time. |
| Sync | **Rojo** (`rojo.space`) | Industry standard. Local file editing → Studio sync. |
| Editor | **VS Code** + Roblox LSP + Selene linter + StyLua formatter | Tier-1 Luau dev experience. |
| Source control | **Git** + GitHub (private repo) | Phase commits per build protocol. |
| MCP | **Roblox Studio MCP** (per `08_MCP_SETUP.md`) | Lets Claude Code drive Studio operations during build sessions. |
| Asset pipeline | **Roblox Studio Asset Manager** + Roblox Marketplace | Per `02_11_asset_pipeline.md`. Don't build models from scratch. |
| Build orchestration | **Claude Code** running per `10_BUILD_PROTOCOL.md` | The agent + protocol does the building; you do taste decisions. |
| Music/SFX | **Roblox Audio Library** (free) + **Pixabay/Audiio** (royalty-free synthwave) | $20–50 of premium tracks lifts atmosphere significantly. |

### 4.2 Phase A — Foundation (Week 1)

**Goal:** Project loads, DataStore round-trips, Remotes scaffolding ready.

| Sub-phase | Concrete deliverables |
|---|---|
| A1 | `default.project.json`, `src/server/`, `src/client/`, `src/shared/`, `.gitignore`, `CLAUDE.md` (project memory file), README |
| A2 | `src/server/Modules/DataManager.luau` — `pcall` + `UpdateAsync` + retry-with-backoff + save-on-`PlayerRemoving` and `BindToClose`. **Versioned schema header (v1.0)** so future migrations are clean. |
| A3 | `src/shared/Remotes.luau` (typed RemoteEvent registry), `src/shared/Constants.luau`, `src/shared/Types.luau` |
| A4 | Empty-but-wired bootstraps: `src/server/init.server.luau`, `src/client/init.client.luau` |

**Audit (must pass before Phase B):**
- Studio loads place, no errors in output
- Player joins → DataStore reads default profile
- Player leaves → DataStore writes profile (verified via Studio console)
- Server shutdown forces final flush via `BindToClose`

**Tools/strategy notes:**
- Use **ProfileService-style abstraction inside DataManager** (don't import ProfileService — write your own thin wrapper following its pattern, per `06_LUAU_REFERENCE.md`). Reason: control + understanding for V1, easy to migrate later if needed.
- Versioned schema header in saved data: `{ version = "1.0", data = {...} }` — V1.1 migration will read version and upgrade in-place.

### 4.3 Phase B — Core Loop (Weeks 2–4)

**Goal:** A player can land on a planet, scout for nodes, place an extractor, watch credits accrue, and build their first wall.

| Sub-phase | Concrete deliverables |
|---|---|
| B1 | **Hybrid extractor system** — server-side node spawner (Poisson disk sampling for natural distribution), client-side scout/highlight, server-validated placement Remote |
| B2 | **Currency system** — `CurrencyService` server module, tick at 1Hz, applies pass multipliers, writes to DataStore on threshold |
| B3 | **Persistent base state** — base layout serializes to compact dictionary (positions + ids), saves on every placement + on PlayerRemoving |
| B4 | **Build mode UI** (third-person camera, build palette, snap-to-grid placement) |
| B5 | **Camera transition system** (TP build ↔ FP combat) — `CameraController.luau` client module, smooth `TweenService` blend, retains player input mapping correctly |

**Audit:**
- Two-client playtest. Both players scout, place extractors, accumulate Credits.
- Both players rejoin → base state and Credits persist correctly.
- Camera swap feels smooth (no nausea, no jitter, no input lag).

**Tools/strategy notes:**
- **Snap-to-grid uses a 4-stud grid** (mobile-thumb-friendly). Decor placement uses 1-stud sub-grid with hold-to-fine-tune.
- **Server-authoritative placement** — client sends `PlaceBuilding` Remote; server validates: (a) player can afford, (b) cell is empty, (c) placement is within their plot bounds. Never trust client.
- **Resource node spawner** uses Poisson disk sampling (rather than random) to ensure even distribution — feels designed, not random.
- Prototype B5 (camera) **before** locking everything else in B. If it feels bad after 2–3 hours of polish, fall back to TP-only.

### 4.4 Phase C — Retention Mechanics (Week 5)

**Goal:** All four daily-return mechanics functional and audited.

| Sub-phase | Concrete deliverables |
|---|---|
| C1 | Login bonus + 7-day streak system, 24hr grace window, server-time-based |
| C2 | Restocking shop — `os.time()` modulo 6h rotation, deterministic seed by date so all players see same stock |
| C3 | Daily quest system — 3 quests selected from pool of ~30 (variety = retention), reset at 00:00 UTC |
| C4 | Offline progression — on join, calculate elapsed time × per-extractor-rate, capped at 12h; show "Welcome Back" panel |

**Audit:**
- Time-shift test: artificially set `os.time()` forward and verify streak/cooldown logic.
- All four mechanics fire rewards correctly without overlap or double-grant.

**Tools/strategy notes:**
- **Quest pool design matters more than mechanics** — 30+ quest variants prevents player fatigue. Examples: "Place 5 extractors", "Survive 3 PvE waves", "Win 1 raid", "Spend 5K Credits", "Visit 2 friend colonies".
- All time logic uses `os.time()` (server) + UTC. Never use client time.

### 4.5 Phase D — Monetization (Week 6)

**Goal:** Real money flows. All passes purchasable. Battle pass infrastructure live (content can fill in V1.1).

| Sub-phase | Concrete deliverables |
|---|---|
| D1 | Game pass infrastructure — `MonetizationService.luau`, `PromptGamePassPurchase` flow, `UserOwnsGamePassAsync` checks cached per-session |
| D2 | Developer product infrastructure — `MarketplaceService.ProcessReceipt` set, **idempotent** receipt handling via DataStore-backed receipt ledger |
| D3 | Pass effects wired into game state — 2x Credits applies in `CurrencyService`, Auto-Collect modifies extractor logic, VIP unlocks blueprints |
| D4 | Battle Pass scaffolding — XP system, tier unlock flow, free vs premium track logic, claim Remote |
| D5 | UI for shop, pass display, battle pass progress bar |

**Audit:**
- Test purchase flow in Studio (sandbox).
- Verify pass effects apply immediately and on rejoin.
- Verify duplicate `ProcessReceipt` calls (Roblox can fire twice) only credit once.

**Tools/strategy notes:**
- **`ProcessReceipt` idempotency is the #1 monetization bug** — implement a `PurchaseLedger.luau` that records `(playerId, productId, receiptId)` tuples. If receipt already in ledger, return `PurchaseGranted` without re-applying effect.
- **Don't ship battle pass content (skins/cosmetics) in V1.** Ship the *system*. Season 1 content can be a ~3-day push in V1.1.

### 4.6 Phase E — Social Layer (Weeks 7–9) ⚠️ **highest-risk phase**

**Goal:** Match-based PvP raids, async matchmaking, NPC fallback waves, clans, voice chat (raid-only), friends, leaderboards.

| Sub-phase | Concrete deliverables |
|---|---|
| E1 | **Raid match server** — uses `MessagingService` for cross-server matchmaking, snapshot of target's base loaded into raid round, 5-min timer, reward distribution on completion |
| E2 | **PvE wave system** (also serves as raid-queue fallback) — wave spawner, alien AI behavior trees, scaling per night number |
| E3 | **Clan/squad system** — `ClanService`, 4-person max, shared stash with role-based access (leader, officer, member), per `MessagingService` for cross-server clan chat |
| E4 | **Voice chat (Spatial Voice)** — enabled only during raid rounds. UI affordance shows when voice is active. |
| E5 | **Leaderboards + friends** — `OrderedDataStore` for global Credits, weekly raid wins; friends list backed by `Players:GetFriendsAsync()` cached per session |

**Audit:**
- Multi-client raid round (2 humans, 1 attacker, 1 defender) executes cleanly.
- Empty queue → NPC wave fires within 10 seconds.
- Clan stash deposits/withdrawals are server-validated and atomic (no race conditions).
- Voice chat enables/disables at raid start/end.

**Tools/strategy notes:**
- **`MessagingService` is the cross-server backbone.** Players queue from any server; matchmaker is one designated server (rotates). Use a sentinel key in `MemoryStoreService` to elect the matchmaker per region.
- **Snapshot raids** — when raid starts, server loads attacker into a *separate place* (a teleport reserved server) running a snapshot of the target's base. The target's *real* server is untouched. This is critical: never let an attacker affect the defender's actual saved state directly.
- **Anti-grief on clan stash:** withdrawals require leader approval if amount > X. Logged for audit.
- **Don't bikeshed Spatial Voice** — Roblox handles moderation. Just enable it during raids. Done.

### 4.7 Phase F — Anti-exploit + FTUE (Weeks 10–11)

**Goal:** Game is hardened against common exploits. New player sees something interesting in 30 seconds.

| Sub-phase | Concrete deliverables |
|---|---|
| F1 | `AntiExploit.luau` rate limiting on every Remote — token-bucket pattern, per-player per-Remote, suspicious activity logged |
| F2 | Validation pass — every RemoteEvent argument type-checked + range-checked on server |
| F3 | Performance audit — object pooling for projectiles, drone swarm units, alien wave spawns; `task.wait` audit; unnecessary `Instance.new` cleanup |
| F4 | **FTUE — the 30-second rule** — first-run player sees: drop pod cinematic (5s) → operator landing animation (3s) → first node highlighted in HUD (player walks to it, ~10s) → first extractor placed, first Credits visible (~12s). **Total: 30s to first reward.** |
| F5 | Tutorial gates — first 3 quests are tutorial-style (place extractor, survive wave 1, claim daily reward) |

**Audit:**
- Exploit kit test — try malformed Remote calls, rate-limit spam, oversized payloads. Server logs and rejects, never crashes.
- Fresh test account FTUE: stopwatch from join to first reward. Must be ≤30s.

**Tools/strategy notes:**
- **Rate limiting:** 10 calls/sec per Remote per player (default), 60/sec for placement Remote (build sprees), 1/sec for purchase Remote. Tunable in `Constants.luau`.
- **FTUE is taste-critical** — playtest with at least 3 friends who have never seen the game. If any of them are confused at 30s, redesign.

### 4.8 Phase G — Aesthetic Pass (Weeks 12–14)

**Goal:** The game looks and sounds like a real product. Bioluminescent jungle aesthetic, synthwave audio, sleek operator UI.

| Sub-phase | Concrete deliverables |
|---|---|
| G1 | **Lighting pass — bioluminescent jungle biome** (Future tech lighting, fog, emissive materials on flora, dynamic light from drone swarm and turrets) |
| G2 | **Lighting pass — volcanic biome** (orange ambient, ash particle, lava emissive) |
| G3 | **Lighting pass — ice cave biome** (cold ambient, blue/white palette, fog density high, atmospheric scattering) |
| G4 | **Audio** — 5+ synthwave tracks (build, combat, raid, victory, defeat), key SFX (extractor place, alarm, turret fire, drone swarm idle/active, alien growls) |
| G5 | **UI polish** — consistent neon-tactical theme, single font family, animation pass on all transitions |
| G6 | **Drone swarm VFX** — 3 preset swarm types with distinct trail/color identities (Recon = blue, Combat = red, Engineering = green) |

**Audit:**
- Vibe check with 2–3 friends from your gaming group. Honest reactions only. Does it feel like a real product or a prototype?

**Tools/strategy notes:**
- **Lighting is 70% of the moat.** Future tech lighting + emissive flora makes the bioluminescent jungle. Don't skimp.
- **Buy marketplace assets aggressively.** $300 budget covers ~30–50 quality marketplace items (sci-fi crates, prop foliage, military operator armor, etc.). Modeling these from scratch is the wrong move.
- **Audio:** 5 royalty-free synthwave tracks from Pixabay + Audiio licenses. Run them through Roblox's audio import. Verify TOS for licensing path.

### 4.9 Phase H — Ship Prep (Week 15)

| Sub-phase | Concrete deliverables |
|---|---|
| H1 | Game icon (3 versions A/B test ready), 3 thumbnails (transformation, defense, raid moment) |
| H2 | Game description, tags, age rating (13+ for combat) |
| H3 | Studio 8-client simulation passes — no desync, no DataStore conflicts |
| H4 | Friends-only soft test — see §5 below |

### 4.10 Phase I — Launch buffer (Weeks 16–18)

| Sub-phase | Concrete deliverables |
|---|---|
| I1 | Friend playtest weekend — 5–15 friends, gather data, fix top 5 issues |
| I2 | Marketing asset prep — 3 TikTok clips, 3 X posts, 2 subreddit launch posts drafted |
| I3 | **Launch.** Public listing live. Pin community update. Begin marketing cadence per §6. |

---

## 5. Pre-launch testing — the honest disagreement

Your stated answer was **"no staged rollout — full launch when V1 is ready."**

I respect that decision and the document plan executes it. But I have to flag this is the **highest-risk single decision in the entire plan**, and I'd be doing you a disservice not to surface why.

**Why "no staged rollout" is risky:**

- Roblox's algorithm gives a game its **biggest organic boost in the first 24–72 hours** of public visibility. If the game has bugs, FTUE confusion, or PvP balance problems, those impressions are wasted forever — the algorithm interprets bounce as low quality.
- A 90-day target of 500 CCU + $2K/mo specifically requires a viral hit. Viral hits depend on the *first wave* of players having a great experience.
- Closed beta data shows things solo devs rarely catch alone — sub-50ms desync issues, unclear UI on specific phone form factors, exploit vectors only multi-player play exposes.

**The compromise I built into the plan (Phase H4):**

- **Friends-only soft test** — 1 weekend, 5–15 friends only, game listed as **private/unlisted** (not public).
- This is *not* a staged rollout. The game is never publicly listed before launch.
- Friend playtest data feeds into Phase I bug-fix sprint.
- Public launch happens at end of Week 16 as planned.

This preserves your "no staged rollout" stance (no public soft launch) while protecting the launch from preventable bugs. **Strongly recommend keeping this in the plan.** If you disagree, remove H4 and accept the launch-day risk.

---

## 6. Launch & marketing strategy (V1)

Per your answer: **friends first → social media (TikTok, X, subreddits)**.

### 6.1 Week-by-week launch plan

**Pre-launch (Weeks 14–15):**
- Set up game's TikTok account, X account, subreddit footprint (your own r/Outpost7 + active accounts in r/roblox, r/RobloxGameDev, r/spaceengineers, r/projectzomboid, sci-fi gaming subs)
- Record 5 short clips during Phase G/H — defense moments, transformation timelapses, drone swarm B-roll
- Draft launch posts for each channel

**Launch day (Day 0):**
- 09:00 — Game goes public. Listing live.
- 09:30 — Personal accounts post to friend group (Discord / iMessage / WhatsApp). "Game I've been building for 4 months is live, free to play, would love to know what you think."
- 11:00 — First TikTok post (transformation timelapse, 15s, synthwave audio overlaid)
- 13:00 — Subreddit posts (r/roblox first — the largest)
- 16:00 — X post with embedded clip + game link
- 20:00 — Second TikTok (defense moment)

**Day 1–7:**
- 2 TikToks per day (mix of gameplay clips + dev commentary)
- 1 X post per day
- Subreddit follow-ups (don't spam — 1 post per sub per week max)
- Reddit AMA on r/RobloxGameDev (Day 5)
- Watch metrics: CCU, retention D1, conversion %

**Week 2–4:**
- TikTok cadence: 1/day minimum, 3/day if any clip pops
- First content update (battle pass Season 1 content if not already in V1)
- First quality-of-life patch based on player feedback

### 6.2 Content strategy — what actually goes in TikTok clips

Clips that work for tycoon-survival-PvP on Roblox typically follow these patterns:

1. **Transformation timelapse** (your spectacle B): "Day 1 vs Day 30 of my colony" — 15s vertical
2. **The "oh shit" wave moment** (your spectacle A): "Wave 30. I almost lost it." — 15s vertical
3. **Raid drama**: "Stole 50K Credits from this guy's base, watch him chase me" — 15s vertical
4. **Funny fail**: "When you forgot to build walls" — chaos energy, brainrot vibe
5. **Tutorial bait**: "How to build the strongest defense in Outpost-7" — 30s, drives clicks
6. **Behind the scenes**: "I built this game in 4 months, here's how it looks now" — dev story angle, works on r/roblox + X

### 6.3 Subreddits to target (V1 launch)

- r/roblox (3.4M members) — the main one. Post: gameplay clip + "made this in 4 months, link in bio"
- r/RobloxGameDev (~80K) — dev story angle. Post: postmortem of build, ask for feedback.
- r/IndieGaming (~250K) — broader audience, sci-fi survival angle.
- r/projectzomboid, r/Helldivers, r/Subnautica — adjacent fandom subs. Be careful — pure self-promotion gets banned. Frame as "Roblox tribute to [game] — would love your feedback."
- Your own subreddit (r/Outpost7) — set up Day 1 as the official community hub. Cross-link from in-game.

### 6.4 Conversion math (sanity check on success target)

Target: **500 CCU + $2K/mo by month 2.**

For 500 CCU, you typically need ~5,000 DAU and ~25,000 MAU. With Roblox's organic distribution and a viral launch:

- Day 1: 50–500 visits (friends + first social posts)
- Week 1: 1,000–10,000 visits if any TikTok pops
- Week 4: 5,000–50,000 cumulative if growth is healthy

**$2K/mo at 500 CCU with this monetization stack is realistic.** It requires:
- 3–5% pass conversion (industry standard for tycoons)
- ARPDAU of $0.05–$0.15 (synthwave/sci-fi audience tends to be slightly higher spenders than cozy)
- No catastrophic FTUE/balance issues

The number is achievable. It's not guaranteed. It's a stretch goal that requires execution + a bit of luck.

---

## 7. V2 strategic outline (data-informed, not pre-planned)

Per the doc-scope answer: V2 is outlined strategically, not designed in detail, because **V2 should be informed by V1 launch data** rather than pre-planned in the dark.

### 7.1 V2 trigger conditions

Begin V2 planning when ONE of these is true:
- V1 hits 500 CCU sustained for 14+ consecutive days (success target met)
- V1 hits 200 CCU sustained for 30+ days (modest success — V2 is the doubling-down)
- V1 has clear signal of a specific underserved demand (e.g., players begging for a co-op mode, or for a specific biome)

### 7.2 Probable V2 themes (in priority order, will reorder based on data)

1. **Trading marketplace** (deferred from V1) — only if V1 economy is balanced enough that trading won't break it.
2. **Player-built PvP arenas** — let clans build custom raid bases. UGC content engine.
3. **Cross-biome resource specialization** — different biomes produce different rare materials, encouraging players to maintain multiple colonies (or trade).
4. **Co-op mode** — 2–4 player shared colony. Adds a parallel social mode without breaking competitive PvP.
5. **Seasonal events** — quarterly themed events (anniversary, holiday, sci-fi fandom crossovers per IP availability).
6. **Mobile UX overhaul** if V1 data shows mobile retention is below desktop.

### 7.3 V2 monetization additions (probable)

- Cosmetic gacha (drone swarm skins, operator armor) — only if V1 cosmetic spend is healthy
- Premium currency bundle promotions (limited-time)
- Battle Pass continuous seasons (every 30 days)

### 7.4 What V2 will NOT include

- Pay-to-win mechanics (V1 commitment maintained)
- Loot boxes with random outcomes that affect gameplay (legal/ToS risk)
- Off-platform redirects of any kind

---

## 8. Open questions / known unknowns

These are flagged for future-you and Claude Code at kickoff:

1. **Camera transition feel.** B5 prototype is a go/no-go gate. If TP↔FP swap feels bad after polish, Soft V1 cuts to TP-only with FP zoom for combat. Decide at end of Week 4.
2. **Match-based raid queue volume.** If V1 doesn't have enough concurrent players to fill raid queues, NPC waves carry the load. If queue wait > 30s consistently, consider switching to fully asynchronous raids in V1.1 (raid against snapshots, no live opponent).
3. **Voice chat moderation risk.** Spatial Voice during raids could surface toxic behavior. If reports spike post-launch, gate Voice behind verified-account requirement.
4. **Battle pass content volume.** Season 1 launches with V1 *if* phase budget allows. If not, ships in V1.1. Not a launch-blocker.
5. **Marketplace asset licensing.** Verify every purchased asset's license allows commercial use in your monetized game. Roblox Marketplace assets are generally safe; third-party (Pixabay/Audiio) require explicit verification.

---

## 9. Required-fields checklist (for `10_BUILD_PROTOCOL.md` Phase 3 kickoff)

Per `10_BUILD_PROTOCOL.md` input requirements:

| Field | Status | Section |
|---|---|---|
| North Star sentence | ✅ | §0, §2 |
| Genre + retention-genre blend | ✅ | §2.3 |
| One-sentence loop | ✅ | §2.2 |
| Daily-return mechanics (≥2) | ✅ | §2.4 (4 mechanics specified) |
| Clippable spectacle moment | ✅ | §2.5 |
| Social interaction layer | ✅ | §2.6 |
| Monetization stack (V1) | ✅ | §2.7 |
| V1 must-haves list | ✅ | §2.8 |
| V1.5 deferred list | ✅ | §2.9 |
| Aesthetic preference | ✅ | §1, §2.5, §4.8 |
| Time budget | ✅ | §3 |

**All required fields present.** Claude Code can begin Phase A on kickoff using the prompt at the bottom of `10_BUILD_PROTOCOL.md`.

---

## 10. Notes from the brainstorming session

Three substantive tensions were surfaced and resolved during brainstorming. Recording for transparency:

1. **The Black Site detour.** Initial direction (decision frame "C — most personally meaningful") suggested Black Site as the winner. Your "defender role" preference revealed the asymmetric design would underserve half the game. Pivoted to Outpost-7 with Black Site's *atmospheric* DNA (lighting, classified vibe in the sci-fi tone) carried over.

2. **Scope vs. timeline.** Original plan called for 6-week V1. Your answers (mixed camera + dual combat + battle pass + voice + clans + multi-biome) drove a frank scope conversation. You chose to extend to 14–18 weeks rather than cut features. This is documented and respected — but Phase E and Phase G are flagged as the most likely slippage points.

3. **Staged rollout vs. full launch.** You chose no staged rollout. The plan respects this but adds a friends-only soft test (Phase H4) that is **not** a public soft launch. This is the safest bridge between your stated preference and the launch-quality risk.

---

## 11. Final sign-off

This concept is **locked.**

The next action is to invoke the kickoff prompt at the bottom of `10_BUILD_PROTOCOL.md`, which will begin Phase A.

When ready, paste:

```
We are starting Phase 3 — build mode.

Read in this order:
1. docs/01_AGENT.md (your identity and principles)
2. docs/10_BUILD_PROTOCOL.md (this build workflow)
3. docs/09_BRAINSTORM.md (the locked concept — Outpost-7)

Verify all required fields are present in 09_BRAINSTORM.md per the input
checklist in 10_BUILD_PROTOCOL.md (§9 of the doc confirms all are present).
Proceed without asking permission.

Once verified:
1. Do the Phase A research pass.
2. Propose the full phase plan, customized to Outpost-7
   (the default in 10_BUILD_PROTOCOL.md is the starting point — modify
   as needed for the sci-fi tycoon + PvP raid scope).
3. Wait for my approval of the phase plan.
4. Once approved, begin Phase A — sub-phase A1.

Do not write any production code until the phase plan is approved.
You may run small exploratory snippets via MCP run_code if needed for
the research pass.
```

---

**End of finalized brainstorm. Outpost-7 — locked, sourced, scoped. Time to build.**
