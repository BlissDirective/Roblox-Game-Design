#!/usr/bin/env python3
"""Seed (or re-seed) harness/design_manifest.json.

The element catalog lives in this file as Python tables so briefs are easy to
diff and review. Running it writes the manifest; existing per-element STATE,
history, and cost fields are preserved so re-seeding never loses progress.

    python3 tools/harness/seed_manifest.py            # write manifest
    python3 tools/harness/seed_manifest.py --check    # exit 1 if manifest drifted

Field reference: harness/schemas/design_manifest.schema.json
"""
from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
MANIFEST = ROOT / "harness" / "design_manifest.json"

MANIFEST_VERSION = 1

# Per-element budgets (USD) and attempt caps. Orchestrator refuses to dispatch
# past these; only the repo owner raises them (edit + commit).
DEFAULT_BUDGET = {
    "concept_images_per_round": 8,
    "concept_rounds": 3,
    "model_generations": 3,
    "usd_cap": 6.0,
}
GLOBAL_BUDGET = {"usd_cap_monthly": 150.0, "usd_spent_month": 0.0, "month": ""}

# Palette hexes are copied from docs/playbooks/ASSETS.md §4 so every prompt
# shares one vocabulary. Keys are referenced by name in element briefs.
PALETTES = {
    "jungle": {
        "corroded_titanium": "#3A3F48",
        "jungle_vine": "#1A3320",
        "neon_magenta": "#FF3EC8",
        "bio_teal": "#00E8D8",
        "chitin": "#22102E",
    },
    "volcanic": {
        "obsidian": "#0D0D12",
        "charcoal": "#1F1F24",
        "molten_orange": "#FF6A1A",
        "lava_red": "#FF2818",
        "warning_amber": "#FFAA33",
        "ash_grey": "#5A5A60",
    },
    "ice": {
        "gunmetal": "#4A525C",
        "glacial_ice": "#C8E8FF",
        "deep_ice": "#5A8CC0",
        "frost_blue": "#AAE0FF",
        "edge_white": "#E8F4FF",
        "shadow_blue": "#3A5078",
    },
    "military": {
        "charcoal_black": "#1A1A22",
        "steel_blue": "#5082B4",
        "gunmetal": "#3A4048",
        "base_shadow": "#2A3540",
        "warning_red": "#FF3838",
        "muzzle_red": "#FF5050",
        "amber": "#FFAA33",
        "tactical_white": "#DDE2E8",
        "plasma_blue": "#00AAFF",
        "recon_blue": "#5096E8",
        "olive": "#5A7048",
        "eng_green": "#88E060",
    },
    "ui": {
        "industrial_bg": "#1C1E22",
        "industrial_panel": "#26282C",
        "text_primary": "#E6E6DC",
        "accent_orange": "#FF9632",
        "jungle_accent": "#78DCB4",
        "ice_accent": "#78C8F0",
        "volcanic_accent": "#FF783C",
        "danger": "#DC3C3C",
    },
}

# tier: how the element is produced / integrated.
#   static_mesh  — image → 3D → FBX → Open Cloud Model → template by id
#   multi_mesh   — static_mesh with named sub-meshes (turret head/base, wheels)
#   rigged       — needs a skeleton + animation set; harness produces the
#                  static mesh + rig-request card, rigging is out-of-loop
#   texture      — 2D: decal / particle / beam / skybox face
#   icon         — 2D UI glyph or store art (one shared style)
#   image        — listing art (made from real screenshots — last)
#   audio        — no image gate; parallel track
#
# class: which registry/consumer the Integrator writes to (see harness/README §6).

# (id, name, tier, class, integration_target, dims_studs, tris, palette, brief, assets_ref, priority)
# priority: lower = earlier. Grouped so early approvals seed the style bible.
ELEMENTS: list[tuple] = []


def add(group, gid, items):
    for it in items:
        ELEMENTS.append((group, gid, *it))


