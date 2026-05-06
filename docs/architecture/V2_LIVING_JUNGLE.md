# V2_LIVING_JUNGLE.md — Living Jungle / Tameable Wildlife

> **Status:** V2 design spec. Approved 2026-05-05 as the major V2 content drop. ~8–10 weeks budget within the V2 release window. Cross-references all V1.5 docs (boss creatures unlock rare crafting materials per `V1_5_MATERIAL_CRAFTING.md`; expedition pockets feature creatures from this catalog per `V1_5_SCOUTING_EXPEDITIONS.md`).

---

## 0. North star

The planet isn't just hostile waves. **Passive flora-fauna, tameable creatures, migratory species, and rare boss-tier wildlife make the world feel alive.** Players capture, breed, deploy creatures as defenders or mounts. Bestiary collection becomes a long-tail tycoon retention loop on the proven Adopt Me / Bee Swarm Simulator pattern.

This is the V2 emotional anchor — players who hit Megacity (Tier 6) at endgame need a fresh long-tail loop that ISN'T more building. Wildlife is that loop: 100+ creatures across biomes/rarities, breeding for rare color variants (the proven shiny mechanic), monthly boss events.

---

## 1. Why this is genuinely tycoon-shaped

- **Pet/creature collection** — single most reliable long-tail tycoon retention driver in Roblox 2020–2026 (Adopt Me, Bee Swarm Simulator, Pet Simulator series).
- **Breeding cycles drive daily-return.** 8–24-hour breeding timer per pair = mandatory log-in to start the next breed.
- **Rare color variants ("shinies") drive social flex.** A 1/100 rare-color drop = bragging right; visible to everyone visiting the colony or in raid context.
- **Monthly boss events** = tentpole calendar moments with universal hype.
- **Material crafting integration** — boss kills drop rare materials (`V1_5_MATERIAL_CRAFTING.md` §2.3). Wildlife taxonomy is the gate to legendary crafted items.

---

## 2. Wildlife taxonomy

Five categories. Total V2 launch catalog: ~40 creatures (mix of categories); V2.1+ expansions push toward the 100+ long-tail.

### 2.1 Hostile (existing — V1 wave aliens)

The V1 alien wave roster (`AlienRegistry.luau`) — Stalker, Magmaling, Cryowraith, plus the V2 expansion variants. These remain hostile and continue to feed the wave defense loop. Cannot be tamed in V2 (V3 stretch goal: tameable hostile alphas).

### 2.2 Neutral

Peaceful unless provoked. Approach is safe; attack triggers retaliation. Provide harvestable material with an ethical cost (V2 faction reputation impact — Verdant Coalition penalizes neutral-creature kills).

| Creature | Biome | Form | Material drop | Rep impact |
|---|---|---|---|---|
| **Rocksinger** | Volcanic | Slow-moving boulder-creature | Magma Crystal (rare) | -1 Verdant rep |
| **Bloomwalker** | Jungle | Plant-on-legs, slow grazer | Bioluminescent Sap (common) | -2 Verdant rep |
| **Frostback** | Ice | Quadruped grazer with thick ice plates | Cryo Crystal (uncommon) | -1 Verdant rep |

Repeated kills push the player into Verdant negative rep, which gates them out of certain V2 faction perks.

### 2.3 Passive

Always peaceful. No drops. Pure ambient/cosmetic role; makes the world feel alive without gameplay impact.

Examples per biome:
- **Jungle:** Spore-puff drifters (small floating creatures), Glowmoth swarms (decorative aerial), Vine-rats (small ground critters)
- **Volcanic:** Ash-flutter (small wing creatures), Heat shrimp (puddle-dwellers), Lava beetles (slow-walking decoratives)
- **Ice:** Frost-finch (small bird-like), Snow-fox (rare passive sighting), Crystal-snail (slow ground decorative)

These exist to reward exploration ("oh look, a snow-fox!") and to populate the world cosmetically. V2.1 may add scan-and-photograph mechanics tied to codex entries.

### 2.4 Tameable

