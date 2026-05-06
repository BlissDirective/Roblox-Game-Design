# V1_5_MATERIAL_CRAFTING.md — Material Crafting + Vehicle Workshop

> **Status:** V1.5 design spec. Approved 2026-05-05. Largest of the V1.5 expansion ideas at ~8–10 weeks budget. Tier 1 (12 base materials + Workshop building, no full crafting UI) may ship in V1.1 to seed the loop early. Cross-references `V1_5_TIER_PROGRESSION.md` and `V1_5_SCOUTING_EXPEDITIONS.md`.

---

## 0. North star

Beyond Credits, the planet hides 30+ exotic materials across 3 biomes. Players harvest, refine, and craft custom vehicles, weapons, and base modules in dedicated workshops. Vehicles are personal — share blueprints, show off custom paint, dominate raids with optimized builds.

This is the second economic layer. Credits remain the universal currency for placement and shop purchases. Materials are the *crafting* economy — bound to specific blueprints, with biome specialization driving meaningful trade and player diversity.

---

## 1. Why this is genuinely tycoon-shaped

- **Secondary loop alongside Credits.** Per-biome material specialization gives the existing 3-biome design (jungle / volcanic / ice) economic significance — currently biomes only differ in lighting / aesthetics; with materials, each biome becomes a *resource specialty*.
- **Long-tail collection drive.** Exotic materials gate legendary blueprints. The "I need 1 more Quantum Filament" goal is a 30+ session ambition.
- **Creative expression.** The Vehicle Builder UI lets players express identity through blueprint design choices. Sharing blueprints (8-char code) creates server-wide social proof.
- **Crafting timers drive return visits.** 5–30 second instant crafts for common items; 2–24 hour timers for exotic blueprints. Daily-return reinforced.

---

## 2. Material taxonomy

Four rarity tiers across three biomes plus a universe-wide exotic tier. Common materials are the baseline daily harvest; exotics are seasonal endgame.

### 2.1 Common (4 per biome — 12 total)

Abundant. Drop from specialty extractors (new buildable subclass; the existing E2 extractor is the *generic* Credits extractor). Stack size: 9999 per material in inventory.

| Material | Biome | Visual | Specialty extractor color |
|---|---|---|---|
| **Bioluminescent Sap** | Jungle | Translucent magenta liquid in a glass vial | Magenta-glow extractor |
| **Hardened Vine** | Jungle | Dark green twisted fiber bundle | Deep-green extractor |
| **Glow-Fungus** | Jungle | Cyan luminescent mushroom cluster | Cyan-glow extractor |
| **Resin** | Jungle | Amber crystalline blob | Amber extractor |
| **Obsidian Shard** | Volcanic | Jet-black sharp crystal | Black extractor |
| **Sulfur** | Volcanic | Bright yellow chunk | Yellow extractor |
| **Heat Crystal** | Volcanic | Glowing red-orange gem | Red-glow extractor |
| **Volcanic Glass** | Volcanic | Smoky translucent shard | Charcoal extractor |
| **Cryo Crystal** | Ice | Pale blue crystal | Pale-blue extractor |
| **Frost Mineral** | Ice | White granular powder | White extractor |
| **Ice Conduit** | Ice | Translucent blue tube fragment | Translucent-blue extractor |
| **Pure Water** | Ice | Liquid in cryo-sealed vial | Pearl-white extractor |

### 2.2 Uncommon (3 per biome — 9 total)

Found via scouting expeditions (`V1_5_SCOUTING_EXPEDITIONS.md`) and rare boss encounters (`V2_LIVING_JUNGLE.md`). Stack size: 999.

