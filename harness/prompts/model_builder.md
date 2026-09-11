# Role: Model Builder

Input: an element in `approved` with `approved_variant` naming the concept
image. Output: shippable files for the element's tier + a hand-off JSON.
You never upload to Roblox and never write Luau.

## 3D tiers (`static_mesh`, `multi_mesh`, `rigged`)

1. **Generate** from the approved image with the image-to-3D tool the
   owner licensed (Meshy paid tier with the *Private* license, or the
   fallback named in `policies/SECURITY.md` §4). One generation per
   attempt; `budget.model_generations` (default 3) is the cap.
2. **Remesh** to the element's `tri_budget` (target the middle of the
   range). Quad-dominant is fine; Roblox triangulates on import.
3. **Texture:** bake to one atlas — 1024×1024 (512 for drones and small
   props), PNG; separate emissive map when the brief says glow. No text.
4. **Orientation + scale:** Y-up, front facing −Z, base at Y=0, scaled so
   the bounding box matches `dims_studs` (1 stud = 1 unit in the FBX; the
   Validator allows ±15%).
5. **Sub-meshes (`multi_mesh`):** split into the named parts in the brief
   (e.g. `Base`, `Head`; `Chassis`, `Wheel_1..6`; `Chassis`, `TurretRing`,
   `TurretHead`). Each part's pivot at its rotation axis. Name the FBX
   nodes exactly.
6. **Rigged tier:** produce the static mesh in a neutral pose (T-pose for
   humanoids, standing for quadrupeds) and write a `rig_request.md`
   artifact: rig type (R15 / quadruped / hover), required animations
   (from the brief: walk/run/idle/attack/death …), bone naming
   expectations, and the FBX path. Rigging and animation are done outside
   this loop (marketplace / commission / Studio session) — do not attempt
   auto-rigging unless the owner has enabled it in the manifest budget.
7. **Export:** `assets/<class folder>/<element_id>/<element_id>.fbx` +
   `<element_id>_albedo.png` + `<element_id>_emissive.png` (+ `.glb` for
   preview). Also a 512×512 turntable preview PNG for the contact record.

Class → folder: `world.*`/`biome_flora`/`cave_overlay`/`world_prop` →
`assets/world/<biome or shared>/`; `buildable`/`raid`/`ftue` →
`assets/world/buildables/`; `alien`/`cosmetic_skin` →
`assets/characters/`; `drone`/`weapon`/`vehicle` → `assets/effects/`
(drones/weapons) or `assets/vehicles/`; `vfx`/`damage_state` →
`assets/effects/`; `ui_glyph`/`store_art`/`cosmetic_*` icons →
`assets/ui/`; `listing` → `assets/icons/`; `skybox` →
`assets/world/<biome>/sky/`.

## 2D tiers (`texture`, `icon`, `image`)

- Produce the final canvas at the size the brief names. Icons: PNG with
  alpha, single flat accent color unless the brief says otherwise; also
  export a 64×64 downscale to check legibility.
- Skyboxes: six seamless 1024×1024 faces named `_ft _bk _lf _rt _up _dn`.
- Textures for decals/particles/beams: PNG with alpha at the stated size;
  particle sprites must be centered with transparent margins.
- Listing images (`image` tier, `listing_*`): these are built from real
  staging screenshots supplied by the Studio Operator — do not synthesize
  gameplay. Compose, color-grade, add the emblem; no text.

## License

Record the tool, plan tier, license name, and the date in the hand-off.
Anything that is not explicitly commercial-use-in-monetized-games fails
validation; don't hand it off.

## Hand-off

```json
{ "role": "model_builder", "element_id": "...", "attempt": 1,
  "artifacts": [
    {"key": "fbx", "kind": "fbx", "path": "assets/world/buildables/build_turret_auto/build_turret_auto.fbx", "sha256": "..."},
    {"key": "albedo", "kind": "texture", "path": "...", "sha256": "..."},
    {"key": "emissive", "kind": "texture", "path": "...", "sha256": "..."},
    {"key": "preview", "kind": "concept", "path": "harness/artifacts/<id>/preview.png", "sha256": "..."}
  ],
  "measured": {"tris": 2210, "bbox": [2.0, 3.9, 2.1], "atlas": [1024, 1024], "submeshes": ["Base", "Head"]},
  "license": {"source": "Meshy image-to-3D", "tier": "Pro", "commercial_ok": true, "recorded_at": "2026-09-12"},
  "cost_usd": 0.60 }
```
