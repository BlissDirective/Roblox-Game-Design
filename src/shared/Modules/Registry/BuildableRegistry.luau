--!strict
--[[
	Outpost-7 — buildable catalog (server-side).

	Phase B1. Two starter buildings: extractor (must be placed on a
	resource node) and wall (placed on any free cell). Phase B+ adds
	turret, drone-bay, decor, etc.

	V1 placement uses simple Parts as visuals — Phase G replaces these
	with real models via assets/world/. The geometry-from-code approach
	keeps B1 testable without any Studio-side authoring.

	Schema (`Buildable`):
	  id            — stable string key, lowercase + underscore
	  displayName   — for HUD / build palette later
	  cost          — Credits to place; checked by PlacementService once
	                  CurrencyService lands in B2 (no-op until then)
	  income        — Credits/sec; only meaningful for extractor-class
	                  buildings; B2 reads it during the currency tick
	  requiresNode  — extractor must overlap a resource node cell
	  size          — Vector3 in studs; used to build the visual Part
	  color         — visual tint
--]]

local BuildableRegistry = {}

export type Buildable = {
	id: string,
	displayName: string,
	cost: number,
	income: number,
	requiresNode: boolean,
	size: Vector3,
	color: Color3,
}

local BUILDABLES: { [string]: Buildable } = {
	extractor = {
		id = "extractor",
		displayName = "Extractor",
		cost = 50,
		income = 1,
		requiresNode = true,
		size = Vector3.new(3, 4, 3),
		color = Color3.fromRGB(180, 200, 80),
	},
	wall = {
		id = "wall",
		displayName = "Wall",
		cost = 20,
		income = 0,
		requiresNode = false,
		size = Vector3.new(4, 5, 1),
		color = Color3.fromRGB(120, 120, 130),
	},
}

function BuildableRegistry.Get(id: string): Buildable?
	return BUILDABLES[id]
end

function BuildableRegistry.IsValidId(id: string): boolean
	return BUILDABLES[id] ~= nil
end

function BuildableRegistry.GetAll(): { [string]: Buildable }
	return BUILDABLES
end

-- Build the visual Part for a placed buildable. Caller is responsible
-- for parenting and CFrame; this just produces the geometry.
function BuildableRegistry.BuildPart(buildable: Buildable, ownerUserId: number): BasePart
	local part = Instance.new("Part")
	part.Name = buildable.id
	part.Anchored = true
	part.CanCollide = true
	part.Size = buildable.size
	part.Material = Enum.Material.Metal
	part.Color = buildable.color
	part.SetAttribute("BuildableId", buildable.id)
	part.SetAttribute("OwnerUserId", ownerUserId)
	return part
end

return BuildableRegistry
