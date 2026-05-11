# PHASE G — Aesthetic Pass

> Per-sub-phase worklog. Updated by Claude Code at the end of each
> sub-phase per `10_BUILD_PROTOCOL.md` (Plan → Confirm → Build → Verify
> → Commit → Report).

**Goal (per `finalized-brainstorm.md` §4.8 + `10_BUILD_PROTOCOL.md`
Phase G):** The game looks and sounds like a real product.
Bioluminescent jungle aesthetic, synthwave audio, sleek operator UI,
cosmetic system replacing D4 placeholder BP rewards.

**Phase audit gate:** Vibe check with 2–3 friends. Honest reactions.
Does it feel like a real product or a prototype?

---

## Phase research pass (run at kickoff)

Three parallel searches recorded findings:

- **Lighting tech 2026:** `Technology` was replaced Jan 2025 with
  `LightingStyle` (Soft / Realistic). Outpost-7 mobile-first →
  ShadowMap (Soft) balances quality + performance.
- **Active light cap:** < 50 per area for mobile.
- **CastShadow = false** on decorative parts.
- **Atmosphere** object handles haze/scattering for the bioluminescent
  fog vibe — better than per-pixel lighting cost.
- **Avoid excessive Neon material** on mobile.

---

## G1 — BiomeLightingService + 3 biome profiles ✅

**Date:** 2026-05-05
**Branch:** `claude/audit-phases-a-d-2BAuW`
**Commit:** `4a74f55`

### What was built

- `Constants.BIOME` block with `DefaultBiome = "jungle"`,
  `LightingTechnology = "ShadowMap"`, and 3 full profiles
- `World/BiomeLightingService.luau` — applies a profile at boot;
  sets Lighting.* + creates/updates child Atmosphere +
  ColorCorrectionEffect; defensive `Enum.Technology` pcall survives
  the Jan 2025 rename
- Wired into BOTH bootstraps (main + raid place)

Profiles per brainstorm §4.8 aesthetic notes:
- **Jungle** (default V1): deep purple ambient #28143C, brightness 1.5,
  post-dusk ClockTime 19.5, magenta atmosphere haze density 0.45
- **Volcanic**: ash-orange ambient, sunset 18.0, thicker haze 0.55
- **Ice cave**: cold-blue ambient, pre-dawn 6.0, low haze 0.40,
  desaturated cinematic grade

### Tech debt deferred

- Specific colors / fog densities are placeholder — iterate via
  Constants edits + Studio playtest
- No skybox assets yet (Phase H asset pipeline)
- Per-place lighting (raid vs main) shares default biome; V1.5+
  differentiates

---

## G7 — Cosmetic system (closes D4 launch blocker) ✅

**Date:** 2026-05-05
**Branch:** `claude/audit-phases-a-d-2BAuW`

### User design call (2026-05-05)

Four taste decisions captured via `AskUserQuestion`:

| Decision | User answer |
|---|---|
| **Cosmetic slots** | Maximalist (8 slots) — skin, helmet_decal, drone_trail, nameplate_flair, emote, banner, vehicle_paint, mount_cosmetic |
| **BP integration** | Additive — keep existing cr/cores rewards; cosmetic granted ALONGSIDE at 6 milestone tiers (5, 10, 15, 20, 25, 30) |
| **VIP pass behavior** | Unlock-only + toast (manual equip, not auto-swap) |
| **Default skin** | Combatant auto-equipped on first join |

V1.5+ slots (emote / banner / vehicle_paint / mount_cosmetic) are
schema-reserved but have no V1 catalog entries.

### What was built

#### Server

- **`Constants.COSMETIC`** — 8 slot identifiers, 4 V1 defaults
  (combatant skin, default decal/trail/flair), 6 BP milestone tier
  → cosmetic id map, pass-bound cosmetic unlock map (VIP → heavy
  defender), 24h NEW! badge window, 200-item inventory cap.