add("Biome arches", "arch", [
    ("arch_jungle", "Bioluminescent Jungle Arch", "static_mesh", "world.arch", "PlotManager arch slot (H4)", [24, 18, 4], [4000, 6000], "jungle",
     "Corroded military structural frame overgrown by alien jungle: glowing vines on weathered titanium beams, magenta/teal bioluminescent flora in the cracks.", "ASSETS.md §4.1.1", 10),
    ("arch_volcanic", "Volcanic Arch", "static_mesh", "world.arch", "PlotManager arch slot (H4)", [24, 18, 4], [4000, 6000], "volcanic",
     "Obsidian-and-steel archway, hex-paneled crossbeam, molten lava fissures glowing inside cracked obsidian pillars, faded amber chevrons.", "ASSETS.md §4.1.2", 40),
    ("arch_ice", "Ice Cave Arch", "static_mesh", "world.arch", "PlotManager arch slot (H4)", [24, 18, 4], [4000, 6000], "ice",
     "Titanium frame encased in translucent fractured ice with blue-white emissive veins, pale rune line along the inner edge, frost mist at the base.", "ASSETS.md §4.1.3", 41),
])

add("Buildables", "build", [
    ("build_extractor", "Extractor", "static_mesh", "buildable", "BuildableRegistry.extractor (model field, H4)", [3, 4, 3], [1500, 2500], "military",
     "Compact resource extractor: drill column into a crystal node, spinning collar, side coolant tanks, teal intake glow at the base, credit-coil readout on top. Reads as the colony's income core.", "BuildableRegistry.luau", 11),
    ("build_wall", "Wall segment", "static_mesh", "buildable", "BuildableRegistry.wall (model field, H4)", [4, 5, 1], [600, 1200], "military",
     "Modular 4-stud wall segment: layered armor plates over a titanium spine, energy-seam glow along the top edge, tileable ends so segments chain cleanly. Three damage states later (see dmg_*).", "BuildableRegistry.luau", 12),
    ("build_turret_auto", "Auto-Turret", "multi_mesh", "buildable", "BuildableRegistry.turret (model field, H4)", [2, 4, 2], [1500, 2500], "military",
     "Single-barrel auto-turret: square base plate with power cables, yaw joint, sensor-cluster head with a 3-stud barrel and faint red muzzle ring. Sub-meshes: Base, Head.", "ASSETS.md §4.4.1", 1),
    ("build_turret_heavy", "Heavy Cannon Turret", "multi_mesh", "buildable", "BuildableRegistry (new row: turret_heavy)", [2.5, 4, 2.5], [2500, 3500], "military",
     "Twin-barrel siege turret: reinforced base with bracing struts, thick frontal armor, dual 4-stud barrels with heat-vent gills, red optic between barrels, visible ammo belt. Sub-meshes: Base, Head.", "ASSETS.md §4.4.2", 30),
    ("build_turret_laser", "Burst Laser Turret", "multi_mesh", "buildable", "BuildableRegistry (new row: turret_laser)", [1.8, 3.2, 1.8], [2000, 3000], "military",
     "Sleek point-defense laser: flowing base, yaw+pitch joints, 2x3 emitter grid with blue plasma lenses, spinning radar element on top, blue emissive radiator seams. Sub-meshes: Base, Yaw, Head.", "ASSETS.md §4.4.3", 31),
])

add("Structure damage states", "dmg", [
    ("dmg_wall_cracked", "Wall — cracked decal", "texture", "damage_state", "StructureHealthController state 2 (H4)", None, None, "military",
     "Alpha decal of fracture lines + scorch for the wall at 66-33% HP; readable at 20 studs on mobile.", "PHASE_R R1b", 50),
    ("dmg_wall_breached", "Wall — breached/burning", "texture", "damage_state", "StructureHealthController state 3 (H4)", None, None, "volcanic",
     "Alpha decal of a breach gap with molten edges + ember emissive map; pairs with a particle burst.", "PHASE_R R1b", 51),
    ("dmg_turret_damaged", "Turret — sparking damage", "texture", "damage_state", "StructureHealthController (H4)", None, None, "military",
     "Exposed-wiring decal + spark emissive for a damaged turret head.", "PHASE_R R1b", 52),
    ("dmg_extractor_disabled", "Extractor — disabled", "texture", "damage_state", "StructureHealthController (H4)", None, None, "military",
     "Dead-glow variant: intake light off, warning-amber fault strip, oil-leak decal at the base.", "PHASE_R R1b", 53),
])

