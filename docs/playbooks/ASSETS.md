# ASSETS.md — Outpost-7 asset-sourcing playbook

> Marketplace search starters, AI-assisted asset generation prompts,
> and Phase G handoff checklist. The 18 V1 asset concepts cataloged
> here are the *concepts* — full detailed design + integration lands
> in Phase G per `docs/10_BUILD_PROTOCOL.md`.
>
> **Status:** Living document. Updated as concepts firm up; Phase G
> stamps each entry with a real AssetId once authored/uploaded.

---

## 0. TL;DR

- **Marketplace > custom.** Per `finalized-brainstorm.md` §4.8: "Modeling these from scratch is the wrong move." $300+ budget covers ~30–50 quality marketplace items.
- **Custom modeling for hero pieces only.** The 1–3 signature pieces that define the silhouette of Outpost-7 (operator profile, hero alien, base biome arch). Everything else: marketplace.
- **AI-assisted generation is fine for prototyping** (Meshy, Tripo3D produce Roblox-compatible MeshParts) but verify license terms before commercial use.
- **Phase G is the integration phase** (weeks 12–14 per brainstorm §3.2). Concepts can be sourced/modeled in *parallel* with code work starting now.

---

## 1. Asset philosophy

### 1.1 Why marketplace-first

- Solo dev with 14–18 weeks total. Custom modeling 30 buildings + 3 alien rigs + 3 vehicles + arches + skins is 200+ hours alone — not feasible alongside code.
- Marketplace assets at $1–50 each are PBR-ready, mobile-optimized, and license-clean (verify per asset).
- Roblox Creator Marketplace integrates directly: `Insert Object → Marketplace → search` adds the asset to your place with one click.

### 1.2 When custom is worth it

- **Iconic silhouette** — the player operator, the hero alien predator, the bioluminescent jungle gate. These define the game's visual identity; marketplace generic doesn't carry the brand.
- **Brainstorm pre-listed exceptions** — the brand-defining hero pieces.
- **Phase G timing** — author/commission concepts in weeks 8–11 in parallel with E/F coding so they're ready for Phase G integration.

### 1.3 V1 license discipline

Before any custom or AI-generated asset goes into a monetized game:
- Read the tool's commercial-use license terms (Meshy, Tripo3D each have tiered terms; free tiers may bar commercial use)
- Roblox Marketplace assets are generally commercial-safe but *verify per asset* (some are CC-BY-NC or asset-flip resales)
- Audio: Pixabay/Audiio licenses must allow commercial use in monetized games (per brainstorm §4.1)
- Document the source + license in this file's §6 audit log when each asset is finalized

---

## 2. Marketplace search starters

### 2.1 Roblox Creator Marketplace

Browse: https://create.roblox.com/store

| Asset class | Search terms | Filter notes |
|---|---|---|
| Sci-fi crates / props | `sci-fi crate`, `military crate`, `cargo container futuristic` | Sort by relevance; verify "Free for commercial use" flag |
| Foliage / flora (jungle) | `bioluminescent plant`, `alien tree`, `jungle vine`, `glowing flora` | Models or Decals as appropriate |
| Volcanic terrain | `volcanic rock`, `lava terrain`, `obsidian` | MeshPart preferred |
| Ice / cave terrain | `ice cave`, `glacier`, `frozen environment`, `crystal cluster` | Watch poly count for mobile |
| Operator armor | `military operator`, `tactical armor`, `sci-fi soldier`, `space marine` | Avatar-shaped rigs only |
| Vehicles | `hover bike`, `military rover`, `tank`, `futuristic vehicle` | Verify VehicleSeat present or be ready to wire one |
| Weapons / turrets | `laser turret`, `auto-turret`, `mounted gun`, `sci-fi weapon` | Animations included? |
| Drones | `combat drone`, `sci-fi drone`, `hover drone`, `recon drone` | Small models (under 50 parts) |
| Aliens / creatures | `alien predator`, `xenomorph`, `monster rig`, `creature` | Animation-rigged for Humanoid |
| UI icons | `sci-fi icon pack`, `military HUD`, `tactical interface` | PNGs at 256×256+ |

### 2.2 Adjacent marketplaces (texture / audio / 3D)

| Marketplace | Use for | Notes |
|---|---|---|
| Sketchfab | High-quality 3D models (.fbx, .glb) | Filter "Downloadable" + "Commercial use"; export → Studio Import 3D |
| TurboSquid | Premium 3D models | Higher cost; verify Roblox-compatible poly count |
| Quixel Megascans | PBR materials, foliage scans | Free with Epic account; Blender import → Studio |
| Pixabay | Royalty-free music + SFX | Filter "Commercial use OK" |
| Audiio | Synthwave / electronic music | Subscription license; brainstorm §4.1 listed |
| Freesound | SFX library | License per-asset (CC0 to CC-BY-NC); verify |

---

## 3. AI-assisted asset generation

### 3.1 Recommended tools (2026)

| Tool | Best for | Roblox compatibility | Notes |
|---|---|---|---|
| **Meshy AI** (meshy.ai) | Text-to-3D, image-to-3D MeshParts | Native `.fbx`/`.glb` export → Studio Import 3D | Tiered plans; verify commercial-use flag on output |
| **Tripo3D** (tripo3d.ai) | Fast text-to-3D prototyping | `.fbx` / `.glb` / `.obj` export | Good for blocking-out concept geometry before custom modeling |
| **CSM (Common Sense Machines)** | Detailed 3D from concept art | `.fbx` / `.glb` | Image-to-3D pipeline (concept art → 3D) |
| **Midjourney v6+** | Concept art (2D) | Indirect — feed images into Tripo3D / Meshy image-to-3D | Best silhouette/composition tool; needs character-sheet prompting for game-ready output |
| **DALL-E 3 (via ChatGPT/API)** | Concept art, texture sheets | Indirect | Strong at orthographic views; ask explicitly for "front / side / 3/4 view" |
| **Stable Diffusion + ControlNet** | Iterative concept art with pose/composition control | Indirect | Free, local; steeper learning curve |
| **Adobe Substance 3D Sampler** | Texture / material generation for existing meshes | Direct PBR export → Studio's `SurfaceAppearance` | Subscription |
| **Spline** (spline.design) | Browser-based 3D modeling | `.glb` export → Studio | No AI; manual but easy |
| **Blender** | Manual modeling, no AI | `.fbx` / `.obj` / `.glb` export → Studio | Free, industry standard, 200+ hour learning curve |

### 3.2 Prompt structure that works for AI 3D tools

A useful AI 3D prompt has six layers, in this order:

1. **Asset class** — "futuristic military hover bike", "bioluminescent alien predator quadruped"
2. **Silhouette** — "sleek aerodynamic profile, narrow at front, wide at rear"
3. **Proportions** — "approximately 8 studs long, 3 studs wide, 1.5 studs tall"
4. **Materials** — "matte tactical metal panels, neon accent strips, exposed plasma vents"
5. **Color palette** — "primary charcoal black (#1a1a22), accent neon teal (#00e0ff), warning red (#ff3838)"
6. **Distinctive details** — "twin forward plasma cannons, hover skirt with blue underglow, holographic windscreen"

Then end with **style modifiers**: "PBR materials, game-ready low-poly, ~5000 triangles, Roblox-compatible, single texture atlas, T-pose / neutral orientation".

### 3.3 Tool-specific tips

- **Meshy / Tripo3D:** keep prompts under ~400 chars; their parsers favor noun-heavy descriptions. Iterate with "remix" features rather than long single prompts.
- **Midjourney:** use `--ar 16:9 --style raw` for concept-sheet output. Add `orthographic views, character sheet, front side back 3/4` for multi-angle reference.
- **DALL-E 3:** explicit format prompts work — "Show front, side, top, and 3/4 perspective views in a single image, white background".
- **All:** end every prompt with `--no logo, --no text, --no watermark` (or equivalent negative prompts).

