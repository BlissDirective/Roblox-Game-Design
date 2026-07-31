# PHASE H — Human handoff checklist

> Phase H is the seam where "computer in the cloud" meets "art, sound, account
> access, and human judgment." The agent has done the code-side prep (asset
> manifest + upload pipeline + docs). Everything below needs **you** — a Roblox
> account, a browser, Studio, money for assets, and taste.
>
> Deployment mechanics live in `docs/playbooks/PUBLISHING.md` — this doc is the
> ordered to-do list; that doc is the reference.

---

## What the agent already did (code side — done)

- `src/shared/AssetIds.luau` — the asset-ID manifest (single source of truth).
- `tools/asset-import/upload-manifest.json` — maps each `assets/…` file to its
  manifest key + Open Cloud asset type (26 slots seeded: icon, 3 thumbnails,
  5 music tracks, 14 SFX, 3 biome ambiences).
- `tools/scripts/upload-assets.sh` — walks the manifest, uploads new assets via
  Open Cloud, records the IDs, regenerates `AssetIds.luau`.
- `.github/workflows/release.yml` + `upload-assets.yml` — the publish + upload
  pipelines (already scaffolded).

## What still needs YOU (ordered)

### 1. Account + verification (allow 1–3 days)
- [ ] A Roblox account you'll own the game under (personal or a Group).
- [ ] **ID-verify that account** in Creator Dashboard → Settings. Required
      before Open Cloud can upload **audio**. This is the long-lead item — do
      it first.

### 2. Create the Experience + places (Creator Dashboard)
Per ADR-009 the game is one Universe with two places (main + raid).
- [ ] Create a new Experience → note its **Universe ID** and the main
      **Place ID**.
- [ ] Add a second place to the same Experience for raids → note the
      **Raid Place ID**.
- [ ] (Recommended) Add a third place for staging → note **Staging Place ID**.
- [ ] Set the main place **Max Players = 8** (matches `WORLD.PlotCount`; audit
      §4.5 — otherwise players 9+ get no plot).

### 3. Two Open Cloud API keys (Dashboard → Credentials → Open Cloud)
- [ ] **Publish key** — scope `universe.place:write` on the Universe. Add as
      GitHub **secret** `ROBLOX_API_KEY`.
- [ ] **Asset key** — scope `asset:read` + `asset:write` on the creator. Used
      by `upload-assets.yml`. (Store as the secret that workflow reads.)
- [ ] GitHub repo **variables**: `UNIVERSE_ID`, `PLACE_ID`, `RAID_PLACE_ID`,
      `STAGING_PLACE_ID` (Settings → Secrets and variables → Actions).

### 4. Fill in the real IDs in `Constants.luau` (a PR)
These are `0` placeholders today and must be real before launch:
- [ ] `RAID.MainPlaceId`, `RAID.RaidPlaceId` → the two Place IDs from step 2.
- [ ] `MONETIZATION.GamePasses.*.id` (2× Credits, Auto-Collect, VIP Operator,
      Battle Pass Premium) → create the passes in the Dashboard, paste IDs.
- [ ] `MONETIZATION.DevProducts.*.id` (Emergency Shield, Credit Pack S/L, Core
      Pack) → create the dev products, paste IDs.
      (The agent can make this PR once you paste the IDs into chat.)

### 5. Acquire + drop in assets (budget ~$280–460, per ASSETS.md)
Prioritize **audio first** — it's the cheapest 50% of "feels like a real game."
- [ ] **5 synthwave tracks** (Pixabay / Audiio, commercial-use verified) →
      save as `assets/audio/music/{build,combat,raid,victory,defeat}.ogg`.
- [ ] **Core SFX** (Freesound / ElevenLabs) → `assets/audio/sfx/…` matching the
      filenames in `tools/asset-import/upload-manifest.json`.
- [ ] **3 biome ambiences** → `assets/audio/ambient/{jungle,volcanic,ice}.ogg`.
- [ ] **Game icon + 3 thumbnails** → `assets/icons/…` (make these from real
      screenshots of the now-polished game — do this LAST, after Phase G art).
- [ ] Marketplace models (foliage, operator armor, alien rigs, turrets,
      vehicles) — imported directly in Studio, not via this pipeline.
> Filenames must match `upload-manifest.json` exactly, or the uploader skips
> them. To add a new slot, add a row to that JSON.

### 6. Upload the assets
- [ ] Actions → **Upload assets to Roblox** → run with `dry_run: true` first
      (confirms the file list), then `dry_run: false`.
- [ ] Review + merge the auto-opened `AssetIds.luau` PR. Now every ID is live
      and the audio/biome systems light up.

### 7. CSG / EditableMesh / EditableImage (Studio, if any)
- [ ] Author any union/mesh/image assets in Studio, upload, pin the AssetId,
      and record them in `PUBLISHING.md` §3. Open Cloud can't publish these
      from CI.

### 8. Listing + rating (Dashboard)
- [ ] Game description, tags, **age rating (13+ for combat)**, genre.

### 9. Verify + dry-run before launch
- [ ] Fresh clone: `aftman install && wally install` clean.
- [ ] `rojo build default.project.json` and `rojo build raid.project.json` open
      cleanly in Studio.
- [ ] **8-client Studio local-server test** — the multi-player desync/DataStore
      pass (this is also where the Phase R Studio audit gates get run —
      `docs/phases/PHASE_R_FORTIFY.md`).
- [ ] Actions → **Release** → `target=main version_type=Saved` against
      `STAGING_PLACE_ID`. Join staging, smoke-test the core loop + a raid.

### 10. Launch
- [ ] `git tag -s v1.0.0 && git push origin v1.0.0` → CI publishes both places.
- [ ] Follow the day-0 timeline in `finalized-brainstorm.md` §6.1.

---

## Things only you can decide / do (the agent cannot)
- Run Roblox Studio, buy marketplace assets, or make art.
- Generate Open Cloud keys or paste GitHub secrets.
- ID-verify the account; create passes/products/places in the Dashboard.
- Post launch marketing (TikTok / X / Reddit).

The agent **can**, on request: make the `Constants.luau` ID-fill PR once you
paste IDs; pin CI actions to SHAs; adjust the upload pipeline; fix any bug the
8-client test or staging dry-run surfaces; write listing/marketing copy drafts.
