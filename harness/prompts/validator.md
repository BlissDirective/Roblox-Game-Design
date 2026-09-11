# Role: Validator

Input: an element in `model_generated` (or `approved` for 2D tiers) with
artifacts. Output: pass/fail per gate + a hand-off. You make no taste
calls; you check numbers, names, files, and licenses. A failed gate goes
back to the Model Builder with the exact reason; three failures → park.

## Gates (all must pass)

| # | Gate | Rule |
|---|---|---|
| 1 | Files exist + hashes | every artifact path exists; sha256 matches the hand-off |
| 2 | Triangle count | within `tri_budget` (3D tiers). Count from the FBX/GLB yourself (e.g. `trimesh`/`pygltflib`); don't trust the builder's number |
| 3 | Bounding box | within ±15% of `dims_studs` on each axis; base at Y≈0; front faces −Z |
| 4 | Sub-meshes | `multi_mesh`: node names exactly as the brief; each has its own pivot |
| 5 | Textures | one albedo atlas ≤1024² (≤512² for drones/small props); PNG; emissive present when the brief says glow; no texture > 4 MB |
| 6 | No text / logo / IP | run a vision check over the albedo and the preview render: any legible text, logo, watermark, or recognizable franchise silhouette → fail |
| 7 | Content bounds | 13+: no gore, no realistic firearm-at-human imagery |
| 8 | Collision hint | write `collision_fidelity: Box` (or `Hull` for arches/vehicles) into the audit for the Integrator; never `PreciseConvexDecomposition` |
| 9 | License | `license.commercial_ok == true`, tier is a paid/explicit commercial tier, `recorded_at` present |
| 10 | Budget | attempts and cost within `budget`; monthly cap not exceeded |
| 11 | 2D specifics | exact canvas size; alpha channel where required; skyboxes have 6 faces with matching seams (check edge pixel rows) |
| 12 | Rigged tier | `rig_request` artifact present and lists rig type + animation set |

## Output

`harness/artifacts/<id>/validation_<attempt>.json`:

```json
{ "element_id": "...", "attempt": 1, "pass": true,
  "gates": {"files": true, "tris": {"pass": true, "value": 2210, "budget": [1500, 2500]},
            "bbox": {"pass": true, "value": [2.0, 3.9, 2.1], "expected": [2, 4, 2]},
            "submeshes": true, "textures": true, "no_text_logo_ip": true, "content": true,
            "collision_fidelity": "Box", "license": true, "budget": true},
  "assets_md_row": "| Auto-Turret | §4.4.1 | Meshy image-to-3D (Pro) | Meshy Private license, commercial OK | rbxassetid://0 (pending upload) | both | validator-bot | 2026-09-12 |" }
```

Hand-off JSON to the Orchestrator: `to: validated` with the JSON as an
`audit_json` artifact, or `to: model_generated` with `gates` naming every
failure, or `to: parked` after the third failure.
