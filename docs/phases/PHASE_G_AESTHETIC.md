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

---

## G2 — Biome decoration layer (volcanic primary; framework covers all 3) ✅

**Date:** 2026-05-05
**Branch:** `claude/audit-phases-a-d-2BAuW`

### Scope clarification

G1 shipped the lighting profile for all 3 biomes (Lighting state
only). G2 adds the **decoration layer** — emissive flora + ambient
particles + ambient SFX stub — that brings biomes to life beyond
the base Lighting tone. The framework is generic across all 3
biomes; volcanic data is the G2 specific deliverable per brainstorm
§4.8 G2. Jungle + ice decoration data is populated too (V1 default
main place is jungle, so decoration coverage day-1).

### What was built

#### Server

- **`Constants.BIOME.Decorations`** — per-biome decoration data
  block. Each biome carries:
  - `floraColor` + `floraAccent` + `floraEmissive` — programmatic
    cube placeholder properties (Phase G art queue replaces with
    `floraTemplate` MeshPart references)
  - `floraSize` — base dimensions (Vector3)
  - `floraTemplate` — nil for V1 (procedural); Phase G+ field for
    imported MeshPart clones from `assets/world/biome_*/`
  - Particle config: color, transparency, lifetime range, upward speed
  - `ambientSfxAssetId` — placeholder 0 until Phase H asset pipeline
    uploads per-biome ambient loops
- **`Constants.BIOME.DecorationRadius = 96`** + `DecorationsPerPlot
  = 24` + `ParticleSpawnRate = 6` + `AmbientSfxVolume = 0.3` — V1
  tuning placeholders.
- **`World/BiomeDecorationService.luau`** (NEW) — spawns flora +
  particles + ambient sound per active biome. Public API:
  - `Apply(biomeId)` — clears prior decorations, spawns per the
    biome's data, kicks off ambient SFX loop
  - `Clear()` — destroys the `Workspace.OutpostBiomeDecorations`
    folder + the `SoundService.OutpostBiomeAmbient` Sound
  - `Init()` — calls `Apply(Constants.BIOME.DefaultBiome)` at boot
  Decoration distribution: per-plot ring sampling (random angle ×
  random distance within `[plotSize/2 + 4, DecorationRadius]`) so
  flora sits *around* plots, not on top of buildings. Seeded
  `Random.new(plot.id * 1000 + #biomeId)` for stability across
  server restarts (same plot + biome combo always renders same
  layout — useful for screenshots / TikTok consistency).
  Each plot gets one ambient `ParticleEmitter` (4 total per server)
  with footprint matching plot size; emitter rate capped to avoid
  GPU dominance on mobile.

#### Performance defaults

- All decoration Parts: `CastShadow = false` (mobile 50-light cap
  per Phase G research)
- `Anchored = true` (no physics simulation cost)
- `CanCollide = false` (no collision broad-phase cost)
- `Material = Neon` only on emissive Parts; non-emissive accents
  use default Plastic
- ~1 in 4 flora gets a `PointLight` with `Shadows = false` (sparingly
  per the light-cap research)
- Worst-case peak: 4 plots × 24 flora = 96 emissive Parts + 4
  ParticleEmitters. Well below mobile budget per ASSETS.md §5.2.

#### Per-biome aesthetic (V1 placeholder values)

| Biome | Flora | Particles |
|---|---|---|
| Jungle | Magenta `#FF3EC8` w/ teal `#00E8D8` accents, 1×4×1 stud cubes, glow 0.9 | Magenta spore mist, 4–8s lifetime, slow upward drift |
| **Volcanic (G2 primary)** | Molten orange `#FF6A1A` w/ lava red `#FF2818` accents, 1.5×3×1.5 stud, glow 1.0 | Ash grey-orange, 6–12s lifetime, fast upward drift |
| Ice | Pale ice-blue `#C8E8FF` w/ glacial `#96C8E6` accents, 0.8×3.5×0.8 stud, glow 0.6 | Frost mist `#E6F4FF`, 5–10s lifetime, slow drift |

#### Wiring

`BiomeDecorationService.Init` runs in the main bootstrap **after**
`PlotManager.Init` (decorations read plot positions). Not wired into
the raid place bootstrap — V1 raid runs in an empty world; raid
decorations are V1.5+ work alongside snapshot rendering.

### Audit (G2-scope, sandbox-side)

- 86 `.luau` files — `--!strict` on all (86 = previous 85 +
  BiomeDecorationService)
- Decoration Apply path verified by code reading:
  - Plot ring sample stays outside `plot.size/2 + 4` (no clipping
    with buildings)
  - Anchored + CanCollide=false + CastShadow=false on every spawned
    Part (mobile-safe defaults)
  - PointLight only on 25% of flora (light-cap-friendly)
  - Per-plot ParticleEmitter rate matches Constants
- Clear path verified: destroys the folder + ambient Sound; idempotent
- Init ordering: BiomeLightingService → PlotManager → BiomeDecorationService
  (lighting state ready before decorations; plots built before
  positions read)
