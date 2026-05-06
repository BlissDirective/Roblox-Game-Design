--!strict
--[[
	Outpost-7 — alien object pool.

	Phase E2. Pre-allocates `Constants.COMBAT.AlienPoolSize` alien
	actors at server start; reuses them across waves to avoid the
	`Instance.new` spike on wave spawn (CLAUDE.md: "object pool anything
	spawned in bulk").

	V1 alien actor: a Part with a Humanoid + a child HumanoidRootPart,
	rooted under `Workspace.AlienActors`. Phase G replaces with real
	models. The Humanoid handles MoveTo + walkspeed; AlienAI drives
	the per-tick targeting.

	Pool semantics:
	  Acquire(def, plot, position)  — returns a configured-and-parked
	                                  alien Model under Workspace, ready
	                                  for AlienAI to drive
	  Release(model)                — returns the model to the pool
	                                  (parent ServerStorage, cleared)
	  Drain()                       — destroys all pool entries (server
	                                  shutdown / Studio script reload
	                                  cleanup)
--]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Constants = require(Shared:WaitForChild("Constants"))
local AlienRegistry =
	require(Shared:WaitForChild("Modules"):WaitForChild("Registry"):WaitForChild("AlienRegistry"))

type AlienDef = AlienRegistry.AlienDef

local AlienPool = {}

local POOL_FOLDER_NAME = "OutpostAlienPool"
local ACTORS_FOLDER_NAME = "AlienActors"

local poolFolder: Folder?
local actorsFolder: Folder?
local available: { Model } = {}

-- Per-instance metadata so AlienAI can read def + last-attack timestamp
-- without piggybacking on Roblox attributes for everything.
export type ActiveAlien = {
	model: Model,
	humanoid: Humanoid,
	root: BasePart,
	def: AlienDef,
	lastMeleeAt: number,
	targetUserId: number?, -- the player this alien is hunting
}

local function ensureFolders()
	if not poolFolder then
		local existing = ServerStorage:FindFirstChild(POOL_FOLDER_NAME)
		if existing and existing:IsA("Folder") then
			poolFolder = existing
		else
			local f = Instance.new("Folder")
			f.Name = POOL_FOLDER_NAME
			f.Parent = ServerStorage
			poolFolder = f
		end
	end
	if not actorsFolder then
		local existing = Workspace:FindFirstChild(ACTORS_FOLDER_NAME)
		if existing and existing:IsA("Folder") then
			actorsFolder = existing
		else
			local f = Instance.new("Folder")
			f.Name = ACTORS_FOLDER_NAME
			f.Parent = Workspace
			actorsFolder = f
		end
	end
end

-- F0 V2 prep: factored geometry construction so V2 can swap to a
-- mesh-template clone path with one branch instead of an architectural
-- refactor. V1 always takes the programmatic branch.
local function buildProcedural(def: AlienDef): Model
	local model = Instance.new("Model")
	model.Name = def.id .. "_alien"

	local root = Instance.new("Part")
	root.Name = "HumanoidRootPart"
	root.Size = def.visualSize
	root.Anchored = false
	root.CanCollide = true
	root.Color = def.visualColor
	root.Material = Enum.Material.Neon
	root.TopSurface = Enum.SurfaceType.Smooth
	root.BottomSurface = Enum.SurfaceType.Smooth
	-- V1 placeholder — neon glow for the bioluminescent vibe.
	root.Parent = model
	model.PrimaryPart = root

	return model
end

local function buildFromTemplate(def: AlienDef, template: Model): Model
	-- V2 path: clone the imported mesh rig. Caller guarantees template
	-- has a PrimaryPart already (the imported rig must be authored
	-- correctly per `docs/playbooks/ASSETS.md`).
	local model = template:Clone()
	model.Name = def.id .. "_alien"
	-- The cloned model's PrimaryPart is preserved; we don't re-set it.
	return model
end

local function buildActor(def: AlienDef): Model
	-- F0 V2 prep: dispatch on meshTemplate. V1 defs all leave nil →
	-- programmatic. V2 defs ship with template references → clone path.
	local model: Model
	if def.meshTemplate then
		model = buildFromTemplate(def, def.meshTemplate)
	else
		model = buildProcedural(def)
	end

	-- Humanoid is universal — both procedural and template paths get one.
	-- Template imports may already include a Humanoid; in that case the
	-- cloned model already has it and we just configure stats.
	local humanoid = model:FindFirstChildOfClass("Humanoid")
	if not humanoid then
		humanoid = Instance.new("Humanoid")
		humanoid.Parent = model
	end
	humanoid.MaxHealth = def.hp
	humanoid.Health = def.hp
	humanoid.WalkSpeed = def.walkSpeed
	humanoid.AutoRotate = true
	humanoid.RequiresNeck = false
	humanoid.BreakJointsOnDeath = false

	-- Pool buildable id attribute so debugging tools can find them.
	model:SetAttribute("AlienId", def.id)

	return model
end

function AlienPool.Init()
	ensureFolders()
	-- Pre-allocate a single-type pool. V1 has only Stalker; if Phase G
	-- adds variants, this becomes a per-type pool keyed by def.id.
	local stalkerDef = AlienRegistry.Get("stalker")
	if not stalkerDef then
		warn("[AlienPool] Stalker def missing; pool not initialized.")
		return
	end
	for _ = 1, Constants.COMBAT.AlienPoolSize do
		local actor = buildActor(stalkerDef)
		actor.Parent = poolFolder
		table.insert(available, actor)
	end
	print(string.format("[AlienPool] Pre-allocated %d Stalker actors.", #available))
end

local function reset(actor: Model, def: AlienDef, position: Vector3)
	local root = actor.PrimaryPart
	if not root then
		return
	end
	local humanoid = actor:FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoid.MaxHealth = def.hp
		humanoid.Health = def.hp
		humanoid.WalkSpeed = def.walkSpeed
	end
	root.CFrame = CFrame.new(position)
	root.AssemblyLinearVelocity = Vector3.zero
	root.AssemblyAngularVelocity = Vector3.zero
end

function AlienPool.Acquire(def: AlienDef, position: Vector3): ActiveAlien?
	ensureFolders()
	local model: Model? = table.remove(available)
	if not model then
		-- Pool exhausted; spawn a fresh actor (graceful degradation).
		warn("[AlienPool] Pool exhausted — spawning fresh actor (tune AlienPoolSize)")
		model = buildActor(def)
	end
	reset(model, def, position)
	model.Parent = actorsFolder

	local humanoid = model:FindFirstChildOfClass("Humanoid")
	local root = model.PrimaryPart
	if not humanoid or not root then
		-- Malformed actor; destroy and bail.
		model:Destroy()
		return nil
	end

	return {
		model = model,
		humanoid = humanoid,
		root = root,
		def = def,
		lastMeleeAt = 0,
		targetUserId = nil,
	}
end

function AlienPool.Release(model: Model)
	if not model.Parent then
		return
	end
	-- Park back in pool. Disable Humanoid simulation by parenting to
	-- ServerStorage; the next Acquire re-parents to Workspace.
	model.Parent = poolFolder
	-- Reset health so the next acquire starts fresh.
	local humanoid = model:FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoid.Health = humanoid.MaxHealth
	end
	table.insert(available, model)
end

function AlienPool.Drain()
	for _, model in available do
		model:Destroy()
	end
	available = {}
	if actorsFolder then
		for _, child in actorsFolder:GetChildren() do
			child:Destroy()
		end
	end
end

return AlienPool