| Material | Biome | Source |
|---|---|---|
| **Predator Carapace** | Jungle | Stalker-Alpha boss kill (idea 5) or jungle Predator Den expedition |
| **Spore Capsule** | Jungle | Alien Nest expedition; rare drop |
| **Magnetic Vine** | Jungle | Resource Field expedition; deeper-zone-only |
| **Lava Diamond** | Volcanic | Predator Den expedition; Forge Hound kill |
| **Eruption Stone** | Volcanic | Storm Pocket expedition (volcanic biome) |
| **Heat-Forged Steel** | Volcanic | Crash Site expedition; salvageable from wrecked tech |
| **Cryo Diamond** | Ice | Ancient Ruin expedition (ice biome) |
| **Glacial Core** | Ice | Resource Field expedition; deep-zone Cryospine bait |
| **Wraith Essence** | Ice | Cryowraith kill (V2 boss creature) |

### 2.3 Rare (2 per biome — 6 total)

Endgame materials. Harvested from boss-tier wildlife or alien ruin chambers. Stack size: 99.

| Material | Biome | Source |
|---|---|---|
| **Nexus Bloom** | Jungle | Hive Queen monthly boss drop |
| **Hive Resonator** | Jungle | Ancient Ruin deep-tier puzzle reward |
| **Magma Heart** | Volcanic | Ember Titan monthly boss drop |
| **Forge Node** | Volcanic | Ancient Ruin deep-tier puzzle reward |
| **Eternal Ice** | Ice | Eternal Sentinel monthly boss drop |
| **Wraith Heart** | Ice | Ancient Ruin deep-tier puzzle reward |

### 2.4 Exotic (3 universe-wide — cross-biome, super-rare)

Universe-wide drops. Stack size: 9. The legendary blueprints gate at exotic-material costs.

| Material | Source | Drop chance |
|---|---|---|
| **Quantum Filament** | Any boss kill | 1/100 |
| **Singular Core** | Storm Pocket expedition completion | 1/200 |
| **Void-Touched Alloy** | Faction super-building (V2 idea 4) byproduct OR cross-clan raid super-loot | Conditional |

## 3. Workshop building

Tier 3+ unlock per `V1_5_TIER_PROGRESSION.md`. New buildable in `BuildableRegistry`.

### 3.1 Geometry

- **Footprint:** 4×4 cells (16×16 studs) — substantial; takes a meaningful plot bite
- **Height:** 8 studs to roof
- **Cost:** 3,000 Credits + 50 Hardened Vine + 30 Obsidian Shard + 20 Cryo Crystal (forces multi-biome material engagement before the player can craft)
- **Visible internals via transparent panels:**
  - Rotating overhead crane with manipulator claws
  - Forge with constant low ember-glow + occasional spark VFX
  - Holographic blueprint projection above the assembly platform
  - Material conveyor belt visible on left wall (decorative; loops continuously)
- **Material color:** matches active blueprint's biome (jungle = magenta-teal; volcanic = molten orange; ice = blue-white)

### 3.2 Workshop tier upgrades

The Workshop itself has 3 internal tiers, each unlocking deeper crafting access. Upgrading a Workshop costs progressively more materials.

| Workshop tier | Unlocks | Upgrade cost |
|---|---|---|
| 1 (default on placement) | Basic blueprints (common-material gear: walls, basic turret, basic vehicle frame) | n/a (placed at this tier) |
| 2 | Uncommon-material blueprints (advanced turret, vehicle modules, custom paint) | 5,000 Credits + 20 of each uncommon material from at least 2 biomes |
| 3 | Rare + exotic blueprints (legendary vehicle chassis, super-buildings, faction gear) | 25,000 Credits + 10 of each rare material from all 3 biomes |

### 3.3 Crafting flow

1. Player approaches Workshop and interacts with the holographic interface
2. Browse blueprint library (categorized: Defense / Vehicle / Utility / Cosmetic)
3. Select blueprint → see required materials + craft time
4. Confirm → materials deducted from inventory atomically (`MaterialInventoryService.TrySpend` chokepoint, mirrors `CurrencyService.TrySpend`)
5. Craft animates: 5s for common, 30s–2min for uncommon, 1–24 hours for rare/exotic
6. Completion: forge sparks, item slides out of the assembly platform, auto-deposits to inventory or directly to the placement queue (player choice)

