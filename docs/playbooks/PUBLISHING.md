# PUBLISHING.md — Open Cloud release pipeline (Outpost-7)

> **STATUS: Stub.** Filled in fully during Phase H (Ship Prep). Anything marked TBD is a known gap, not an oversight.
>
> **Read this doc before any release.** It is the single source of truth for how a `.rbxl` gets from a CI runner into the live Roblox place. If something here disagrees with another doc, this one wins for deployment topics.

---

## 0. TL;DR — the happy path

```bash
# Local sanity check (both places per ADR-009 two-PlaceId split)
aftman install
wally install
selene src/ && stylua --check src/
rojo build default.project.json --output build/Game.rbxl
rojo build raid.project.json    --output build/Raid.rbxl

# Release (tag-driven, runs in CI)
git tag v0.1.0 && git push origin v0.1.0
# → .github/workflows/release.yml builds Game.rbxl + Raid.rbxl, publishes
#   each to its respective PlaceId (PLACE_ID and RAID_PLACE_ID) via Open Cloud.
```

If any of those five lines is unfamiliar, read the rest of this doc before you ship.

---

## 1. Required secrets & vars (GitHub Actions)

| Kind | Name | Scope | Where to get it |
|---|---|---|---|
| Secret | `ROBLOX_API_KEY` | repo | https://create.roblox.com/dashboard/credentials → **Open Cloud API Keys** → new key. Permissions: `universe.place:write` on the target universe (covers both PlaceIds since they share a Universe). IP allowlist: `0.0.0.0/0` for GitHub-hosted runners (or pin to a self-hosted runner range if you have one). |
| Var | `UNIVERSE_ID` | repo | Creator Dashboard → game → ⋯ → **Copy Universe ID**. |
| Var | `PLACE_ID` | repo | Creator Dashboard → game → main place → ⋯ → **Copy Place ID**. The public-facing start place; what the game listing points at. |
| Var | `RAID_PLACE_ID` | repo | Creator Dashboard → game → raid place → ⋯ → **Copy Place ID**. Created in Phase H per ADR-009; until then leave the var unset (or 0) and `release.yml` short-circuits the raid publish step with a warning. |
| Var (optional) | `STAGING_PLACE_ID` | repo | A separate place under the same universe used for dry-runs of the main place. Recommended — you do not want the first Open Cloud test to be against the live game. (A raid-staging place is also valuable but ships only if Phase H beta surfaces raid-place-specific issues.) |

**Never commit any of these to git.** The API key in particular grants write access to the live game.

**Key rotation:** Open Cloud keys should be rotated quarterly and immediately if a contributor with access leaves. Rotation = generate new key in dashboard → update `ROBLOX_API_KEY` secret → revoke old key.

---

## 2. Build artifact format

- **Use `.rbxl` (binary), not `.rbxlx` (XML).** Smaller, faster to upload, matches the Roblox sample-repo convention. `.rbxlx` is fine for local diffing but not for shipping.
- Build commands (per ADR-009 two-PlaceId split):
  - Main: `rojo build default.project.json --output build/Game.rbxl`
  - Raid: `rojo build raid.project.json    --output build/Raid.rbxl`
- Both `.project.json` files map the same `src/` tree but specialize Workspace `$properties` per place (raid uses smaller streaming radii since the raid plot is fixed at 64×64 studs). Phase G adds raid-only lighting, fog, and ambient differentiators.
- Artifacts live in `build/` which is gitignored. CI uploads each as a separate workflow artifact (`Game.rbxl`, `Raid.rbxl`) with 7-day retention so a release can be re-pushed without rebuilding.

---

## 3. CSG / EditableMesh / EditableImage caveat

**Open Cloud cannot publish these from CI.** They must be authored and saved from a Studio session at least once, then committed.

