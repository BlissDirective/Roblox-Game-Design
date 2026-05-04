# PUBLISHING.md — Open Cloud release pipeline (Outpost-7)

> **STATUS: Stub.** Filled in fully during Phase H (Ship Prep). Anything marked TBD is a known gap, not an oversight.
>
> **Read this doc before any release.** It is the single source of truth for how a `.rbxl` gets from a CI runner into the live Roblox place. If something here disagrees with another doc, this one wins for deployment topics.

---

## 0. TL;DR — the happy path

```bash
# Local sanity check
aftman install
wally install
selene src/ && stylua --check src/
rojo build default.project.json --output build/Game.rbxl

# Release (tag-driven, runs in CI)
git tag v0.1.0 && git push origin v0.1.0
# → .github/workflows/release.yml uploads build/Game.rbxl to PLACE_ID via Open Cloud
```

If any of those four lines is unfamiliar, read the rest of this doc before you ship.

---

## 1. Required secrets & vars (GitHub Actions)

| Kind | Name | Scope | Where to get it |
|---|---|---|---|
| Secret | `ROBLOX_API_KEY` | repo | https://create.roblox.com/dashboard/credentials → **Open Cloud API Keys** → new key. Permissions: `universe.place:write` on the target universe. IP allowlist: `0.0.0.0/0` for GitHub-hosted runners (or pin to a self-hosted runner range if you have one). |
| Var | `UNIVERSE_ID` | repo | Creator Dashboard → game → ⋯ → **Copy Universe ID**. |
| Var | `PLACE_ID` | repo | Creator Dashboard → game → place → ⋯ → **Copy Place ID**. The *root* place for a single-place game; per-place for multi-place experiences. |
| Var (optional) | `STAGING_PLACE_ID` | repo | A separate place under the same universe used for dry-runs. Recommended — you do not want the first Open Cloud test to be against the live game. |

**Never commit any of these to git.** The API key in particular grants write access to the live game.

**Key rotation:** Open Cloud keys should be rotated quarterly and immediately if a contributor with access leaves. Rotation = generate new key in dashboard → update `ROBLOX_API_KEY` secret → revoke old key.

---

## 2. Build artifact format

- **Use `.rbxl` (binary), not `.rbxlx` (XML).** Smaller, faster to upload, matches the Roblox sample-repo convention. `.rbxlx` is fine for local diffing but not for shipping.
- Build command: `rojo build default.project.json --output build/Game.rbxl`
- Artifact lives in `build/` which is gitignored. CI uploads it as a workflow artifact (30-day retention) before publishing, so a release can be re-pushed without rebuilding if needed.

---

## 3. CSG / EditableMesh / EditableImage caveat

**Open Cloud cannot publish these from CI.** They must be authored and saved from a Studio session at least once, then committed.

| Type | Why CI can't publish | What to do |
|---|---|---|
| `UnionAsync` / `SubtractAsync` results | CSG ops require Studio's geometry kernel. | Author in Studio → save to a Roblox asset (or commit the resulting `MeshPart` model XML) → reference by AssetId. |
| `EditableMesh` | Runtime-mutable mesh; the *initial* mesh data must be uploaded as a `MeshPart` first. | Build the base `MeshPart` in Studio, upload, pin AssetId. CI ships the runtime code that mutates it. |
| `EditableImage` | Same as above for images. | Build the base `Image` asset in Studio, upload, pin AssetId. |

**Inventory of CSG / EditableMesh / EditableImage assets in Outpost-7:**

| Asset name | Type | AssetId | Studio-publish date | Owner |
|---|---|---|---|---|
| _TBD — fill in during Phase G/H_ | | | | |

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

### 4.3 Upload workflow (manual, not CI)

Asset uploads are a **manual step**, not a CI step. The reason: Open Cloud asset uploads don't have great idempotency, so accidentally double-uploading on every CI run wastes IDs and pollutes the asset list.

```bash
# scripts/upload-asset.sh (TBD — write during Phase H)
# 1. POST asset binary to https://apis.roblox.com/assets/v1/assets
#    Headers: x-api-key: $ROBLOX_API_KEY
#    Body: multipart with creationContext + file
# 2. Poll the operation until done
# 3. Print the new AssetId
# 4. Manually paste into src/shared/AssetIds.luau and commit
```

The Open Cloud key used for uploads needs **`asset:create` + `asset:read`** scope on the target creator (user or group). This is a **separate** key from the place-publishing key in §1, scoped narrower.

---

## 5. CI workflow — `.github/workflows/release.yml`

_TBD — written during Phase H. Sketch:_

```yaml
on:
  push:
    tags: ['v*']

jobs:
  release:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: ok-nick/setup-aftman@v0.4.2
      - run: wally install
      - run: selene src/
      - run: stylua --check src/
      - run: rojo build default.project.json --output build/Game.rbxl
      - uses: actions/upload-artifact@v4
        with: { name: place-rbxl, path: build/Game.rbxl, retention-days: 30 }
      - name: Publish to Roblox
        env:
          ROBLOX_API_KEY: ${{ secrets.ROBLOX_API_KEY }}
          UNIVERSE_ID:    ${{ vars.UNIVERSE_ID }}
          PLACE_ID:       ${{ vars.PLACE_ID }}
        run: |
          curl -sSf -X POST \
            -H "x-api-key: $ROBLOX_API_KEY" \
            -H "Content-Type: application/octet-stream" \
            --data-binary @build/Game.rbxl \
            "https://apis.roblox.com/universes/v1/$UNIVERSE_ID/places/$PLACE_ID/versions?versionType=Published"
```

Pin third-party actions to a SHA before going to production — version tags are mutable.

---

## 6. Pre-release checklist (run before tagging)

- [ ] `aftman install && wally install` clean on a fresh clone
- [ ] `selene src/` zero warnings
- [ ] `stylua --check src/` zero diffs
- [ ] `rojo build` produces a `.rbxl` that opens in Studio without errors
- [ ] All CSG / EditableMesh / EditableImage assets in §3 inventory have a non-TBD AssetId
- [ ] `src/shared/AssetIds.luau` has no placeholder `0000000000` IDs left
- [ ] DataStore schema version in `DataManager` matches what's on the live place (no surprise migration)
- [ ] Dry-run release against `STAGING_PLACE_ID` first, join the staging place, smoke-test the core loop
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

- §4.3 — `scripts/upload-asset.sh` not written yet
- §5 — `release.yml` not written yet
- §3 — CSG/EditableMesh/EditableImage inventory empty until Phase G/H
- Per-environment universe split (dev / staging / prod) — TBD; for V1 a single universe with two places (`STAGING_PLACE_ID` + `PLACE_ID`) is sufficient

---

**End of PUBLISHING.md.** Update this doc as the pipeline solidifies — out-of-date deployment docs are worse than no deployment docs.