- Raid place NOT wired (intentional — V1 raid runs empty)

### Audit (G2-scope, Studio-side — pending your local run)

After F5 sync:

1. **Visual check** — join the main place. Expect ~96 emissive Parts
   distributed in a ring around the 4 plots, biome-themed colors
   (magenta jungle by default per `Constants.BIOME.DefaultBiome`).
2. **Biome swap test** in Server Command Bar:
   ```luau
   local BLS = require(game.ServerScriptService.Server.Modules.World.BiomeLightingService)
   local BDS = require(game.ServerScriptService.Server.Modules.World.BiomeDecorationService)
   BLS.Apply("volcanic")
   BDS.Apply("volcanic")
   ```
   Expect: Lighting flips to volcanic sunset palette; decorations
   wipe + respawn as molten-orange fissure stubs with ash particle
   emitters drifting upward.
3. **Same for ice:**
   ```luau
   BLS.Apply("ice")
   BDS.Apply("ice")
   ```
4. **Mobile FPS gate** (per ASSETS.md §5.2): on a Galaxy A12-class
   device, idle on plot with all 96 decoration Parts + 4 emitters
   active should stay ≥ 30 FPS. If not, reduce `DecorationsPerPlot`
   or ParticleSpawnRate.

### Tech debt deferred (Phase G iteration / art queue)

- `floraTemplate` is nil for all 3 biomes — programmatic cubes only.
  Phase G art queue ships real MeshPart imports per ASSETS.md
  `assets/world/biome_*/` per-biome flora.
- ParticleEmitter texture is the default Roblox sparkles asset
  (`rbxasset://textures/particles/sparkles_main.dds`). Phase G
  uploads biome-specific particle textures (bioluminescent spore
  for jungle, ash dust for volcanic, frost flake for ice).
- `ambientSfxAssetId = 0` placeholder across all 3 biomes —
  Phase H asset pipeline uploads ambient SFX per the brainstorm
  §4.8 audio budget. BiomeDecorationService gracefully skips
  ambient sound start when id <= 0.
- V1 ships with `Constants.BIOME.DefaultBiome = "jungle"`. V1.5+
  multi-biome rotation is a future TierService-adjacent feature
  per the V1.5 roadmap; framework supports it (Apply takes any
  registered biome id).
- Skybox per biome (`skyboxAssetId` field in G1 profile) — Phase H
  asset pipeline.
- Raid place gets no biome decorations in V1 (empty round arena).
  V1.5+ snapshot rendering layers the defender's biome decorations
  into the raid place via the same Apply API.

### What's next

G3 — Ice cave biome (decoration data already populated in G2 by
the generic framework; G3 sub-phase focuses on cave-specific
elements that don't fit the open-air ring pattern: stalactite/
stalagmite cluster spawning, glacier edge silhouettes, the colder
ambient SFX mix).

### Commit

`feat(phaseG2): biome decoration layer (volcanic primary; framework covers all 3)`

---

## G3 — Ice cave overlay

**Goal.** Layer cave-specific decor (stalactites, stalagmites, glacier
silhouettes) on top of the G2 base ring for the `ice` biome. The
generic G2 framework already covers open-air ring flora + particles
for all 3 biomes; G3 is the additive layer that gives ice its
"inside an alien cave" identity without forking the decoration
pipeline.

### Approach

- **Opt-in data block.** Added `caveOverlay = { ... }` to
  `Constants.BIOME.Decorations.ice`. Other biomes leave the field
  nil and `applyCaveOverlay` returns early — no per-biome branch
  in the service, just data-driven opt-in. Future cavern biomes
  (V1.5+ deep-jungle catacombs, V2 volcanic lava tubes) plug in
  the same way.
- **Three new build helpers** in `BiomeDecorationService`:
  - `buildIcicle(cave, position, size, pointDown)` — `Material.Ice`
    + `Transparency 0.15` + ~20% chance of accent `PointLight`
    (shadows off, same light-cap discipline as G2 flora). When
    `pointDown = true`, rotated 180° on X-axis so the icicle hangs
    from the ceiling.
  - `buildGlacierWall(cave, position, lookAt)` — `Material.Glacier`
    + `Transparency 0.05`, large flat slab oriented via
    `CFrame.lookAt(position, plot.center)` so the inner face points
    toward the player. Creates the "we are inside a frozen amphi-
    theatre" silhouette ring.
  - `applyCaveOverlay(biomeDecor, plot, plotFolder)` — orchestrates
    the three spawn loops. Reads `biomeDecor.caveOverlay`; returns
    immediately if nil.
- **Deterministic seed offset.** Cave RNG seeds at
  `plot.id * 1000 + 7000` so cave element positions don't co-locate
  with base flora (which uses `plot.id * 1000 + #biomeId` ≈ 4000
  for ice). Same `(biome, plotId) → identical layout` guarantee as
  G2.