| Type | Why CI can't publish | What to do |
|---|---|---|
| `UnionAsync` / `SubtractAsync` results | CSG ops require Studio's geometry kernel. | Author in Studio → save to a Roblox asset (or commit the resulting `MeshPart` model XML) → reference by AssetId. |
| `EditableMesh` | Runtime-mutable mesh; the *initial* mesh data must be uploaded as a `MeshPart` first. | Build the base `MeshPart` in Studio, upload, pin AssetId. CI ships the runtime code that mutates it. |
| `EditableImage` | Same as above for images. | Build the base `Image` asset in Studio, upload, pin AssetId. |

**Inventory of CSG / EditableMesh / EditableImage assets in Outpost-7:**

Per ADR-009, raid-only geometry / images are authored against the *raid* PlaceId; main-only against the *main* PlaceId. The "place" column tracks the publish target so re-authoring on PlaceId churn is bounded.

| Asset name | Type | Place | AssetId | Studio-publish date | Owner |
|---|---|---|---|---|---|
| _TBD — fill in during Phase G/H_ | | | | | |

If this table grows past ~20 rows, consider whether the design is leaning on these types too heavily — every row is a manual step a future-you has to remember.

---

## 4. Asset pipeline — Open Cloud Assets API + `AssetIds.luau` manifest

### 4.1 Why a manifest

Hardcoding `rbxassetid://1234567890` in a dozen modules is the same anti-pattern as hardcoding magic numbers (see `CLAUDE.md` → "Always-do"). The manifest gives one place to swap an asset and one place to audit what's loaded.

### 4.2 Manifest shape

```lua
-- src/shared/AssetIds.luau
--!strict

local AssetIds = {
    Icons = {
        GamePass2xCredits = "rbxassetid://0000000000",
        BattlePassPremium = "rbxassetid://0000000000",
    },
    Sounds = {
        ExtractorPlace = "rbxassetid://0000000000",
        TurretFire     = "rbxassetid://0000000000",
    },
    Decals = {
        ColonyBanner = "rbxassetid://0000000000",
    },
} :: AssetManifest

export type AssetManifest = { [string]: { [string]: string } }
return AssetIds
```

Every consumer reads `AssetIds.Sounds.ExtractorPlace` — never a literal `rbxassetid://`.

### 4.3 Upload workflow (manually triggered, runs in CI)

Asset uploads are a **manually triggered** workflow — `.github/workflows/upload-assets.yml` (`workflow_dispatch` only). Roblox AssetIds are immutable once issued, so re-uploading on every push wastes IDs and pollutes the creator's asset list. Trigger this workflow only when you've added or changed binary assets in `assets/`.

**What it does:**
1. Runs `tools/scripts/upload-assets.sh`, which walks `assets/` and POSTs new/changed files to `https://apis.roblox.com/assets/v1/assets` with `x-api-key: $ROBLOX_API_KEY`.
2. Polls each operation until done.
3. Regenerates `src/shared/AssetIds.luau` from `tools/asset-import/upload-manifest.json`.
4. Opens a PR (`assets/auto-upload-<run>`) with the regenerated manifest. Review the diff before merging — that's the human checkpoint that prevents a bad upload from contaminating `main`.

**Dry-run option:** `workflow_dispatch` exposes a `dry_run` boolean. Use it the first time on any new asset set to confirm the upload script's output before mutating Roblox state.

The Open Cloud key used by `upload-assets.yml` needs **`asset:read` + `asset:write`** scope on the target creator (user or group). For audio uploads, the creator account must also be **ID-verified** in the Creator Dashboard. This is a **separate** key from the place-publishing key in §1, scoped narrower.

---

## 5. CI workflow — `.github/workflows/release.yml`

The release workflow is live. Two trigger modes:

- **Tag push** — push a `v*.*.*` tag (e.g. `git tag -s v0.1.0 && git push origin v0.1.0`). Runs the full pipeline and publishes new `Published` (live) versions of *both* places.
- **Manual** — `workflow_dispatch` from the Actions UI. Inputs:
  - `version_type` — `Saved` (draft) or `Published` (live). Use `Saved` for staging dry-runs.
  - `target` — `both` (default), `main`, or `raid`. Lets you publish one place without re-publishing the other (useful when only the raid logic changed).