add("Aliens", "alien", [
    ("alien_stalker", "Stalker (jungle)", "rigged", "alien", "AlienRegistry.stalker.meshTemplate", [6, 4, 2], [5000, 7000], "jungle",
     "Quadruped predator: chitinous plates with magenta bioluminescent seams, 2x3 teal eye cluster, mandible mouth, spine frill, segmented glowing tail tip. Low predatory stance.", "ASSETS.md §4.3.1", 2),
    ("alien_magmaling", "Magmaling (volcanic)", "rigged", "alien", "AlienRegistry (new row: magmaling)", [3, 5, 2], [5000, 7000], "volcanic",
     "Hunched bipedal heavy: cracked obsidian armor over a molten core, arms to the ground ending in three-finger claws, featureless dome head with a glowing horizontal crack, back heat vents.", "ASSETS.md §4.3.2", 32),
    ("alien_cryowraith", "Cryowraith (ice)", "rigged", "alien", "AlienRegistry (new row: cryowraith)", [1, 6, 1], [4500, 6500], "ice",
     "Tall thin floating wraith of fractured translucent ice, blue emissive veins, three vertical eye slits, icicle-claw arms, lower body dissolving into frost mist.", "ASSETS.md §4.3.3", 33),
])

add("Biome flora", "flora", [
    ("flora_jungle_vine_tree", "Jungle — vine tree", "static_mesh", "biome_flora", "Constants.BIOME.Decorations.jungle.floraTemplate", [3, 9, 3], [1200, 2000], "jungle",
     "Twisted alien tree: dark trunk wrapped in glowing magenta vines, teal spore pods at the tips, roots gripping a rock. Silhouette-first; reads at distance.", "PHASE_G G2", 20),
    ("flora_jungle_glow_fern", "Jungle — glow fern cluster", "static_mesh", "biome_flora", "Constants.BIOME.Decorations.jungle.floraTemplate", [2, 2, 2], [400, 900], "jungle",
     "Low fern cluster with bioluminescent leaf veins; the ground-cover filler placed 24x per plot.", "PHASE_G G2", 21),
    ("flora_jungle_spore_pod", "Jungle — spore pod", "static_mesh", "biome_flora", "Constants.BIOME.Decorations.jungle.floraTemplate", [1.5, 3, 1.5], [400, 800], "jungle",
     "Bulbous stalk with a translucent pod full of drifting magenta motes; particle emitter host.", "PHASE_G G2", 22),
    ("flora_volcanic_fissure", "Volcanic — obsidian fissure stub", "static_mesh", "biome_flora", "Constants.BIOME.Decorations.volcanic.floraTemplate", [1.5, 3, 1.5], [400, 900], "volcanic",
     "Jagged obsidian shard cluster split by a glowing lava crack; ember emitter host.", "PHASE_G G2", 42),
    ("flora_volcanic_ash_tree", "Volcanic — ash-dead tree", "static_mesh", "biome_flora", "Constants.BIOME.Decorations.volcanic.floraTemplate", [3, 8, 3], [900, 1600], "volcanic",
     "Blackened leafless tree with glowing ember veins in the bark.", "PHASE_G G2", 43),
    ("flora_ice_crystal", "Ice — crystal cluster", "static_mesh", "biome_flora", "Constants.BIOME.Decorations.ice.floraTemplate", [0.8, 3.5, 0.8], [400, 900], "ice",
     "Translucent blue crystal spikes with internal emissive veins; frost mist emitter host.", "PHASE_G G2", 44),
    ("flora_ice_frozen_shrub", "Ice — frozen shrub", "static_mesh", "biome_flora", "Constants.BIOME.Decorations.ice.floraTemplate", [2, 2, 2], [400, 900], "ice",
     "Ice-glazed alien shrub, pale white edges, faint blue subsurface glow.", "PHASE_G G2", 45),
])

add("Ice cave overlay", "cave", [
    ("cave_stalactite", "Stalactite", "static_mesh", "cave_overlay", "BiomeDecorationService.buildIcicle template (H4)", [1, 4, 1], [200, 500], "ice",
     "Hanging ice spike, faceted, subtle internal glow; tileable at three scales.", "PHASE_G G3", 60),
    ("cave_stalagmite", "Stalagmite", "static_mesh", "cave_overlay", "BiomeDecorationService.buildIcicle template (H4)", [1.5, 4, 1.5], [200, 500], "ice",
     "Floor ice spike ring element; wider base, frost at the foot.", "PHASE_G G3", 61),
    ("cave_glacier_wall", "Glacier wall slab", "static_mesh", "cave_overlay", "BiomeDecorationService.buildGlacierWall template (H4)", [40, 24, 6], [800, 1500], "ice",
     "Horizon-scale glacier slab with a titanium frame half-buried in it; the amphitheatre silhouette.", "PHASE_G G3", 62),
])

