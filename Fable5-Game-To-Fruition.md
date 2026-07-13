# Fable5 — Game To Fruition

> **Full-repo audit + roadmap to a shipped game.** Produced 2026-07-13 against `main`
> (`ed88b8a` — "Phases A–G complete"). Scope: every doc in `docs/`, all ~21,000 lines
> of Luau in `src/`, CI workflows, and the project's own status claims
> (`Final-Actions.md`, `ROADMAP.md`, prior audits).
>
> Read this top to bottom once, then use §6 (the plan) as the working checklist.

---

## 1. The verdict, up front

**Outpost-7 is one of the best-run solo Roblox projects I have audited — and it is
not yet a game.** Both halves of that sentence matter.

The engineering discipline is genuinely rare: strict Luau everywhere, a
server-authoritative trust boundary on every Remote, token-bucket rate limiting,
idempotent receipt processing, versioned save schemas, object pooling, two-place
raid architecture with a clean ADR trail, and a Constants file that centralizes
every tunable. Most shipped Roblox games — including some with millions of visits —
have worse foundations than this repo.

But the North Star is *"Build, fortify, raid"* — and today:

- **"Raid" is an empty timer.** The raid round teleports the attacker into a blank
  reserved server, waits 5 minutes, declares them the winner, and sends them home.
  No base is rendered, nothing can be stolen, no one can lose.
- **"Fortify" has no mechanical meaning.** Aliens ignore walls and turrets entirely —
  they pathfind straight to the player and melee the player. Buildings take no
  damage and block nothing. A player who builds zero walls defends exactly as well
  as one who builds a fortress.
- **The player has no weapon.** First-person combat mode exists as a camera state,
  but there is no gun, no firing, no player-dealt damage. Turrets and drones do
  100% of the fighting. The V1 must-have "Combat mode (weapon system)" is unmet.

So the honest status is: **the platform is ~90% done; the game on top of it is
~50% done.** The docs say "Phases A–G code-complete, ready for Phase H ship prep" —
that is true for *systems*, but shipping Phase H today would launch a tycoon with
no functioning combat fantasy. The plan in §6 inserts the missing gameplay phase
(I call it **Phase R — "Make the verbs real"**) before ship prep, because the three
verbs in your North Star are the entire moat.

Estimated remaining effort to a launch that matches the vision: **6–9 weeks at your
10–20 hrs/week pace** (3–4 weeks of gameplay code I can drive, 2–3 weeks of Studio/
asset/dashboard work only you can do, 1–2 weeks of playtest + fix). That is within
the original 14–18 week envelope's spirit, if past its letter.

---

## 2. Scorecard against your locked vision (`finalized-brainstorm.md` §2.8)