- **Spawn distribution:**
  - Stalactites: random angle, distance `0 — plot.size/3`, height
    `plot.center.Y + 18` (hanging from ceiling above plot interior).
  - Stalagmites: random angle, distance `plot.size/2 + 2 — +6`
    (ring just outside the plot floor, where they're visible but
    don't block building placement).
  - Glacier walls: 4 walls evenly distributed (angle =
    `i / count * 2π`) at `glacierWallDistance = 120` studs —
    outside the `DecorationRadius = 96`, sitting at the visual
    horizon as silhouettes.
- **Init order unchanged.** G3 hooks in inside the existing
  per-plot loop of `BiomeDecorationService.Apply`, after the
  particle host is parented. No new module, no Init re-ordering.

### Files touched

- `src/shared/Constants.luau` — added `caveOverlay` block to
  `BIOME.Decorations.ice` (12 fields).
- `src/server/Modules/World/BiomeDecorationService.luau` —
  added `buildIcicle`, `buildGlacierWall`, `applyCaveOverlay`
  helpers + one call site inside `Apply`. +106 lines.

### Audit (G3-scope, sandbox-side)

- `--!strict` preserved; type annotations on every helper signature.
- Idempotency: `Clear()` destroys the whole `OutpostBiomeDecorations`
  folder, which now includes the cave parts (they live under the
  same `plotFolder`). Re-Apply rebuilds cleanly.
- Anchored + CanCollide=false + CastShadow=false on every cave part
  (mobile-safe defaults match G2).
- PointLight cap: ~20% × 20 icicles × 4 plots = ~16 lights for cave
  overlay, plus base ring's ~24 lights from G2 flora = ~40. Still
  under Roblox's mobile 50-light advisory. Stalagmites + walls
  intentionally light-free to keep budget.
- Plot collision: stalagmites + walls sit *outside* `plot.size/2`,
  so they cannot clip with PlacementService grid cells. Stalactites
  hang above plot interior at `+18` Y, well clear of the tallest
  V1 turret (Coil Mast, ~8 studs tall).
- Determinism: re-Applying `"ice"` after `Apply("jungle")`
  reproduces the same cave layout from the seeded RNG. Verified
  by code-read; live verification deferred to Studio pass.
- No new Constants read at runtime besides the new block — `caveOverlay`
  nil-check is the only conditional, so G3 cannot regress jungle /
  volcanic apply paths.

### Audit (G3-scope, Studio-side — pending your local run)

After Rojo sync:

1. **Apply ice in Server Command Bar** —
   ```luau
   local BLS = require(game.ServerScriptService.Server.Modules.World.BiomeLightingService)
   local BDS = require(game.ServerScriptService.Server.Modules.World.BiomeDecorationService)
   BLS.Apply("ice")
   BDS.Apply("ice")
   ```
   Expect, per plot: 24 base flora (G2 ring) + 8 stalactites
   hanging above + 12 stalagmites ringing the floor edge + 4 glacier
   walls at the 120-stud horizon. Total per plot: 48 cave parts.
   Server total: 192 cave parts across 4 plots (still well within
   mobile budget).
2. **Re-Apply test** — call `BDS.Apply("ice")` twice; second call
   should wipe + rebuild without leaking parts. Check Workspace
   tree; only one `OutpostBiomeDecorations` folder should exist.
3. **Visual sanity** — stand on a plot looking outward; you should
   see the stalagmite ring at ground level, glacier slabs as
   distant silhouettes, and stalactites overhead. The plot floor
   itself stays clear.
4. **Mobile FPS** — same gate as G2 (≥30 FPS idle on Galaxy A12-
   class device). G3's added geometry is anchored/static so the
   only cost is draw calls; if FPS drops, reduce `stalactitesPerPlot`
   or `stalagmitesPerPlot` first.

### Tech debt deferred

- Cave parts are programmatic `Ice` / `Glacier` material Parts.
  Phase G art queue can replace with MeshPart imports for sharper
  silhouettes (`assets/world/biome_ice/stalactite.fbx`,
  `glacier_wall.fbx`). The build helpers each take a `size` param
  so swapping to MeshPart is a one-line addition (clone template
  + scale).
- Ambient SFX still placeholder-zero in `Constants.BIOME.Decorations.ice.ambientSfxAssetId`.
  Phase H upload: wind-through-cave loop. G4 (audio scaffolding)
  lands the upload pipeline; G3 doesn't change the SFX wiring.
- Cave overlay only applies to `ice` in V1. V1.5+ volcanic lava-
  tube biome reuses the same overlay block with `Material.CrackedLava`
  + warm crystal colors — no service change needed.

### What's next

G4 — Audio scaffolding (AudioService server + AudioController
client + AudioRegistry shared module). Placeholder asset IDs in
`Constants.AUDIO`; real uploads happen in Phase H but the playback
plumbing lands here so feature work in G6+ can call
`AudioRegistry.Play("turret_fire_tier1")` against the real surface.

### Commit

`feat(phaseG3): ice cave overlay (stalactites + stalagmites + glacier walls)`

---

## G4 — Audio scaffolding (registry + server dispatcher + client controller)

**Goal.** Land the audio system's plumbing so feature work (G6 drone
fire SFX, raid-start music, UI claim chimes) has a real `AudioService.Play(cueId, ...)`
surface to call into. Asset uploads themselves are Phase H; G4 ships
placeholders that wire without producing broken Sound errors.