**Long-craft handling:**
- Crafts >5 minutes can be queued (player offline-OK); persisted in `profile.Data.activeCrafts: { [craftId]: CraftEntry }`
- Up to 3 concurrent craft slots (Game Pass holders +1)
- Server tick every 60s scans active crafts for completion; pushes notification + adds to inventory

## 4. Vehicle Builder UI

The crown jewel of this system. Modular slot-based UI similar to *No Man's Sky* freighter customization or *Starbase* ship builder.

### 4.1 Modular slot system

```
┌──────────────────────────────────────────────────┐
│  Vehicle Builder — "My Hover Tank"               │
│  ────                                            │
│                                                  │
│  ┌────────────────┐  Stats:                      │
│  │                │   Health    ▓▓▓▓▓▓▓░░  72%   │
│  │   [3D PREVIEW] │   Speed     ▓▓▓▓░░░░░  44%   │
│  │   rotates      │   Damage    ▓▓▓▓▓▓░░░  62%   │
│  │                │   Range     ▓▓▓▓▓░░░░  56%   │
│  │                │   Fuel use  ▓▓▓▓░░░░░  45%   │
│  └────────────────┘                              │
│                                                  │
│  Chassis:    [Hover Tank   ▼]  (Heavy)           │
│  Powertrain: [Plasma Drive ▼]  (Tier 2)          │
│  Armor:      [Reinforced   ▼]  (3 plates)        │
│  Weapon 1:   [Laser MG     ▼]                    │
│  Weapon 2:   [Empty]       [+]                   │
│  Utility:    [Repair Field ▼]                    │
│  Paint:      [Vanguard Red ▼]                    │
│                                                  │
│  Cost to craft:                                  │
│   • 800 Credits                                  │
│   • 12 Heat-Forged Steel                         │
│   • 5 Lava Diamond                               │
│   • 1 Quantum Filament                           │
│                                                  │
│  Craft time: ~8 hours                            │
│                                                  │
│  [TEST DRIVE]  [SAVE BLUEPRINT]  [CRAFT]         │
└──────────────────────────────────────────────────┘
```

### 4.2 Chassis (3 base + future expansions)

The 3 vehicle concepts from `docs/playbooks/ASSETS.md` §4.6 become the base chassis catalog:

| Chassis | Class | Base stats |
|---|---|---|
| Sleek Hover Bike | Light | High speed, low health, 1 weapon slot |
| All-Terrain Rover | Medium | Balanced, 2 weapon slots, cargo bonus |
| Armed Hover Tank | Heavy | High health, low speed, 2 weapon slots, gunner-mode capable |

### 4.3 Per-slot stat tradeoffs

Every module has positive AND negative stat impacts — no module is strictly better. The builder UI surfaces tradeoffs as colored bar deltas (green up, red down).

**Example — Powertrain options:**

| Powertrain | Speed | Fuel use | Cost | Materials |
|---|---|---|---|---|
| Standard | +0 | +0 | 100 cr | 5 Resin |
| Plasma Drive | +30% | +20% | 400 cr | 3 Heat Crystal + 2 Lava Diamond |
| Cryo-Coil | +10% | -25% | 600 cr | 5 Cryo Crystal + 3 Cryo Diamond |
| Quantum Drive | +50% | -50% | 2000 cr | 1 Quantum Filament + 5 Heat Crystal |

**Example — Weapon options:**

| Weapon | Damage | Range | Fire rate | Notes |
|---|---|---|---|---|
| Twin Plasma | Med | Med | Fast | Vehicle-scaled E2 turret pattern |
| Laser MG (default tank turret) | Low | High | Very fast | Anti-swarm |
| Heavy Cannon | Very High | Low | Very slow | Anti-armor; recoil staggers light vehicles |
| Cryo Beam | Low | Med | Med | Slows enemies on hit (status effect) |