**Pipeline steps** (see the file for exact details):
1. `setup-aftman` → installs the pinned toolchain (Rojo, Selene, StyLua, Wally, Lune)
2. `wally install`
3. `selene src/` and `stylua --check src/`
4. `rojo build default.project.json --output build/Game.rbxl`
5. `rojo build raid.project.json    --output build/Raid.rbxl`
6. **Main publish** — POST `build/Game.rbxl` to `https://apis.roblox.com/universes/v1/$UNIVERSE_ID/places/$PLACE_ID/versions?versionType=$VERSION_TYPE` with `x-api-key: $ROBLOX_API_KEY`. Skipped if `target=raid`.
7. **Raid publish** — POST `build/Raid.rbxl` to the same endpoint with `$RAID_PLACE_ID`. Skipped if `target=main` OR if `RAID_PLACE_ID` is unset / 0 (Phase H prerequisite).
8. On tag pushes only: opens a GitHub Release with both `.rbxl` files attached, release notes including both published version numbers.

The job runs in the `production` environment, so any required reviewers / wait timers configured on that environment apply. Concurrency is `release` with `cancel-in-progress: false` — releases queue, never cancel each other mid-upload.

**Hardening backlog:**
- Pin third-party actions (`ok-nick/setup-aftman`, `softprops/action-gh-release`) to a SHA before V1 launch — version tags are mutable.
- Wire `STAGING_PLACE_ID` into a separate manual job so dry-runs target staging without editing the workflow each time.

---

## 6. Pre-release checklist (run before tagging)

- [ ] `aftman install && wally install` clean on a fresh clone
- [ ] `selene src/` zero warnings
- [ ] `stylua --check src/` zero diffs
- [ ] `rojo build default.project.json` produces a `.rbxl` that opens in Studio without errors
- [ ] `rojo build raid.project.json` produces a `.rbxl` that opens in Studio without errors
- [ ] All CSG / EditableMesh / EditableImage assets in §3 inventory have a non-TBD AssetId, with the right "place" column entry
- [ ] `src/shared/AssetIds.luau` has no placeholder `0000000000` IDs left
- [ ] `Constants.RAID.MainPlaceId` and `Constants.RAID.RaidPlaceId` are set to real PlaceIds (no `0` placeholders)
- [ ] DataStore schema version in `DataManager` matches what's on the live places (no surprise migration)
- [ ] Dry-run release with `target=main version_type=Saved` against `STAGING_PLACE_ID`; join staging, smoke-test the core loop
- [ ] Dry-run release with `target=raid version_type=Saved` if a raid-staging place exists
- [ ] Tag is signed (`git tag -s vX.Y.Z`) and the tag message names the V1 phase or hotfix scope

---

## 7. Rollback procedure

If a release breaks the live game:

1. **Roblox Creator Dashboard → game → Versions → restore previous version.** This is instant and authoritative — do this before debugging.
2. Re-tag the prior known-good commit as `vX.Y.Z-rollback` and re-run `release.yml` against it (so `main` and the live place stay in sync, and the next release builds on a known base).
3. Open a postmortem issue. Don't ship the next release until the failure mode is understood.

Open Cloud keeps the last several published versions of a place — verify retention settings in the dashboard.

---

## 8. Known gaps / TBDs

- §3 — CSG / EditableMesh / EditableImage inventory empty until Phase G/H
- §5 — third-party actions in `release.yml` not yet pinned to SHAs (still on version tags)
- §5 — staging dry-run still requires manually swapping `PLACE_ID`; wire `STAGING_PLACE_ID` into a separate job during Phase H
- Per-environment universe split (dev / staging / prod) — for V1, a single universe with two places (`STAGING_PLACE_ID` + `PLACE_ID`) is sufficient

---

**End of PUBLISHING.md.** Update this doc as the pipeline solidifies — out-of-date deployment docs are worse than no deployment docs.