add("World props", "prop", [
    ("prop_resource_node", "Resource node (crystal cluster)", "static_mesh", "world_prop", "ResourceNodeSpawner template (H4)", [4, 3, 4], [600, 1200], "jungle",
     "Ground crystal cluster the extractor drills into: teal-core crystals in a rock collar with a faint pulse. Must read as 'place extractor here' from FTUE distance.", "ResourceNodeSpawner.luau", 13),
    ("prop_plot_floor", "Plot floor tile", "texture", "world_prop", "PlotManager floor material (H4)", None, None, "military",
     "Tileable 4-stud landing-pad plate texture: hex panels, faint grid lines, worn edges; 4x4 grid must align to Constants.GRID.Size.", "PlotManager.luau", 23),
    ("prop_plot_border", "Plot border beacon", "static_mesh", "world_prop", "PlotManager border (H4)", [1, 3, 1], [200, 400], "military",
     "Corner post with a vertical light strip marking plot bounds; colored by biome accent.", "PlotManager.luau", 24),
    ("prop_dropship_pad", "Spawn dropship pad", "static_mesh", "world_prop", "PlotManager spawn (H4)", [8, 1, 8], [600, 1200], "military",
     "Circular landing pad with chevrons and blue edge lights; the player's spawn point and the raid 'extraction' anchor.", "RaidBaseRenderer.luau", 25),
])

add("Drones", "drone", [
    ("drone_recon", "Recon drone", "static_mesh", "drone", "DroneSwarmRegistry.recon template (H4)", [1.2, 0.4, 0.8], [600, 1000], "military",
     "Bird-like scout drone, single cyclopean sensor pod, pale blue silent thrusters, white/recon-blue.", "ASSETS.md §4.5.1", 34),
    ("drone_combat", "Combat drone", "static_mesh", "drone", "DroneSwarmRegistry.combat template (H4)", [1.2, 0.4, 0.8], [800, 1200], "military",
     "Wedge fighter drone, twin forward laser barrels, red sensor lens, red-orange thrusters, charcoal/red.", "ASSETS.md §4.5.2", 3),
    ("drone_engineering", "Engineering drone", "multi_mesh", "drone", "DroneSwarmRegistry.engineering template (H4)", [1.2, 0.4, 0.8], [700, 1100], "military",
     "Utility repair drone, olive/green, retracted manipulator arm under a tool bay, three status LEDs. Sub-meshes: Body, Arm.", "ASSETS.md §4.5.3", 35),
])

add("Player weapon", "weapon", [
    ("weapon_rifle_world", "Hitscan rifle — world model", "static_mesh", "weapon", "WeaponController / character Tool (H4)", [0.4, 0.8, 2.6], [1500, 2500], "military",
     "Compact sci-fi carbine: charcoal body, steel-blue rails, teal energy cell window, short muzzle with a red emissive ring. Held R15 grip.", "PHASE_R R3", 14),
    ("weapon_rifle_view", "Hitscan rifle — first-person view model", "static_mesh", "weapon", "WeaponController FP viewmodel (H4)", [0.4, 0.8, 2.6], [2500, 3500], "military",
     "Same rifle with a higher-detail front half for first-person; consistent with the world model.", "PHASE_R R3", 15),
    ("weapon_muzzle_flash", "Muzzle flash texture", "texture", "vfx", "BeamPool muzzle emitter texture via AssetIds (H4)", None, None, "military",
     "Star-burst flash sprite, teal-white core, red rim; 256x256 alpha.", "BeamPool.luau", 16),
])

add("Operator skins", "skin", [
    ("skin_combatant", "Combatant Operator (default)", "rigged", "cosmetic_skin", "CosmeticRegistry.skin_combatant BodyParts (H4)", None, [8000, 10000], "military",
     "Medium frontline armor, charcoal black, red accent stripes, full-face helmet with a red visor band. The stock silhouette.", "ASSETS.md §4.2.2", 70),
    ("skin_recon", "Recon Operator", "rigged", "cosmetic_skin", "CosmeticRegistry.skin_recon BodyParts (H4)", None, [8000, 10000], "military",
     "Sleek scout armor, matte dark-grey, neon teal stripes, wraparound visor, asymmetric single pauldron.", "ASSETS.md §4.2.1", 71),
    ("skin_heavy_defender", "Heavy Defender Operator", "rigged", "cosmetic_skin", "CosmeticRegistry.skin_heavy_defender BodyParts (H4)", None, [9000, 11000], "military",
     "Bulky exoskeleton armor, gunmetal, amber glow seams, oversized pauldrons, vertical visor slit.", "ASSETS.md §4.2.3", 72),
])

