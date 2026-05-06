# V1_5_TIER_PROGRESSION.md — Colony Tier Progression

> **Status:** V1.5 design spec. Approved 2026-05-05 as a major V1.5 content drop expanding tycoon depth. Implementation budget ~6–8 weeks within the V1.5 release window. This doc is the single source of truth for the tier system; cross-referenced by `V1_5_MATERIAL_CRAFTING.md`, `V1_5_SCOUTING_EXPEDITIONS.md`, and `POST_V1_ROADMAP.md`.

---

## 0. North star

The player's first arrival is a single drop pod in a jungle clearing. Over weeks of play, that pod evolves through **7 visible tier silhouettes**, each one a distinct architectural identity, until they own a sprawling neon-lit megacity visible from orbit. The brainstorm §2.5 transformation spectacle (the "before / after" thumbnail moment) becomes the *entire game economy*.

This is a foundational addition — every existing tycoon system (placement, currency, raids, retention) plugs into the tier framework. V1's locked 64×64 plot becomes Tier 4 retroactively when this ships; pre-V1.5 players auto-grant to Tier 4 on the migration.

---

## 1. Why this is genuinely tycoon-shaped

- **Long-arc visual progression** — each tier is the natural session goal that drives daily-return ("just one more tier"); 40+ hour tier path produces 200+ hours of layered ambition.
- **Mid-tier walls force commitment cycles.** Saving up 80K Credits for the Tier 4 → Tier 5 gate creates visible spend goals; the brainstorm §4.3 "reinvest Credits" loop scales naturally.
- **Spectacle moments stack.** Each tier-up cinematic is auto-clipped; players post their tier-3-to-tier-4 transformation on TikTok per brainstorm §6.2 content strategy #1.
- **Endgame anchor.** Megacity (Tier 6) is a ~200-hour goal — competitive players race to be first-on-server-to-Megacity.

---

## 2. Tier breakdown

| # | Name | Plot size | Time-to-tier (est) | Major unlocks | Silhouette |
|---|---|---|---|---|---|
| 0 | Drop Pod | 8×8 studs | 0 (landing) | 1 extractor, 4 walls | White-orange capsule, 4 emissive ribs, single rotating beacon on top |
| 1 | Pioneer Tent | 16×16 studs | ~30 min | Basic turret, drone bay slot | 6-panel geodesic dome, semi-transparent windows, single airlock door, biome-themed exterior (vine-wrapped jungle / ash-streaked volcanic / frost-covered ice) |
| 2 | Forward Shelter | 32×32 studs | ~3 hr | Advanced wall types, perimeter floodlights | 3 connected modular pods with hex paneling, central command pod with raised antenna, exterior cargo crates |
| 3 | Operating Base | 48×48 studs | ~10 hr | **Workshop building** (see `V1_5_MATERIAL_CRAFTING.md`), heavy turret tier | 2-story tactical building, reinforced doors, central courtyard, single watchtower, fenced perimeter |
| 4 | Outpost | 64×64 studs (V1 base) | ~30 hr | **Vehicle Factory** + **Expedition Pad** (see `V1_5_SCOUTING_EXPEDITIONS.md`) | Walled compound, 4 corner watchtowers, vehicle entry gate, paved courtyard, banner pole |
| 5 | Settlement | 96×96 studs | ~80 hr | NPC colonists arrive, monorail tracks, energy substation | Sectored layout (military / civilian / industrial), monorail loop perimeter, central plaza, faction banner (V2 idea 4 cross-ref) |
| 6 | Megacity | 128×128 studs | ~200 hr (endgame) | **Faction super-building** (V2), drone traffic patrol routes | Layered skyscrapers, 3-ring defense (perimeter / mid / core), central plaza with name-engraved monument, public lighting grid, observation tower |

**Time-to-tier estimates** assume a non-Game-Pass player playing ~2 hr/day. Game Pass holders (2× Credits, Auto-Collect) hit Tier 4 in ~12 hours; Tier 6 in ~80 hours.

**Plot expansion** is non-destructive — existing buildings stay in place, the world simply unfolds outward. New cells are paved/themed per the new tier on tier-up.

## 3. Tier-up gates

