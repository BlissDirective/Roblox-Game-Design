--!strict
--[[
	Outpost-7 — drone swarm preset catalog.

	Phase E2.6. V1 ships 3 swarm presets per brainstorm §4.8 G6:
	  - **Recon** (blue) — scouts, spots aliens at range
	  - **Combat** (red) — attacks aliens
	  - **Engineering** (green) — repairs / heals turrets + walls

	Only **Combat** is functional in V1. Recon + Engineering are
	catalog entries with placeholder behavior tags so the framework
	supports them once Phase G ships their gameplay (Recon's "spot"
	behavior needs a minimap/HUD overlay; Engineering's "repair"
	behavior needs turret HP — both V1.5 / Phase G work).

	V1.5 (per brainstorm §2.7) adds the customization editor; for
	now the player gets the Combat preset auto-deployed.
--]]

local DroneSwarmRegistry = {}

export type SwarmBehaviorTag = "spot" | "attack" | "repair"

export type SwarmPreset = {
	id: string,
	displayName: string,
	color: Color3,
	behaviorTag: SwarmBehaviorTag,
	-- V1 functional presets are gated on this flag. Recon + Engineering
	-- ship false until Phase G wires their gameplay.
	v1Active: boolean,
}

DroneSwarmRegistry.Catalog = {
	recon = {
		id = "recon",
		displayName = "Recon Swarm",
		color = Color3.fromRGB(80, 160, 255),
		behaviorTag = "spot" :: SwarmBehaviorTag,
		v1Active = false,
	},
	combat = {
		id = "combat",
		displayName = "Combat Swarm",
		color = Color3.fromRGB(255, 70, 70),
		behaviorTag = "attack" :: SwarmBehaviorTag,
		v1Active = true,
	},
	engineering = {
		id = "engineering",
		displayName = "Engineering Swarm",
		color = Color3.fromRGB(80, 220, 140),
		behaviorTag = "repair" :: SwarmBehaviorTag,
		v1Active = false,
	},
} :: { [string]: SwarmPreset }

function DroneSwarmRegistry.Get(id: string): SwarmPreset?
	return DroneSwarmRegistry.Catalog[id]
end

-- The default V1 preset. Auto-deployed on player join. Phase G's
-- customization UI lets the player pick (and V1.5 lets them save
-- a config per brainstorm §2.7).
DroneSwarmRegistry.DefaultV1Preset = "combat"

return DroneSwarmRegistry
