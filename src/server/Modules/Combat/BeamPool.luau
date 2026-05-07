--!strict
--[[
	Outpost-7 — beam visual pool (turret/drone "shoot a line" effect).

	Phase F3. Replaces the per-shot `Instance.new("Part") +
	Debris:AddItem` pattern that E2.5 (TurretService) and E2.6
	(DroneSwarmService) shipped. CLAUDE.md: "Object pool anything
	spawned in bulk... `Instance.new` in tight loops is the #1 cause
	of frame drops on lower-end mobile devices."

	Why this matters at peak load:
	  - 40 turrets × 1 shot/sec = 40 Instance.new/sec from turrets
	  - 12 drones × 2 shots/sec = 24 Instance.new/sec from drones
	  - ≈ 64 Parts created + destroyed per second at peak
	  - Each is a full Studio replication round-trip per Part (create
	    + property writes + parent + destroy)

	Pool semantics:
	  - Pre-allocate `BeamPoolSize` (60) Parts in ServerStorage on Init
	  - Acquire(from, to, color, lifetime?): grab a Part, configure,
	    parent to Workspace, schedule return-to-pool via task.delay
	  - On lifetime expire: parent back to ServerStorage, available
	    for next Acquire
	  - Pool exhausted: spawn fresh Part with warn log (graceful
	    degradation matches AlienPool / DroneSwarmService pattern)

	Phase G replaces the Part-line-segment visual with a proper Beam
	+ ParticleEmitter pair; the pool API stays the same (Acquire /
	auto-release after lifetime).

	Public API:
	  Init                                         — pre-allocate the pool
	  Acquire(from, to, color, lifetime?)          — fire-and-forget; auto-releases
--]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Constants = require(Shared:WaitForChild("Constants"))

local BeamPool = {}

local POOL_FOLDER_NAME = "OutpostBeamPool"

local poolFolder: Folder?
local available: { BasePart } = {}

local function ensurePool()
	if poolFolder then
		return
	end
	local existing = ServerStorage:FindFirstChild(POOL_FOLDER_NAME)
	if existing and existing:IsA("Folder") then
		poolFolder = existing
		return
	end
	local f = Instance.new("Folder")
	f.Name = POOL_FOLDER_NAME
	f.Parent = ServerStorage
	poolFolder = f
end

local function buildBeamPart(): BasePart
	local part = Instance.new("Part")
	part.Name = "Beam"
	part.Anchored = true
	part.CanCollide = false
	part.CastShadow = false
	part.Material = Enum.Material.Neon
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	-- Default size; Acquire overrides per-shot.
	part.Size = Vector3.new(0.2, 0.2, 1)
	return part
end

local function acquirePart(): BasePart
	local part: BasePart? = table.remove(available)
	if part then
		return part
	end
	-- Pool exhausted — graceful degradation. Phase H prep may bump
	-- BeamPoolSize if this warn fires regularly in production.
	warn("[BeamPool] Exhausted — spawning fresh Beam (tune BeamPoolSize)")
	return buildBeamPart()
end

local function releasePart(part: BasePart)
	if not part.Parent then
		return
	end
	part.Parent = poolFolder
	table.insert(available, part)
end

function BeamPool.Acquire(from: Vector3, to: Vector3, color: Color3, lifetime: number?)
	ensurePool()
	local diff = to - from
	local length = diff.Magnitude
	if length <= 0 then
		return
	end
	local part = acquirePart()
	-- Configure + place. Beam thickness is a per-shot constant; size
	-- only changes in length to match from→to distance.
	part.Size = Vector3.new(0.2, 0.2, length)
	part.Color = color
	part.CFrame = CFrame.lookAt(from + diff / 2, to)
	part.Parent = Workspace

	-- Schedule release. Using task.delay (vs Debris:AddItem with destroy)
	-- because we need to recycle, not destroy.
	local effectiveLifetime = lifetime or Constants.COMBAT.BeamLifetimeSeconds
	task.delay(effectiveLifetime, function()
		releasePart(part)
	end)
end

function BeamPool.Init()
	ensurePool()
	for _ = 1, Constants.COMBAT.BeamPoolSize do
		local part = buildBeamPart()
		part.Parent = poolFolder
		table.insert(available, part)
	end
	print(string.format("[BeamPool] Pre-allocated %d beam parts.", #available))
end

return BeamPool
