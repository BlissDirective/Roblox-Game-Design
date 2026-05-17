# POST_V1_ROADMAP.md — V1.1 / V1.5 / V2 expansion roadmap

> **Status:** Approved 2026-05-05. Master sequencing doc for the four formalized tycoon expansions plus the existing brainstorm §2.9 deferred list. Updated as scope firms; dates relative to V1 launch (week 18 per brainstorm §3.2).

---

## 0. Summary

Four major tycoon expansions formalized in dedicated design specs:

| Doc | Scope | Window | Budget |
|---|---|---|---|
| `V1_5_TIER_PROGRESSION.md` | Drop Pod → Megacity 7-tier arc | V1.5 | 6–8 weeks |
| `V1_5_MATERIAL_CRAFTING.md` | 30+ materials + Workshop + Vehicle Builder | V1.1 seed → V1.5 full | 8–10 weeks |
| `V1_5_SCOUTING_EXPEDITIONS.md` | Solo PvE expeditions, 6 pocket types, codex | V1.5 | 5–7 weeks |
| `V2_LIVING_JUNGLE.md` | Tameable wildlife, breeding, migration events, monthly bosses | V2 | 8–10 weeks |

**Faction system (idea 4)** intentionally not formalized — held for re-evaluation when V2 player data shows whether identity/loyalty mechanics are actually retention-positive at this game's scale. May ship in V2.x or V3.

---

## 1. Sequencing principle

The four expansions are designed to **interlock**, not stand alone. Sequencing respects the dependency graph:

```
                  ┌──────────────────────────────┐
                  │  V1 LAUNCH (week 18)          │
                  │  — Phase A–E shipped          │
                  │  — assets in art queue        │
                  └──────────────┬───────────────┘
                                 │
                                 ▼
              ┌──────────────────────────────────────┐
              │  V1.1 (week ~22)                     │
              │  — 12 base materials + Workshop      │
              │    (CRAFTING tier 1, no UI builder)  │
              │  — closes E2.5 turret HP tech debt   │
              │  — battle pass season 1 cosmetics    │
              └──────────────┬───────────────────────┘
                             │  (V1.1 seeds the material loop;
                             │   V1.5 expands)
                             ▼
              ┌──────────────────────────────────────┐
              │  V1.5 (week ~30)                     │
              │  — TIER_PROGRESSION (full 7 tiers)   │
              │  — MATERIAL_CRAFTING (full UI)       │
              │  — SCOUTING_EXPEDITIONS (full)       │
              │  ──                                  │
              │  Tier system unlocks Workshop +      │
              │  Expedition Pad; Workshop crafts     │
              │  vehicles + uses materials sourced   │
              │  from expeditions. The three         │
              │  reinforce each other in one drop.   │
              └──────────────┬───────────────────────┘
                             │  (V1.5 is the major tycoon-depth
                             │   release; ~6 months post-launch)
                             ▼
              ┌──────────────────────────────────────┐
              │  V2.0 (week ~52)                     │
              │  — LIVING_JUNGLE (wildlife + bosses) │
              │  — Trading marketplace (deferred     │
              │    from §2.9; depends on V1.5 econ)  │
              │  — Auto-clip / replay system         │
              └──────────────┬───────────────────────┘
                             │  (V2 = identity + life;
                             │   ~12 months post-launch)
                             ▼
              ┌──────────────────────────────────────┐
              │  V2.1+ (week ~58+)                   │
              │  — Faction system (re-evaluate)      │
              │  — Player-built PvP arenas           │
              │  — Cross-biome trading               │
              │  — Seasonal events                   │
              │  — 4th–6th biomes                    │
              └──────────────────────────────────────┘
```

---

## 2. Why this sequencing

### 2.1 V1.1 seeds the loop early

The Workshop building + 12 base materials in V1.1 (week ~22) gives players who burn through the V1 daily-return stack a fresh secondary loop without committing to the full V1.5 build. Low risk: 12 materials + Workshop tier 1 + 6 basic blueprints is ~2 weeks of work; ~2 weeks ships in V1.1. Players who like it stay engaged for V1.5; players who don't haven't lost anything.

V1.1 also closes the E2.5 tech debt (turret invincibility) by adding turret HP per the deferred work in `PHASE_E_SOCIAL.md` — necessary infrastructure for V2 wildlife defenders.

### 2.2 V1.5 ships the three V1.5 docs together

Tier progression, material crafting, and scouting expeditions are designed to reinforce each other:
- **Tier gates Workshop access** (Tier 3+ unlocks Workshop)
- **Tier 4 unlocks Expedition Pad**
- **Workshops craft vehicles using materials sourced from expeditions**
- **Expedition codex unlocks new blueprints in the Workshop**
- **Vehicles (crafted) carry expedition loot back home**

Shipping any one of these alone produces a fragmented experience. Shipping all three together produces the V1.5 "tycoon depth" feel — the moment players realize Outpost-7 has a deep, layered economy. This is the spec'd 6-month-post-launch tentpole.

### 2.3 V2 is the emotional anchor

