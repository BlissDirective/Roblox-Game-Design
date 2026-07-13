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
	  combatRole    — E2.5 dispatch: "turret" registers with
	                  Combat.TurretService on placement; nil for purely
	                  passive structures (walls, extractors)
	  maxHp         — Phase R1: structure hit points. Aliens damage
	                  structures via StructureHealthService; at 0 a wall/
	                  turret is destroyed and an extractor is disabled or
	                  destroyed per Constants.COMBAT.WaveLossMode. nil/0 =
	                  indestructible (no V1 buildable relies on that).

	F0 generalization (V1.5 expansion prep — additive fields):
	  placementBehaviors — array of behavior tags; generalizes combatRole
	                       so a buildable can simultaneously act as a
	                       turret + material extractor + interact target
	                       (e.g. V1.5 specialty extractors are
	                       {"extractor", "materialDrop"})
	  unlockTier         — V1.5 Tier system gate (0 = always available;
	                       3 = unlocked at Tier 3 Operating Base; etc.).
	                       Phase G's BuildPalette filters by player's
	                       current tier. V1 ignores (no tier system yet).
	  materialDrop       — V1.5 specialty extractors drop a specific
	                       material per second instead of (or in addition
	                       to) Credits. Currency vs material is decided
	                       by which fields are populated.
	  interactRemote     — name of a Remote in `Remotes.luau` that fires
	                       when a player interacts with this building.
	                       Used for Workshop, Expedition Pad, Pen,
	                       Vehicle Factory, Boss Beacon, Archive, etc.
	                       V1 buildables (extractor / wall / turret)
	                       have no interact prompt (nil here).
--]]

local BuildableRegistry = {}

export type MaterialDrop = {
	id: string, -- material id from V1.5 MaterialRegistry
	ratePerSec: number, -- materials produced per second per extractor
}

export type Buildable = {
	id: string,
	displayName: string,
	cost: number,
	income: number,
	requiresNode: boolean,
	size: Vector3,
	color: Color3,
	combatRole: string?,
	maxHp: number?, -- Phase R1 structure HP; nil/0 = indestructible
	-- F0 V1.5 prep (all optional, additive — V1 callers ignore):
	placementBehaviors: { string }?,
	unlockTier: number?,
	materialDrop: MaterialDrop?,
	interactRemote: string?,
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
		-- The income core. Lower HP than a wall so an unwalled extractor
		-- is genuinely at risk — the whole point of R1 is that walls matter.
		maxHp = 150,
	},
	wall = {
		id = "wall",
		displayName = "Wall",
		cost = 20,
		income = 0,
		requiresNode = false,
		size = Vector3.new(4, 5, 1),
		color = Color3.fromRGB(120, 120, 130),
		-- Highest HP — walls are the perimeter meant to soak the swarm so
		-- turrets and extractors behind them survive. ~15 alien hits.
		maxHp = 300,
	},
	turret = {
		id = "turret",
		displayName = "Turret",
		cost = 200,
		income = 0,
		requiresNode = false,
		size = Vector3.new(2, 4, 2),
		-- Steel-blue tactical visual; Phase G replaces with a real model.
		color = Color3.fromRGB(80, 130, 180),
		combatRole = "turret",
		-- Between wall and extractor. A turret behind a wall outlasts the
		-- wall; an exposed turret gets swarmed. Encourages layered defense.
		maxHp = 250,
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
	part:SetAttribute("BuildableId", buildable.id)
	part:SetAttribute("OwnerUserId", ownerUserId)
	-- Phase R1: stamp HP so StructureHealthService and the client damage-
	-- state renderer read a single source of truth off the Part. maxHp nil
	-- means indestructible — leave the attributes unset so consumers can
	-- treat "no MaxHp attribute" as "cannot be damaged".
	if buildable.maxHp and buildable.maxHp > 0 then
		part:SetAttribute("MaxHp", buildable.maxHp)
		part:SetAttribute("CurrentHp", buildable.maxHp)
	end
	return part
end

return BuildableRegistry
