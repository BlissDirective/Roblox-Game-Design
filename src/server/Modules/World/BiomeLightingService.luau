--!strict
--[[
	Outpost-7 — biome lighting service.

	Phase G1. Applies a biome-specific Lighting + Atmosphere +
	ColorCorrection profile to the place at boot. V1 main place is
	jungle by default (`Constants.BIOME.DefaultBiome`); V1.5+ multi-
	biome rotation selects per-server.

	Profiles are pure data in `Constants.BIOME.Profiles`. This service
	owns the *apply* path:
	  - Sets Lighting.<property> from profile (Ambient, Brightness,
	    ClockTime, GeographicLatitude, ExposureCompensation, FogStart,
	    FogEnd, FogColor)
	  - Sets Lighting.Technology to ShadowMap per mobile-first research
	    (50-light cap, no shadow casting from PointLights — decorative
	    bioluminescent flora must use Beam / SpotLight or accept no-shadow
	    PointLights with `Shadows = false`)
	  - Creates / updates child Atmosphere instance with profile's
	    haze + scattering values
	  - Creates / updates child ColorCorrectionEffect for the cinematic
	    color grade per biome

	Phase G can iterate parameter values via Constants edits without
	touching this module. Phase H+ may add per-place skybox upload via
	the AssetIds.luau manifest.

	Public API:
	  Init                       — applies Constants.BIOME.DefaultBiome
	  Apply(biomeId)             — yielding (sets Lighting properties);
	                               called explicitly when V1.5 rotation lands
	  GetCurrentBiome()          — returns the active biome id
--]]

local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Constants = require(Shared:WaitForChild("Constants"))

local BiomeLightingService = {}

local ATMOSPHERE_NAME = "OutpostBiomeAtmosphere"
local COLOR_CORRECTION_NAME = "OutpostBiomeGrade"

local currentBiome: string = Constants.BIOME.DefaultBiome

local function ensureAtmosphere(): Atmosphere
	local existing = Lighting:FindFirstChild(ATMOSPHERE_NAME)
	if existing and existing:IsA("Atmosphere") then
		return existing
	end
	-- Roblox auto-creates one if missing; we name ours explicitly so
	-- subsequent Apply() finds it without re-creating.
	local atmosphere = Instance.new("Atmosphere")
	atmosphere.Name = ATMOSPHERE_NAME
	atmosphere.Parent = Lighting
	return atmosphere
end

local function ensureColorCorrection(): ColorCorrectionEffect
	local existing = Lighting:FindFirstChild(COLOR_CORRECTION_NAME)
	if existing and existing:IsA("ColorCorrectionEffect") then
		return existing
	end
	local effect = Instance.new("ColorCorrectionEffect")
	effect.Name = COLOR_CORRECTION_NAME
	effect.Parent = Lighting
	return effect
end

local function applyTechnology()
	-- Lighting.Technology — ShadowMap for mobile-first per the Phase G
	-- research. Wrapped in pcall because the property name has been
	-- renamed in Roblox releases (Jan 2025: Technology → LightingStyle
	-- with Soft/Realistic enum). Defensive read keeps us from
	-- hard-failing on a name change that ships before we update.
	local techName = Constants.BIOME.LightingTechnology
	local enumValue: any = nil
	local ok = pcall(function()
		enumValue = Enum.Technology[techName]
	end)
	if not ok or not enumValue then
		warn(string.format("[BiomeLightingService] Enum.Technology.%s not found; leaving default", techName))
		return
	end
	pcall(function()
		Lighting.Technology = enumValue
	end)
end

local function applyProfile(profile: any)
	-- Lighting properties
	Lighting.Ambient = profile.ambient
	Lighting.OutdoorAmbient = profile.outdoorAmbient
	Lighting.Brightness = profile.brightness
	Lighting.ClockTime = profile.clockTime
	Lighting.GeographicLatitude = profile.geographicLatitude
	Lighting.ExposureCompensation = profile.exposureCompensation
	Lighting.FogStart = profile.fogStart
	Lighting.FogEnd = profile.fogEnd
	Lighting.FogColor = profile.fogColor

	-- Atmosphere child
	local atmosphere = ensureAtmosphere()
	atmosphere.Density = profile.atmosphereDensity
	atmosphere.Offset = profile.atmosphereOffset
	atmosphere.Color = profile.atmosphereColor
	atmosphere.Decay = profile.atmosphereDecay
	atmosphere.Glare = profile.atmosphereGlare
	atmosphere.Haze = profile.atmosphereHaze

	-- ColorCorrection child
	local cc = ensureColorCorrection()
	cc.TintColor = profile.colorTint
	cc.Brightness = profile.colorBrightness
	cc.Contrast = profile.colorContrast
	cc.Saturation = profile.colorSaturation
end

function BiomeLightingService.Apply(biomeId: string)
	local profile = Constants.BIOME.Profiles[biomeId]
	if not profile then
		warn(string.format("[BiomeLightingService] Unknown biome '%s'; using default", biomeId))
		biomeId = Constants.BIOME.DefaultBiome
		profile = Constants.BIOME.Profiles[biomeId]
		if not profile then
			warn("[BiomeLightingService] Default biome profile missing; aborting")
			return
		end
	end
	applyTechnology()
	applyProfile(profile)
	currentBiome = biomeId
	print(string.format("[BiomeLightingService] Applied biome '%s' (%s)", biomeId, profile.displayName))
end

function BiomeLightingService.GetCurrentBiome(): string
	return currentBiome
end

function BiomeLightingService.Init()
	BiomeLightingService.Apply(Constants.BIOME.DefaultBiome)
end

return BiomeLightingService