add("Helmet decals", "decal", [
    ("decal_chevron_red", "Red Chevron decal", "texture", "cosmetic_decal", "CosmeticRegistry.decal_chevron_red (texture + iconAssetId)", None, None, "military",
     "Forward-facing chevron insignia, warning red on transparent; plus a 256x256 panel icon.", "CosmeticRegistry.luau", 63),
    ("decal_skull_amber", "Amber Skull decal", "texture", "cosmetic_decal", "CosmeticRegistry.decal_skull_amber", None, None, "military",
     "Stylized non-gory skull insignia, amber glow; panel icon.", "CosmeticRegistry.luau", 64),
    ("decal_op7_emblem", "Outpost-7 emblem", "texture", "cosmetic_decal", "CosmeticRegistry.decal_op7_emblem", None, None, "ui",
     "The game's own emblem: a stylized '7' inside a hex outpost silhouette, teal/gold. Original mark — also used for listing branding.", "CosmeticRegistry.luau", 17),
])

add("Drone trails", "trail", [
    ("trail_neon_red", "Neon Red trail", "texture", "cosmetic_trail", "CosmeticRegistry.trail_neon_red (beam texture + icon)", None, None, "military",
     "Beam texture strip + panel icon, blood-red.", "CosmeticRegistry.luau", 65),
    ("trail_neon_blue", "Neon Blue trail", "texture", "cosmetic_trail", "CosmeticRegistry.trail_neon_blue", None, None, "military",
     "Beam texture strip + panel icon, electric blue.", "CosmeticRegistry.luau", 66),
    ("trail_neon_gold", "Neon Gold trail", "texture", "cosmetic_trail", "CosmeticRegistry.trail_neon_gold", None, None, "ui",
     "Beam texture strip + panel icon, legendary gold with a subtle shimmer.", "CosmeticRegistry.luau", 67),
])

add("Nameplate flairs", "flair", [
    ("flair_pioneer", "Pioneer flair", "icon", "cosmetic_flair", "CosmeticRegistry.flair_pioneer.iconAssetId", None, None, "ui",
     "Small gold badge glyph for early adopters.", "CosmeticRegistry.luau", 68),
    ("flair_op7_veteran", "Veteran flair", "icon", "cosmetic_flair", "CosmeticRegistry.flair_op7_veteran.iconAssetId", None, None, "ui",
     "Small teal/blue badge glyph for BP tier 25.", "CosmeticRegistry.luau", 69),
])

add("Raid", "raid", [
    ("raid_loot_core", "Loot core (raid extractor variant)", "static_mesh", "raid", "RaidBaseRenderer extractor variant (H4)", [3, 4, 3], [1500, 2500], "military",
     "The extractor with an exposed glowing credit core and a 'crack me' vulnerability window; reads as the raid target.", "RaidBaseRenderer.luau", 36),
    ("raid_arena_floor", "Raid arena floor", "texture", "raid", "RaidBaseRenderer floor (H4)", None, None, "military",
     "Darker industrial variant of the plot floor tile for the reserved-server raid place.", "RaidBaseRenderer.luau", 37),
    ("raid_attacker_pad", "Attacker spawn pad", "static_mesh", "raid", "RaidSession spawn (H4)", [8, 1, 8], [600, 1200], "military",
     "Red-lit variant of the dropship pad marking the attacker's entry / extraction point.", "RaidSession.luau", 38),
])

add("FTUE", "ftue", [
    ("ftue_ring_beacon", "Ring beacon", "static_mesh", "ftue", "FTUEController beacon (H4)", [6, 0.5, 6], [300, 600], "ui",
     "Rotating ground ring with chevrons pointing inward; accent-colored emissive; replaces the procedural segments.", "PHASE_G G8", 54),
    ("ftue_pointer_arrow", "HUD pointer arrow", "icon", "ftue", "FTUEController pointer (H4)", None, None, "ui",
     "Angular sci-fi arrow glyph used for on-screen pointers.", "PHASE_G G8", 55),
    ("ftue_intro_frame", "Intro cinematic title card", "image", "ftue", "FTUEController cinematic (H4)", None, None, "jungle",
     "Wide 16:9 title frame: outpost silhouette against the bioluminescent jungle at dusk, emblem top-left, no text.", "PHASE_G G8", 56),
])