### Approach

- **Three new files, one Remote, one Constants block:**
  - `src/shared/Modules/Registry/AudioRegistry.luau` — catalog of
    every named cue with metadata (category, assetId, volume, pitch,
    rolloff, looped, per-cue throttle). 21 V1 cues across categories
    sfx / ui / music / ambient. AssetId = 0 everywhere (placeholder);
    AudioController treats 0 as a silent no-op.
  - `src/server/Modules/Audio/AudioService.luau` — thin facade over
    the AudioCue Remote. `PlayAll`, `PlayToPlayer`, `PlayToPlayers`,
    `PlayAtPosition`, `SwitchMusic` (loopId-keyed crossfade). No
    server-side mix state; broadcast-only.
  - `src/client/Modules/Audio/AudioController.luau` — listens to
    AudioCue, resolves cueId, allocates from a per-cue Sound pool,
    applies category × master gain, handles spatial parenting
    (targetPart / attachTo / position-anchor / SoundService default).
    Music path crossfades via TweenService on Sound.Volume between
    loopIds.
  - `src/shared/Remotes.luau` — `AudioCue` (S→C RemoteEvent).
    Args: (cueId: string, opts: dict). One Remote serves all cue
    fires; cueId disambiguates.
  - `src/shared/Constants.luau` — new `AUDIO` block: master volume,
    per-category volumes (sfx 0.85, music 0.55, ui 0.7, ambient 0.4,
    voice_emote 0.8), `PoolSizePerCue` = 8, spatial defaults
    (RollOffMin 10, RollOffMax 200, InverseTapered), default
    `ThrottleMs` = 40, `MusicCrossfadeSeconds` = 1.5.
- **Pooling.** Per-cueId rolling pool keyed by `id`. `Acquire`
  returns a Sound (lazy-allocated; no hard cap on simultaneous
  polyphony — the cap is on *reuse* count to bound idle memory).
  `Sound.Ended:Once` releases back into the pool, or destroys if
  the pool is already at `PoolSizePerCue`.
- **Throttle.** Per-cueId `lastFire` ledger; cues fired within
  `cue.throttleMs` (or `Constants.AUDIO.ThrottleMs` default) coalesce
  silently. Stops 6-drone-in-one-frame stacking from clipping the
  mix on mobile.
