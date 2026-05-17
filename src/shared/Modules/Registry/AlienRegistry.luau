--!strict
--[[
	Outpost-7 — alien type catalog.

	Phase E2. V1 ships one alien type ("Stalker" — matches the
	bioluminescent jungle theme). Phase G adds biome-specific variants
	(volcanic, ice cave) and tunes per-type stats via
	`config/content/wave_scaling.json`.

	Stats sourced from `Constants.COMBAT.*`. The registry exists so
	Phase G can add types without touching the wave director or AI.
--]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Constants = require(Shared:WaitForChild("Constants"))

local AlienRegistry = {}

export type AlienDef = {
	id: string,
	displayName: string,
	hp: number,
	meleeDamage: number,
	meleeCooldown: number,
	walkSpeed: number,
	-- V1 placeholder geometry — programmatic Part-with-Humanoid in
	-- AlienPool.buildActor. Phase G replaces with real model templates.
	visualSize: Vector3,
	visualColor: Color3,
	emissive: number,
	-- F0 V2 prep: optional pre-built model template. If provided,
	-- AlienPool clones this Model instead of constructing geometry
	-- programmatically. Phase G / V2 wires this field with imported
	-- MeshPart rigs from `assets/characters/`. V1 leaves nil and uses
	-- the visualSize/visualColor fields for procedural construction.
	meshTemplate: Model?,
}

AlienRegistry.Catalog = {
	stalker = {
		id = "stalker",
		displayName = "Stalker",
		hp = Constants.COMBAT.AlienBaseHp,
		meleeDamage = Constants.COMBAT.AlienMeleeDamage,
		meleeCooldown = Constants.COMBAT.AlienMeleeCooldownSeconds,
		walkSpeed = Constants.COMBAT.AlienWalkSpeed,
		visualSize = Vector3.new(2, 4, 2),
		-- Bioluminescent magenta/cyan combo — brainstorm aesthetic.
		visualColor = Color3.fromRGB(200, 60, 240),
		emissive = 0.6,
	},
} :: { [string]: AlienDef }

function AlienRegistry.Get(id: string): AlienDef?
	return AlienRegistry.Catalog[id]
end

return AlienRegistry