---

## 4. V1 asset concept catalog

The 18 concepts below are the V1 design catalog — concepts fully
documented now, full detailed design + Roblox integration in Phase G.
Each entry has:

- **Concept summary** — the elevator pitch
- **Visual references** — game/film/real-world anchors
- **AI design prompt** — paste-ready into Meshy/Tripo3D/Midjourney
- **Materials & palette** — PBR materials + hex codes
- **Scale & poly target** — Roblox studs + triangle budget
- **Animation needs** — what rigs / motions are required
- **Marketplace fallback** — search terms if going the buy-not-build route

### 4.1 Biome arches (3) — colony entry gates

The arch is the iconic "this is your colony" silhouette per biome. It frames the player's first arrival and is the most-recognizable thumbnail element. Three arches ship in V1, one per biome (jungle, volcanic, ice cave), each ~24 studs wide × 18 studs tall, freestanding around the plot's spawn-side edge.

#### 4.1.1 Bioluminescent Jungle Arch

- **Concept:** Organic-tech fusion. A corroded military structural frame overgrown by alien jungle: twisted glowing vines wrapped around weathered titanium beams, with bioluminescent flora pulsing magenta and teal from the cracks.
- **References:** *Avatar* hometree roots; *Subnautica* alien architecture; *Horizon Forbidden West* derelict tech overgrowth.

**AI design prompt:**

```
Bioluminescent alien jungle entrance arch, futuristic military origin
overgrown by hostile flora. Wide load-bearing arch ~24 studs across
and 18 studs tall, two stout titanium pillars connected by a curved
header beam. Pillars wrapped in thick twisted vines that glow from
within with magenta and teal bioluminescence. Header beam shows
exposed military structural ribs, partially corroded. Glowing alien
moss patches on lower pillar bases. Faint emissive flora particles
floating around the arch. PBR materials. Color palette: corroded
titanium (#3a3f48), deep jungle vine (#1a3320), neon magenta glow
(#ff3ec8), bioluminescent teal (#00e8d8). Game-ready low-poly,
target 4000-6000 triangles, single 1024x1024 texture atlas with
emissive map. Front-facing T-pose orientation, base flat to ground.
No logos, no text.
```

- **Materials & palette:** corroded titanium `#3A3F48` matte, jungle vine `#1A3320` rough, neon magenta `#FF3EC8` emissive 0.8, teal `#00E8D8` emissive 0.6
- **Scale:** 24 studs wide × 18 tall × 4 deep
- **Poly target:** 4,000–6,000 triangles
- **Animation needs:** subtle pulsing emissive material (driven by `TweenService` on `MeshPart.Color` cycling intensity, not skeletal); particle emitter for ambient glow motes
- **Marketplace fallback:** `bioluminescent arch`, `alien gateway`, `jungle ruins entrance`, `overgrown sci-fi structure`

#### 4.1.2 Volcanic Arch

- **Concept:** Obsidian and steel construction, lava-fissure inlays glowing molten orange beneath dark hex-paneled metal. Heat shimmer at the apex.
- **References:** *Doom Eternal* hell-tech architecture; *Halo* Forerunner volcanic forge; the Mordor Black Gate silhouette refit in sci-fi.

**AI design prompt:**

```
Volcanic biome militaristic entrance arch. Heavy industrial archway
~24 studs wide, 18 studs tall, two thick obsidian-armored pillars
joined by a hex-paneled steel crossbeam. Vertical lava fissures run
down the inside faces of the pillars, glowing molten orange and red
from inside cracked obsidian. Hex panels on the crossbeam are dark
charcoal with subtle volcanic rim-lighting. Heat-haze shimmer effect
suggested at the apex. Embedded warning chevron decals on the
pillar sides in faded amber. PBR materials. Color palette: obsidian
black (#0d0d12), tactical charcoal (#1f1f24), molten orange
(#ff6a1a), lava red (#ff2818), warning amber (#ffaa33). Game-ready
low-poly, target 4000-6000 triangles, single 1024x1024 texture atlas
with strong emissive map for the lava fissures. Front-facing
orientation, base flat to ground. No logos, no text.
```

- **Materials & palette:** obsidian `#0D0D12` smooth, charcoal `#1F1F24` matte, molten orange `#FF6A1A` emissive 1.0, warning amber `#FFAA33` emissive 0.5
- **Scale:** 24 × 18 × 4 studs
- **Poly target:** 4,000–6,000 triangles
- **Animation needs:** lava-fissure emissive pulse (slow ~3s loop); ParticleEmitter for ember motes drifting upward
- **Marketplace fallback:** `volcanic arch`, `obsidian gateway`, `industrial sci-fi arch`, `lava entrance`

#### 4.1.3 Ice Cave Arch

- **Concept:** Translucent crystalline ice grown over a militarized titanium frame, refractive blue/white interior glow, frost-cracked surface with embedded blue emissive lines.
- **References:** *Mass Effect* Noveria glacier base; *Halo Infinite* Cryptum glow; *Subnautica Below Zero* ice biome.

**AI design prompt:**

```
Cryogenic ice cave entrance arch, military structure encased in
crystalline ice. Two pillars 24 studs apart, 18 studs tall, with a
load-bearing titanium frame visible through translucent fractured
ice that grew over it. Ice has internal blue-white emissive
fractures running through it like veins. Titanium frame underneath
is gunmetal grey with frost crystals at the joints. Pale blue
emissive runes embedded along the inner edge of the arch, simple
geometric forms, evenly spaced. Faint frosty mist particles at the
base. PBR materials, ice surface uses subsurface-scattering shader
hint via translucency. Color palette: gunmetal titanium (#4a525c),
glacial ice translucent (#c8e8ff), deep ice (#5a8cc0), emissive
frost-blue (#aae0ff), pale white edge highlight (#e8f4ff).
Game-ready low-poly, target 4000-6000 triangles, single 1024x1024
texture atlas with strong subsurface and emissive maps.
Front-facing orientation, base flat to ground. No logos, no text.
```

- **Materials & palette:** titanium `#4A525C` matte, ice `#C8E8FF` `Glass` material, deep ice `#5A8CC0` translucent, frost-blue `#AAE0FF` emissive 0.7
- **Scale:** 24 × 18 × 4 studs
- **Poly target:** 4,000–6,000 triangles
- **Animation needs:** subtle emissive pulse on rune lines; ParticleEmitter for frost mist at base
- **Marketplace fallback:** `ice arch`, `crystal gateway`, `frozen sci-fi entrance`, `glacier doorway`

### 4.2 Operator skin packs (3) — playable character cosmetics

Three thematic operator skin packs cover both gameplay role expression and the brainstorm §2.7 monetization stack (VIP Operator pass cosmetic, Battle Pass premium reward, Heavy Defender as a future shop unlock). All three skins fit the standard Roblox `R15` rig so they ship as `BodyParts` swap or accessory bundle. Phase G decides whether to use full BodyParts swap (more visual fidelity) or accessory-only overlay (mobile-friendlier).

#### 4.2.1 Recon Operator skin pack

- **Concept:** Lightweight tactical scout. Sleek matte-dark plating with neon teal accent stripes; visor-style helmet with faint blue glow; profile is agile and silhouetted-runner.
- **References:** *Apex Legends* Wraith / Pathfinder silhouette; *Helldivers 2* light scout armor; *Destiny 2* Hunter class profile.

**AI design prompt:**