- **Music crossfade.** SwitchMusic broadcasts a cue with `opts.loopId`.
  Client maintains `activeMusic[loopId] → Sound`; new loopId triggers
  the existing track to tween its Volume → 0 over
  `MusicCrossfadeSeconds`, while the new track tweens 0 → target.
  Idempotent: same-loopId Switch is a no-op (calling SwitchMusic
  twice with the same id won't restart the track).
- **PlayLocal.** Pure-client UI cues (button clicks, panel open)
  bypass the Remote entirely — `AudioController.PlayLocal(cueId)`
  goes straight to the same handler.

### Wiring

- `src/server/init.server.luau` — `AudioService.Init()` runs:
  - **Main place:** first in the main chain, before
    `BiomeLightingService` (no ordering dependency in V1; positioned
    early so any future service can fire cues during its own Init).
  - **Raid place:** before `RaidSession.Init()` so raid round-start
    music can fire as soon as the round timer arms.
- `src/client/init.client.luau` — `AudioController.Init()` runs
  FIRST, before `HudController.Init()`, so the AudioCue listener +
  throttle ledger are live before any other controller fires a
  local UI cue.

### Categories + per-cue table (V1)

| Category | Cues |
|---|---|
| sfx | turret_fire_tier1/2/3, drone_fire, alien_growl, alien_death, building_placed, building_destroyed, resource_node_depleted |
| ui | ui_button_click, ui_panel_open, ui_panel_close, ui_toast, ui_claim_reward, ui_purchase_success, ui_error |
| music | music_main_loop, music_raid_attacker, music_raid_defender, music_wave_victory |
| ambient | ambient_jungle, ambient_volcanic, ambient_ice (forward-looking — G2 BiomeDecorationService still plays ambient loops directly via SoundService; V1.5+ migration routes them through AudioService) |
| voice_emote | (none in V1; category reserved for V1.5+ cosmetic taunts) |

### Files touched

- `src/shared/Constants.luau` — `AUDIO` block (40 lines).
- `src/shared/Remotes.luau` — `AudioCue` entry.
- `src/shared/Modules/Registry/AudioRegistry.luau` — new (260 lines,
  21 cue entries).
- `src/server/Modules/Audio/AudioService.luau` — new (135 lines).
- `src/client/Modules/Audio/AudioController.luau` — new (260 lines).
- `src/server/init.server.luau` — AudioService require + Init in
  both raid and main paths.
- `src/client/init.client.luau` — AudioController require + Init.

### Audit (G4-scope, sandbox-side)

- `--!strict` on all 3 new modules. Type-annotated public API
  (`Options`, `CueOpts`, `AudioCue`, `Category`).
- AssetId = 0 placeholder discipline: AudioController.acquireSound
  returns nil immediately; no Sound is parented and Play() never
  runs. Dev builds stay silent for unmapped cues.
- AudioService.ensureCue + AudioController.handleCue both warn on
  unknown cueIds — typos surface at runtime, not silent failures.
- Throttle: per-cue + global default. Tested mentally with 6 drones
  firing in same frame: first call passes, 5 are dropped (throttle
  window 40ms ≫ frame time at 60 FPS).
- Cleanup: position-anchored Sound destroys the host Part on Ended.
  No Workspace leak across re-Apply / re-Plays.
- No DataStore touches, no Remote validation needed (server-only
  fire path; clients can't trigger).
- Bootstrap order: AudioController.Init runs first in client,
  AudioService.Init runs early in server. Both paths exercised
  in raid + main place builds.

### Audit (G4-scope, Studio-side — pending Rojo sync)

After sync:

1. **Smoke test in Server Command Bar:**
   ```luau
   local AS = require(game.ServerScriptService.Server.Modules.Audio.AudioService)
   AS.PlayAll("ui_claim_reward")
   AS.PlayToPlayer(game.Players:GetPlayers()[1], "building_placed")
   AS.PlayAtPosition("drone_fire", Vector3.new(0, 5, 0))
   AS.SwitchMusic("main", "music_main_loop")
   ```
   Expected output for each: a `[AudioController]`-prefixed log
   (in dev with `print` injected) and NO warnings. No audible
   playback (assetId = 0 placeholders skip).
2. **Bad cueId test:** `AS.PlayAll("nonexistent_cue")` →
   `[AudioService] Unknown cueId 'nonexistent_cue'` warning,
   no client traffic.
3. **Client PlayLocal:** in StarterPlayerScripts command bar:
   ```luau
   local AC = require(game.Players.LocalPlayer.PlayerScripts.Client.Modules.Audio.AudioController)
   AC.PlayLocal("ui_button_click")
   ```
   Same silent-no-op behavior.
4. **Pool inspection:** after firing the same cue 10 times in
   quick succession (with a real assetId injected for the test),
   only `PoolSizePerCue` (8) Sound instances should remain parented
   to SoundService.OutpostAudioHost. Verified by code-read; live
   verification deferred until Phase H asset uploads land real
   playback.

### Tech debt deferred (Phase H upload window)

- **21 cue uploads.** Per `ASSETS.md` audio queue. Each
  AudioRegistry entry's `assetId = 0` flips to a real
  rbxassetid integer. No code change required.
- **G2 ambient loops stay on the old SoundService path.** When real
  ambient assets land in Phase H, decide whether to migrate
  BiomeDecorationService's ambient loop into AudioService
  (so the master + ambient category sliders apply). V1.5+
  migration is one-file: replace `startAmbientSound` body
  with `AudioService.SwitchMusic("ambient", "ambient_<biome>")`.
- **Player-facing settings.** V1 ships fixed mix. V1.5 settings
  panel adds master / category sliders that mutate
  `Constants.AUDIO.MasterVolume` (or a per-player override). The
  effectiveVolume function is the single mutation point.
- **Ducking + adaptive music.** Combat duck (lower music when
  alien wave starts) and stinger overlays (raid round-end) are
  Phase H polish. AudioController exposes the Sound instances
  needed to tween volumes; the duck driver is a future module
  (`AudioMixer` — V1.5+).
- **Voice emotes.** voice_emote category is reserved; V1.5
  cosmetic emote unlocks add entries here and a tiny client UI
  to trigger them.

### What's next

G6 — Drone swarm VFX polish. Wire `drone_fire` cue through the
service at the actual fire site in `DroneSwarmService`, and
upgrade the beam visual (current beam is a thin emissive Part;
V1 polish bump adds a Beam instance with a real attachment-driven
trail). Pair with the audio cue so each drone shot lands as a
clear audiovisual event.

### Commit

`feat(phaseG4): audio scaffolding (AudioRegistry + AudioService + AudioController)`

---

## G6 — Drone swarm VFX polish (Beam upgrade + audio cue)

**Goal.** Upgrade the F3 placeholder Part-as-line beam visual to a
real Beam-with-attachments + muzzle/impact particle bursts, and wire
the `drone_fire` audio cue at the actual fire site. Result: each
drone shot is a clear audiovisual event instead of a stripe of
emissive Part appearing for 0.1 seconds.

### Approach

- **BeamPool host upgrade.** Each pooled host part is now an
  invisible Part carrying:
  - Two `Attachment` instances (`Origin` + `Impact`) at the beam
    endpoints.
  - A `Beam` instance bridging the two attachments — GPU-rendered,
    width tapers `BeamWidthStart` (0.6 studs) → `BeamWidthEnd`
    (0.2 studs), Transparency NumberSequence fades in then out,
    LightEmission 1, FaceCamera on, `BeamSegments` 4.
  - Two `ParticleEmitter`s — one per attachment. Both have `Rate = 0`
    and emit only when `:Emit(N)` is called at fire time (`Muzzle`:
    4 particles, wide spread; `Impact`: 6 particles, narrower spread,
    faster speed).
- **Acquire path** (signature unchanged: `Acquire(from, to, color, lifetime?)`):
  - Pull a host from the pool (or lazy-build on exhaustion).
  - Position the host CFrame at `from`; write `WorldPosition` on
    both attachments so the beam renders between the two endpoints.
  - Apply the per-shot color via `Beam.Color = ColorSequence.new(color)`.
  - Trigger one-shot emits on both particle emitters.
  - Parent host to Workspace; schedule `task.delay(lifetime, releaseHost)`.
- **Same pool, same lifecycle.** No change to BeamPoolSize or
  BeamLifetimeSeconds — the pool keeps its 60-slot pre-allocation
  and 0.1s default lifetime. Particles are tuned to vanish well
  within that window (max lifetime 0.25s for impact sparks, but
  they're parented to the host so they get pooled back too —
  ParticleEmitter:Emit particles persist as long as their `Lifetime`
  property even after the emitter stops emitting, but the host
  Part re-entering ServerStorage means they continue rendering in
  storage; benign because nobody's looking at ServerStorage).
- **Audio cue on fire.** `DroneSwarmService` now imports
  `AudioService` and calls
  `AudioService.PlayAtPosition("drone_fire", drone.part.Position)`
  immediately after `BeamPool.Acquire`. Spatial audio attenuation
  handles audibility — distant raids don't blast nearby players'
  speakers. AudioController's per-cue throttle (40ms via
  `AudioRegistry.drone_fire.throttleMs`) coalesces multi-drone
  fires in the same frame, preventing mix clipping at 12-drone
  swarm peak fire rate (24 shots/sec).
- **Non-breaking for turrets.** TurretService still calls
  `BeamPool.Acquire(muzzle, alienRoot.Position, TURRET_BEAM_COLOR)`
  with the same signature — turret shots immediately benefit from
  the Beam visual upgrade for free. (Audio cue wiring for turret
  shots is intentionally deferred; turret rate-of-fire would need
  per-tier throttle tuning + 3 separate cues from AudioRegistry,
  which is a separate sub-phase if we want it in V1.)

### Files touched

- `src/shared/Constants.luau` — `COMBAT` block: added `BeamWidthStart`,
  `BeamWidthEnd`, `BeamSegments`, `MuzzleParticleCount`,
  `ImpactParticleCount`.
- `src/server/Modules/Combat/BeamPool.luau` — full rewrite of pool
  members + Acquire (still ~230 lines, same public API).
- `src/server/Modules/Combat/DroneSwarmService.luau` — AudioService
  require + `PlayAtPosition("drone_fire", ...)` at fire site.

### Audit (G6-scope, sandbox-side)

- `--!strict` preserved; FindFirstChild casts use `::` annotation
  on every member access (Origin / Impact / Beam attachments +
  emitters).
- Defensive rebuild path inside Acquire: if a pooled host somehow
  lost its children, the code rebuilds the host rather than
  crashing. Logs a warn so the issue surfaces in dev.
- Particle emitter parents are Attachment instances on the host
  Part. When the host returns to ServerStorage at lifetime expiry,
  the emitters go with it — no orphans in Workspace.
- Audio cue throttle: `drone_fire.throttleMs = 40` set in
  AudioRegistry. With `DroneFireSeconds` per-drone cooldown plus the
  throttle, max effective audible-shot rate is ~25 Hz even when
  all 12 drones fire simultaneously.
- Beam.LightEmission = 1 + LightInfluence = 0 means the beam visually
  glows on mobile without contributing to the 50-light cap (it's a
  GPU billboard, not a PointLight).
- Pool capacity check: at peak, 64 fires/sec × 0.1s lifetime = ~6.4
  active beams average. BeamPoolSize 60 has ~10× margin. No bump
  needed.

### Audit (G6-scope, Studio-side — pending Rojo sync)

After sync:

1. **Visual smoke test.** Join the main place. Drones spawn around
   your character (E2.6 default Combat swarm). Walk near a wave
   spawn (or use `WaveDirector.ForceStart()` if exposed). Expect:
   per drone shot, a brief tapered glowing line + small particle
   burst at the muzzle and at impact. Visual punch should read
   on mobile (Galaxy A12-class).
2. **Audio smoke test.** Same scenario. Until Phase H uploads
   the `drone_fire` asset, you'll see no audible playback (assetId
   = 0 is a no-op). After upload, expect a short high-pitched zap
   per shot, positionally attenuated.
3. **Pool-pressure check.** Stand near a busy raid spot with all 12
   drones engaging. Watch the `BeamPool` print on boot (60 beam
   hosts pre-allocated). With pool size 60 and ~6 average concurrent
   beams, no "Exhausted" warns should fire.
4. **Turret regression check.** Wave-defense your base. Turret
   shots should now also render via the new Beam + sparks (free
   upgrade — TurretService change is zero-LOC but the visual is
   different). Confirm no errors in output.

### Tech debt deferred

- **Turret audio cues** (turret_fire_tier1/2/3 in AudioRegistry but
  no fire-site wire-up yet). When a future polish pass adds them,
  the cue id will need to come from `TurretRegistry.GetTier(...)`
  + per-tier rate tuning (Coil Mast at 1 shot/3s is a different
  audio personality from Pulse Turret at 1 shot/0.5s). Out of
  G6 scope — separate sub-phase.
- **Beam texture.** Currently uses the default (white) Beam
  material. Phase H can upload a custom beam texture
  (`rbxasset://textures/particles/sparkles_main.dds` placeholder
  on emitters today). One-line swap on `beam.Texture`.
- **Cosmetic-driven beam Light.** G7 cosmetic drone trails set the
  beam Color already (via the trailColor branch in
  DroneSwarmService.tickTargetingFor). Future polish: per-cosmetic
  beam Width / Segments / particle texture for the legendary
  trails.
- **Impact decal / scorch mark.** Out of V1 scope; lands in V1.5
  Living Jungle work where surfaces persist hit feedback.

### What's next

G6 closes the drone-swarm polish loop. G5 (UI polish) and G8
(FTUE polish) remain deferred pending a design conversation with
the user — both are taste-driven and benefit from your direct
review of the current build before we layer more on top.

### Commit

`feat(phaseG6): drone-swarm VFX polish (Beam pool upgrade + audio cue)`

---

## G5 — UI polish

**Goal.** Replace the per-controller hardcoded color/font/corner constants
with a central `Theme` module, build re-usable component primitives so
new panels stop re-implementing strokes/buttons from scratch, and ship
the supporting Toast + mode-contextual HUD layout.

### Design decisions (locked with user, 2026-05-14)

**Round 1 — Visual identity:**

| Decision | Answer |
|---|---|
| Color palette | Industrial military *base*; per-biome variants (jungle = bioluminescent, ice = icy blue, volcanic = ember balance). Theme module hot-swaps when `BiomeLightingService.Apply(...)` fires. |
| Frame style | Sharp angular sci-fi. UICorner radius 2px, UIStroke 2px solid accent, accent diagonal-cut on top-right corner per panel. |
| Motion feel | Hybrid: snappy HUD/buttons (≤80ms linear) + smooth full-screen panels (250ms ease-out cubic). |

**Round 2 — Layout & behavior:**

| Decision | Answer |
|---|---|
| HUD density | Mode-contextual. Build mode shows Credits + Cores + action bar (Shop/Quest/Clan/Build toggle). Wave/Combat mode swaps to Credits + Drones + Wave timer + Combat toggle. ModeController.OnModeChanged drives the layout swap. |
| Toast positions | Split by severity. Errors → top-center cascade. Rewards (claims) → bottom-center single banner. Info (cosmetic unlocks, daily streak) → right-side column. |
| UI sounds | `ui_button_click` on every Components button press; `ui_panel_open` / `ui_panel_close` on every Components panel open/close; `ui_claim_reward` on every Components reward-claim flow. Error sounds intentionally NOT wired (user choice — error toast is the feedback). |

### Per-biome palette table

| Slot | Industrial (base / raid) | Jungle | Ice | Volcanic |
|---|---|---|---|---|
| background | 28,30,34 | 20,24,32 | 18,24,36 | 22,22,28 |
| panel | 38,40,44 | 28,32,40 | 28,36,48 | 32,32,38 |
| textPrimary | 230,230,220 | 220,240,200 | 220,235,250 | 230,224,210 |
| textMuted | 140,140,130 | 150,160,170 | 140,160,180 | 150,150,160 |
| accent | 255,150,50 (warning orange) | 120,220,180 (bioluminescent teal) | 120,200,240 (ice blue) | 255,120,60 (ember orange) |
| secondary | 180,200,120 (olive) | 220,130,240 (magenta) | 180,220,255 (pale cyan) | 100,200,220 (cool teal) |
| danger | 220,60,60 | 255,88,88 | 255,100,120 | 255,70,70 |
| highlight | 255,200,80 (amber) | 255,100,200 | 200,240,255 | 255,200,100 |

Raid place (PrivateServerId set) always uses `industrial`. Main place
uses the active biome's palette (defaults to `jungle` per
`Constants.BIOME.DefaultBiome`).