| Vision pillar | Status | Evidence |
|---|---|---|
| Hybrid extractor loop (scout → place → earn) | ✅ **Working** | `ResourceNodeSpawner`, `PlacementService`, `CurrencyService` — full server-validated chain |
| Credits + Cores dual currency | ✅ Working | `CurrencyService`, DataStore-backed |
| Build mode (TP camera, snap-to-grid) | ✅ Working | `BuildController`, `PlacementPreview`, 4-stud grid |
| Combat mode — camera | ✅ Working | `CameraController` TP↔FP transition, mode state machine |
| Combat mode — **weapon system** | ❌ **Missing** | No player weapon exists anywhere in `src/`. `CombatController.luau` is only a wave HUD banner |
| Camera transition system | ✅ Working | B5 shipped; go/no-go feel test still pending in Studio |
| Match-based raid queue + matchmaking | ✅ Working (infra) | `RaidMatchmaker` — MemoryStore queue, leader election, reserved-server teleport |
| **Raid round gameplay** | ❌ **Missing** | `RaidSession.luau:139-144` — outcome is `attackerWon = stillIn`; snapshot base never rendered; nothing stealable |
| PvE alien waves | ⚠️ **Half-working** | Waves spawn, scale, and end (`WaveDirector`) — but aliens only melee players (`AlienAI.luau:84-96`); they never attack walls, turrets, or extractors, so defense-building is cosmetic |
| Three biomes at launch | ⚠️ Framework only | Lighting + decoration profiles for all 3 exist and are good; visuals are procedural placeholder cubes; only jungle is player-facing |
| Per-player base save/load | ✅ Working | `BaseSerializer` + `BuildRestorer` + ProfileStore |
| Anti-exploit on every Remote | ✅ **Strong** | `AntiExploit` token buckets + `RemoteValidator` + `AuditLog` — genuinely above-market |
| FTUE 30-second rule | ✅ Working (untested) | `FTUEService` state machine + G8 polish; never stopwatch-verified with a real new player |
| Offline progression / shop rotation / daily quests / login streak | ✅ All four working | Phase C complete; time-shift audit still pending in Studio |
| 3 game passes + 4 dev products + receipts | ⚠️ Code-complete, IDs = 0 | `PurchaseLedger` idempotency is correct. **Emergency Shield has no effect implementation** (`DevProductService.luau:74-88` returns `NotProcessedYet`) — a purchasable product that takes money and grants nothing is a refund/moderation risk |
| Battle Pass infra | ✅ Working | XP, tiers, free/premium, cosmetic milestones (G7) |
| Clans (4-person, stash, chat) | ✅ Working | `ClanService` + `ClanStashLedger` (CAS via UpdateAsync) + cross-server chat |
| Voice (raid-only) | ✅ Working (needs dashboard toggle) | `VoiceGate` both places |
| Leaderboards + friends | ✅ Working | OrderedDataStore weekly buckets per ADR-010 |
| Synthwave audio (5+ tracks) | ❌ All `assetId = 0` | Whole audio system wired and silent |
| Icon/thumbnails/listing | ❌ Not started | Phase H |

**Bottom line: 17 of 24 pillars working, but the 4 misses are concentrated in the
game's identity** — raid gameplay, base-targeting AI, player weapon, and the
aesthetic/audio layer that was explicitly called "the moat."

---

## 3. What is genuinely strong (keep doing this)

1. **Trust boundary discipline.** Every C→S Remote passes rate-check → validate →
   semantic check → mutate. The `RemoteValidator` + `Constants.VALIDATION` caps +
   `AuditLog` ring buffer is a pattern most professional studios don't reach.
2. **Persistence architecture.** ProfileStore + `Reconcile()` + versioned
   `ProfileSchema.Migrate` + `BindToClose` flush + session-steal kick handling
   (`DataManager.luau:103-112`) is textbook. The PurchaseLedger's crash-safety
   argument (grant + ledger flush atomically on the same profile write) is correct.
3. **The two-place raid split (ADR-009).** Snapshot raids that never touch the
   defender's live server is the right call and is *ahead* of what most raid games
   do. The infrastructure (MemoryStore snapshot, MessagingService outcome relay,
   leader-elected matchmaker) is done — it just needs a game inside it.
4. **Constants/feature-flag discipline.** 988 lines of documented tunables, zero
   magic numbers found in modules. V1.5 plot-size reservation (F0) means tier
   progression ships without world migration. This is what "built to last" looks like.
5. **Docs as an operating system.** The phase worklogs, ADR supersession chain,
   playbooks, and `Final-Actions.md` mean any session (human or agent) can cold-start.
   The docs' one flaw is optimism drift — see §4.7.
6. **Performance hygiene.** AlienPool / DronePool / BeamPool, staggered wave spawns,
   batched bulk-destroy, StreamingEnabled tuning — the mobile-first constraint is
   being taken seriously before launch, not after.

---

## 4. Critical findings (ranked by launch impact)

### 4.1 🔴 The raid round is a placeholder — the flagship feature doesn't exist
`src/server/Modules/Raid/RaidSession.luau:100-144`. The attacker teleports into an
empty world, a 5-minute timer runs, and `attackerWon = stillIn` — staying connected
is the win condition. The defender's `baseLayout` is captured into the snapshot but
never rendered; `creditsAtSnapshot` is captured but nothing reads it as a steal cap.
The E1 worklog is honest about this ("timer+outcome shell only") but `ROADMAP.md`
and the PR title ("V1 systems code-complete") obscure it. **This is the single
largest gap between repo and vision.** Fix in Phase R2 (§6).