```
Sci-fi military Recon operator armor set, lightweight tactical
scout. Full-body humanoid armor designed for agility. Sleek matte
dark-grey base plating across torso, arms, legs. Slim cut with
articulated joint guards at elbows and knees. Asymmetric chest
plate with one shoulder pauldron, the other shoulder bare for
weapon mobility. Helmet is a sleek wraparound visor design, no
exposed face, with a faint horizontal blue-glow visor strip at eye
level. Neon teal accent stripes run along the outer thigh, outer
forearm, and along the helmet visor edge. Lightweight tactical
backpack with two emissive teal data-cable loops visible. Boots are
articulated multi-segment combat boots in same matte dark-grey.
Color palette: matte dark-grey (#22252a), accent neon teal
(#00e0ff), helmet visor glow (#aaeaff), darker grey trim (#15171c),
muted black gloves (#0d0e12). PBR materials, game-ready
low-poly, target 8000-10000 triangles total across full rig.
Standard humanoid R15 proportions, T-pose orientation.
No logos, no text.
```

- **Materials & palette:** dark-grey `#22252A` matte, neon teal `#00E0FF` emissive 0.9, visor `#AAEAFF` translucent, trim `#15171C` matte
- **Scale:** Standard R15 humanoid (`Players.RespawnTime` rig)
- **Poly target:** 8,000–10,000 triangles total (per-BodyPart split)
- **Animation needs:** Standard R15 animation set; Phase G may add emissive pulse on visor (subtle breathing effect)
- **Marketplace fallback:** `sci-fi scout armor`, `tactical recon operator`, `cyberpunk light armor`, `R15 sci-fi character`

#### 4.2.2 Combatant Operator skin pack (default V1 silhouette)

- **Concept:** Standard frontline armor — medium balanced plating, charcoal black with red accent stripes, full-face helmet. The default V1 power-fantasy silhouette and the "stock" look unless the player owns a cosmetic.
- **References:** *Helldivers 2* base helldiver; *Mass Effect* N7 armor; *Halo* ODST silhouette.

**AI design prompt:**

```
Sci-fi military Combatant operator armor set, standard frontline
balanced plating. Full-body humanoid armor in tactical charcoal
black. Medium-thickness chest plate with central reinforced sternum
panel, twin shoulder pauldrons of equal size, reinforced bicep
guards, articulated forearm gauntlets ending in armored gloves.
Hip plate with visible utility pouches and a sidearm holster on the
right thigh. Lower legs have shin plates and combat boots with
ankle guards. Helmet is full-face enclosure with a single
horizontal red visor band and exposed breathing-vent grills along
the jawline. Red accent stripes on outer biceps, outer shins,
helmet centerline ridge, and a single chest stripe across the
sternum. Subtle wear and battle scratches on plate edges. Color
palette: charcoal black (#1a1a22), accent warning red (#ff3838),
visor red glow (#ff5050), darker shadow black (#0d0d12), muted
metal trim (#3a3f48). PBR materials, game-ready low-poly, target
8000-10000 triangles total across full rig. Standard humanoid R15
proportions, T-pose orientation. No logos, no text.
```

- **Materials & palette:** charcoal `#1A1A22` matte, accent red `#FF3838` emissive 0.4, visor `#FF5050` emissive 0.9, metal trim `#3A3F48` matte
- **Scale:** Standard R15 humanoid
- **Poly target:** 8,000–10,000 triangles total
- **Animation needs:** Standard R15 set; helmet visor emissive matches breathing rhythm in Phase G
- **Marketplace fallback:** `sci-fi soldier armor`, `space marine R15`, `tactical operator`, `military sci-fi character`

#### 4.2.3 Heavy Defender Operator skin pack

- **Concept:** Bulky reinforced base-defender armor — thick angular plating, gunmetal grey with amber accent strips, exoskeleton-powered shoulders. Visually heaviest of the three, signals "I hold the line."
- **References:** *Halo* Mark VI armor at scale; *Warhammer 40K* Cataphractii Terminator silhouette (toned down for Roblox proportions); *Destiny 2* Titan class.

**AI design prompt:**

```
Sci-fi military Heavy Defender operator armor set, bulky reinforced
base-defender exoskeleton. Full-body humanoid armor with oversized
plating across torso, shoulders, and thighs. Massive shoulder
pauldrons sit higher than the helmet line, each with a glowing
amber data port. Thick chest plate with vertical reinforcing ribs.
Powered exoskeleton joints visible at hips, knees, shoulders with
exposed pistons and amber glow seams. Heavy thigh plates and shin
guards with armored toecaps. Helmet is reinforced with a heavy
brow ridge, a vertical visor slit instead of horizontal, and
amber-glow eye sensors visible inside the slit. Amber accent
strips along the chest center line, shoulder pauldron edges,
helmet brow, and along the thigh exoskeleton seams. Strong
heavy-duty silhouette, broad shoulders narrowing slightly at the
waist. Color palette: gunmetal grey (#4a525c), darker base shadow
(#2a2f38), accent amber (#ffaa33), amber emissive glow (#ffcc66),
exoskeleton seam amber (#ff8800). PBR materials, game-ready
low-poly, target 9000-11000 triangles total across full rig
(slightly higher budget for the bulk). Standard humanoid R15
proportions exaggerated outward in shoulders/thighs, T-pose
orientation. No logos, no text.
```

- **Materials & palette:** gunmetal `#4A525C` matte, base shadow `#2A2F38` matte, amber `#FFAA33` emissive 0.6, glow `#FFCC66` emissive 0.9
- **Scale:** Standard R15 humanoid with exaggerated shoulder/thigh bulk (still rig-compatible)
- **Poly target:** 9,000–11,000 triangles total
- **Animation needs:** Standard R15 set; Phase G adds idle "exoskeleton pneumatic" hiss SFX timed to step animations
- **Marketplace fallback:** `heavy power armor`, `sci-fi tank operator`, `space marine heavy`, `exoskeleton armor R15`

### 4.3 Alien concepts (3) — biome-tied wave variants

V1 currently codes only the Stalker (per `AlienRegistry.luau`). Phase G adds the volcanic + ice-cave variants and ties wave composition to the active biome. All three are humanoid-rigged so they reuse the existing `AlienAI.luau` MoveTo + Touched melee code path; per-variant stats live in `Constants.COMBAT` overrides.

#### 4.3.1 Stalker — bioluminescent jungle predator (V1 active)

- **Concept:** Quadrupedal predator with bioluminescent magenta body, four insect-like legs, glowing eye cluster. The default V1 alien.
- **References:** *Subnautica* Reaper Leviathan compressed to dog-size; *Half-Life* Houndeye; *Avatar* Pandora wildlife.

**AI design prompt:**

```
Bioluminescent alien predator quadruped, jungle hunter creature.
Body length approximately 6 studs nose-to-tail, height at shoulder
approximately 4 studs, low-slung agile profile. Four insect-like
articulated legs with sharp claws. Carapace torso has chitinous
plates with bioluminescent magenta veins glowing through the seams.
Front of head has a vertical cluster of six small glowing teal eyes
arranged in a 2x3 grid, no traditional face. Mouth is a horizontal
mandible split, teeth visible. Body texture is a glossy
chitin-style with subsurface magenta glow seeping through cracks.
Skeletal frill of small spines along the spine ridge. Tail is short
and segmented with a single bioluminescent tip. Predatory
forward-leaning stance. Color palette: deep chitin black-purple
(#22102e), bioluminescent magenta glow (#ff3ec8), eye-cluster teal
(#00e8d8), pale claw bone (#a8a89a). PBR materials, glossy
chitin shader, game-ready low-poly, target 5000-7000 triangles,
single 1024x1024 texture atlas with strong emissive map for the
seams and eyes. Skeletal rig compatible with Roblox humanoid
animator (4-leg quadruped rig). No logos, no text.
```

