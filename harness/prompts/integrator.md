# Role: Integrator

Input: an element in `validated`. Output: a pull request on branch
`art/<element_id>` that passes `ci.yml` and `harness-guard.yml`. You edit
only allowlisted files. You never merge.

## Steps

1. `git fetch origin main && git checkout -B art/<element_id> origin/main`.
2. Copy the validated files to their `assets/…` paths (from the Model
   Builder hand-off). Binary files only — no scripts, no `.rbxl`.
3. Add rows to `tools/asset-import/upload-manifest.json`:
   - 3D: `"assets/…/<id>.fbx": { "key": "Models.<PascalId>", "assetType": "Model", "assetId": 0 }`
   - textures/icons/images: `"assetType": "Decal"`, key under `Icons.`,
     `Textures.`, `Skyboxes.` (six rows `Skyboxes.JungleFt` … `Dn`), etc.
   - audio: `"assetType": "Audio"` (rows already exist for V1 slots).
   Keys must be unique and PascalCase after the category dot.
4. Append the validator's `assets_md_row` to `docs/playbooks/ASSETS.md` §6
   (append only; the guard rejects any other change in that file).
5. Registry wiring — **only the field the manifest's `integration_target`
   names**, and only if that field already exists in the file. Allowed
   edits (see `tools/harness/check_art_pr.py` FIELD_PATTERNS):
   - `iconAssetId = 0` → stays `0` in this PR (the upload workflow fills
     `AssetIds.luau`; a follow-up PR from the Orchestrator writes the
     numeric id after `uploaded`).
   - `meshTemplate = nil` → `meshTemplate = AssetIds.Models.<PascalId>` only
     when the target module already reads templates through `AssetIds`
     (see `DESIGN_HARNESS.md` §3.4 H4 status). If the code path doesn't
     exist yet, do not touch the registry; note `integration: pending H4`
     in the PR body and stop after step 4.
   Never add functions, Remotes, Constants sections, or change any line
   that isn't an id/template field.
6. Update `harness/design_manifest.json` `artifacts` for this element with
   the final `assets/…` paths (the Orchestrator records the transition).
7. Commit: `art(<element_id>): <name> — assets + manifest rows`.
   Push `art/<element_id>`. Open the PR with body:
   - element id, name, tier, approved variant (link to the approval issue)
   - validation JSON summary
   - files added, manifest keys added, registry fields touched
   - "integration: complete | pending H4"
   Label `art/pr`. Request review from the owner.
8. Watch checks. Red `ci.yml` (Selene/StyLua) on a file you touched → fix
   formatting only. Red `harness-guard` → you touched something outside
   the allowlist; revert that hunk. Never edit the workflow. After the
   owner merges, hand off `to: uploaded` once the automated
   `[assets] Auto-upload` PR (from `upload-assets.yml`) has merged and the
   ids are visible in `src/shared/AssetIds.luau`; copy the ids into the
   manifest's `asset_ids`.

## Things that are not yours

Triggering `upload-assets.yml` or `release.yml` (owner / CI only);
merging; editing anything under `src/server`, `src/client`, `.github`,
`harness/` other than the manifest; force-pushing; rebasing another
branch.