add("VFX textures", "vfx", [
    ("vfx_spore_jungle", "Jungle spore particle", "texture", "vfx", "BiomeDecorations.jungle particle texture via AssetIds (H4)", None, None, "jungle", "Soft magenta mote with teal core, 128x128 alpha.", "BiomeDecorationService.luau", 26),
    ("vfx_ash_volcanic", "Volcanic ash particle", "texture", "vfx", "BiomeDecorations.volcanic particle texture (H4)", None, None, "volcanic", "Grey-orange ash flake with ember edge, 128x128 alpha.", "BiomeDecorationService.luau", 46),
    ("vfx_frost_ice", "Frost flake particle", "texture", "vfx", "BiomeDecorations.ice particle texture (H4)", None, None, "ice", "Six-point frost flake, pale blue, 128x128 alpha.", "BiomeDecorationService.luau", 47),
    ("vfx_beam_turret", "Turret beam texture", "texture", "vfx", "BeamPool beam texture via AssetIds (H4)", None, None, "military", "Horizontal beam strip with bright core and soft falloff, 512x64.", "BeamPool.luau", 27),
    ("vfx_beam_drone", "Drone beam texture", "texture", "vfx", "BeamPool (drone variant) (H4)", None, None, "military", "Thinner, faster-looking strip with a dashed energy pattern, 512x64.", "BeamPool.luau", 28),
    ("vfx_impact_spark", "Impact spark particle", "texture", "vfx", "BeamPool impact emitter (H4)", None, None, "military", "Sharp spark shard, white-hot core, 64x64 alpha.", "BeamPool.luau", 29),
])

add("Skyboxes", "sky", [
    ("sky_jungle", "Jungle skybox (6 faces)", "texture", "skybox", "AssetIds.Skyboxes.Jungle", None, None, "jungle", "Post-dusk deep-purple sky with a magenta nebula band and two moons; seamless cube map.", "AssetIds.luau", 57),
    ("sky_volcanic", "Volcanic skybox (6 faces)", "texture", "skybox", "AssetIds.Skyboxes.Volcanic", None, None, "volcanic", "Ash-orange sunset haze, distant eruption glow on one horizon.", "AssetIds.luau", 58),
    ("sky_ice", "Ice skybox (6 faces)", "texture", "skybox", "AssetIds.Skyboxes.Ice", None, None, "ice", "Pre-dawn cold blue with aurora ribbons.", "AssetIds.luau", 59),
])

UI_GLYPHS = [
    ("credits", "Credits currency glyph"), ("cores", "Cores currency glyph"), ("shop", "Shop"), ("quests", "Quests"),
    ("clan", "Clan"), ("build", "Build mode toggle"), ("combat", "Combat mode toggle"), ("cosmetics", "Cosmetics"),
    ("battle_pass", "Battle Pass widget"), ("store", "Store"), ("friends", "Friends"), ("leaderboard", "Leaderboard"),
    ("voice", "Voice"), ("repair", "Repair"), ("shield", "Emergency Shield status"), ("wave_alarm", "Wave alarm"),
]
add("UI glyphs", "ui", [
    (f"ui_{k}", f"UI glyph — {n}", "icon", "ui_glyph", "HUD / panels (ImageLabel via AssetIds.Icons, H4)", None, None, "ui",
     f"Flat angular sci-fi glyph for '{n}', single-color on transparent, 128x128, matches the Theme accent; the whole set is approved as one sheet first, then per glyph.", "PHASE_G G5", 48)
    for k, n in UI_GLYPHS
])

