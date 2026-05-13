--!strict
--[[
	Outpost-7 — audio cue catalog (shared).

	Phase G4. Central registry of every named audio cue the game can
	play. Server fires by `cueId` via the AudioCue Remote; client
	resolves the id against this catalog to find the asset id and the
	per-cue playback policy.

	V1 ships `assetId = 0` placeholders for every entry. AudioController
	treats `0` as a no-op, so the wiring is exercised in dev without
	flooding the output with "Sound failed to load" messages. Phase H
	asset pipeline uploads the real `rbxassetid://` integers and bumps
	these values in a single PR.

	Schema (`AudioCue`):
	  id            — stable string key, lowercase + underscore
	  category      — one of Constants.AUDIO.CategoryVolume keys
	                  (sfx | music | ui | ambient | voice_emote)
	  assetId       — Roblox audio asset id (rbxassetid integer);
	                  0 = placeholder (no-op until Phase H upload)
	  volume        — per-cue gain multiplier (post-category mix); 1.0 = unity
	  pitch         — playbackSpeed; 1.0 = default. Variation noted per cue
	  rollOffMin    — spatial only; overrides Constants.AUDIO.Spatial defaults
	  rollOffMax    — spatial only; overrides Constants.AUDIO.Spatial defaults
	  looped        — true for music + ambient loops; one-shots leave false
	  throttleMs    — per-cue override on Constants.AUDIO.ThrottleMs
	  description   — short doc string for the asset queue

	Adding a cue: pick a category, drop a placeholder entry here, fire
	via `AudioService.Play(cueId, ...)` from the server (or
	`AudioController.PlayLocal(cueId)` for pure UI). Asset upload comes
	later — code does not block on it.
--]]

local AudioRegistry = {}

export type Category = "sfx" | "music" | "ui" | "ambient" | "voice_emote"

export type AudioCue = {
	id: string,
	category: Category,
	assetId: number,
	volume: number,
	pitch: number,
	rollOffMin: number?,
	rollOffMax: number?,
	looped: boolean,
	throttleMs: number?,
	description: string,
}