- **Materials & palette:** chitin `#22102E` glossy, magenta `#FF3EC8` emissive 0.9, teal eyes `#00E8D8` emissive 1.0, claw `#A8A89A` matte
- **Scale:** 6 studs long × 4 tall × 2 wide
- **Poly target:** 5,000–7,000 triangles
- **Animation needs:** Walk cycle, run, idle, attack (lunge bite), death — quadruped rig; Roblox `Humanoid` with `RigType = R6` substituted
- **Marketplace fallback:** `alien predator quadruped`, `xenomorph creature`, `glowing alien beast`, `sci-fi monster rig`

#### 4.3.2 Magmaling — volcanic biome heavy

- **Concept:** Slow heavy alien — molten obsidian shell with cracks revealing a lava core, two long arms ending in claws. Hits harder, walks slower than Stalker. Volcanic biome wave variant.
- **References:** *Diablo IV* Khazra hellforged; *Doom Eternal* Pinky imp; *Halo* Hunter scaled down.

**AI design prompt:**

```
Volcanic alien heavy melee creature, slow but armored. Bipedal
hunched humanoid silhouette approximately 5 studs tall and 3 studs
wide at shoulders. Body is encased in cracked obsidian-armor
plating, jet black exterior with deep cracks revealing molten
orange lava core glowing from inside. Heavy arms hang nearly to
the ground, ending in three-fingered obsidian claws. Short
muscular legs with hoof-like obsidian feet. Head is a featureless
obsidian dome with a single horizontal crack running across where
eyes would be, lava glow visible through it. Massive armored back
ridge with vertical heat vents emitting wavy heat distortion.
Slow heavy stance, slightly forward-leaning. Color palette: deep
obsidian black (#0d0d12), molten orange core (#ff6a1a), bright
lava red (#ff2818), darker shadow black (#1f1f24), pale ash grey
(#5a5a60). PBR materials, glossy obsidian shader for armor with
strong emissive map for the lava core cracks, game-ready
low-poly, target 5000-7000 triangles, single 1024x1024 texture
atlas. Skeletal rig compatible with Roblox humanoid animator
(R15 bipedal). No logos, no text.
```

- **Materials & palette:** obsidian `#0D0D12` glossy, molten `#FF6A1A` emissive 1.0, lava red `#FF2818` emissive 0.8, ash `#5A5A60` matte
- **Scale:** 5 tall × 3 wide × 2 deep studs
- **Poly target:** 5,000–7,000 triangles
- **Animation needs:** Walk (slow heavy), idle, melee (heavy swing), death (crack open + lava burst); R15 rig with custom slow walk cycle
- **Stat overrides (proposed for Phase G `Constants.COMBAT`):** HP 200, melee 25, cooldown 1.5s, walkspeed 8
- **Marketplace fallback:** `lava monster`, `obsidian creature`, `volcanic alien`, `hellforged enemy R15`

#### 4.3.3 Cryowraith — ice cave biome variant

- **Concept:** Translucent crystalline alien — blue refractive body, no defined face, drifts/glides slightly above ground rather than walking. Phases briefly when damaged. Ice cave biome wave variant.
- **References:** *Mass Effect* Banshee silhouette; *Halo* Lekgolo worm-light fusion; *Diablo IV* Spirit Born ethereal forms.

**AI design prompt:**

```
Crystalline ice alien wraith creature, ethereal floating predator.
Tall thin humanoid silhouette approximately 6 studs tall and 1
stud wide. Body is composed of translucent fractured ice with
internal blue-white emissive veins. No solid skeleton visible from
outside, only the ice forms suggesting torso and elongated arms.
Lower body trails off into a wispy frozen mist tail rather than
ending in legs, with the figure floating 1 stud above the ground.
Head is an elongated upright crystal cluster with three vertical
blue glowing slits where eyes would be, no mouth. Two long thin
arms ending in elongated icicle-claws, knuckles glowing brighter
than the rest. Constant faint frosty mist particle aura around the
figure. Body has subsurface scattering — light passes through the
ice and reflects internally. Color palette: glacial ice translucent
(#c8e8ff), deep core ice (#5a8cc0), bright emissive eye-blue
(#aae0ff), pale white edge (#e8f4ff), darker shadow blue (#3a5078).
PBR materials with strong subsurface scattering shader and
emissive map for the internal veins, game-ready low-poly, target
4500-6500 triangles, single 1024x1024 texture atlas with alpha
for the wispy lower body. Skeletal rig compatible with Roblox
humanoid animator (R15 with floating offset replacing leg
animations). No logos, no text.
```

- **Materials & palette:** ice `#C8E8FF` `Glass` material, deep ice `#5A8CC0` translucent, emissive blue `#AAE0FF` emissive 0.9, edge `#E8F4FF` translucent
- **Scale:** 6 tall × 1 wide × 1 deep studs (floating 1 stud above ground)
- **Poly target:** 4,500–6,500 triangles
- **Animation needs:** Floating idle (no walk cycle — vertical bob), drift toward target (replace MoveTo physics with `BodyPosition`/`AlignPosition` for hover effect in `AlienAI.luau` variant branch), claw attack, "phase" damage tell (briefly translucent + back), death (shatter into ice shards)
- **Stat overrides (proposed):** HP 75, melee 15, cooldown 0.8s, walkspeed 12 (faster than Stalker, less HP, glass-cannon profile)
- **Marketplace fallback:** `ice wraith`, `crystal alien`, `frozen specter`, `ethereal R15 enemy`

### 4.4 Turret concepts (3) — placeable defensive emplacements

V1 currently codes only the basic Auto-Turret (single buildable id `turret` per `BuildableRegistry.luau`). Phase G adds the two specialty turrets as new buildables with role-distinct stats. Each turret is a 1-cell placement on the plot grid (`Constants.GRID.Size = 4` studs); the visual base + rotating head structure stays under the cell footprint.

#### 4.4.1 Auto-Turret — basic single-barrel (V1 active)

- **Concept:** Standard auto-targeting turret, single barrel, balanced damage and rate. The default V1 placeable defensive option.
- **References:** *Half-Life 2* combine ceiling turret simplified; *Helldivers 2* sentry turret; *Aliens* (1986) sentry guns.

**AI design prompt:**

```
Sci-fi military auto-turret, single barrel defensive emplacement.
Square base plate approximately 2 studs wide and 1 stud tall, with
exposed power-coupling cables running into the ground. Center post
with a yaw-rotation joint, supporting a turret head 1.5 studs wide
and 1.5 studs tall. Turret head is a tactical sensor cluster on top
with two horizontal optical lenses, single forward barrel
approximately 3 studs long protruding from the front of the head,
muzzle has a faint red emissive ring. Cooling fins along the sides
of the head, twin small antenna stalks on the back of the head.
Base plate has warning chevron decals on the four corners in muted
amber. Color palette: steel-blue tactical (#5082b4), darker base
shadow (#2a3540), barrel gunmetal (#3a4048), muzzle red emissive
(#ff5050), warning amber (#ffaa33). PBR materials, game-ready
low-poly, target 1500-2500 triangles, single 1024x1024 texture
atlas. The turret head should be a separate MeshPart from the base
so server code can rotate it via CFrame around the yaw axis.
T-pose (head facing forward) orientation. No logos, no text.
```

- **Materials & palette:** steel-blue `#5082B4` matte, base shadow `#2A3540` matte, gunmetal `#3A4048` matte, muzzle red `#FF5050` emissive 0.7
- **Scale:** 2 × 2 × 3 studs (base + head)
- **Poly target:** 1,500–2,500 triangles
- **Animation needs:** Yaw rotation of head MeshPart driven by `TurretService` per-tick CFrame; muzzle-flash brief emissive pulse on fire (Phase G uses `ParticleEmitter`)
- **Marketplace fallback:** `auto turret`, `sentry gun`, `defensive turret`, `sci-fi mounted gun`

#### 4.4.2 Heavy Cannon Turret — anti-armor, slow rate, high damage