add("Store art", "store", [
    ("store_pass_2x_credits", "Game pass icon — 2× Credits", "icon", "store_art", "Creator Dashboard + AssetIds.Icons", None, None, "ui", "512x512 square, credits glyph doubled with a gold burst.", "Constants.MONETIZATION", 73),
    ("store_pass_auto_collect", "Game pass icon — Auto-Collect", "icon", "store_art", "Creator Dashboard + AssetIds.Icons", None, None, "ui", "Extractor with a magnet/collect arrow motif.", "Constants.MONETIZATION", 74),
    ("store_pass_vip", "Game pass icon — VIP Operator", "icon", "store_art", "Creator Dashboard + AssetIds.Icons", None, None, "ui", "Heavy Defender helmet silhouette with amber glow.", "Constants.MONETIZATION", 75),
    ("store_pass_bp_premium", "Game pass icon — Battle Pass Premium", "icon", "store_art", "Creator Dashboard + AssetIds.Icons", None, None, "ui", "Emblem on a premium banner ribbon.", "Constants.MONETIZATION", 76),
    ("store_dp_shield", "Dev product icon — Emergency Shield", "icon", "store_art", "Creator Dashboard", None, None, "ui", "Hex shield over a plot silhouette, blue.", "Constants.MONETIZATION", 77),
    ("store_dp_credits_s", "Dev product icon — Credit Pack (Small)", "icon", "store_art", "Creator Dashboard", None, None, "ui", "Small stack of credit coils.", "Constants.MONETIZATION", 78),
    ("store_dp_credits_l", "Dev product icon — Credit Pack (Large)", "icon", "store_art", "Creator Dashboard", None, None, "ui", "Large crate of credit coils.", "Constants.MONETIZATION", 79),
    ("store_dp_cores", "Dev product icon — Core Pack", "icon", "store_art", "Creator Dashboard", None, None, "ui", "Cluster of glowing cores.", "Constants.MONETIZATION", 80),
    ("store_bp_banner", "Battle Pass premium banner", "image", "store_art", "BattlePassPanel header (H4)", None, None, "jungle", "Wide banner: Recon operator + drone over the jungle at dusk, season-one framing, no text.", "BattlePassPanel.luau", 81),
])

add("Listing", "listing", [
    ("listing_game_icon", "Game icon", "image", "listing", "AssetIds.Icons.GameIcon", None, None, "jungle", "512x512: emblem + outpost silhouette; made from a real staging screenshot after the world art lands. LAST.", "PHASE_H H1", 90),
    ("listing_thumb_transformation", "Thumbnail — Day 1 vs Day 30", "image", "listing", "AssetIds.Thumbs.Transformation", None, None, "jungle", "Split-frame transformation from real screenshots. LAST.", "PHASE_H H1", 91),
    ("listing_thumb_defense", "Thumbnail — wave breach", "image", "listing", "AssetIds.Thumbs.Defense", None, None, "jungle", "The 'oh no, the east wall' moment from a real screenshot. LAST.", "PHASE_H H1", 92),
    ("listing_thumb_raid", "Thumbnail — raid drama", "image", "listing", "AssetIds.Thumbs.Raid", None, None, "military", "Attacker at the loot core, klaxon glow. LAST.", "PHASE_H H1", 93),
])

add("Vehicles (gated)", "vehicle", [
    ("vehicle_rover", "All-terrain rover", "multi_mesh", "vehicle", "FEATURES gate — no module yet", [14, 6, 7], [6000, 8000], "military", "6-wheel armored exploration buggy, roll cage, cargo bed, plasma exhaust. Sub-meshes: Chassis, Wheel x6.", "ASSETS.md §4.6.1", 100),
    ("vehicle_hover_bike", "Hover bike", "static_mesh", "vehicle", "FEATURES gate — no module yet", [8, 2.5, 3], [4500, 6000], "military", "Single-rider hover bike, integrated twin plasma cannons, downforce wings, blue ground-effect glow. Original silhouette.", "ASSETS.md §4.6.2", 101),
    ("vehicle_hover_tank", "Hover tank", "multi_mesh", "vehicle", "FEATURES gate — no module yet", [16, 5, 8], [7000, 9500], "military", "Dual-crew hover tank, sloped glacis, ring-mount laser turret, plasma vents. Sub-meshes: Chassis, TurretRing, TurretHead.", "ASSETS.md §4.6.3", 102),
])