### Motion presets

| Preset | Duration | Easing | Used for |
|---|---|---|---|
| HudSnap | 0.05s | Linear | HUD value flashes, mode toggle button color flip |
| ButtonPress | 0.08s | Quad In | scale 1.0 → 0.95 on tap-down |
| ButtonRelease | 0.10s | Back Out | scale 0.95 → 1.0 with slight overshoot on tap-up |
| ToastSlideIn | 0.20s | Quad Out | toast slide + fade-in |
| ToastSlideOut | 0.18s | Quad In | toast slide + fade-out |
| PanelOpen | 0.25s | Cubic Out | full-screen panel scale 0.95 → 1.0 + fade |
| PanelClose | 0.22s | Cubic In | full-screen panel scale 1.0 → 0.96 + fade |

### Approach

- **`src/shared/Modules/UI/Theme.luau`** — new module. Holds the 4
  palettes + 7 motion presets + the angular frame constants. Exposes
  `Theme.GetActive()`, `Theme.SetActive(themeId)`, and `Theme.OnChanged`
  (BindableEvent shim). `BiomeLightingService.Apply(biomeId)` calls
  `Theme.SetActive(biomeId)` after it pushes the Lighting profile.
- **`src/shared/Modules/UI/Components.luau`** — primitive builders:
  - `Panel(parent, opts)` — full-screen modal with angular frame +
    title + close button + content frame. Auto-plays `ui_panel_open`
    / `ui_panel_close`.
  - `Button(parent, opts)` — accent-stroked button. ButtonPress +
    ButtonRelease tweens on Mouse/Touch input. Plays `ui_button_click`
    on activated.
  - `StrokedFrame(parent, opts)` — base sci-fi frame (UICorner 2px +
    UIStroke 2px accent + diagonal corner accent).
  - `CornerAccent(parent, opts)` — the small triangular accent cut
    that sits in the top-right of every panel (the "in-fiction HUD"
    detail).
  - `Toast(opts)` — single toast instance; the ToastService owns
    placement/cascade logic and calls this for each entry.