- **Concept:** Twin-barrel siege turret. Slow fire rate but high damage per shot — designed to one-shot heavy aliens (Magmaling) or punch through clustered targets.
- **References:** *StarCraft* Siege Tank; *Halo* Wraith mortar style adapted to fixed mount; *Warhammer 40K* Predator tank turret.

**AI design prompt:**

```
Sci-fi military heavy cannon turret, anti-armor twin-barrel
emplacement. Square reinforced base plate approximately 2.5 studs
wide and 1 stud tall, with heavy-duty bracing struts at the four
corners and exposed coolant lines wrapping around the base. Center
mount with a yaw-rotation joint, supporting a heavy turret head 2
studs wide and 2 studs tall. Turret head has a thick frontal armor
plate, dual side-by-side cannon barrels approximately 4 studs long
each, barrel diameter noticeably thicker than the basic turret.
Each barrel has a heat-vent gill pattern along its top surface.
Single tactical optic between the barrels, glowing red. Heavy
ammunition feed visible from the back of the head, leading into a
visible ammo belt hanging out the side. Reinforced shoulder plates
on the head sides for armor. Color palette: gunmetal heavy grey
(#3a3f48), darker armor shadow (#1f2228), barrel hot-metal
(#4a3f3a), warning red emissive optic (#ff2818), dirty hazard amber
(#cc8822). PBR materials with surface wear and battle scratches,
game-ready low-poly, target 2500-3500 triangles, single 1024x1024
texture atlas with strong specular for the barrels. Head separate
from base for yaw rotation. T-pose orientation. No logos, no text.
```

- **Materials & palette:** gunmetal `#3A3F48` matte with wear, armor shadow `#1F2228` matte, optic red `#FF2818` emissive 0.9, hazard amber `#CC8822` matte
- **Scale:** 2.5 × 2.5 × 4 studs
- **Poly target:** 2,500–3,500 triangles
- **Animation needs:** Yaw rotation; heavy recoil (head jerks back ~0.3 studs on fire, returns over 0.5s); muzzle flash + ParticleEmitter ember burst per shot
- **Stat overrides (proposed for Phase G `Constants.COMBAT`):** range 35, damage 80 (1-shot Stalker, 3 shots Magmaling), fire rate 3.0s (slow), cost 600 credits
- **Marketplace fallback:** `siege turret`, `heavy cannon`, `dual barrel turret`, `anti-tank emplacement`

#### 4.4.3 Burst Laser Turret — anti-swarm, fast rate, low damage

- **Concept:** Multi-emitter cluster head, blue plasma glow, fast fire rate, low damage per shot. Designed for crowd control against alien waves and air-targeting (drones/wraiths).
- **References:** *Mass Effect* GARDIAN laser defense; *Halo* anti-air laser; *EVE Online* point-defense weapons.

**AI design prompt:**

```
Sci-fi military burst laser turret, anti-swarm point-defense
emplacement. Lightweight base plate approximately 1.8 studs wide
and 0.8 studs tall with elegant flowing lines, fewer hard angles
than the heavy cannon. Center mount has a yaw-rotation joint and a
secondary pitch joint for vertical aim, supporting a sleek
emitter cluster head 1.5 studs wide and 1.2 studs tall. Cluster
head has six small laser emitter barrels arranged in a tight 2x3
grid on the front face, each barrel ending in a glowing blue
plasma lens. Twin advanced sensor arrays on top of the head with a
spinning radar-style detection element. Heat-radiator fins along
the sides of the head with bright blue emissive seams. Profile is
sleeker, more refined than the other turrets — suggests
high-tech precision. Color palette: clean tactical white
(#dde2e8), refined steel-blue (#5082b4), darker shadow steel
(#2a3540), bright blue plasma emissive (#00aaff), cool white
emissive (#ccddff), trim red warning (#ff3838 sparse). PBR
materials with subtle metallic sheen, game-ready low-poly, target
2000-3000 triangles, single 1024x1024 texture atlas with strong
emissive for the emitter lenses and radiator seams. Head separate
from base for yaw, sub-head separate for pitch (two-axis rig).
T-pose orientation. No logos, no text.
```

- **Materials & palette:** white `#DDE2E8` semi-matte, steel-blue `#5082B4` matte, plasma `#00AAFF` emissive 1.0, white emissive `#CCDDFF` emissive 0.7
- **Scale:** 1.8 × 1.8 × 2 studs
- **Poly target:** 2,000–3,000 triangles
- **Animation needs:** Two-axis aim (yaw + pitch); rapid fire emissive pulse on each emitter in sequence (suggests automatic burst); spinning radar element on top idle-spins constantly
- **Stat overrides (proposed):** range 30, damage 6 (4 shots to kill a Stalker), fire rate 0.2s (5 shots/sec), cost 350 credits
- **Marketplace fallback:** `point defense laser`, `anti-air turret`, `burst laser`, `precision laser turret`

### 4.5 Drone swarm concepts (3) — autonomous companions

V1 has all three presets registered in `DroneSwarmRegistry.luau`; only Combat is functional in V1 per E2.6. Phase G ships visuals for all three plus wires the V1.5+ Recon spotting and Engineering repair behaviors. Drones are small Parts (~0.8 × 0.4 × 1.2 studs) that orbit the player at radius 8.

#### 4.5.1 Recon Swarm — scout (V1.5+ active)

- **Concept:** Small scout drone with a single forward sensor pod, fast and quiet. Phase G wires the "spot" behavior: the drone tags aliens within 50 studs on a HUD overlay so the player can pre-position turrets/walls.
- **References:** *Battlefield* recon drone; *Mass Effect* combat drone scout variant; modern military quadcopter aesthetic.

**AI design prompt:**

```
Sci-fi military scout drone, small autonomous companion. Compact
flying body approximately 1.2 studs long, 0.8 studs wide, 0.4 studs
tall — bird-like aerodynamic profile pointing forward. Sleek
streamlined body with a single large forward-facing sensor pod
making up the front 30% of the drone, like a single cyclopean
camera lens. Behind the sensor pod, a slim body section with two
small horizontal stabilizing fins on each side. Two compact
silent-thruster nozzles at the rear, glowing pale blue. Belly has
a small targeting laser emitter pointing down. Profile is light,
fast, observational rather than threatening. Color palette: clean
tactical white (#dde2e8), recon blue accent (#5096e8), darker
shadow (#2a3540), sensor lens cyan emissive (#80c8ff), thruster
glow blue (#5cb8ff). PBR materials with subtle metallic sheen,
game-ready low-poly, target 600-1000 triangles, single 512x512
texture atlas. Forward-facing T-pose orientation. The body is one
MeshPart; thruster glow is achieved via emissive material on the
nozzle vertices, no separate part needed. No logos, no text.
```