### 4.2 🔴 Aliens never attack the base — "fortify" is cosmetic
`AlienAI.luau` steers every alien at the target player's HumanoidRootPart and
damages only that player on touch. Walls have no HP, turrets can't be destroyed,
extractors are never threatened. Consequences: walls are pure decoration, the
"oh shit, the eastern wall breached" spectacle moment (brainstorm §2.5) cannot
happen, and the reinvest-into-defenses loop has no pressure driving it. Fix in
Phase R1: give buildables HP + make aliens target the nearest structure between
them and the player (or the extractors), with wall-breaching as the designed drama.

### 4.3 🔴 No player weapon
The FP combat camera exists; the combat verb doesn't. In PvE the player stands
inside their turret coverage; in a raid the attacker will have literally no way to
interact with the defender's base. A single server-validated hitscan rifle
(client fires ray → server re-raycasts from character position with reach/angle/
rate validation → `DamageService`) closes this. All the plumbing it needs
(`DamageService` chokepoint, `BeamPool` visuals, `AntiExploit` rate check,
`RemoteValidator`) already exists — this is ~1 focused week.

### 4.4 🟠 Emergency Shield is sellable but unimplemented
`DevProductService.applyEffect` correctly refuses to grant it (`NotProcessedYet`),
which means a real purchase would charge Robux, retry forever, and grant nothing.
Either implement the raid-immunity timer (matchmaker already needs a
`shieldedUntil` check when building the target pool — small) or remove it from the
`MONETIZATION.DevProducts` catalog until it works. **Do not launch with it listed.**

### 4.5 🟠 Server size vs. plot count mismatch
`Constants.WORLD.PlotCount = 4`, and neither project file nor the docs pin the
place's max players. Roblox default server size (50) would leave players 5+ with
"[PlotManager] No free plot — server full" and no base. Set **Max Players = 4** in
the Creator Dashboard (or raise PlotCount) and record it in `PUBLISHING.md` §
pre-release checklist. Also think ahead: 4-player servers make the world feel
empty and hurt raid-queue liquidity — consider 8 plots (2×4) with the same
128-stud slot reservation before layout ossifies.

### 4.6 🟠 Zero automated tests
`tests/` is scaffolding + `.gitkeep`s. Lune is already pinned in `aftman.toml` and
CI already runs Selene/StyLua/rojo-build — adding a `lune test` step is cheap. The
highest-value pure-logic targets (no Roblox API mocking needed): `GridMath`,
`PoissonDisk`, `ProfileSchema.Migrate`, streak/rotation/quest-reset date math in
the retention managers, battle-pass XP/tier math, and `BaseSerializer` round-trip.
Retention date math is exactly the code that silently breaks at a UTC boundary
three weeks after launch.

### 4.7 🟡 Status-doc drift (fix cheap, prevents wrong decisions)
- `ROADMAP.md` shows **every** Phase A–G checkbox unchecked while `Final-Actions.md`
  declares A–G complete. One of them is lying to every fresh session; the truth is
  in between (systems done, gameplay gaps per §4.1–4.3).
- `Final-Actions.md` still says the work lives on `claude/audit-phases-a-d-2BAuW`,
  but PR #9 already merged it to `main`.
- The three Studio audit gates (Phase A DataStore round-trip, Phase B two-client +
  camera feel test, Phase C time-shift) are still marked pending from the 2026-05-04
  audit — meaning **the core loop has never been verified in Studio by a human**.
  This is the highest-risk unknown in the whole project: 21K lines that have only
  ever been reasoned about, never run. Run these before writing more code.

### 4.8 🟡 Known tech debt worth pulling forward (from the 05-04 audit, still open)
- 2× Credits multiplier not applied to offline progression grants
  (`OfflineProgression.GrantOnJoin` reads raw `incomePerSecond`) — paying customers
  will notice within days of launch.
- Placement reach check is still the B1 placeholder (no server-side raycast).
  Acceptable for launch given plot-bounds validation, but log it.
