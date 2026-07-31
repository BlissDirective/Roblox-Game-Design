--!strict
--[[
	Outpost-7 — first-party asset ID manifest (single source of truth).

	Phase H. Every `rbxassetid://` the game loads for a first-party asset
	(uploaded via Open Cloud) lives here — never a literal `rbxassetid://…`
	scattered in a module (same rule as "no magic numbers", per CLAUDE.md).

	Lifecycle:
	  - This file is HAND-AUTHORED as a seed with placeholder `rbxassetid://0`
	    entries (0 = "not uploaded yet"; consumers treat it as a no-op).
	  - `tools/scripts/upload-assets.sh` (run by the `upload-assets.yml`
	    workflow) uploads the binaries under `assets/`, records the returned
	    IDs in `tools/asset-import/upload-manifest.json`, and REGENERATES this
	    file. After that, uploading a new asset changes only this one file.

	Category ↔ folder mapping (upload-manifest keys are `Category.Name`):
	  Icons     → assets/icons/        (game icon + store/pass thumbnails)
	  Thumbs    → assets/icons/        (the 3 discovery thumbnails)
	  Music     → assets/audio/music/
	  Sfx       → assets/audio/sfx/
	  Ambient   → assets/audio/ambient/
	  Skyboxes  → assets/world/…       (per-biome sky, when authored)

	Adding an asset: drop the file in the right `assets/…` folder, add a row to
	`upload-manifest.json`, run the upload workflow. Do NOT hand-edit the IDs
	once the pipeline owns them.
--]]

export type AssetManifest = { [string]: { [string]: string } }

local PLACEHOLDER = "rbxassetid://0"

-- Inferred table type (categories + the isPlaceholder helper). The
-- AssetManifest export above is the shape of the category subtables for
-- consumers / the regen script; this local intentionally isn't annotated
-- with it so the helper function can live alongside the categories.
local AssetIds = {
	-- Game listing + store art (Creator Dashboard / Phase H1).
	Icons = {
		GameIcon = PLACEHOLDER,
	},
	-- The 3 discovery thumbnails per finalized-brainstorm.md §2.5.
	Thumbs = {
		Transformation = PLACEHOLDER, -- "Day 1 vs Day 30" timelapse hero
		Defense = PLACEHOLDER, -- the "oh shit" wave-breach moment
		Raid = PLACEHOLDER, -- raid drama
	},
	-- 5 synthwave tracks (finalized-brainstorm.md §2.8 / Phase G4).
	Music = {
		Build = PLACEHOLDER,
		Combat = PLACEHOLDER,
		Raid = PLACEHOLDER,
		Victory = PLACEHOLDER,
		Defeat = PLACEHOLDER,
	},
	-- Core SFX. Names match the AudioRegistry cue ids so the Phase-H
	-- AudioRegistry migration is a mechanical key swap.
	Sfx = {
		WeaponFire = PLACEHOLDER, -- R3 rifle
		TurretFire = PLACEHOLDER,
		DroneFire = PLACEHOLDER,
		ExtractorPlace = PLACEHOLDER,
		WallPlace = PLACEHOLDER,
		StructureBreach = PLACEHOLDER, -- R1 wall/extractor destroyed
		RepairComplete = PLACEHOLDER, -- R1 repair
		AlienGrowl = PLACEHOLDER,
		WaveAlarm = PLACEHOLDER,
		ClaimChime = PLACEHOLDER,
		UiClick = PLACEHOLDER,
		UiPanelOpen = PLACEHOLDER,
		FtueIntroSting = PLACEHOLDER,
		FtueStepAdvance = PLACEHOLDER,
	},
	-- Per-biome ambient loops (Constants.BIOME.*.ambientSfxAssetId today).
	Ambient = {
		Jungle = PLACEHOLDER,
		Volcanic = PLACEHOLDER,
		Ice = PLACEHOLDER,
	},
	-- Per-biome skyboxes (Constants.BIOME.*.skyboxAssetId today). A Roblox
	-- Sky uses 6 face textures — the upload pipeline expands each of these
	-- into the 6 face ids when the skybox art is authored; V1 may ship the
	-- default sky and leave these placeholder.
	Skyboxes = {
		Jungle = PLACEHOLDER,
		Volcanic = PLACEHOLDER,
		Ice = PLACEHOLDER,
	},
}

-- True when an id is still the unset placeholder. Consumers (AudioController,
-- BiomeLightingService, HUD) use this to no-op cleanly on a V1 dev build
-- instead of spawning a broken Sound / Sky / Image instance.
function AssetIds.isPlaceholder(id: string?): boolean
	return id == nil or id == PLACEHOLDER or id == "rbxassetid://0" or id == "0"
end

return AssetIds
