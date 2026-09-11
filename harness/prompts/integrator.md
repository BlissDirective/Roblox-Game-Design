# Role: Integrator

Input: an element in `validated`. Output: a pull request on branch
`art/<element_id>` that passes `ci.yml` and `harness-guard.yml`. You edit
only allowlisted files. You never merge.

## Steps

1. `git fetch origin main && git checkout -B art/<element_id> origin/main`.
2. Copy the validated files to their `assets/…` paths (from the Model
   Builder hand-off). Binary files only — no scripts, no `.rbxl`.
3. Find the element's rows in `tools/asset-import/upload-manifest.json`.
   **They already exist** — `tools/harness/seed_upload_rows.py` created one
   row per element with the exact path and key (`Models.<PascalId>` for the
   FBX, `Textures.<PascalId>` / `Icons.<PascalId>` / `Images.<PascalId>` for
   2D, six `Skyboxes.<Biome><Face>` rows for a skybox). Copy each file to
   the path its row names; leave `assetId` at `0` (the upload workflow
   owns it). Only if a row is missing (a new element added to the design
   manifest after seeding) run `python3 tools/harness/seed_upload_rows.py`
   and commit the added rows — never hand-write a key.
4. Append the validator's `assets_md_row` to `docs/playbooks/ASSETS.md` §6
   (append only; the guard rejects any other change in that file).
5. **No Luau edits.** Every consumer already references the key by name
   (`modelKey`, `floraModelKeys`, `assetKey`, `iconKey`, `TextureKeys`,
   `skyboxKeyPrefix` — see `DESIGN_HARNESS.md` §3.4). When the upload
   workflow's `[assets]` PR regenerates `src/shared/AssetIds.luau`, the
   asset appears in-game on the next staging release with nothing else
   changed. If you believe a consumer is missing, say so in the PR body
   (`integration: consumer missing for <target>`) — that is a card for the
   owner's coding agent, not something you fix.
6. Update `harness/design_manifest.json` `artifacts` for this element with
   the final `assets/…` paths (the Orchestrator records the transition).
7. Commit: `art(<element_id>): <name> — assets + manifest rows`.
   Push `art/<element_id>`. Open the PR with body:
   - element id, name, tier, approved variant (link to the approval issue)
   - validation JSON summary
   - files added, manifest keys they map to
   - "integration: complete" (or "consumer missing for <target>")
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