- Failed placements are silent client-side (no `PlacementResult` toast).
- Quest pool is ~10 entries vs. the 30+ the brainstorm calls for (fatigue risk
  by day 4 of retention).

### 4.9 🟡 Raid-queue liquidity is a math problem, not a code problem
Match-based raids require an online, plot-owning, non-shielded target at queue time.
At your own success target (500 CCU across ~125 four-player servers), queues will
mostly work; at launch-week reality (10–50 CCU) they will mostly hit the 30s
deadline and fall back to PvE waves — meaning most players will never see the
flagship feature. The snapshot architecture already makes raids asynchronous in
all but name. **Recommendation:** persist each player's latest snapshot to a
DataStore on logout and let the matchmaker fall back to *offline* targets before
falling back to PvE. Live-vs-offline can pay different reward bands. This turns
raid liquidity from "needs 500 CCU" into "needs 2 players ever."

---

## 5. Systems inventory (for the record)

| Layer | Modules | State |
|---|---|---|
| Persistence | DataManager, ProfileSchema, ProfilePrefsService | ✅ production-grade |
| Economy | CurrencyService, ShopService, BlueprintRegistry | ✅ |
| Build | PlacementService, BaseSerializer, BuildRestorer, GridMath, PoissonDisk | ✅ |
| Combat | WaveDirector, AlienAI/Pool, TurretService, DroneSwarmService, DamageService, BeamPool | ⚠️ works, but no base-targeting + no player weapon |
| Raid | RaidMatchmaker, RaidSnapshot, RaidSession, RaidRewardService, ReservedServerLauncher | ⚠️ infra ✅ / gameplay ❌ |
| Retention | DailyLogin, DailyQuest, OfflineProgression, QuestObjectives | ✅ |
| Monetization | MonetizationService, GamePass/DevProduct services, PurchaseLedger, BattlePass suite, PassEffects | ⚠️ ✅ except Shield + IDs=0 |
| Social | ClanService/Stash/Chat, LeaderboardService, FriendsService, VoiceGate | ✅ |
| Security | AntiExploit, RemoteValidator, AuditLog, ServerAuthorityBootstrap | ✅ strong |
| World/Aesthetic | PlotManager, BiomeLighting/Decoration, ResourceNodeSpawner, Theme/Components, AudioService/Registry | ⚠️ framework ✅ / assets 0 |
| FTUE | FTUEService + Controller | ✅ (unverified with humans) |
| Tests | — | ❌ none |

---

## 6. The plan to fruition

Sequenced for one builder + one agent at 10–20 hrs/week. Each phase ends with a
committable, auditable state per `10_BUILD_PROTOCOL.md`. **Phase R is new** — it
sits between the old G and H because shipping without it ships a different game
than the one you designed.

### Phase 0 — Ground truth (this week, ~4 hrs, mostly you)
1. Run the three overdue Studio audit gates (A: DataStore round-trip; B: two-client
   build loop + camera feel go/no-go; C: time-shift retention test). File findings
   into the phase worklogs. *Nothing else proceeds on code that has never run.*
2. Fix doc drift: check off ROADMAP A–G items that are true, annotate the ones that
   aren't (§4.1–4.3), update `Final-Actions.md` branch note.
3. Decision: raise `PlotCount` to 8 or pin Max Players = 4 (recommend 8 — see §4.5).