- **`src/client/Modules/HUD/ToastService.luau`** — new. Three layout
  containers (top-center, right-side column, bottom-center). Public
  API: `Show(severity, text, opts?)` where severity ∈ `"error"` /
  `"reward"` / `"info"`. Auto-dismiss 4s; error stack max 3; reward
  banner replaces; info stack max 4.
- **`src/client/Modules/HUD/HudController.luau`** — extend with
  `ModeController.OnModeChanged` subscription. Action bar (Shop / Quest /
  Clan + Build toggle) shows in Build mode; Combat overlay (Wave timer
  + drones + Combat toggle) shows in Combat/Raid mode. Use Theme
  motion presets for the swap.
- **`Constants.UI`** — top-level block. Slot key list (canonical palette
  slot names), motion preset durations (so they're tunable without
  module edits), toast timings (auto-dismiss seconds, stack maxes).
- **HUD migration (G5.1 proof-of-concept):** Migrate `CreditsDisplay`
  and `CoresDisplay` to use `Theme.GetActive().textPrimary` /
  `accent` / `panel` colors. These are the always-visible HUD elements
  so the biome swap is immediately observable.
- **Defer:** Shop / BP / Daily Quests / Clan / Leaderboard / Friends /
  Voice / Cosmetic panel migrations (G5.2). They're a mechanical
  find-replace once Theme + Components ship; user check-in opportunity
  before the bulk migration lands.

