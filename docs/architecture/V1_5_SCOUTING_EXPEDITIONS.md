# V1_5_SCOUTING_EXPEDITIONS.md — Solo Scouting Expeditions

> **Status:** V1.5 design spec. Approved 2026-05-05. ~5–7 weeks budget within V1.5 release window. Ships *after* `V1_5_MATERIAL_CRAFTING.md` so loot is meaningfully rewarding. Cross-references `V1_5_TIER_PROGRESSION.md` (Expedition Pad unlocks at Tier 4) and `V2_LIVING_JUNGLE.md` (encounter creature catalog overlap).

---

## 0. North star

Step beyond the plot perimeter and explore. 3 expedition tiers (close / mid / deep), each generating procedural adventure pockets with random encounters: rare materials, abandoned tech caches, hostile wildlife, alien ruins, dynamic events.

This is the **solo PvE content layer** that fills the gap between PvP raids (cooperative-competitive) and base building (solo-construction). Brainstorm §2.6 hints at this with "scout the planet to find resource nodes" — V1 implements that as a one-time placement; V1.5 expands it into an entire repeatable loop with discovery, lore, and risk/reward dynamics.

---

## 1. Why this is genuinely tycoon-shaped

- **Solo PvE counters PvP fatigue.** Some sessions, players want to raid. Other sessions, they want to build/explore alone. V1's PvE-wave-defense is the only solo-PvE content; expeditions deepen that lane massively.
- **Material gathering loop feeds crafting.** Per `V1_5_MATERIAL_CRAFTING.md` §2.2, uncommon materials are *only* available via expeditions. This makes expeditions structurally non-skippable for the crafting loop's payoff.
- **Discovery progression** = long-tail content. The 50+ lore datapad codex unlocks faction lore (V2 idea 4 setup), recipe blueprints, cosmetic emotes — drives 100+ hours of completionist play.
- **Daily expedition rotation** drives return visits. 3 active expeditions per day, server-rotated; same for everyone (lets clan members coordinate / compete on clear times).

---

## 2. Expedition mechanics

### 2.1 The Expedition Pad

Tier 4+ unlock per `V1_5_TIER_PROGRESSION.md`. New buildable.

- **Footprint:** 3×3 cells (12×12 studs); helipad-style flat platform with raised perimeter beacons
- **Cost:** 2,500 Credits + 30 Heat-Forged Steel + 20 Resin
- **Geometry:** circular landing pad with painted directional markings, 4 corner beacons emissive cyan, central holographic mission-select panel projecting 3 floating cards
- **Animation:** beacons pulse softly when missions are available; pulse rate increases as the daily rotation deadline approaches

### 2.2 Daily mission slots

Server picks 3 missions every UTC midnight (deterministic seed by date so all players on all servers see the same 3 missions per day — like the daily quest pattern from C3). Mission types are weighted; biome distribution rotates so jungle / volcanic / ice each appear ~33% of the time.

Each mission card shows:
- **Distance:** Close / Mid / Deep
- **Duration estimate:** 3 / 6 / 15 min
- **Risk indicator:** Low / Medium / High (rendered as 1–3 hazard chevrons)
- **Reward preview:** material rarity hints (e.g., "Uncommon materials likely; Rare possible")
- **Pocket type icon:** Crash Site / Resource Field / Alien Nest / Ancient Ruin / Predator Den / Storm Pocket
- **Biome banner:** background tint matches the pocket's biome theme

### 2.3 Loadout

Before launch, the player optionally loads:
- Vehicle from their owned fleet (V1.5 vehicles per `V1_5_MATERIAL_CRAFTING.md`) — extends carry capacity and combat survivability
- Stamina pack (consumable Dev Product, optional) — extends in-pocket time before death penalty
- Drone swarm preset toggle (from existing E2.6 system) — swap to Recon for scouting bonus, Combat for fighting, etc.

If no vehicle: player goes on foot. Slower, more dangerous, but accessible to any tier-4+ player without crafting prerequisites.

### 2.4 Launch sequence