- **Materials & palette:** white `#DDE2E8` semi-matte, recon blue `#5096E8` matte, sensor lens `#80C8FF` emissive 1.0, thruster `#5CB8FF` emissive 0.8
- **Scale:** 1.2 × 0.8 × 0.4 studs
- **Poly target:** 600–1,000 triangles
- **Animation needs:** Idle hover bob (already done by `DroneSwarmService` orbit); Phase G adds a sensor-pod-pulse emissive when an alien is spotted
- **V1.5 behavior:** subscribes to `Workspace.AlienActors` scan; emits `AlienSpotted` Remote per tagged alien; client overlays a marker on the HUD minimap (Phase G's HUD work)
- **Marketplace fallback:** `scout drone`, `recon drone`, `surveillance drone`, `sci-fi quadcopter`

#### 4.5.2 Combat Swarm — attack (V1 active)

- **Concept:** Aggressive fighter drone — twin laser emitters, neon-red trail, breaks orbit to chase aliens within 25 studs. The default V1 active preset.
- **References:** *Mass Effect 3* combat drone; *Helldivers 2* "Guard Dog Rover" laser drone; *Halo* Engineer-as-hunter aesthetic flipped offensive.

**AI design prompt:**

```
Sci-fi military combat drone, autonomous attack companion.
Compact body approximately 1.2 studs long, 0.8 studs wide, 0.4
studs tall. More aggressive silhouette than the scout — wedge-
shaped front with twin forward-mounted laser emitter barrels
(each ~0.4 studs long protruding from the front-left and front-
right). Sharp angled body panels. Single central red sensor lens
on top of the body, smaller than the scout's. Twin propulsion
thrusters at the rear, glowing red-orange. Two small canted
stabilizer fins angled downward and outward (like a fighter jet
in attack profile). Belly has small hardpoint with two micro-
missile pods (decorative, V1.5 may activate). Color palette:
charcoal black (#1a1a22), aggressive red accent (#ff3838),
darker shadow (#0d0d12), laser emitter red emissive (#ff5050),
thruster glow red-orange (#ff6a1a), sensor lens red emissive
(#ff2818). PBR materials with edge wear, game-ready low-poly,
target 800-1200 triangles, single 512x512 texture atlas.
Forward-facing T-pose orientation. Single MeshPart body; emissive
laser barrels and thrusters via material, no separate parts. No
logos, no text.
```

- **Materials & palette:** charcoal `#1A1A22` matte, red accent `#FF3838` emissive 0.4, laser barrel `#FF5050` emissive 1.0, thruster `#FF6A1A` emissive 0.8
- **Scale:** 1.2 × 0.8 × 0.4 studs
- **Poly target:** 800–1,200 triangles
- **Animation needs:** Already wired in V1 — orbit + break-to-chase + laser beam visual via `Debris:AddItem`. Phase G adds a brief muzzle-flash particle on each shot
- **Marketplace fallback:** `combat drone`, `attack drone`, `sci-fi laser drone`, `military strike drone`

#### 4.5.3 Engineering Swarm — repair (V1.5+ active)

- **Concept:** Repair drone with a manipulator arm and green emissive pulses. Phase G wires "repair" behavior once turrets/walls have HP (V1 has them invincible per E2.5 tech debt).
- **References:** *Mass Effect Andromeda* APEX engineering drone; *Star Wars* mouse droid scaled up; *Half-Life 2* Combine Manhack with friendly-paint job.

**AI design prompt:**

```
Sci-fi military engineering drone, repair companion. Compact body
approximately 1.2 studs long, 0.8 studs wide, 0.4 studs tall.
Sturdy utilitarian silhouette, less sleek than scout/combat
variants. Body has a central tool-bay opening on the underside
revealing a folded manipulator arm with a small claw and a welder
torch tip. Arm is currently retracted into the bay; will deploy
when active. Three small status indicator lights on the top of
the body (left amber, center green, right amber) — diagnostic LED
strip pattern. Twin propulsion thrusters at the rear, glowing
green. Stubbier stabilizer fins than scout/combat — function over
form. Belly has a docking magnet plate (small disc on the
underside). Color palette: utility olive-green (#5a7048), darker
shadow olive (#2f3a25), bright engineering green emissive
(#88e060), thruster green glow (#aaff80), warning amber (#ffaa33),
white indicator light (#e8f4ff). PBR materials with utility-spec
wear and tool-marks, game-ready low-poly, target 700-1100
triangles, single 512x512 texture atlas. Forward-facing T-pose
orientation. The manipulator arm is a separate MeshPart so the
repair animation can deploy it via CFrame. No logos, no text.
```

- **Materials & palette:** olive `#5A7048` matte, green emissive `#88E060` emissive 0.7, thruster `#AAFF80` emissive 0.9, amber `#FFAA33` emissive 0.4
- **Scale:** 1.2 × 0.8 × 0.4 studs
- **Poly target:** 700–1,100 triangles
- **Animation needs:** Idle hover; manipulator arm deploy CFrame on repair start; welder torch tip emissive pulse during repair; auto-retract arm on repair end
- **V1.5 behavior:** subscribes to `TurretService.OnDamaged` (Phase G adds the signal alongside turret HP); selects the most-damaged friendly structure within 25 studs; emits `RepairTick` events; restores HP at a configurable rate
- **Marketplace fallback:** `repair drone`, `engineering drone`, `utility drone`, `sci-fi medic drone`

### 4.6 Vehicles (3) — V1 scope addition (approved 2026-05-05)

User-approved scope addition (see brainstorm.md §2.8). Three vehicles ship in V1: ground rover for scouting, hover bike for raid mobility, hover tank for cooperative team-play. All use Roblox `VehicleSeat` + Constraint physics per the Phase E2.5 research pass; server-authoritative driving Remotes wire into raid context where exploits matter (Phase G integration sub-phase).

#### 4.6.1 All-Terrain Military Exploratory Rover

- **Concept:** 6-wheel armored military exploration buggy — ground-based, used for scouting deeper jungle terrain, transports the operator + cargo. Driver seat plus exposed cargo bed.
- **References:** *Halo* Warthog (M12 LRV); *Star Citizen* Cyclone; *Helldivers 2* utility transport; real-world MRZR / DAGOR military buggies.

**AI design prompt:**

```
Futuristic military all-terrain exploratory rover, 6-wheel utility
buggy. Total length approximately 14 studs, width 7 studs, height
6 studs to roof. Open-top design with a heavy-duty roll cage in
exposed black tubing forming a protective frame above the cabin.
Three pairs of large knobby off-road wheels (6 wheels total)
mounted on independent suspension arms — front pair, middle pair,
rear pair, each wheel approximately 3 studs in diameter. Wide
fender flares over each wheel. Front of the vehicle has a heavy
brush guard and twin LED headlight bars in cool white. Cabin has
two front bucket seats with tactical webbing harnesses, raised
center console between them with a small sci-fi GPS holographic
display element. Open cargo bed at rear (approximately 5 studs
long) with cargo tie-down strap rings and a small mounted
toolbox. Side panels have armored skirting in plate metal with
warning chevrons. Spare wheel mounted on the rear left side.
Twin exhaust pipes wrapping up and over the rear (futuristic
plasma exhaust style, with cool blue glow rings instead of
gas exhaust). Color palette: military jungle-green base (#3a4a32),
darker shadow olive (#1f2818), tactical black trim (#0d0d12),
warning amber chevrons (#ffaa33), headlight cool white emissive
(#e8f4ff), exhaust plasma blue emissive (#5cb8ff), tire matte
black (#15171c). PBR materials with heavy weathering, mud streaks
on lower body and wheel arches, game-ready low-poly, target
6000-8000 triangles, single 1024x1024 texture atlas. Wheels are
separate MeshParts (6 of them) so HingeConstraints can drive them.
T-pose orientation, front-facing. No logos, no text.
```

- **Materials & palette:** military green `#3A4A32` matte weathered, shadow olive `#1F2818` matte, black trim `#0D0D12` matte, amber `#FFAA33` matte, headlight `#E8F4FF` emissive 1.0, plasma exhaust `#5CB8FF` emissive 0.8
- **Scale:** 14 long × 7 wide × 6 tall studs
- **Poly target:** 6,000–8,000 triangles
- **Animation needs:** Wheel rotation via `HingeConstraint` motors driven by `VehicleSeat`; suspension travel via `SpringConstraint` (one per wheel); headlight emissive intensity scales with night-cycle in Phase G
- **Roblox integration notes:** `VehicleSeat` in front-left seat with `MaxSpeed = 28`, `Torque = 50`, `TurnSpeed = 8`; 6 `HingeConstraint`-driven wheels with `MotorMaxAcceleration` tuned for off-road feel; `SpringConstraint` per wheel for suspension; mass roughly distributed 60% rear (cargo bed) for off-road stability; mobile-friendly: VehicleSeat handles touch input automatically
- **Phase E.5 / G implementation file path:** `src/server/Modules/Vehicle/RoverService.luau` (new), `src/shared/Modules/Registry/VehicleRegistry.luau` (new catalog)
- **Marketplace fallback:** `military buggy`, `sci-fi rover`, `Halo warthog inspired`, `6 wheel offroad vehicle`, `tactical UTV`

#### 4.6.2 Sleek Militaristic Hover Bike

- **Concept:** Halo Ghost-inspired hover bike but more militaristic and aggressive. Single rider. Hovers ~2 studs above ground. Twin forward plasma cannons. Sleek tactical fairings. Designed for raid mobility — fast, agile, lightly armed.
- **References:** *Halo* Ghost (the silhouette anchor); *Star Wars* speeder bike refit; *Cyberpunk 2077* Yaiba Kusanagi hover variant.

**AI design prompt:**

```
Futuristic militaristic hover bike, single-rider tactical fast-attack
vehicle. Total length approximately 8 studs, width 3 studs (excluding
wing extensions), height 2.5 studs to top of rider position when
empty. Hovering body sits 2 studs above ground level — no wheels,
no skis, only ground-effect glow underneath. Sleek aerodynamic
nose at front, narrowing to a tactical hardpoint where twin
forward-mounted plasma cannons protrude approximately 2 studs
each. Cannons are integrated into the chassis, not external
mounts — they belong to the vehicle's silhouette. Single
forward-leaning rider position with handlebar grips and a
recessed seat (the rider's torso is exposed but legs tuck into
the chassis). Two small angled wing extensions on each side
(left and right, ~2 studs each) angled slightly downward,
suggesting downforce or stabilization, with cool blue thruster
vents on their undersides. Rear has a single large central
thruster nozzle approximately 2 studs in diameter glowing bright
blue. Beneath the body, a hover skirt with steady cool-blue
ground-effect glow underlining the entire bike. Tactical military
hex-paneling along the body sides. Color palette: tactical
gunmetal grey (#3a4048), darker shadow (#1f2228), aggressive red
warning accent (#ff3838 sparingly), plasma cannon blue emissive
muzzle (#5cb8ff), main thruster blue emissive (#00aaff),
hover-skirt ground-effect glow (#3aa8ff), cooling vent cool-cyan
(#80c8ff). PBR materials with subtle metallic edges and battle
scratches on the nose, game-ready low-poly, target 4500-6000
triangles, single 1024x1024 texture atlas. The bike body is a
single MeshPart anchored to the VehicleSeat; no actual wheels
needed. T-pose orientation, front-facing. No logos, no text.
```

- **Materials & palette:** gunmetal `#3A4048` matte, shadow `#1F2228` matte, red accent `#FF3838` emissive 0.3, plasma `#5CB8FF` emissive 1.0, thruster `#00AAFF` emissive 1.0, ground-effect `#3AA8FF` emissive 0.6
- **Scale:** 8 long × 3 wide × 2.5 tall studs (hovers 2 studs above ground)
- **Poly target:** 4,500–6,000 triangles
- **Animation needs:** Constant subtle bob (vertical sine wave 0.1 stud amplitude, 1.5s period) when stationary — driven via `BodyPosition` or `AlignPosition` rather than per-frame CFrame; ground-effect glow particles ParticleEmitter underneath; cannon muzzle flash on fire; lean into turns (5° roll on yaw input)
- **Roblox integration notes:** No wheels — use a `VehicleSeat` + `BodyVelocity` or modern `LinearVelocity` constraint for forward thrust + `BodyGyro` / `AlignOrientation` for steering. Hover offset maintained by raycast-down + `BodyPosition` Y-target. `MaxSpeed = 50`, `Torque` doesn't apply — apply `LinearVelocity.MaxForce` instead. Cannons fire raycast damage via a dedicated `FireBike` Remote (server validates rider == owner of vehicle); damage routes through `DamageService` per E2 chokepoint.
- **Phase E.5 / G implementation file path:** `src/server/Modules/Vehicle/HoverBikeService.luau`
- **Marketplace fallback:** `hover bike`, `Halo ghost inspired`, `sci-fi speeder bike`, `futuristic motorcycle hover`, `tactical hover vehicle`

#### 4.6.3 Armed Hover Tank (driver + gunner)

- **Concept:** Main battle tank silhouette but hovering. Driver seat (front) + gunner seat (top). Roof-mounted laser machine gun turret. Heavy frontal armor, exposed plasma vents. Solo player can drive AND shoot via a toggle key; cooperative play has the gunner free-aim while the driver focuses on positioning.
- **References:** *Halo* Wraith / Scorpion silhouette merged; *Battlefield 2142* hover tank; *Mass Effect* Mako with hover treatment; *EVE Online* Caldari ship aesthetic at vehicle scale.

**AI design prompt:**

```
Futuristic militaristic hover tank, dual-crew armed armored
vehicle. Total length approximately 16 studs, width 8 studs,
height 5 studs to top of mounted turret (3.5 studs to chassis
roof). Main chassis is a hovering hull sitting 1.5 studs above
ground — no wheels, no treads. Heavily armored front-facing
glacis plate with sloped angles for deflection, multiple
horizontal armor laminate layers visible at the edges. Driver
position is a forward-recessed cockpit at the front-center of
the chassis, partially enclosed with an armored canopy and a
narrow horizontal viewing slit (or holographic windscreen).
Gunner position is a raised armored hatch on top-center of the
chassis with a 360-degree-rotating circular ring mount. On top
of the ring mount, a laser machine gun turret with a single long
emitter barrel approximately 4 studs long, plus a secondary
twin-barrel anti-personnel laser cluster on the left side of the
turret head. Turret head can rotate independently of the chassis.
Side hull armor has horizontal heat-sink fins and exposed plasma
vents (3 per side) glowing bright cyan from internal heat. Rear
has two massive primary thruster nozzles (3 studs diameter each)
glowing intense blue, plus a smaller central rear maneuvering
thruster. Underside has a constant cool-blue hover-effect glow
along the entire belly. Side armor has stenciled warning hazard
chevrons in faded amber and a subtle painted division marker.
Track-style lower armor skirts (vestigial — no actual treads,
purely visual armor) wrap around the lower hull edges. Color
palette: heavy military green-grey base (#3f4838), darker shadow
(#1f2520), tactical black trim (#0d0d12), plasma vent cyan
emissive (#5cb8ff), main thruster intense blue emissive (#00aaff),
hover-belly blue glow (#3aa8ff), warning amber chevrons (#ffaa33),
turret laser barrel red emissive at muzzle (#ff5050), driver
canopy holo-blue (#80c8ff translucent). PBR materials with heavy
weathering, mud streaks on lower hull, battle scratches on
glacis plate, game-ready low-poly, target 7000-9500 triangles,
single 1024x1024 texture atlas with strong emissive maps for
vents and thrusters. The chassis is one MeshPart, the turret
ring is a separate MeshPart for yaw rotation, and the turret
head + barrel cluster is a separate MeshPart for both yaw and
pitch. T-pose orientation, front-facing, turret centered and
forward. No logos, no text.
```

- **Materials & palette:** military `#3F4838` matte heavy weathered, shadow `#1F2520` matte, plasma vent `#5CB8FF` emissive 0.9, main thruster `#00AAFF` emissive 1.0, hover belly `#3AA8FF` emissive 0.6, amber chevrons `#FFAA33` matte, laser muzzle `#FF5050` emissive 1.0
- **Scale:** 16 long × 8 wide × 5 tall studs (hovers 1.5 studs above ground)
- **Poly target:** 7,000–9,500 triangles
- **Animation needs:** Hover bob (slow 0.05 stud amplitude); turret yaw + pitch independent of chassis; muzzle flash + emissive pulse on fire; thruster glow intensity scales with throttle; ground-effect particles when moving
- **Roblox integration notes:**
  - Two `VehicleSeat`s — front (driver) drives chassis movement; rear-top (gunner) rotates turret via mouse/touch input
  - **Solo toggle:** when only the driver is occupied AND `Constants.VEHICLE.HoverTank.SoloMode == true`, an `E` keybind switches input control between driver-mode (chassis movement) and gunner-mode (turret aim + fire). Switching is server-arbitrated to prevent dual-input exploits
  - Movement uses `LinearVelocity` + `AlignOrientation` constraints (same hover pattern as the bike, scaled)
  - Turret rotation server-authoritative via `FireTank` Remote (gunner aim → server validates → applies damage via `DamageService`)
  - Damage via raycast from turret muzzle through `DamageService.ApplyToHumanoid`
  - `MaxSpeed = 22` (slower than bike, faster than rover); `Torque` analogue via `LinearVelocity.MaxForce` tuned for tank-like inertia (slow accel, slow brake)
  - Mass: 4× rover, 8× hover bike (relative tuning)
- **Phase E.5 / G implementation file path:** `src/server/Modules/Vehicle/HoverTankService.luau`
- **Marketplace fallback:** `hover tank`, `Halo wraith inspired`, `sci-fi assault tank`, `futuristic military tank`, `floating tank vehicle`

---

## 5. Phase G handoff checklist

### 5.1 Pre-Phase G prerequisites (run weeks 8–11 in parallel with code)

- [ ] Marketplace shopping pass — browse the §2 search starters; bookmark candidates, tag with their license terms
- [ ] AI prompt iteration — run each §4 prompt through Meshy / Tripo3D, generate 3–5 variants per asset, pick the best
- [ ] Hero-asset commission decision — for the 1–3 truly custom pieces (likely Stalker, jungle arch, hover tank), decide: in-house Blender modeling, paid commission, or Marketplace+heavy-edit
- [ ] License audit — record each candidate asset's source + license in §6 below
- [ ] `assets/` folder organized per `REPO_STRUCTURE.md` §1: `assets/world/biome_jungle/`, `assets/characters/`, `assets/effects/`, etc.

### 5.2 Phase G integration tasks (weeks 12–14)

#### Code wiring

- [ ] `src/shared/AssetIds.luau` created and populated — every asset has a non-placeholder `rbxassetid://` per the manifest pattern in `docs/playbooks/PUBLISHING.md` §4.2
- [ ] `BuildableRegistry.luau` — replace `Instance.new("Part")`-style geometry in `BuildPart` with `MeshPart` clones from a `ServerStorage.BuildableTemplates` folder; reads asset IDs from `AssetIds.luau`
- [ ] `AlienRegistry.luau` extended to volcanic + ice-cave variants; `AlienPool` builds variant-specific actors; `WaveDirector` picks the variant matching `Constants.RAID.RaidPlaceId` biome flag (or rolls per active wave)
- [ ] `TurretService` extended with HeavyCannon + BurstLaser entries in BuildableRegistry (new buildables, not new turret-class — same TurretService loop with per-buildable stat overrides)
- [ ] `DroneSwarmService` — wire Recon ("spot" → minimap overlay) + Engineering ("repair" → turret HP restore) behaviors. Currently both are `v1Active = false` in DroneSwarmRegistry
- [ ] `Vehicle/` module folder created: `RoverService`, `HoverBikeService`, `HoverTankService` + `VehicleRegistry`. Server-authoritative driving Remotes wired into raid context
- [ ] Custom skin pack BodyParts integrated via `Players.LocalPlayer.Character` swap path; VIP Operator pass triggers Heavy Defender swap; Battle Pass premium track grants Recon Operator at tier 30
- [ ] All four biome arches placed in plot spawn template (`PlotManager.buildPlot` adds the arch reference; Phase G's biome system picks which arch per active biome)

#### Asset upload + AssetIds population

- [ ] `tools/asset-import/upload-manifest.json` populated with all custom asset paths
- [ ] Open Cloud Assets API uploads run via `.github/workflows/upload-assets.yml` (manual `workflow_dispatch`)
- [ ] Generated `AssetIds.luau` reviewed in PR; merged
- [ ] CSG / EditableMesh / EditableImage assets that can't go via Open Cloud authored in Studio + committed (per `PUBLISHING.md` §3 inventory table; "place" column tracks main-vs-raid)

#### Audit gates per asset class

- [ ] **Biome arches:** all 3 arches load in their respective places without errors; emissive pulses run; no z-fighting on the plot spawn floor
- [ ] **Operator skins:** all 3 skin packs apply via character-swap path; R15 animations still work (no broken bones); helmet visor emissive renders correctly
- [ ] **Aliens:** all 3 variants spawn from `AlienPool`; AI walk cycles work for the unique Cryowraith hover; per-variant stats apply correctly (Magmaling slow + heavy, Cryowraith fast + low-HP)
- [ ] **Turrets:** all 3 turret tiers placeable; HeavyCannon recoil animation plays; BurstLaser sequential emitter pulse renders; cost validation passes
- [ ] **Drones:** all 3 presets spawn from `DroneSwarmService.DeploySwarm`; Recon spot overlay renders on HUD; Engineering manipulator arm deploys + retracts; preset color-tied trail particles fire
- [ ] **Vehicles:** all 3 vehicles spawnable via Phase G's `VehicleSpawner` UI; VehicleSeat occupied path teleports player into seat; driving feels stable (no derail at MaxSpeed); hover bike + tank ground-effect glow renders; tank gunner can independently aim turret

#### Mobile performance gates (Phase F handoff overlap)

- [ ] FPS check on a Galaxy A12-class Android device:
  - [ ] Idle on plot with 4 turrets + 3 drones = 30+ FPS
  - [ ] Active wave with 6 aliens + turrets + drones firing = 30+ FPS
  - [ ] In a vehicle = 30+ FPS
- [ ] Each MeshPart has `CollisionFidelity = "Box"` or `"Hull"` (not "PreciseConvexDecomposition") unless physics specifically requires it
- [ ] Texture memory total budget < 100 MB across all assets

#### Pre-launch sign-off

- [ ] No placeholder asset IDs (`0000000000`) remain in `AssetIds.luau`
- [ ] All marketplace asset licenses confirmed commercial-safe and recorded in §6 audit log
- [ ] Battle Pass Season 1 cosmetic rewards replace placeholder Credits/Cores grants per the D4 worklog launch-blocker

<!-- ASSETS-CHECKLIST-INSERT-POINT -->

---

## 6. Asset audit log

Append one row per finalized asset as it's authored / sourced. Phase G integration PRs reference rows here. Template:

| Asset | §4 entry | Source | License | AssetId | Place | Audited by | Date |
|---|---|---|---|---|---|---|---|
| _e.g. Stalker rig_ | §4.3.1 | Meshy AI text-to-3D iteration #4 | Meshy commercial tier (verified) | `rbxassetid://0` (TBD) | both | _name_ | YYYY-MM-DD |
| _(empty until Phase G work begins)_ | | | | | | | |

Columns:
- **Asset** — display name from §4
- **§4 entry** — section reference (e.g. §4.3.2)
- **Source** — Marketplace listing, AI tool prompt iteration, custom Blender model, etc.
- **License** — exact license terms; "commercial use OK" is the bar
- **AssetId** — Roblox `rbxassetid://N` once uploaded
- **Place** — `main` / `raid` / `both` per ADR-009 split (CSG/EditableMesh constraint per `PUBLISHING.md` §3)
- **Audited by** — name of the human who reviewed the asset before merge
- **Date** — ISO date of audit-pass

<!-- ASSETS-AUDIT-INSERT-POINT -->

---

**End of ASSETS.md.** Update sections §4–§6 as concepts firm up and assets land in Phase G.