- **`Modules/Registry/CosmeticRegistry.luau`** (shared) — V1 catalog
  with 13 items across 4 active slots:
  - 3 skins: combatant (default), recon (BP T15), heavy_defender
    (VIP pass)
  - 4 helmet decals: default, chevron_red (T10), skull_amber (T25),
    op7_emblem (T30 capstone)
  - 4 drone trails: default, neon_red (T5), neon_blue (T20),
    neon_gold (T30 capstone)
  - 3 nameplate flairs: default, pioneer (early-adopter
    achievement), op7_veteran (T25)
  Each carries display name + description + source tag + rarity
  (common/uncommon/rare/legendary — drives badge color) + V1
  placeholder color tints. Phase G art queue replaces tints with
  imported MeshParts + Decals per `ASSETS.md`.
- **`Cosmetics/CosmeticService.luau`** (NEW) — ownership tracking,
  equip API, character apply path:
  - `GrantCosmetic(player, id)` — idempotent (no double-grant on
    rejoin); fires `CosmeticUnlocked` toast + pushes `CosmeticState`
  - `TryEquip(player, slot, cosmeticId)` — validates slot is known,
    cosmetic exists, cosmetic.slot matches arg, player owns
  - `ApplyToCharacter(player)` — V1 placeholder: BodyColors tint
    per skin, small neon Part decal on Head per helmet decal.
    Phase G replaces with real BodyParts swap + Decal upload.
  - `GetEquippedTrailColor(player)` — public API for DroneSwarm
    to read per-shot
  - `ensureDefaults(player)` on join — grants + equips the 4 V1
    defaults (insurance-checked; idempotent)
  - Hooks `CharacterAdded` for re-apply on respawn
- **`Remotes.luau`** — added 3 Remotes:
  - `CosmeticState` (S→C) — full state push
  - `EquipCosmetic` (C→S RemoteFunction) — wired through
    F1 RateCheck + F2 RemoteValidator
  - `CosmeticUnlocked` (S→C) — 5s toast trigger
- **`AntiExploit.RATE_LIMITS_BY_REMOTE`** — added `EquipCosmetic`
  entry (default 10/s)
- **`ProfileSchema.luau`** — added `cosmeticsOwned: { [id]: number }`
  + `equippedCosmetics: { [slot]: string }`. Additive; older saves
  get empty tables via Reconcile.

#### Hooks

- **`BattlePassService.TryClaim`** — extended success path: after
  cr/cores grant, looks up
  `Constants.COSMETIC.BattlePassMilestones[tier]` and grants each
  cosmetic id via `CosmeticService.GrantCosmetic`. Lazy-require to
  avoid load-order cycle.
- **`MonetizationService.Init`** — second `OnOwnershipChanged`
  subscription: on `owned == true`, looks up
  `Constants.COSMETIC.PassUnlocks[passKey]` and grants each item.
  VIP Operator pass purchase → heavy_defender skin unlocked
  (toast fires; player manually equips per user design call).
- **`DroneSwarmService`** — beam-color path reads
  `CosmeticService.GetEquippedTrailColor(owner)`; falls back to
  preset (Recon blue / Combat red / Engineering green) if player
  has default trail.

#### Client

- **`Cosmetics/CosmeticController.luau`** (NEW) — toggle button +
  right-side panel:
  - Tabbed by slot (V1 4 active + 4 greyed V1.5+ reservations)
  - Per-cosmetic row: name, rarity-colored stroke, "EQUIPPED" /
    "Equip" / "NEW!" / "Locked" status badge
  - Click any owned-not-equipped row → fires `EquipCosmetic`
  - Listens to `CosmeticState` for state pushes
  - Listens to `CosmeticUnlocked` for 5s rarity-colored toast
    banner ("🎁 NEW COSMETIC UNLOCKED — Recon Operator")

### Audit (G7-scope, sandbox-side)

- 84 `.luau` files — `--!strict` on all (84 = previous 82 + Registry
  + Service + Controller)
- Single-writer invariant: only `CosmeticService` mutates
  `cosmeticsOwned` + `equippedCosmetics` (verified by grep)