1. Click mission card → confirm dialog with full reward preview
2. Pad beacons spike; teleport beam VFX
3. `TeleportService:ReserveServerAsync` reserves a per-pocket server (same architecture as raids per ADR-008 single-PlaceId mode, OR the dedicated raid PlaceId per ADR-009 — TBD; recommendation: dedicated `ExpeditionPlaceId` distinct from raid place to keep raid throughput bounded)
4. Player teleports with `setTeleportData` carrying `{ pocketType, biome, distance, seed, expirationAt }`
5. Pocket loads in ~3s; HUD swaps to expedition mode

### 2.5 In-pocket loop

Real-time exploration; no time-lock outside the soft 15-minute upper bound (matches Deep-tier mission duration).

- **Compass** points to primary objective (loot cache, ruin entrance, boss spawn)
- **Stamina bar** — drains on sprint, recovers on rest. Empty stamina = walk speed only
- **Inventory monitor** — current haul + carry capacity (foot capacity 12 stacks; vehicle capacity 50 stacks)
- **"Return to colony" button** always accessible — yields a 5-second teleport-out countdown; can be canceled
- **Fog of war** — pocket starts dark; reveals as player explores; entire pocket can be discovered in 5–10 minutes of methodical play

### 2.6 Death handling

If the player's character dies in-pocket:
- Lose **half** of all materials collected this session (random selection — V1.5 may iterate to "lose half of each stack")
- Vehicle (if loaded) takes damage (10% durability hit; durability is a V1.5 vehicle stat — see `V1_5_MATERIAL_CRAFTING.md` §4.3)
- Auto-teleport back to colony after 3-second death cam
- 5-minute cooldown before next expedition launch (penalty for reckless play; tier-up cinematic for second deaths in the same day's rotation could trigger an "Insurance Beacon" Dev Product purchase prompt — V2 sales path)

### 2.7 Successful return

- Auto-teleport back to colony at expiration timer OR voluntary "return" button
- Loot summary: animated reveal panel (slot-machine drop-in for each material); confetti for rare/exotic finds
- All materials deposited to inventory atomically
- Pocket-completion bonus: small Insight reward (V2 faction tech-tree currency; placeholder Cores until V2)

## 3. Pocket types (procedural)

Six distinct pocket archetypes. Each has its own generation rules, encounter table, and reward profile. Server picks one per expedition slot at daily rotation.

### 3.1 Crash Site

- **Risk:** Low
- **Reward focus:** Common materials + occasional Heat-Forged Steel (uncommon)
- **Layout:** 200×200 stud pocket with a wrecked starship as the centerpiece (50 studs across, broken into 3 hull sections); scattered debris field; small fauna roaming
- **Encounter:** Light wildlife (stalker juveniles, scavenger creatures); rare wandering boss (5% chance)
- **Loot:** 3–5 cargo containers scattered through the wreck, each with 2–6 stacks; 1 datapad in the bridge section (50% chance — drives codex completion)
- **Theme:** Salvage. Ambient SFX of metal creaking, distant warning beacons.

### 3.2 Resource Field

- **Risk:** Low–Medium (varies by distance tier)
- **Reward focus:** Bulk common materials + 1 uncommon (Magnetic Vine for jungle, etc.)
- **Layout:** 200×200 stud pocket dense with biome-themed harvestable flora (3×–5× the density of a normal plot's resource nodes); soft natural curves, no architectural structures
- **Encounter:** Mostly passive wildlife; opportunistic predators if player lingers
- **Loot:** Direct material harvest from flora (approach + interact = mini extractor cycle, 5–10s per node, 2–4 stacks per node)
- **Theme:** Pastoral. Ambient SFX of bioluminescent flora hums, distant fauna.

### 3.3 Alien Nest

- **Risk:** High
- **Reward focus:** Uncommon material from Predator Carapace / Spore Capsule + chance at rare boss drop
- **Layout:** 200×200 stud pocket centered on a biological nest mound (organic structure, vine-and-chitin construction); narrow approach corridors between mound chambers
- **Encounter:** Hostile-wave-style — 8–15 alien creatures spawn over 5 minutes; 1 alpha boss spawns at the center chamber
- **Loot:** Boss kill drops + chamber caches; risk of getting overwhelmed if player doesn't manage adds
- **Theme:** Hive. Ambient SFX of skittering, hiveling chittering, organic pulsing.

### 3.4 Ancient Ruin

- **Risk:** Medium
- **Reward focus:** Rare materials + exotic chance + 2–3 datapads (highest codex yield)
- **Layout:** 200×200 stud pocket featuring Forerunner-style architecture — geometric stone pyramids, holographic glyphs, central control chamber with a puzzle (V2 puzzle mechanic; V1.5 ships as "find and interact with 3 glyphs in correct order")
- **Encounter:** Defensive automated guardians (sentry-style turrets); puzzle solve unlocks the deep loot chamber
- **Loot:** Puzzle-solve rewards rare material; datapads scattered in side chambers; 1% exotic chance from the deep chamber
- **Theme:** Archaeological. Ambient SFX of resonant hums, distant geometric pings, glyph-activation chimes.

### 3.5 Predator Den

- **Risk:** High
- **Reward focus:** Boss-tier creature material + rare drop chance
- **Layout:** 200×200 stud pocket with cave-like environment built into terrain; central lair with the boss creature; surrounding den has young / juveniles patrolling
- **Encounter:** **Boss fight focused.** One major creature (V2 wildlife — Stalker-Alpha for jungle, Forge-Hound-Alpha for volcanic, Cryowraith-Alpha for ice); 4–6 minor creatures; arena combat
- **Loot:** Boss drops + cave wall material harvest
- **Theme:** Predatory. Ambient SFX of low growls, claws-on-stone, pre-fight tension.

### 3.6 Storm Pocket

- **Risk:** Medium (variable — environmental rather than enemy)
- **Reward focus:** Singular Core (exotic) is *only* obtained here; otherwise mid-tier rewards
- **Layout:** 200×200 stud pocket with violent environmental storm (electric storm in volcanic biome / blizzard in ice / pulse-storm in jungle); intermittent visibility; safe pockets between gusts
- **Encounter:** Environmental hazards (lightning strikes, freezing zones); occasional fauna driven into the pocket by the storm
- **Loot:** 5 storm-loot chests scattered; 1 of them guaranteed to have the Singular Core (1/200 chance per Storm Pocket — averaging ~7 weeks of daily Storm Pocket completions to get one)
- **Theme:** Apocalyptic. Ambient SFX of howling wind, thunder, distant pressure waves.

## 4. Procedural generation

### 4.1 Seeded determinism

Daily rotation seed = ISO date + server-region salt (so EU and US servers see the same 3 missions on the same day; different regions could have minor variants for V2 PvP balance).

Per-pocket seed = mission daily seed + pocket index. This keeps the layout deterministic — every player who runs today's Crash Site sees the same wreck arrangement, same loot positions, same encounter patterns. Enables:
- Speed-run leaderboards (clan-vs-clan / global)
- Coordinated farming guides
- Anti-cheat (server can validate player position vs. expected geometry)

### 4.2 Layout primitives

Each pocket type has a **layout template** (skeleton of mandatory features) + **filler distribution** (Poisson disk for natural placement of secondary elements, reusing the existing `Modules/Math/PoissonDisk.luau`).

Example — Crash Site template:
1. Mandatory: 1 ship wreck (50 studs, fixed orientation per seed)
2. Mandatory: 3–5 cargo containers (Poisson-disk placed within 80 studs of wreck)
3. Mandatory: 1 datapad (50% chance per seed; in the bridge section if present)
4. Optional: scattered fauna (3–8 creatures, Poisson-disk placed across the full pocket)
5. Optional: minor terrain features (rocks, plants — biome-themed)

### 4.3 Loot table tiers by distance

| Distance | Common drop weight | Uncommon | Rare | Exotic |
|---|---|---|---|---|
| Close (3min, low risk) | 80% | 18% | 2% | 0% |
| Mid (6min, med risk) | 50% | 35% | 13% | 2% |
| Deep (15min, high risk) | 20% | 35% | 35% | 10% |

Rolls happen per loot container, not per-pocket-as-a-whole. A Deep mission with 5 containers averages ~1.75 rare drops per run. Tunable in V1.5 playtest.

### 4.4 Procedural pocket lifecycle

- Pocket teleport fires → reserved server boots with `seed` from teleport data
- `ProceduralPocketBuilder.Build(seed, pocketType, biome)` constructs the pocket synchronously (~2s for layout, ~1s for fauna spawn)
- Player loads in; pocket exists for the player's session OR up to 30 minutes (whichever is shorter — protects against soft-locked sessions)
- On player teleport-out OR pocket expire: reserved server destroys itself; loot already deposited to player profile via in-pocket cache → home server relay (same MessagingService pattern as raid outcomes per ADR-008)

### 4.5 Encounter creature catalog

Reuses the V2 wildlife taxonomy (`V2_LIVING_JUNGLE.md`) — V1.5 expeditions ship with 8–10 creatures from the V2 catalog landing early to support pocket diversity. Treat as V1.5 launch dependency; coordinate creature design across both docs.

| Creature | Biome | Pocket types | Difficulty |
|---|---|---|---|
| Stalker (existing) | Jungle | All | Easy |
| Stalker-Alpha | Jungle | Predator Den, Alien Nest | Boss-tier |
| Resin Tick | Jungle | Resource Field, Crash Site | Trivial (passive harvest creature) |
| Magmaling (existing) | Volcanic | All | Medium |
| Forge Hound | Volcanic | Predator Den | Boss-tier |
| Sulfur Slug | Volcanic | Resource Field | Trivial |
| Cryowraith (existing) | Ice | All | Medium |
| Cryowraith-Alpha | Ice | Predator Den | Boss-tier |
| Frost Mite | Ice | Resource Field | Trivial |

Boss-tier creatures have V1.5 cosmetic skins + unique drop tables.

## 5. Discovery codex + Archive building

### 5.1 Lore datapads

Datapads are small holographic devices found in Crash Site, Ancient Ruin, and Storm Pocket pockets. Each datapad contains:

- A short lore entry (200–500 chars)
- An audio log voiceover (Phase G ships these — defer voice acting cost to launch budget per brainstorm §4.8 strategy)
- An asset reveal (faction insignia preview, blueprint hint, or cosmetic)

50+ datapads to collect → completionist long-tail. Distributed across the 3 biomes so all biomes need exploration.

### 5.2 Datapad categories

| Category | Sample entry | Reveal |
|---|---|---|
| **Corporate logs** | Vanguard Initiative deployment briefings | Faction lore + V2 setup |
| **Personal journals** | Dead operator's last log | Aesthetic emote unlock |
| **Scientific reports** | Helios bio-survey of jungle predators | Recipe blueprint unlock |
| **Engineering schematics** | Damaged blueprint scraps | Vehicle module unlock (cosmetic-only) |
| **Forerunner glyphs** | Pre-human alien civilization fragments | V2 deep lore + endgame setup |

### 5.3 Archive building (Tier 4+ unlock)

Architecturally a small library — 3×3 cells, 6 studs tall. Internal: holographic table displaying all collected datapads as small floating tablets; player approaches to "read" (opens a panel with full text + audio playback). Pure cosmetic on top of the codex panel; the building is the *visible flex* (raiders see "you've collected 47/50 datapads" via the building's exterior glyph display).

Cost: 4,000 Credits + 30 Resin + 20 Heat-Forged Steel + 15 Cryo Crystal.

### 5.4 Codex panel

Toggle button in the top HUD row (alongside other social buttons). Opens a centered modal:

- **Datapads tab** — grid of 50+ slots, greyed for uncollected. Click a collected entry to read full text + play audio.
- **Encounters tab** — bestiary view. Each creature has a stat sheet, encounter conditions, drop table. Greyed entries reveal silhouette + biome only.
- **Pockets tab** — list of pocket types with completion stats (best clear time, total clears, biome distribution).
- **Achievements tab** — "First Crash Site clear", "10 Predator Den boss kills", "Singular Core obtained" — drives milestone return visits.

## 6. UI/UX in detail

### 6.1 Expedition Pad UI (in-world)

When player walks within 8 studs of the pad, an interaction prompt appears: "[E] View Expeditions". Pressing E opens the floating holographic mission cards (in-world, 3 cards arranged in a fan above the pad center). Each card is interactive — hover for details, click to start.

### 6.2 In-pocket HUD

Replaces standard colony HUD on teleport-in:
- **Top-left:** mission card mini (pocket type + biome + duration timer)
- **Top-right:** loot capacity bar + collected stacks count
- **Bottom-left:** stamina bar + sprint key reminder
- **Bottom-right:** "Return to Colony" button (always visible; 5-second teleport countdown)
- **Center-bottom:** compass strip with objective markers (loot caches, ruin entrances, boss location)

### 6.3 Loot summary modal

On successful return:
- Background dim + slow-mo zoom on player character
- Materials cascade in from top edge of screen, slot-machine style (1 per 0.3s)
- Rare/exotic drops trigger gold particle burst + extra dramatic SFX
- Total summary at bottom: "X stacks collected, Y datapads, Z Credits Insight"
- "Continue" button dismisses to colony view

### 6.4 Daily mission timer indicator

A subtle banner across the colony Expedition Pad: "Next missions refresh in 08:34:21" — counts down in 1-second ticks (driven by client `os.time()` against next UTC midnight; not server-pushed for low overhead).

## 7. Monetization integration

| Type | Name | Price | Effect | Risk |
|---|---|---|---|---|
| Game Pass | Veteran Scout | 399 R$ | +1 daily expedition slot (3→4); 50% faster expedition timers; +25% loot capacity | Low — accelerates loop without trivializing |
| Game Pass | Codex Insider | 299 R$ | Datapad audio logs auto-replay; +1 datapad reveal per pocket; codex completion XP boost | Low — pure flavor |
| Dev Product | Rescue Beacon | 49 R$ | One-time use. Activates on death; teleports player home with no penalty (full loot kept, no cooldown) | Low — paying to undo a single mistake |
| Dev Product | Stamina Pack (3 charges) | 99 R$ | 3 stamina-restore consumables for use in pocket | Low — consumable accelerator |
| Dev Product | Reroll Daily | 199 R$ | One-time per day, rerolls all 3 daily missions for THIS player only (server pool stays the same for everyone else) | **Medium** — surface as ADR; risks "RNG manipulation" perception. Balance: only THIS player's rolls reset; doesn't change global pool |
| Cosmetic Pass | Expedition Cosmetics | 599 R$ | Unique helmet decal "Pioneer", expedition-themed banner, compass animation | Low |

## 8. Implementation cost + module breakdown

**Estimated:** 5–7 weeks. Procedural pocket generation is the technical risk.

### 8.1 New server modules

- `src/server/Modules/Expedition/ExpeditionRotationService.luau` — daily seed generation, mission picking, push to clients
- `src/server/Modules/Expedition/ExpeditionLauncher.luau` — wraps `ReserveServerAsync` for expedition pockets; carries seed via `setTeleportData` (mirrors `Raid.ReservedServerLauncher` pattern from E1)
- `src/server/Modules/Expedition/ProceduralPocketBuilder.luau` — runs in the reserved-pocket server; generates layout from seed
- `src/server/Modules/Expedition/PocketSession.luau` — pocket-server-only lifecycle module; handles in-pocket stamina, death, loot accumulation, return teleport. Mirrors `Raid.RaidSession` pattern.
- `src/server/Modules/Expedition/ExpeditionRewardService.luau` — main-place outcome relay (subscribes to `outpost.expedition.outcome` MessagingService topic; applies materials to home profile via `MaterialInventoryService.Add`)
- `src/server/Modules/Expedition/CodexService.luau` — datapad/encounter/pocket completion tracking; per-player codex state
- `src/shared/Modules/Registry/PocketRegistry.luau` — catalog of 6 pocket types + per-type generation rules + loot tables

### 8.2 New client modules

- `src/client/Modules/Expedition/ExpeditionPadController.luau` — in-world holographic mission cards
- `src/client/Modules/Expedition/PocketHUD.luau` — replaces standard HUD when in pocket
- `src/client/Modules/Expedition/LootSummaryModal.luau` — animated loot reveal on return
- `src/client/Modules/Expedition/CodexPanel.luau` — datapad/encounter/pocket/achievement tabs

### 8.3 Schema additions

```luau
-- ProfileSchema.luau
expeditionRunsToday: number,        -- resets at UTC midnight; gates "+1 slot" pass
collectedDatapads: { [string]: boolean },  -- datapadId → true
codexEncounterCount: { [string]: number }, -- creatureId → kill count
expeditionAchievements: { [string]: number },  -- achievementId → progress

-- New DataStore keyspace: ExpeditionPlaces_v1 (analogous to ClanData_v1) is NOT
-- needed — pocket state is entirely server-instance scoped, no persistence.
```

### 8.4 Constants additions

```luau
EXPEDITION = {
    DailyMissionCount = 3,
    DistanceTiers = {
        close = { duration = 180, riskWeight = 1, lootMultiplier = 1.0 },
        mid   = { duration = 360, riskWeight = 2, lootMultiplier = 1.5 },
        deep  = { duration = 900, riskWeight = 3, lootMultiplier = 2.5 },
    },
    PocketSize = 200,           -- stud square per pocket
    StaminaMaxBase = 100,
    StaminaSprintDrainPerSec = 20,
    DeathPenaltyLossFraction = 0.5,
    DeathCooldownSeconds = 300,
    ExpeditionPlaceId = 0,      -- REPLACE_BEFORE_LAUNCH at Phase H
    -- MessagingService topics
    TopicOutcome = "outpost.expedition.outcome",
}
```

### 8.5 New Remotes (~8)

`ExpeditionMissionsState`, `RequestLaunch`, `RequestRescue`, `PocketSummary`, `CodexState`, `RequestCodexEntry`, `ExpeditionCompletion`, `RerollDailyRequest` (paid).

### 8.6 V1.5 staging

Per the staging plan in `POST_V1_ROADMAP.md`:
- **Week 26–27 (V1.5 prep):** ProceduralPocketBuilder + 2 pocket types (Crash Site, Resource Field) — minimum viable
- **Week 28–29:** Remaining 4 pocket types + creature catalog wiring
- **Week 30 (V1.5 launch):** Codex + audio polish + monetization integration

## 9. Risks + open questions

1. **PlaceId proliferation.** Already at Main + Raid (ADR-009); adding Expedition Place makes 3. Open Cloud + CI tooling scales linearly, but operational complexity grows. **Recommendation:** ADR before V1.5 launch; the alternative is shared "reserved pocket" instances of the raid place with bootstrap branching on teleport-data type — saves a PlaceId at the cost of 2× the bootstrap branches.
2. **Procedural generation determinism across Roblox versions.** A Lua `math.random` change between Roblox engine releases could re-seed pockets. **Mitigation:** use `Random.new(seed):NextNumber()` exclusively (deterministic across versions per Roblox docs); never use raw `math.random` in the procedural pipeline.
3. **Boss balance in Predator Den.** A foot-only player without crafted weapons may be unable to clear Mid/Deep boss encounters; gameplay-locked behind crafting. **Mitigation:** Close-tier Predator Den exists with significantly tuned-down boss; foot-only completion possible there.
4. **Reroll Daily monetization perception.** Surface as ADR; ensure server-pool rolls remain global (only the player's rerolls reset). If perception is bad, cut the product.
5. **Audio log voiceover budget.** 50 datapads × 30s VO each = 25 minutes of voice work. Brainstorm §4.8 has $300+ asset budget; voice acting fits but requires advance commission. Phase G work item.

---

## 8. Cross-references

- `V1_5_TIER_PROGRESSION.md` — Expedition Pad unlocks at Tier 4
- `V1_5_MATERIAL_CRAFTING.md` — uncommon materials sourced exclusively from expeditions; discovery datapads unlock new blueprints
- `V2_LIVING_JUNGLE.md` — Predator Den / Alien Nest pockets feature creatures from the V2 wildlife taxonomy
- `POST_V1_ROADMAP.md` — sequencing within V1.5

---

**End of V1_5_SCOUTING_EXPEDITIONS.md.**