3–5 species across the 3 biomes for V2 launch. Designed to be capturable, raisable, and deployable as defenders/mounts/cargo. **The core V2 collection drive.**

| Species | Biome | Form | Tame method | Use cases |
|---|---|---|---|---|
| **Dawnstrider** | Jungle | 6-stud-tall quadruped pack-beast, neon teal stripes | Feed bioluminescent fruit (common-material harvested) | Cargo carry, mount |
| **Sporling** | Jungle | Small mushroom-creature pet | Mature near a Workshop (passive — proximity over time) | Sentry buff, decorative |
| **Forge Hound** | Volcanic | Dog-sized obsidian creature with lava core | Combat-bond (defeat without killing 5x in a row, then feed) | Combat companion, perimeter defender |
| **Ash Drake** | Volcanic | Small dragon-like flier (3 studs wingspan) | Egg find + 24-hour incubation | Aerial scout, mount (rideable in air — V2 vehicle alternative) |
| **Cryospine** | Ice | Small spiky snow creature, glides slightly | Scan with research tool (Tier 4+ Workshop unlock) | Scout aide (extends scout range +30%) |
| **Aerolarva** | All biomes (airborne) | Bee-sized swarm creature | Pheromone bait (consumable craft from Workshop) | Pollinate decorative flora; aesthetic flex (visible swarm cloud over colony) |

### 2.5 Boss

Rare scheduled events. Killed for unique rare materials per `V1_5_MATERIAL_CRAFTING.md` §2.3. 4-player co-op encounters in dedicated boss arenas (reuses raid place architecture).

| Boss | Biome | Cadence | Health | Drop |
|---|---|---|---|---|
| **Hive Queen** | Jungle | Monthly | 50,000 HP | `Hive Resonator`, `Nexus Bloom` (rare drop chance) |
| **Ember Titan** | Volcanic | Monthly | 60,000 HP | `Magma Heart`, `Forge Node` (rare drop chance) |
| **Eternal Sentinel** | Ice | Monthly | 55,000 HP | `Eternal Ice`, `Wraith Heart` (rare drop chance) |