Every tier-up requires **all three** to pass. The 60/20/20 weighting prevents both pure money rush and pure grind — players must engage with the full tycoon loop.

| Gate | Weight | Purpose |
|---|---|---|
| **Cumulative credits invested in plot** | 60% | The dominant tycoon spend signal — total Credits spent on placements (not just current-balance) |
| **N waves survived** | 20% | Engagement with PvE wave defense (E2 system) — prevents pure builders from skipping combat |
| **M raids attempted** | 20% | Engagement with PvP raid layer (E1 system) — offensive OR defensive count |

**Gate values per tier** (illustrative; tune in playtest):

| Tier | Credits invested | Waves survived | Raids attempted |
|---|---|---|---|
| 0→1 | 200 | 0 | 0 |
| 1→2 | 1,500 | 1 | 0 |
| 2→3 | 8,000 | 5 | 1 |
| 3→4 | 30,000 | 15 | 5 |
| 4→5 | 100,000 | 40 | 20 |
| 5→6 | 400,000 | 100 | 60 |

Schema additions to `ProfileSchema.luau`:
- `tier: number` (default 0; bumped by `TierService.PromoteToNext`)
- `creditsInvestedLifetime: number` (incremented by `PlacementService` on every successful placement, *not* refunded on demolish — sticky tycoon-spend signal)
- `waveSurvivedTotal` already exists as `wavesSurvived` from E2
- `raidsAttempted: number` (sum of `raidWins + raidLosses + raidsRaided + raidsDefended` — derived, not stored)

## 4. Tier-up cinematic

The spectacle moment per brainstorm §2.5 — designed to be auto-clipped (V1.5 auto-clip system, deferred from §2.9) and shared on TikTok.

**Sequence (8 seconds total):**

1. **0.0–0.5s** — Player input freezes. Gate-pass SFX swell (rising synthwave chord).
2. **0.5–2.0s** — Existing buildings dissolve in a layered teal-magenta glow; particles drift upward. Camera pulls back smoothly (no jitter — `TweenService` `EasingStyle.Quart`).
3. **2.0–6.0s** — Time-lapse reconstruction at new tier scale. Each new building snaps into place with a brief scale-in (0.05s per building). Drone swarm fly-by following camera (3 drones in formation).
4. **6.0–7.5s** — Camera holds on the new tier silhouette from a hero angle (3/4 elevated view).
5. **7.5–8.0s** — Banner: "Tier 4 Reached: Operating Base" — gold-stroke floating text, fades after 3s. Subtle confetti particles in faction colors.

**During the cinematic:**
- Player movement disabled
- Other players on this server see the affected player's plot pulse with a magenta-teal beacon (their tier-up is publicly visible — drives nearby observers' aspiration / FOMO)
- Auto-save 30-second clip to gallery (V1.5+ when auto-clip lands)

## 5. UI/UX

### 5.1 HUD progress indicator

- **Subtle progress bar** at HUD top edge — 1px tall when not active, 4px when hovered or when a gate just ticked closer
- Color: matches current tier theme (tier 0 white, tier 1 light teal, escalating to tier 6 gold)
- Tooltip on hover: "Tier 4 Outpost — 67% to Tier 5 (gate breakdown: ...)"

### 5.2 Tier-up panel (toggle button + modal)

Toggle button alongside the existing top-row HUD buttons (Store / Battle Pass / Clan / Leaderboard / Friends). Opens a centered panel:

```
┌─────────────────────────────────────────────────┐
│  Tier 3: Operating Base                         │
│  ────────────                                   │
│  [holographic 3D preview rotating slowly]       │
│                                                 │
│  Progress to Tier 4: Outpost                    │
│  ▓▓▓▓▓▓▓░░░  67%                                │
│                                                 │
│  Gates:                                         │
│   ✓ Credits invested:  18,500 / 30,000  [62%]   │
│   ✓ Waves survived:    8 / 15           [53%]   │
│   ⨯ Raids attempted:   3 / 5            [60%]   │
│                                                 │
│  Next tier unlocks:                             │
│   • Vehicle Factory (V1.5 — see ASSETS.md)      │
│   • Expedition Pad                              │
│   • Plot expanded to 64×64 studs                │
│                                                 │
│  [LOCK IN TIER UP] (disabled until all gates)   │
└─────────────────────────────────────────────────┘
```