- Trust boundary: `EquipCosmetic` Remote routes through
  AntiExploit.RateCheck + RemoteValidator.IsString chain (F1+F2);
  validates ownership before mutation; cosmetic.slot mismatch
  rejection prevents cross-slot equip cheats
- BP milestone grants verified at all 6 tier rows (5/10/15/20/25/30);
  tier 25 + 30 grant 2 cosmetics (correct per Constants table)
- VIP pass unlock: heavy_defender granted on `owned=true` flip
  per the OnOwnershipChanged subscription
- Default skin path: ensureDefaults runs on every player-loaded
  WaitForData → idempotent; first-join player gets combatant
  skin + default decal/trail/flair equipped automatically
- Drone trail integration: DroneSwarmService falls back to preset
  color on default trail (Recon=blue / Combat=red / Engineering=green
  preserved per E2.6); equipped trail overrides per shot

### Audit (G7-scope, Studio-side — pending your local run)

After F5 + G1 sync:

1. **Fresh profile** — wipe via Server Command Bar:
   ```luau
   local DM = require(game.ServerScriptService.Server.Modules.Player.DataManager)
   local data = DM.GetData(game.Players:GetPlayers()[1])
   data.cosmeticsOwned = {}
   data.equippedCosmetics = {}
   ```
2. **Restart F5** — defaults should auto-grant + equip. Expect:
   - `[CosmeticService] <Name> unlocked skin_combatant (default)`
   - Same 3 lines for decal_default / trail_default / flair_default
   - HUD toast banner for each unlock
   - Character takes the combatant tint (charcoal + red trim)
3. **Open Cosmetics panel** — 4 active slots visible with 1-3
   options per slot; locked entries greyed
4. **BP milestone test:**
   ```luau
   local BPS = require(game.ServerScriptService.Server.Modules.Monetization.BattlePass.BattlePassService)
   local p = game.Players:GetPlayers()[1]
   BPS.GrantXP(p, 5000)
   print(BPS.TryClaim(p, 5, "free"))
   ```
   Expect: cr/cores grant + cosmetic toast for `trail_neon_red`.
   Open panel — trail entry shows NEW! badge.
5. **Drone trail equip:** equip Neon Red → trigger a wave → drone
   shots fire red-tinted beams (overrides preset).
6. **VIP grant simulation** (requires Studio-only force-flip per
   the GamePassService internal cache — not externally accessible
   in V1; Phase H tests against real PromptGamePassPurchaseFinished).

### Tech debt / deferred (Phase G art queue items)

- **V1 skin apply is placeholder BodyColors tint.** Phase G art
  queue ships real BodyParts swap from imported MeshParts per
  `ASSETS.md` §4.2.
- **V1 helmet decal apply is placeholder neon Part.** Phase G ships
  real Decal upload + textures per the asset pipeline.
- **V1 nameplate flair apply is server-side only** (stored on
  profile). G5 (UI polish) wires Roblox chat / HUD nameplate
  rendering.
- **No icon assets for the cosmetics panel.** `iconAssetId = 0`
  placeholders; Phase H asset pipeline uploads.
- **No equip-flair animation.** Phase G adds a brief shimmer /
  particle burst on successful equip.
- **No achievement-source cosmetics wired.** `flair_pioneer` source
  is `"achievement:pioneer"` but no AchievementService exists in
  V1; V1.5+ adds the achievement system.
- **4 V1.5+ slots greyed in UI** — emote / banner / vehicle_paint
  / mount_cosmetic show "No cosmetics in catalog yet." until V1.5+.
- **No rarity-driven drop / unlock visual effects.** Phase G polish.
- **No cosmetic preview** before equip (e.g., 3D model rotation).
  Phase G or V1.1 if data shows players want it.

### What's next

G2 — Volcanic biome lighting polish (per-biome decorative emissive
flora + ambient SFX hooks; the lighting profile in G1 covers the
base Atmosphere/Lighting state, G2 layers per-biome decorative
elements).

### Commit

`feat(phaseG7): cosmetic system (closes D4 BattlePass launch blocker)`