Boss arenas are dedicated reserved-server places (same `ReserveServerAsync` pattern as raids and expeditions — likely shares the Expedition Place per V1_5_SCOUTING_EXPEDITIONS.md §9 risk #1, OR own dedicated `BossPlaceId` if PlaceId proliferation tradeoffs allow).

## 3. Capture mechanic

### 3.1 The Tracker tool

Tier 3+ unlock per `V1_5_TIER_PROGRESSION.md`. Requires Workshop tier 2.

- **Crafting cost:** 1,000 Credits + 5 Heat-Forged Steel + 3 Cryo Crystal + 2 Resin
- **Form factor:** handheld scanner device, 0.5-stud wide; visible in player's hand when equipped (V2 client-side tool model from `assets/tools/tracker/`)
- **Operation:** equip → emits a soft pulse SFX every 1.5s → on detection, points compass-needle toward nearest tameable creature within 80 studs; distance display + creature ID

### 3.2 Capture flow

1. **Locate** — Tracker compass guides toward target creature
2. **Approach** — must remain undetected (creatures have a 12-stud detection radius for "agitated" state); player crouch-walk reduces detection radius to 6 studs
3. **Specific tame method** — varies by species (per §2.4 table). Each species has a unique mini-mechanic:
   - Dawnstrider: hold the bait fruit out → creature approaches → press capture key when within 6 studs (timing window 2s)
   - Sporling: zone of effect — must spend 5 minutes within 16 studs of an active Workshop without combat triggering nearby
   - Forge Hound: combat-bond. Defeat in melee (Stamina-based, not Humanoid-kill) 5 times in a row → bond mini-game → feed for permanent tame
   - Ash Drake: find an egg in Predator Den expeditions (1/8 expedition completion chance) → place in Pen + 24-hour incubation → hatched
   - Cryospine: deploy Tracker in scan mode → scan creature for 30 seconds without disrupting → automatic capture
   - Aerolarva: craft pheromone bait at Workshop → place near jungle flora → swarm comes to bait → activate capture beam (creates a small swarm cloud entity)
4. **Failed capture** — creature flees + 1-hour cooldown before that specific creature spawns again in the player's plot area

### 3.3 Capture failure modes

- Detected before approach: creature flees full speed (impossible to catch this attempt)
- Mistimed capture key: brief stagger; can re-attempt within 30s
- Combat triggered during scan: scan resets to 0; cooldown applied
- Pen full at capture moment: capture succeeds but creature stored in **outside pen** holding (V2 limit: 3 outside-pen slots; 4th capture fails until pen space freed)

## 4. Breeding system

### 4.1 The Pen building

Tier 4+ unlock. New buildable.

- **Footprint:** 3×3 cells (12×12 studs)
- **Cost:** 5,000 Credits + 30 Hardened Vine + 20 Cryo Conduit + 10 Magnetic Vine
- **Geometry:** open-top enclosure with transparent dome roof, 4 corner posts with emissive teal LED strips, central feed/water trough, pet-bed pad areas around the perimeter
- **Capacity:** 4 pet slots base; +2 with V2 Master Tamer Game Pass (so 6 slots total max)

### 4.2 Pair selection

Both pet slots in the breeding pair must:
- Be the same species (no cross-species V2; V3 stretch goal)
- Be at "adult" maturity (age 7+ days from capture/hatch)
- Not already be in an active breeding cycle

Player selects via Pen UI: pick two adults → "Breed" button → confirm. Breeding cycle starts.

### 4.3 Breeding cycle

| Species | Cycle duration | Offspring count | Color variant chance |
|---|---|---|---|
| Dawnstrider | 12 hours | 1 | 1/100 (rare cyan-magenta variant) |
| Sporling | 8 hours | 1–2 | 1/200 (rare gold-cap variant) |
| Forge Hound | 18 hours | 1 | 1/100 (rare emerald-core variant) |
| Ash Drake | 24 hours | 1 (always single egg) | 1/300 (rare obsidian-scale variant) |
| Cryospine | 10 hours | 1–3 | 1/150 (rare arctic-aurora variant) |
| Aerolarva | 6 hours | 5–10 (swarm offspring) | 1/500 (rare iridescent variant) |

**Stat inheritance:** offspring averages parent stats with random ±10% variance. Selective breeding for stat-min-maxing is a long-tail meta hook.

**Color variants ("shinies"):** the 1/N rare-color drop is the proven retention hook. Each rare variant has a unique color palette + subtle visual difference (extra glow trail, larger size, etc.). Bragging-right tier.

### 4.4 Maturity progression

- **Egg / spore stage** (some species) — 12–24 hours after capture/breed; cosmetic-only
- **Juvenile** (day 1–7 post-hatch) — half stats, walk-only, can't deploy
- **Adult** (day 7+) — full stats, deployable, breedable

Time-shift accelerated by paying Cores (V2 dev product): "Maturity Accelerator" 99 R$ → +24h maturity progress; gives whales a way to optimize their breeding pipeline without trivializing the cycle for free players.

## 5. Deployment

Tamed adult creatures can be deployed in three modes. Each creature has a **primary** mode it's bred for; secondary modes are partial (lower effectiveness).

### 5.1 Mount mode

- Player rides on the creature → +60% movement speed; mounted creature can't be attacked while ridden
- **Best fit:** Dawnstrider (built for this); Ash Drake (aerial mount — flies above plot at low altitude)
- Toggled via HUD button when within 4 studs of the creature in pen or at the Mount Stable building (V2.1+ unlock)

### 5.2 Defender mode

- Assigned to perimeter; creature attacks alien wave incomings alongside turrets/drones
- Damage / HP / fire rate vary by species (Forge Hound is the heaviest melee defender; Cryospine is ranged ice-pulse)
- Creature dies if HP hits 0 → respawns in pen after 6-hour timer (V2 may add Resurrection Dev Product 99 R$)
- **Best fit:** Forge Hound, Cryospine

### 5.3 Cargo mode

- Creature AI-paths between buildings to carry materials/Credits between Workshops, extractors, stash
- Visual: idle income visualization — players can SEE their economy moving (proven retention shape)
- **Best fit:** Dawnstrider (cargo-bred)

### 5.4 Aesthetic mode

- Pure cosmetic — the creature wanders around the colony plot decoratively, no gameplay effect
- **Best fit:** Aerolarva (swarm cloud over flora), Sporling (sits near Workshop)

## 6. Migration events

Twice-weekly server-rotation events. 12-hour capture window per event. Drives daily-return ("don't miss tonight's Pulse Migration").

### 6.1 Event types

| Event | Cadence | Location | Spawn creature(s) | Capture mechanic |
|---|---|---|---|---|
| **Pulse Migration** | Tuesday + Friday 18:00–06:00 UTC | Jungle plots | Bioluminescent flock (Aerolarva + rare Spore Drake) | Pheromone bait |
| **Lavaflow Surge** | Monday + Thursday 18:00–06:00 UTC | Volcanic plots | Magma creatures temporarily emerge | Combat-bond |
| **Cryo Cascade** | Wednesday + Saturday 18:00–06:00 UTC | Ice plots | Glacial pack (Cryospine flock + rare Frost Stalker) | Tracker scan |

### 6.2 Spore Drake / Frost Stalker — event-exclusive species

Migration events introduce 2 species that can ONLY be captured during their respective events:
- **Spore Drake** (jungle, Pulse Migration only) — small 4-stud-wingspan flying creature; cosmetic-rare
- **Frost Stalker** (ice, Cryo Cascade only) — apex tameable; defender-mode-bred; high stats

Plus a future V2.1+ slot for **Inferno Wolf** (volcanic, Lavaflow event-exclusive).

This adds a hard FOMO loop: miss the event = miss the species. Players who can't make a session are locked out of that week's chance. **Risk:** anti-FOMO sentiment in the community. **Mitigation:** event repeats twice-weekly so players have two windows; missed-event "Migration Compass" Dev Product (199 R$) lets the player trigger a personal mini-migration with reduced spawn rate.

### 6.3 Event UI

- Migration calendar accessible from the codex panel — countdown to next event of each type
- 30-min and 5-min push notifications before event start (V2 client toast system)
- During event: special HUD banner "PULSE MIGRATION ACTIVE — 4h 12m remaining"
- Auto-tracker active during event (free, no Tracker tool required) for the event-exclusive species

## 7. Boss wildlife (4-player co-op)

Monthly boss events per §2.5. The communal endgame moment.

### 7.1 Encounter mechanics

- 4-player queue at the Boss Beacon building (V2 Tier 5+ unlock; placed once per server, owned by the highest-tier player or rotated by clan if matched)
- Beacon spawns the boss summon countdown (24h pre-event teaser → 1h "boss ready" → 4-player team enters)
- Group teleports to dedicated boss arena (reserved place — same TeleportService pipeline as raids/expeditions)
- 30-minute time limit; boss has phases (3 phases per boss; new mechanics every 33% HP threshold)
- Death: respawn in arena after 60s; if all 4 players die simultaneously, encounter wipes (no loot)

### 7.2 Per-boss mechanics

**Hive Queen (jungle):**
- Phase 1: melee swipes + summon waves of Stalkers
- Phase 2: ranged spore-bomb attacks
- Phase 3: Queen enrages, full mobility, AOE pulse damage on every kill landed by a player
- **Mechanic gimmick:** players must keep moving — stationary players take exponential damage from a "settling spore cloud" mechanic

**Ember Titan (volcanic):**
- Phase 1: ground-pound AOE; surrounding terrain becomes lava-floor (avoid)
- Phase 2: hurls obsidian boulders (telegraphed; players must dodge)
- Phase 3: Titan partially submerges and spawns 4 Magma Hands that grasp at players from below
- **Mechanic gimmick:** safe platforms shrink each phase — final phase has only 4 small islands of solid ground

**Eternal Sentinel (ice):**
- Phase 1: ranged crystal-shard volleys
- Phase 2: deploys 3 ice-mirror clones; players must identify the real Sentinel (subtle visual cue per attempt)
- Phase 3: arena freezes — 80% movement speed reduction; Sentinel resurrects fallen players as ice-thralls (PvE adds)
- **Mechanic gimmick:** mirror clones return damage to attackers

### 7.3 Loot distribution

- Per-player drop on encounter complete
- Roll table: 1 guaranteed boss-tier rare material + 5% chance for Quantum Filament (exotic) + 1/200 chance for unique Boss Trophy cosmetic per encounter
- Cooldown: 7 days per player per specific boss (so a player can do ~4 encounters/month total — 1 of each + 1 repeat)

## 8. UI/UX

### 8.1 Bestiary panel

Toggle button in the top HUD row (alongside Codex from `V1_5_SCOUTING_EXPEDITIONS.md`). Opens a centered panel.

- **Tabs:** Hostile / Neutral / Passive / Tameable / Boss
- **Grid:** all known species per tab; greyed for undiscovered (with silhouette + biome hint); colored for discovered
- **Per-creature card:** stat sheet, capture method, biome, taxonomy notes, kill count / capture count / breeding count stats
- **Color variant tracker:** for tameable species, shows "0/100 chance hit" with running attempt count → drives the rare-shiny grind

### 8.2 Pen UI

In-world hologram interface at each Pen building.

```
┌─────────────────────────────────────────┐
│  Pen — Bay 1                            │
│  ───                                    │
│  Slot 1: Dawnstrider "Bramble"  Adult   │
│  Slot 2: Dawnstrider "Vine"     Adult   │
│  Slot 3: Forge Hound "Ember"    Juv 4d  │
│  Slot 4: [Empty]                        │
│                                         │
│  [Breed Slots 1+2]  [Deploy] [Inspect]  │
│                                         │
│  Active breeding: none                  │
└─────────────────────────────────────────┘
```

- **Breed action:** opens pair selection modal; click two compatible adults → confirm → breeding cycle starts; offspring slot reserved
- **Deploy action:** picks a creature, mode (Mount/Defender/Cargo/Aesthetic), and confirms; creature animates to deploy position
- **Inspect action:** opens detail card with stats, parents (if bred), age, color variant flag, history

### 8.3 Boss arena UI

In-arena HUD overlay during boss encounters:
- Boss HP bar (large, top center)
- Phase indicator (1/3, 2/3, 3/3)
- 4-player party panel (left side) with HP/role indicators
- Mechanic warnings (center alerts for incoming AOEs, e.g., "INCOMING POUND — MOVE")

### 8.4 Migration calendar

Sub-tab in the Bestiary panel. Shows:
- Next 7 days of scheduled events
- "Time until next event of each type" countdowns
- Past 30 days of events (with player participation flags — drives FOMO recap)

## 9. Monetization integration

| Type | Name | Price | Effect | Risk |
|---|---|---|---|---|
| Game Pass | Master Tamer | 599 R$ | +2 Pen slots (4→6); 50% faster breeding; +1 simultaneous breeding pair (1→2); rare-color variant chance +1% (e.g., 1/100 → 1/95) | Medium — surface as ADR; minor PvE-tilt to color luck |
| Game Pass | Boss Hunter | 499 R$ | -1 day boss cooldown (7→6 day); +1 guaranteed rare material drop; auto-revive on 1st death per boss encounter | Medium — accelerates loot; ADR |
| Dev Product | Capture Net (5 charges) | 99 R$ | One-time captures bypass timing/scan mini-game; 5 uses per pack | Low — paying for convenience |
| Dev Product | Maturity Accelerator | 99 R$ | +24 hours to a juvenile creature's maturity (skip wait) | Low |
| Dev Product | Breeding Speed-Up | 49 R$ | Skip remaining time on one active breeding cycle | Low |
| Dev Product | Migration Compass | 199 R$ | Triggers personal mini-migration if missed scheduled event (50% spawn rate of full event) | **High** — ADR required; risks anti-FOMO complaint compounding monetization complaint |
| Cosmetic Pass | Boss Trophy Pack | 799 R$ | Display 6 unique Boss Trophy cosmetic emotes / pet leashes | Low |
| Cosmetic | Rare Variant Color Pack | 999 R$ | One guaranteed rare-variant color reroll per pack purchase (3 charges) | **Very high** — ADR required; this is essentially loot-box-adjacent paid-for-luck. Strong recommendation: **DO NOT SHIP** in this form. Replace with cosmetic-only paint pack at 599 R$. |

**Real-money flow rule:** any change to creature drop rates, breeding probabilities, or boss loot tables requires human approval per `10_BUILD_PROTOCOL.md`.

**Loot-box risk on the Rare Variant Color Pack:** marked as "do not ship in this form" above. The acceptable alternative is paying for direct cosmetic palette unlocks (no probabilistic luck). ADR pre-decision required before V2 launch; revisit Roblox 2026 loot-box policy before shipping.

## 10. Implementation cost + module breakdown

**Estimated:** 8–10 weeks. AI behaviors per species, capture/breeding state machines, migration event scheduler, boss-arena reserved-server orchestration.

### 10.1 New server modules

- `src/server/Modules/Wildlife/WildlifeRegistry.luau` (shared) — full creature catalog with per-species behavior tags
- `src/server/Modules/Wildlife/WildlifeSpawner.luau` — server-tick-based spawning of passive/neutral creatures across plots; respects migration events
- `src/server/Modules/Wildlife/CaptureService.luau` — owns the per-species capture mini-mechanics, Tracker tool tool integration
- `src/server/Modules/Wildlife/PenService.luau` — pen state per player, breeding cycle ticker, color-variant rolling, maturity progression
- `src/server/Modules/Wildlife/DeploymentService.luau` — manages Mount/Defender/Cargo/Aesthetic modes for deployed creatures
- `src/server/Modules/Wildlife/MigrationEventScheduler.luau` — server-time-based event activation, push notifications, event-exclusive spawn injection
- `src/server/Modules/Wildlife/BossEncounterLauncher.luau` — wraps `ReserveServerAsync` for boss arenas (similar to expedition pockets), 4-player teleport coordination
- `src/server/Modules/Wildlife/BossArenaSession.luau` — boss-arena-only lifecycle module, phase mechanics, loot distribution

### 10.2 New client modules

- `src/client/Modules/Wildlife/BestiaryPanel.luau`
- `src/client/Modules/Wildlife/PenController.luau`
- `src/client/Modules/Wildlife/CaptureUI.luau` (per-species capture mini-game UIs)
- `src/client/Modules/Wildlife/MigrationCalendar.luau`
- `src/client/Modules/Wildlife/BossArenaHUD.luau`

### 10.3 Schema additions

```luau
-- ProfileSchema.luau
ownedCreatures: { [string]: CreatureEntry },  -- key = creatureInstanceId (GUID)
activeBreeds: { [string]: BreedEntry },
discoveredCreatures: { [string]: number },    -- speciesId → first-seen timestamp
captureStats: { [string]: number },           -- speciesId → capture count
bossEncounterLastAt: { [string]: number },    -- bossId → last encounter timestamp (for cooldown)
penAcquireDate: number?,                       -- when pen was first built (unlocks anniversary cosmetic)

type CreatureEntry = {
    creatureId: string,
    speciesId: string,
    capturedAt: number,
    maturityAt: number,        -- timestamp when creature becomes adult
    stats: { hp, damage, speed, fireRate },  -- inherited from parents
    colorVariant: string?,     -- nil for common; "rare_cyan_magenta" etc. for rare drops
    mode: "stored" | "mount" | "defender" | "cargo" | "aesthetic",
    parentIds: { string }?,    -- for bred creatures, references parents
}
```

### 10.4 Constants additions

```luau
WILDLIFE = {
    PenSlotsBase = 4,             -- +2 with Master Tamer pass
    BreedingPairsBase = 1,        -- +1 with Master Tamer pass
    JuvenileMaturityDays = 7,
    BossEncounterCooldownDays = 7,  -- -1 with Boss Hunter pass
    BossArenaPlaceId = 0,         -- REPLACE_BEFORE_LAUNCH at Phase H
    -- MessagingService topics
    TopicMigrationEvent = "outpost.wildlife.migration",
    TopicBossOutcome = "outpost.wildlife.boss.outcome",
}

CREATURES = {
    -- per-species catalog: stats, capture method, breeding cycle, color variant probabilities
}

BOSSES = {
    -- per-boss config: HP, phase thresholds, loot tables, mechanics
}
```

### 10.5 New Remotes (~14)

`BestiaryState`, `PenState`, `RequestCapture`, `RequestBreed`, `RequestDeploy`, `RequestRecall`, `RequestInspect`, `MigrationActiveState`, `BossSummonState`, `RequestBossSummon`, `BossArenaState` (in-arena), `BossOutcome` (post-encounter), `RequestMaturityAccelerate`, `RequestBreedingSkip`.

### 10.6 V2 staging

- **V2.0 launch (week ~52):** 5 of 6 tameables, 2 of 3 bosses, all 3 migration events, full Pen + breeding loop. Total V2 launch creature catalog: ~30 creatures across all categories.
- **V2.1 (week ~58):** add 6th tameable (Aerolarva), 3rd boss, V2 puzzle mechanics for Ancient Ruin pockets, expand passive creature catalog
- **V2.2 (week ~64):** add 4 new migration event types, 2 new boss types, V3 stretch goals (cross-species breeding, hostile-tameable conversion)

## 11. Risks + open questions

1. **Boss arena PlaceId.** Adds another reserved-place architecture alongside raid + expedition. **Recommendation:** ADR before V2 launch. Likely option: share with Expedition Place — both are "instanced PvE pockets" with similar bootstrap shape; reserved instance branches on teleport-data type.
2. **Creature population scaling.** Per-server passive creature spawning at 50 CCU = ~150 active creatures = 150 server-side AI loops. **Mitigation:** decimate aggressively — only spawn passives near players (within 100 stud streaming radius); despawn when no player nearby.
3. **Breeding RNG perception.** A player who breeds 200 times without a rare variant will perceive the system as broken (even at 1/100 odds, two-sigma deviation says ~5% of players will hit 200 attempts). **Mitigation:** pity timer — guaranteed rare variant after N breeds without one (set N at 250 to make the median experience feel fair).
4. **Loot box ToS risk on Rare Variant Color Pack.** Strong recommendation per §9: do not ship that product in its current form. Use direct cosmetic unlocks instead.
5. **Boss encounter difficulty across player skill bands.** A 4-player team of mismatched-skill players may wipe repeatedly. **Mitigation:** matchmaking score based on tier + raid wins + boss completions; default to "skill-matched" queue with opt-out for clan-specific groups.
6. **Migration event server load.** 12-hour event windows could 2× server load due to migration spawning. **Mitigation:** event spawn cap per server (50 event creatures max simultaneous); test in V2 prep load testing.
7. **Anti-FOMO community concern.** 12-hour migration windows + monthly bosses = real anti-FOMO sentiment risk. **Mitigation:** explicit ADR pre-decision; consider shipping events as 24-hour windows initially, observe player feedback, then iterate.

---

## 8. Cross-references

- `V1_5_TIER_PROGRESSION.md` — Pen + Tracker buildings unlock at Tier 4+; NPC colonists arrive at Tier 5
- `V1_5_MATERIAL_CRAFTING.md` — boss kills drop rare materials; tameable creatures bred for unique craft inputs
- `V1_5_SCOUTING_EXPEDITIONS.md` — expedition pockets feature creatures from this catalog; Predator Den boss encounters
- `POST_V1_ROADMAP.md` — V2 sequencing relative to V1.5 launch

---

**End of V2_LIVING_JUNGLE.md.**