The `LOCK IN TIER UP` button is the deliberate friction — players actively choose to tier up rather than auto-promoting. Lets them stockpile (e.g. wait until they've built up walls before tier-promoting and triggering the cinematic during a wave).

### 5.3 Tier comparison hover

Hovering a future-tier preview (greyed in the panel) shows a side-by-side silhouette comparison: current tier on left, hovered tier on right. Helps players visualize the climb.

## 6. Cosmetics + identity

### 6.1 Operator Tier evolution

Tier 4+ unlocks the **Operator Tier** cosmetic system. The player's operator armor (the 3 ASSETS.md skin packs — Recon / Combatant / Heavy Defender) gains tier-themed decals as the colony grows:

| Tier | Cosmetic addition |
|---|---|
| 4 | Subtle tier-3 chevron decal on left shoulder pauldron |
| 5 | Settlement insignia on chest (small, embroidered-style) |
| 6 | Megacity faction crest (full back panel, glowing trim) |

Decals are non-removable while the tier is held — visible identity flex. Phase G's asset pipeline ships these as overlay decals on the existing skin pack `BodyParts`, not full skin replacements.

### 6.2 Player monument (Tier 5+)

Settlement tier (5) unlocks a **Personal Monument** placed in the colony center plaza. Geometry: 4-stud-tall obelisk with the player's display name engraved + tier achievement date. Visible to raiders during raids (they see "Raided: <Name>'s Monument — Tier 5 Settlement"). Pure flex; no gameplay effect.

### 6.3 Tier-up commemorative emote

Each tier-up auto-grants a one-time commemorative emote (V1.5 emote system). Replays the tier-up moment as a pose. Can be triggered later for the photo-mode shot.

### 6.4 Megacity skybox + ambient sound

Tier 6 megacity has a custom skybox layer — extra atmospheric haze, distant city lights. Ambient sound layer adds subtle drone-traffic hum + distant vehicle whir. Phase G work; these skin features differentiate the endgame visually + sonically without affecting gameplay.

## 7. Monetization integration

| Type | Name | Price | Effect | Risk |
|---|---|---|---|---|
| Dev Product | Tier 1→2 Skip | 99 R$ | One-time tutorial accelerator (skips Pioneer Tent grind only) | Low — limited to first tier-up; bounded effect |
| Dev Product | Insight Boost (24h) | 199 R$ | +50% on cumulative-credits-invested gate progress for 24h | Low — accelerates a tier, doesn't trivialize |
| Game Pass | Veteran Colony | 499 R$ | Start fresh accounts at Tier 2 (skips first two tutorial tiers) | **Medium** — surface as ADR before launch; risks "this game is pay-to-win for first impressions" complaint. ADR should propose: tier 2 start does NOT bypass any gate values for tier 3+, so the long-arc grind is preserved |
| Cosmetic Pass | Tier Skin Pack | 299 R$ | Cosmetic-only building skins for tiers 4–6 (neon-glow accent variants) | Low — pure cosmetic |

**Real-money flow rule:** any change to tier gate values, tier IDs, or the Veteran Colony pass effect requires human approval per `10_BUILD_PROTOCOL.md` escalation rules.

## 8. Implementation cost + module breakdown

**Estimated:** 6–8 weeks within V1.5 release window.

### 8.1 New server modules

- `src/server/Modules/Tier/TierService.luau` — owns tier state per player; `PromoteToNext`, `GetTier`, `GetGateProgress` API; subscribes to `QuestObjectives.Emit` for "creditsInvested", "waveSurvived", "raidAttempted" event accumulation.
- `src/server/Modules/Tier/TierGateEvaluator.luau` — pure logic; given player profile, returns gate progress + boolean readiness.
- `src/server/Modules/Tier/TierCinematicService.luau` — orchestrates the 8-second tier-up sequence (camera, particles, building dissolve+rebuild, banner). Server-coordinated, client-rendered.
- `src/server/Modules/World/PlotExpander.luau` — non-destructively grows the plot to the new tier's size; wraps `PlotManager.buildPlot` for the per-tier dimensions.

### 8.2 New client modules

- `src/client/Modules/Tier/TierController.luau` — toggle button + tier panel UI + HUD progress indicator
- `src/client/Modules/Tier/TierCinematicController.luau` — camera control, particle spawning, audio cue playback during the cinematic

### 8.3 Schema additions

```luau
-- ProfileSchema.luau (additive, default safe)
tier: number,                        -- default 0 (Drop Pod); migration sets 4 for V1 carryovers
creditsInvestedLifetime: number,     -- default 0; PlacementService increments on placement
-- raidsAttempted derived from raidWins + raidLosses + raidsRaided + raidsDefended (no new field)
```

### 8.4 Constants additions

```luau
TIER = {
    GateRequirements = {
        [1] = { credits = 200,    waves = 0,   raids = 0  },
        [2] = { credits = 1500,   waves = 1,   raids = 0  },
        [3] = { credits = 8000,   waves = 5,   raids = 1  },
        [4] = { credits = 30000,  waves = 15,  raids = 5  },
        [5] = { credits = 100000, waves = 40,  raids = 20 },
        [6] = { credits = 400000, waves = 100, raids = 60 },
    },
    PlotSizePerTier = {
        [0] = 8,  [1] = 16, [2] = 32, [3] = 48,
        [4] = 64, [5] = 96, [6] = 128,
    },
    CinematicDurationSeconds = 8,
}
```

### 8.5 New Remotes

- `TierState` (S→C event) — pushes `{ tier, gateProgress }` on join + on every gate-progress tick
- `RequestTierUp` (C→S RemoteFunction) — player taps the LOCK IN button; server validates all gates + triggers cinematic

### 8.6 Cross-system hooks

- `PlacementService` — on every successful placement (non-trusted), emit `creditsInvested` to `QuestObjectives`; `TierService` subscribes and increments `creditsInvestedLifetime`
- `WaveDirector` — already emits `wave_survived`; `TierService` subscribes
- `RaidRewardService` — emit `raid_attempted` per outcome; `TierService` subscribes

### 8.7 V1 → V1.5 migration

When V1.5 launches, every existing V1 player profile is migrated:
- Set `tier = 4` (the V1 plot is the Tier 4 Outpost)
- Set `creditsInvestedLifetime` = `credits + sum(buildable cost for every entry in baseLayout)` (best-effort backfill; new fresh value is already correct going forward)
- Cinematic skipped on migration (no spectacle for retroactive promotion)
- One-time `TierMigrationCompleted` toast: "Welcome to V1.5 — your colony is now Tier 4: Outpost"

Migration runs lazily on next `LoadPlayer` per the existing `ProfileSchema.Migrate` pattern (versioned schema bump).

## 9. Risks + open questions

1. **Cinematic camera ownership.** The 8-second cinematic locks player input; if a wave fires *during* the cinematic, do enemies still damage the player? **Recommendation:** wave spawning paused during tier-up cinematic; `WaveDirector.Pause(player, 8)` API.
2. **Multi-player cinematics on shared servers.** Two players hitting tier-up within seconds of each other — do their cinematics overlap? **Recommendation:** per-player cinematic camera; nearby players see the *other* player's plot pulse but don't have their own camera locked.
3. **Veteran Colony pass perception risk.** Surfacing this monetization path before V1.5 ships lets us brief on Discord/dev-forum first. **Recommendation:** ADR pre-decision before V1.5 launch.
4. **Tier 6 endgame retention.** Once a player hits Megacity, what keeps them logging in? **Recommendation:** Tier 6 unlocks faction super-buildings (V2) AND seasonal "Era" cosmetic resets (every 90 days); deferred to V2 design.

---

## 8. Cross-references

- `V1_5_MATERIAL_CRAFTING.md` — Workshop unlocks at Tier 3; Vehicle Factory at Tier 4
- `V1_5_SCOUTING_EXPEDITIONS.md` — Expedition Pad unlocks at Tier 4
- `V2_LIVING_JUNGLE.md` — NPC colonists arrive at Tier 5; Pen + Tracker at Tier 4
- `POST_V1_ROADMAP.md` — sequencing relative to V1 launch + V1.1 / V2 windows

---

**End of V1_5_TIER_PROGRESSION.md.**