### Files touched / added (G5.1 slice)

- NEW `src/shared/Modules/UI/Theme.luau`
- NEW `src/shared/Modules/UI/Components.luau`
- NEW `src/client/Modules/HUD/ToastService.luau`
- `src/shared/Constants.luau` — `UI` block
- `src/client/Modules/HUD/CreditsDisplay.luau` — Theme migration
- `src/client/Modules/HUD/CoresDisplay.luau` — Theme migration
- `src/client/Modules/HUD/HudController.luau` — ModeController hook +
  mode-contextual layout
- `src/server/Modules/World/BiomeLightingService.luau` — fire
  `Theme.SetActive` from `Apply` (via a ReplicatedStorage
  ObjectValue ping so client-side Theme subscribes without a Remote)
- `src/client/init.client.luau` — register ToastService.Init early

### What's deferred to G5.2

- **Bulk panel migrations.** All non-HUD controllers stay on their
  hardcoded colors until G5.2 land. They'll work side-by-side with
  the themed HUD without visual chaos because the industrial /
  jungle palettes share the same charcoal-background family.
- **Mobile thumb-zone tuning.** Current action-bar position works on
  most aspects; per-device tuning lands in G5.3 if mobile playtest
  flags issues.
- **Animations on existing claim flows** (DailyLoginPopup, ClaimQuest,
  ClaimBattlePassTier) — they currently use no transitions; G5.2
  migration wraps them in Components.Panel which brings the motion
  presets automatically.