### 4.4 3D preview

Full WASD-rotatable preview pane. Real-time updates as the player swaps modules — the new module mesh slides into place via `TweenService` (1s smooth swap, no jarring snap). Player can zoom in/out (mobile pinch + desktop scroll).

### 4.5 Test Drive sandbox

Click "Test Drive" — player teleports to a small dedicated sandbox plot (50×50 stud arena, instanced per player) with the current build configured. Free to drive around for up to 3 minutes. No materials committed, no actual craft started. Returns to colony on timer expiry or manual exit.

### 4.6 Blueprint library

- 5 saved blueprint slots per player (Game Pass +3)
- Each blueprint has: name, thumbnail (auto-rendered from preview), config snapshot, total stats summary
- **Share via 8-char alphanumeric code** (e.g. `XK4M-9P2A`). Pasteable in chat, on Discord, etc. Recipient enters code in their builder → loads the configuration (must own / craft the materials themselves to actually craft it)
- Community-shared blueprint browser (V1.5 panel; in-game): browse top-rated configurations by category. V2 may add a marketplace where blueprints can be sold for Credits between players (separate from the brainstorm §2.9 trading marketplace deferred for V1.5 — different scope).

## 5. Vehicle paint system

Paint is the primary social-flex layer. Cosmetic-only — no gameplay impact — but visible from raid distance. Paint jobs unlock progressively across factions, battle pass, achievements.

### 5.1 Layered paint system

| Layer | Options | How unlocked |
|---|---|---|
| **Primary color** | 24 base colors | Default access |
| **Secondary color** | 24 base colors | Default access |
| **Decal pattern** | 16 patterns (stripes, hex, camo, splatter, etc.) | Battle pass tier rewards + faction affiliation |
| **Trim** | 8 trim styles (chrome, gold, neon-glow, etched) | Achievement / Workshop tier 3 unlocks |
| **Emissive accent** | On / off + 8 colors | Default access (but emissive-on uses 1 Heat Crystal per paint) |

### 5.2 Faction paint unlocks (V2 cross-ref)

Each V2 faction (idea 4 — deferred) ships 1 default + 3 unlockable paint patterns:

| Faction | Default | Tier-up unlocks |
|---|---|---|
| Vanguard | Charcoal + red trim | "Forged in Battle", "Crimson Dawn", "Last Stand" |
| Helios | Amber + white | "Gold Standard", "Sunburst", "Empire" |
| Cryosphere | Cold blue + white | "Glacial", "Quantum", "Pure Logic" |
| Verdant | Deep green + magenta | "Symbiote", "Nightbloom", "Pulse" |

### 5.3 Custom paint recipes

Legendary paints require materials beyond the base credit cost. Example: "Quantum" paint costs 1 Quantum Filament + 5 Cryo Crystal + 3 Heat-Forged Steel — gates the absolute-top-tier cosmetic flex behind grind even for paying players.

## 6. Material inventory + UI

### 6.1 Inventory schema

Schema additions to `ProfileSchema.luau`:

```luau
-- Inventory by material id; default empty per-key (filled lazily on first acquisition)
materials: { [string]: number }
-- Active long-running crafts per player; cleared on completion
activeCrafts: { [string]: CraftEntry }
-- Saved blueprint slots
vehicleBlueprints: { [string]: VehicleBlueprint }

type CraftEntry = {
    craftId: string,
    blueprintId: string,
    startedAt: number,
    completesAt: number,
    materialsCommitted: { [string]: number },  -- for refund on cancel
}

type VehicleBlueprint = {
    name: string,
    chassis: string,
    modules: { [string]: string },  -- slot → moduleId
    paint: PaintConfig,
    shareCode: string,  -- 8-char alphanumeric
    createdAt: number,
}

type PaintConfig = {
    primary: Color3,
    secondary: Color3,
    decal: string?,
    trim: string?,
    emissive: { enabled: boolean, color: Color3? },
}
```