Wildlife (idea 5) is V2 because it requires V1.5's crafting + expedition systems to be in place — the boss creatures drop materials that crafting consumes; expeditions are where rare creatures are found. Without V1.5 substrate, V2 wildlife is collection-for-collection's-sake. With V1.5 substrate, it's collection-with-purpose.

### 2.4 Faction system held back

Idea 4 (`Research Tree + Corporate Sponsor Faction` from the original brief) is the most ambitious of the five — 6–8 weeks for the tech tree alone, plus identity/loyalty design that may or may not work at this game's scale. The honest call is: **wait for V2 data before committing.** If wildlife collection drives the desired retention, factions become incremental polish. If it doesn't, factions become essential. Re-evaluate at V2.0 launch + 6 weeks (week ~58); commit to a V2.x or V3 implementation based on data.

---

## 3. Cross-system integration map

| Mechanic | V1 | V1.1 | V1.5 | V2 |
|---|---|---|---|---|
| Currency (Credits) | ✅ | ✅ | ✅ | ✅ |
| Premium currency (Cores) | ✅ | ✅ | ✅ | ✅ |
| Materials | — | ✅ 12 base | ✅ 30+ full | ✅ + boss drops |
| Vehicles | concepts only | — | ✅ full builder | + boss-tier modules |
| Buildings | walls + extractor + turret + drone | + invincibility removed | + Workshop + Expedition Pad + Archive + Vehicle Factory | + Pen + Boss Beacon + Mount Stable |
| Tier progression | — | — | ✅ 7 tiers | + Tier 7 endgame (V2.x) |
| Expeditions | — | — | ✅ 6 pocket types | + new pockets per V2 creatures |
| Wildlife | hostile waves | — | — | ✅ full taxonomy |
| Breeding | — | — | — | ✅ |
| Migration events | — | — | — | ✅ 3 types |
| Bosses | — | — | — | ✅ 3 monthly |
| Faction identity | — | — | — | re-evaluate |

---

## 4. Implementation budget summary

Total V1.1 → V2.0 work: ~21–32 weeks of dev (across 14-month window). Solo dev with 10–20 hr/week per brainstorm §3.1 = ~150–500 hours over 14 months = within reach.

| Window | Weeks | New modules | New Remotes | Schema additions |
|---|---|---|---|---|
| V1.1 (week 22) | ~2 wk | ~5 server, 2 client | ~4 | materials seed |
| V1.5 (week 30) | ~12–18 wk | ~25 server, 12 client | ~30 | tier, materials full, expeditions, codex |
| V2.0 (week 52) | ~10–14 wk | ~12 server, 5 client | ~14 | wildlife, breeding, bosses, migration |
| **Total** | **~24–34 wk** | **~42 server, ~19 client** | **~48** | substantial |

These are infrastructure investments — by V2 the codebase is roughly 2× V1's size. The schema versioning system in `ProfileSchema.luau` handles the additive changes per the existing pattern.

---

## 5. Real-money flow escalation

Every monetization addition across these expansions requires human approval before merge per `10_BUILD_PROTOCOL.md`. Specific flagged ADRs needed *before* shipping:

- ADR-011 — Veteran Colony pass (V1.5 idea 1 §7) — perception risk
- ADR-012 — Material Pack / Reroll Daily / Breeding Speed-Up (V1.5/V2 dev products) — gacha-adjacent surface area
- ADR-013 — Migration Compass (V2 idea 5 §9) — anti-FOMO + monetization compounding risk
- ADR-014 — Rare Variant Color Pack (V2 idea 5 §9) — strong recommendation: do NOT ship in current form; replace with direct cosmetic unlocks

These ADRs land at the start of each release window's ~2-week prep phase, NOT at the end of implementation — gives 2 weeks for community/dev-forum surface check before launch.

---

## 6. Out of scope for this roadmap

Explicitly NOT covered here, intentionally:

- **Faction system** (idea 4 from the original brief) — re-evaluation at V2.0 + 6 weeks
- **Auto-clip / replay system** (brainstorm §2.9) — V1.5 or V2 polish work, not core mechanic
- **Trading marketplace between players** (brainstorm §2.9) — V2 economy depends on whether V1.5 crafting is monetizing well
- **Mobile UI overhaul** (brainstorm §2.9) — data-driven; ship if V1.1 mobile retention < desktop

These remain in `finalized-brainstorm.md` §2.9 deferred list. Cross-references added below in §7.

---

## 7. Cross-references

- `finalized-brainstorm.md` §2.8 V1 must-haves — V1 launch baseline (with the asset concepts addition added 2026-05-05)
- `finalized-brainstorm.md` §2.9 V1.5+ deferred list — pre-existing items not in the four formalized expansions
- `docs/playbooks/ASSETS.md` — V1 art queue (cross-references roadmap timing for asset integration)
- `docs/architecture/DECISIONS.md` — ADR log; future ADRs 011–014 for monetization escalations
- All four expansion docs (`V1_5_*.md`, `V2_*.md`)

---

**End of POST_V1_ROADMAP.md.**