### Phase R — Make the verbs real (3–4 weeks, agent-heavy) ⚠️ the critical path
**R1 — Fortify (week 1).** Buildable HP (`BuildableRegistry` gains `maxHp`;
occupancy grid tracks damage), aliens target structures blocking their path to the
plot core / extractors (nearest-obstruction heuristic, not full pathfinding),
breach → pour through gap. Wall repair verb (hold-to-repair, costs credits).
Wave-loss consequence: aliens that reach extractors disable them until repaired —
pressure without hard punishment. Emit `wave_survived` quest/BP XP events.
**R2 — Raid (weeks 2–3).** Render `snapshot.baseLayout` into the raid place on
attacker arrival (reuse `BuildRestorer`); attacker damages structures with the R3
weapon; loot model: destroy extractors/vault to "extract" a % of
`creditsAtSnapshot` (cap ~10–15%, floor for the defender); win condition = credits
extracted before timer, loss = timer expiry or attacker death (snapshot turrets +
drones fight back using the existing `TurretService` logic pointed at the
attacker). Outcome relay already works — just feed it real results.
**R3 — Weapon (parallel, ~1 week).** One hitscan rifle: client intent → server
raycast re-validation (origin within character reach, rate-limited via existing
token buckets), `DamageService` routing, `BeamPool` tracer, damage numbers.
Works in both PvE defense and raids. One weapon, tuned well, beats three untuned.
**R4 — Shield + loose ends (2–3 days).** Implement Emergency Shield
(`shieldedUntil` in profile + matchmaker target-pool filter + HUD indicator), wire
2× Credits into offline grants, add `PlacementResult` toast, expand quest pool to
30 including `survive_wave` / `win_raid` / `raid_attended` objectives.

**Audit gate:** two-human raid playtest — attacker steals from defender's snapshot,
defender's home server receives the outcome, both profiles correct after rejoin.

### Phase T — Test floor (3–4 days, agent, can overlap R)
Lune unit tests for the pure-logic modules listed in §4.6 + CI step. Target: the
date/streak/rotation math and serializer round-trip at minimum.

### Phase H — Ship prep (2 weeks, human-heavy; unchanged from `Final-Actions.md` §3)
The existing plan is good. Order of operations: `AssetIds.luau` manifest +
`upload-assets.sh` + SHA-pin actions (agent) → your dashboard work (account
verification, two Open Cloud keys, universe + 4 place IDs, secrets/vars) → staging
dry-run of `release.yml` → asset shopping ($300–460 per the ASSETS.md budget;
prioritize: 5 music tracks + core SFX first — audio is the cheapest 50% of "feels
real" — then jungle flora meshes, then operator/alien skins) → 8-client Studio
sim → icon/thumbnails from real polished screenshots → listing copy.

### Phase P — Soft test + fix (1 week)
Friends weekend (5–15 players, unlisted). Stopwatch the FTUE on people who have
never seen it. Watch: raid comprehension, wave difficulty wall, mobile thumb reach,
queue fallback frequency. Fix top 5. This is the compromise you already accepted
in brainstorm §5 — keep it.

### Phase L — Launch (per brainstorm §6.1, unchanged)
The day-0 timeline and TikTok cadence in the brainstorm are solid. One addition:
have the **week-1 patch pre-planned** (quest pool refresh + one new blueprint) so
the algorithm's first-week window sees an "actively updated" signal.

### Post-launch (V1.1 → V1.5, gated on data)
Battle Pass S1 cosmetic content → offline-target raids if queue data confirms §4.9
→ tier progression (`V1_5_TIER_PROGRESSION.md`) as the first big retention update
→ crafting/expeditions per `POST_V1_ROADMAP.md`.

### Effort split
| Track | Weeks | Owner |
|---|---|---|
| Phase 0 | 0.5 | You (Studio) |
| Phase R | 3–4 | Agent codes, you feel-test each sub-phase |
| Phase T | 0.5 | Agent |
| Phase H | 2 | ~70% you, 30% agent |
| Phase P | 1 | You + friends, agent fixes |
| **Total to launch** | **~7–8** | |

---

## 7. Best game improvements & enhancements (based on your current concepts)

These are additive design recommendations, ranked by expected impact ÷ effort.
None change the locked concept — they sharpen it.

### 7.1 Make extraction the raid's dramatic spine (high impact, lands inside R2)
Don't let raiders nibble credits per structure destroyed. Instead: breaking the
defender's **vault** starts a loud 60-second klaxon during which the attacker must
carry a physical loot core back to their dropship while the snapshot's turrets and
drones go berserk. One decision point, huge tension, and it *is* your TikTok clip
("30 seconds left, 12K credits on my back"). Steal-a-Brainrot proved carry-the-loot
is the clippable half of the raid genre; your sci-fi skin does it better.

### 7.2 Offline-snapshot raids as the liquidity backbone (high impact, small delta)
Per §4.9 — persist snapshots and raid offline players. Then add the retention hook:
the defender's next login shows a **"While you were away" raid report** (who
attacked, what broke, what survived, defense reward earned). This converts being
raided from pure loss into a login reason, and it feeds the daily-return stack a
fifth mechanic for free.