AUDIO = [
    ("audio_music_build", "Music — build loop", "assets/audio/music/build.ogg"), ("audio_music_combat", "Music — combat", "assets/audio/music/combat.ogg"),
    ("audio_music_raid", "Music — raid", "assets/audio/music/raid.ogg"), ("audio_music_victory", "Music — victory", "assets/audio/music/victory.ogg"),
    ("audio_music_defeat", "Music — defeat", "assets/audio/music/defeat.ogg"),
    ("audio_sfx_weapon_fire", "SFX — weapon fire", "assets/audio/sfx/weapon_fire.ogg"), ("audio_sfx_turret_fire", "SFX — turret fire", "assets/audio/sfx/turret_fire.ogg"),
    ("audio_sfx_drone_fire", "SFX — drone fire", "assets/audio/sfx/drone_fire.ogg"), ("audio_sfx_extractor_place", "SFX — extractor place", "assets/audio/sfx/extractor_place.ogg"),
    ("audio_sfx_wall_place", "SFX — wall place", "assets/audio/sfx/wall_place.ogg"), ("audio_sfx_structure_breach", "SFX — structure breach", "assets/audio/sfx/structure_breach.ogg"),
    ("audio_sfx_repair_complete", "SFX — repair complete", "assets/audio/sfx/repair_complete.ogg"), ("audio_sfx_alien_growl", "SFX — alien growl", "assets/audio/sfx/alien_growl.ogg"),
    ("audio_sfx_wave_alarm", "SFX — wave alarm", "assets/audio/sfx/wave_alarm.ogg"), ("audio_sfx_claim_chime", "SFX — claim chime", "assets/audio/sfx/claim_chime.ogg"),
    ("audio_sfx_ui_click", "SFX — UI click", "assets/audio/sfx/ui_click.ogg"), ("audio_sfx_ui_panel_open", "SFX — UI panel open", "assets/audio/sfx/ui_panel_open.ogg"),
    ("audio_sfx_ftue_intro_sting", "SFX — FTUE intro sting", "assets/audio/sfx/ftue_intro_sting.ogg"), ("audio_sfx_ftue_step_advance", "SFX — FTUE step advance", "assets/audio/sfx/ftue_step_advance.ogg"),
    ("audio_ambient_jungle", "Ambient — jungle", "assets/audio/ambient/jungle.ogg"), ("audio_ambient_volcanic", "Ambient — volcanic", "assets/audio/ambient/volcanic.ogg"),
    ("audio_ambient_ice", "Ambient — ice", "assets/audio/ambient/ice.ogg"),
]
add("Audio (parallel track)", "audio", [
    (aid, name, "audio", "audio", f"upload-manifest.json row {path}", None, None, "military",
     "Synthwave / sci-fi per finalized-brainstorm.md §2.8; sourced or generated with a commercial-use license; no image gate — owner approves by listening.", "PHASE_H_HANDOFF.md §5", 110)
    for aid, name, path in AUDIO
])


def build_element(row: tuple) -> dict:
    (group, gid, eid, name, tier, cls, target, dims, tris, palette, brief, ref, prio) = row
    return {
        "id": eid,
        "group": group,
        "group_id": gid,
        "name": name,
        "tier": tier,
        "class": cls,
        "integration_target": target,
        "dims_studs": dims,
        "tri_budget": tris,
        "palette": palette,
        "brief": brief,
        "reference": ref,
        "priority": prio,
        "gated": gid == "vehicle",
        "state": "pending_brief",
        "approved_variant": None,
        "artifacts": {},
        "license": None,
        "asset_ids": {},
        "cost_usd": 0.0,
        "attempts": {"concept_rounds": 0, "model_generations": 0, "validations": 0},
        "history": [],
        "budget": dict(DEFAULT_BUDGET),
    }


PRESERVE = ("state", "approved_variant", "artifacts", "license", "asset_ids", "cost_usd", "attempts", "history", "budget")


def build_manifest(existing: dict | None) -> dict:
    prev = {e["id"]: e for e in (existing or {}).get("elements", [])}
    elements = []
    for row in ELEMENTS:
        el = build_element(row)
        if el["id"] in prev:
            for k in PRESERVE:
                if k in prev[el["id"]]:
                    el[k] = prev[el["id"]][k]
        elements.append(el)
    ids = [e["id"] for e in elements]
    assert len(ids) == len(set(ids)), "duplicate element id"
    elements.sort(key=lambda e: (e["priority"], e["id"]))
    return {
        "manifest_version": MANIFEST_VERSION,
        "project": "Outpost-7",
        "generated_by": "tools/harness/seed_manifest.py",
        "global_budget": (existing or {}).get("global_budget", GLOBAL_BUDGET),
        "palettes": PALETTES,
        "elements": elements,
    }


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--check", action="store_true", help="fail if the manifest is out of date")
    args = ap.parse_args()
    existing = json.loads(MANIFEST.read_text()) if MANIFEST.exists() else None
    manifest = build_manifest(existing)
    text = json.dumps(manifest, indent=2, ensure_ascii=False) + "\n"
    if args.check:
        if MANIFEST.exists() and MANIFEST.read_text() == text:
            print("manifest up to date")
            return 0
        print("::error::harness/design_manifest.json is out of date — run tools/harness/seed_manifest.py")
        return 1
    MANIFEST.write_text(text)
    counts: dict[str, int] = {}
    for e in manifest["elements"]:
        counts[e["tier"]] = counts.get(e["tier"], 0) + 1
    print(f"wrote {MANIFEST.relative_to(ROOT)} — {len(manifest['elements'])} elements: {counts}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