AudioRegistry.Catalog = {
	-- ============ Combat SFX ============
	turret_fire_tier1 = {
		id = "turret_fire_tier1",
		category = "sfx",
		assetId = 0, -- REPLACE_BEFORE_LAUNCH — short pulse, ~120ms
		volume = 0.7,
		pitch = 1.0,
		rollOffMin = 8,
		rollOffMax = 120,
		looped = false,
		throttleMs = 60, -- 6 turrets firing simultaneously won't stack
		description = "Tier 1 (Pulse Turret) single shot.",
	},
	turret_fire_tier2 = {
		id = "turret_fire_tier2",
		category = "sfx",
		assetId = 0,
		volume = 0.75,
		pitch = 1.0,
		rollOffMin = 10,
		rollOffMax = 140,
		looped = false,
		throttleMs = 60,
		description = "Tier 2 (Burst Turret) 3-round burst.",
	},
	turret_fire_tier3 = {
		id = "turret_fire_tier3",
		category = "sfx",
		assetId = 0,
		volume = 0.85,
		pitch = 1.0,
		rollOffMin = 12,
		rollOffMax = 180,
		looped = false,
		throttleMs = 80,
		description = "Tier 3 (Coil Mast) charged-shot — big, deep, slow.",
	},
	drone_fire = {
		id = "drone_fire",
		category = "sfx",
		assetId = 0,
		volume = 0.55,
		pitch = 1.0,
		rollOffMin = 6,
		rollOffMax = 100,
		looped = false,
		throttleMs = 40, -- drone swarms burst fire; coalesce sub-frame
		description = "Drone swarm shot — light high-pitched zap.",
	},
	alien_growl = {
		id = "alien_growl",
		category = "sfx",
		assetId = 0,
		volume = 0.7,
		pitch = 1.0,
		rollOffMin = 12,
		rollOffMax = 160,
		looped = false,
		description = "Alien wave spawn growl — wave-start cue.",
	},
	alien_death = {
		id = "alien_death",
		category = "sfx",
		assetId = 0,
		volume = 0.6,
		pitch = 1.0,
		rollOffMin = 10,
		rollOffMax = 100,
		looped = false,
		description = "Alien killed (wave NPC). Audible to nearby players.",
	},
	building_placed = {
		id = "building_placed",
		category = "sfx",
		assetId = 0,
		volume = 0.6,
		pitch = 1.0,
		looped = false,
		description = "Confirm chime + thud when a placement commits.",
	},
	building_destroyed = {
		id = "building_destroyed",
		category = "sfx",
		assetId = 0,
		volume = 0.75,
		pitch = 1.0,
		rollOffMin = 10,
		rollOffMax = 140,
		looped = false,
		description = "Building HP hits zero (raid attacker / wave defender feedback).",
	},
	resource_node_depleted = {
		id = "resource_node_depleted",
		category = "sfx",
		assetId = 0,
		volume = 0.5,
		pitch = 1.0,
		looped = false,
		description = "Resource node fully harvested (collapse cue).",
	},

	-- ============ UI ============
	ui_button_click = {
		id = "ui_button_click",
		category = "ui",
		assetId = 0,
		volume = 0.4,
		pitch = 1.0,
		looped = false,
		description = "Standard button press feedback.",
	},
	ui_panel_open = {
		id = "ui_panel_open",
		category = "ui",
		assetId = 0,
		volume = 0.5,
		pitch = 1.0,
		looped = false,
		description = "Shop / build palette / clan panel open.",
	},
	ui_panel_close = {
		id = "ui_panel_close",
		category = "ui",
		assetId = 0,
		volume = 0.5,
		pitch = 1.0,
		looped = false,
		description = "Panel close.",
	},
	ui_toast = {
		id = "ui_toast",
		category = "ui",
		assetId = 0,
		volume = 0.55,
		pitch = 1.0,
		looped = false,
		description = "Toast popup (cosmetic unlocked, daily login, etc.).",
	},
	ui_claim_reward = {
		id = "ui_claim_reward",
		category = "ui",
		assetId = 0,
		volume = 0.7,
		pitch = 1.0,
		looped = false,
		description = "Reward claim chime — daily login / quest / battle pass tier.",
	},
	ui_purchase_success = {
		id = "ui_purchase_success",
		category = "ui",
		assetId = 0,
		volume = 0.7,
		pitch = 1.0,
		looped = false,
		description = "Monetization Robux purchase confirmed.",
	},
	ui_error = {
		id = "ui_error",
		category = "ui",
		assetId = 0,
		volume = 0.55,
		pitch = 1.0,
		looped = false,
		description = "Invalid input / insufficient currency / rate-limited.",
	},

	-- ============ Music ============
	music_main_loop = {
		id = "music_main_loop",
		category = "music",
		assetId = 0,
		volume = 0.6,
		pitch = 1.0,
		looped = true,
		description = "Main place ambient bed — alien jungle synth pad.",
	},
	music_raid_attacker = {
		id = "music_raid_attacker",
		category = "music",
		assetId = 0,
		volume = 0.7,
		pitch = 1.0,
		looped = true,
		description = "Raid place attacker track — aggressive, percussive.",
	},
	music_raid_defender = {
		id = "music_raid_defender",
		category = "music",
		assetId = 0,
		volume = 0.7,
		pitch = 1.0,
		looped = true,
		description = "Wave defense track — tense, building.",
	},
	music_wave_victory = {
		id = "music_wave_victory",
		category = "music",
		assetId = 0,
		volume = 0.75,
		pitch = 1.0,
		looped = false,
		description = "Short victory sting after final wave cleared.",
	},

	-- ============ Ambient (per-biome) ============
	-- Note: BiomeDecorationService currently plays ambient loops directly
	-- via SoundService (G2 code). G4 keeps that path working — these
	-- registry entries are forward-looking for V1.5 when ambient flows
	-- through AudioService for consistency. AssetIds align with
	-- Constants.BIOME.Decorations.<biome>.ambientSfxAssetId; both
	-- placeholders are zero until Phase H.
	ambient_jungle = {
		id = "ambient_jungle",
		category = "ambient",
		assetId = 0,
		volume = 1.0,
		pitch = 1.0,
		looped = true,
		description = "Jungle creature loop — chitters + distant calls.",
	},
	ambient_volcanic = {
		id = "ambient_volcanic",
		category = "ambient",
		assetId = 0,
		volume = 1.0,
		pitch = 1.0,
		looped = true,
		description = "Volcanic rumble + ash hiss.",
	},
	ambient_ice = {
		id = "ambient_ice",
		category = "ambient",
		assetId = 0,
		volume = 1.0,
		pitch = 1.0,
		looped = true,
		description = "Glacial wind howl through cave.",
	},

	-- ============ Voice emotes (V1.5+ reservation) ============
	-- V1 has no emote cues; entries stub the surface so V1.5 cosmetic
	-- emote unlocks can ship without growing the schema.
}

-- Type-assert the catalog so accidental missing fields fail at compile time.
local _typed: { [string]: AudioCue } = AudioRegistry.Catalog :: any

function AudioRegistry.Get(cueId: string): AudioCue?
	return AudioRegistry.Catalog[cueId]
end

return AudioRegistry