### 7.3 A real night cycle instead of a 10-minute wave timer (medium effort, identity-defining)
`WaveClockSeconds = 600` approximates "by night, the jungle moves" — but the
brainstorm's fantasy is the *dread of dusk*. Add a visible 8-minute day / 3-minute
night cycle: days for scouting/building (flora dims, safe), nights for waves (flora
ignites, `BiomeLightingService` shifts, synth track swaps). Same wave code, but now
the player *watches the light change and braces*. This single change manufactures
your Spectacle A on a schedule and makes the bioluminescent aesthetic mechanical
instead of decorative.

### 7.4 Wall/turret damage states = free spectacle (small, inside R1)
When structures have HP, render 3 damage states (intact / cracked+sparking /
breached+burning) with emissive decals from the existing theme palette. Ruined
bases photograph well, sell repair urgency, and make the transformation timelapse
(Spectacle B) read even when the colony is mid-crisis.

### 7.5 Defense rating + revenge raids (medium, V1.1)
Score each base 1–5 stars from wall coverage + turret DPS + layout. Matchmaker
pairs by rating (protects new players); leaderboard gains a "most-feared base"
board (defender-side prestige — *your* stated fantasy is the spider, and today all
ranking glory goes to attackers); and every raid report offers a one-tap
**Revenge** queue against your attacker's snapshot. Revenge loops are the highest
retention-per-line-of-code feature in the raid genre.

### 7.6 Specimen codex — pull one slice of V2 forward (small, V1.1)
`V2_LIVING_JUNGLE.md` is far away, but a 12-entry alien codex (kill/scan a Stalker
variant → unlock lore card + small Cores drop) costs days, not weeks. Collection
pressure is a proven Roblox retention layer your stack currently lacks, and it
seeds the V2 wildlife fantasy without committing to taming/breeding.

### 7.7 Photo mode before launch, not V1.5 (small)
Brainstorm §2.5 says player-recorded clips are the growth engine, then defers the
recording affordances. A minimal photo mode (free camera + hide UI + time-of-day
slider) is ~2 days on top of the existing `CameraController` and directly
manufactures your marketing supply chain. The auto-clip system can stay V1.5;
photo mode shouldn't.

### 7.8 First night at minute 3 (FTUE tuning, zero new systems)
The FTUE gets a player to first credits in 30s — good — but the *hook* of this game
is the first wave. Script wave 1 (3 weak aliens, guaranteed survivable with the
starter turret) to hit ~3 minutes into a new player's first session, immediately
after they place their first turret via a tutorial quest. Players who experience
one defense in session 1 are the ones who come back for night 2. Don't let the
first wave land on the ambient 10-minute clock.

### 7.9 Sharpen Auto-Collect back to its fantasy (design consistency)
The pass was redefined from "extractors auto-deposit" (a genuine QoL fantasy that
sells) to "+50% income while online" (a stat that stacks to ×3.0 with 2× Credits
and quietly edges toward pay-to-win in a game with raid stakes). Recommend
restoring the QoL version: manual collection runs for free players (walking your
perimeter = seeing your base = organic defense checks), Auto-Collect removes the
chore. QoL passes convert as well as stat passes and keep your "no power for money"
line clean before PvP raids make that line matter.

### 7.10 Clan raid assists (V1.1, uses existing spatial voice)
Let one clanmate join a raid round as backup (2-attacker cap, harder target tier,
shared loot). It gives clans a verb beyond the stash, makes Spatial Voice — which
you're already paying complexity for — actually matter, and creates the "duo raid
chaos" clip category. The reserved-server flow already supports multiple
teleported players; this is mostly matchmaker + reward-split work.

---

## 8. One-line summary

**Foundation: exceptional. Gameplay: finish the three verbs. Path: Phase 0 ground
truth → Phase R (fortify/raid/weapon) → ship prep as already planned — roughly 7–8
weeks to a launch that matches the game you actually designed.**