### 6.2 Material inventory panel

Tabbed by biome (Jungle / Volcanic / Ice / Exotic). Sorted by rarity within each tab. Hover tooltip shows: rarity, source (where to find), used-by (which blueprints need it). Quick-jump button: "Show me how to get more" → opens scouting expedition browser if expedition-sourced.

### 6.3 Workshop panel

- **Active crafts:** queue list with completion timers, "speed up with Cores" option (V1 premium currency from D2 Core Pack)
- **Browse blueprints:** filtered library, search bar, "Ready to craft" filter (only show blueprints whose materials I currently have)
- **Saved blueprints:** my 5 slots, share-code copy button, Edit / Craft buttons per slot

### 6.4 Vehicle showroom

Tier 4+ unlocks a **Showroom** (3×3 cell building, ~2000 cr). Place up to 3 of your saved-blueprint vehicles on display pedestals. Visible to raiders during raids and to friends visiting the colony (V1.5 observe colony — currently deferred per E5 worklog tech debt). Pure flex.

## 7. Monetization integration

| Type | Name | Price | Effect | Risk |
|---|---|---|---|---|
| Game Pass | Master Engineer | 599 R$ | +1 Workshop craft slot (3→4); +1 Workshop tier (start at T1 = T2 capability); 50% faster craft times; +3 blueprint slots (5→8) | Low — accelerates grind, doesn't trivialize |
| Game Pass | Customizer | 299 R$ | +8 paint pattern unlocks; +1 emissive layer; vehicle-name-engraved nameplate | Low — pure cosmetic |
| Dev Product | Material Pack — Common (10 each) | 49 R$ | 10 of every common material across all 3 biomes | Low — small economy boost |
| Dev Product | Material Pack — Rare (3 random) | 199 R$ | 3 random rare materials | **Medium** — gacha-adjacent; surface ToS risk + ensure deterministic per-purchase reveal (no loot box) |
| Dev Product | Craft Speed Up | 99 R$ | Skips remaining craft time on one active craft (consumes 50 Cores' worth) | Low — pay-to-time-skip standard |
| Cosmetic | Legendary Blueprint Pack | 799 R$ | 12 visual-only blueprints (cosmetic blueprints — own them as showcase/reference, can craft to display) | Low |

**Real-money flow rule:** any change to material drop rates, craft times, or blueprint pricing requires human approval per `10_BUILD_PROTOCOL.md`.

**Loot box risk on "Material Pack — Rare":** to stay clear of Roblox's loot-box guidance, the pack should reveal contents *before* purchase OR offer guaranteed deterministic distribution (e.g., always the same 3 materials in rotation, refreshed weekly). ADR pre-decision required.

## 8. Implementation cost + module breakdown

**Estimated:** 8–10 weeks. Largest of the V1.5 ideas. Schema-heavy.

### 8.1 New server modules

- `src/server/Modules/Crafting/MaterialInventoryService.luau` — inventory chokepoint (`Add`, `TrySpend`, `Get`); mirrors `CurrencyService` patterns
- `src/server/Modules/Crafting/CraftingService.luau` — owns active crafts, tick-based completion checker, Workshop tier gating
- `src/server/Modules/Crafting/BlueprintRegistry.luau` — full catalog of craftable items + their material costs + craft times
- `src/server/Modules/Crafting/SpecialtyExtractorService.luau` — extends `CurrencyService.RegisterExtractor` with material-specific drops (the 12 specialty extractor variants — magenta-glow, etc.)
- `src/server/Modules/Vehicle/VehicleBlueprintService.luau` — saves/loads/shares blueprints; share-code encode/decode
- `src/server/Modules/Vehicle/VehicleSpawnService.luau` — instantiates a configured vehicle from a blueprint at the Vehicle Factory location
- `src/server/Modules/Vehicle/PaintService.luau` — applies layered paint config to spawned vehicle MeshParts at runtime

### 8.2 New client modules

- `src/client/Modules/Crafting/MaterialInventoryPanel.luau`
- `src/client/Modules/Crafting/WorkshopPanel.luau`
- `src/client/Modules/Vehicle/VehicleBuilderUI.luau` (the big one — 3D preview, slot system, stat bars, paint picker)
- `src/client/Modules/Vehicle/TestDriveController.luau` (sandbox teleport handling)
- `src/client/Modules/Vehicle/BlueprintLibraryPanel.luau`

### 8.3 Constants additions

```luau
CRAFTING = {
    MaxConcurrentCraftsBase = 3,  -- +1 with Master Engineer pass
    MaxBlueprintSlotsBase = 5,    -- +3 with Master Engineer pass
    WorkshopTierUpgradeCosts = { ... per tier ... },
    SpeedUpCoresPerMinute = 1,
}

MATERIALS = {
    -- per-material catalog metadata: rarity, biome, default specialty extractor stats, etc.
}

VEHICLE = {
    -- per-chassis / per-module catalogs
}
```

### 8.4 New Remotes (~12)

`MaterialInventoryState`, `CraftingState`, `RequestCraft`, `CancelCraft`, `RequestSpeedUp`, `BlueprintList`, `SaveBlueprint`, `DeleteBlueprint`, `LoadShareCode`, `RequestTestDrive`, `RequestSpawnVehicle`, `RequestPaintApply`.

### 8.5 V1.1 seed scope

To validate the loop early, V1.1 (week ~22) ships:

- 12 common materials (the §2.1 catalog only)
- Specialty extractors as new buildables (no UI builder yet — just placement)
- Workshop building (Tier 1 only, no upgrades)
- 6 basic blueprints: Heavy Cannon Turret, Burst Laser Turret, basic vehicle frame (no modules), 3 wall variants
- Material inventory panel only (no Workshop UI — crafting via interact prompt only)

V1.5 (week ~30) adds full crafting UI, vehicle builder, paint, all uncommon/rare/exotic materials, blueprint library + sharing.

## 9. Risks + open questions

1. **Storage cost scaling.** A heavy player may accumulate `materials: {}` with 30+ keys × counts. At ~50 chars per row, 30 rows × 4 bytes per number = under 2KB per profile. Well within DataStore quota; non-issue.
2. **Atomicity of craft commit.** If `MaterialInventoryService.TrySpend` succeeds but `CraftingService.QueueCraft` fails (DataStore hiccup), materials are lost. **Mitigation:** mirror the `ClanStashLedger.TryDeposit` refund pattern — deduct, queue, refund on failure.
3. **Blueprint share-code collision.** 8-char alphanumeric = 36^8 = ~2.8 trillion codes. Negligible collision risk for V1.5; V2 may add per-server scoping or longer codes.
4. **Test Drive sandbox isolation.** A player in test drive must NOT take damage from waves or raiders. **Recommendation:** sandbox teleports to a per-player reserved server (same `ReserveServerAsync` pattern as raids); 3-minute timer enforced server-side.
5. **Vehicle-on-vehicle PvP.** V1.5 vehicles in raid context — does the attacker drive their tank into the defender's snapshot base? **Decision deferred:** V1.5 ships vehicles as colony-only; raid integration is V2 work alongside snapshot rendering.

---

## 8. Cross-references

- `V1_5_TIER_PROGRESSION.md` — Workshop unlocks at Tier 3; Vehicle Factory at Tier 4
- `V1_5_SCOUTING_EXPEDITIONS.md` — uncommon materials harvested via expedition pockets
- `V2_LIVING_JUNGLE.md` — boss wildlife drops rare materials; tameable creatures bred for unique craft inputs
- `POST_V1_ROADMAP.md` — V1.1 seed (basic 12 materials + Workshop) → V1.5 full crafting

---

**End of V1_5_MATERIAL_CRAFTING.md.**
