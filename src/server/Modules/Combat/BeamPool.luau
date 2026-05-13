--!strict
--[[
	Outpost-7 — beam visual pool (turret/drone "shoot a line" effect).

	Phase F3 (original pool). Phase G6 visual upgrade.

	F3: replaces the per-shot `Instance.new("Part") + Debris:AddItem`
	pattern that E2.5 (TurretService) and E2.6 (DroneSwarmService)
	shipped. CLAUDE.md: "Object pool anything spawned in bulk...
	`Instance.new` in tight loops is the #1 cause of frame drops on
	lower-end mobile devices."

	G6: each pooled "beam" is now an invisible host Part carrying:
	  - two Attachments (`Origin`, `Impact`)
	  - a `Beam` instance bridging the two attachments (GPU-rendered,
	    width tapers from start → end, light-emitting Neon look)
	  - a `ParticleEmitter` on Origin (one-shot muzzle flare)
	  - a `ParticleEmitter` on Impact (one-shot impact spark)
	The pool API stays the same: `Acquire(from, to, color, lifetime?)`.
	Acquire repositions the two attachments in world space, sets the
	beam color, and triggers `:Emit(N)` on both particle emitters.

	Why this matters at peak load:
	  - 40 turrets × 1 shot/sec = 40 fires/sec from turrets
	  - 12 drones × 2 shots/sec = 24 fires/sec from drones
	  - ≈ 64 effects per second at peak
	  - Pool means ZERO Instance.new at fire time

	Pool semantics:
	  - Pre-allocate `BeamPoolSize` (60) host Parts in ServerStorage on Init
	  - Acquire: grab a host, reposition attachments, fire particles,
	    parent host to Workspace, schedule return via task.delay
	  - On lifetime expire: parent back to ServerStorage, available
	    for next Acquire
	  - Pool exhausted: build fresh host with warn log (graceful
	    degradation matches AlienPool / DroneSwarmService pattern)

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

local function buildMuzzleEmitter(parent: Attachment): ParticleEmitter
	-- G6: short-lived muzzle flare. Emit-on-fire (no continuous Rate).
	local p = Instance.new("ParticleEmitter")
	p.Name = "Muzzle"
	p.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	p.Rate = 0 -- only emits via :Emit()
	p.Lifetime = NumberRange.new(0.08, 0.18)
	p.Speed = NumberRange.new(2, 6)
	p.SpreadAngle = Vector2.new(35, 35)
	p.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.6),
		NumberSequenceKeypoint.new(1, 0),
	})
	p.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0),
		NumberSequenceKeypoint.new(1, 1),
	})
	p.LightEmission = 1
	p.LightInfluence = 0
	p.Rotation = NumberRange.new(0, 360)
	p.RotSpeed = NumberRange.new(-180, 180)
	p.Acceleration = Vector3.new(0, -4, 0)
	p.Enabled = true -- emit when Emit() is called; not continuous
	p.Parent = parent
	return p
end

local function buildImpactEmitter(parent: Attachment): ParticleEmitter
	-- G6: impact spark — narrower spread, faster particles outward.
	local p = Instance.new("ParticleEmitter")
	p.Name = "Impact"
	p.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	p.Rate = 0
	p.Lifetime = NumberRange.new(0.10, 0.25)
	p.Speed = NumberRange.new(4, 10)
	p.SpreadAngle = Vector2.new(20, 20)
	p.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.5),
		NumberSequenceKeypoint.new(1, 0),
	})
	p.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0),
		NumberSequenceKeypoint.new(0.5, 0.4),
		NumberSequenceKeypoint.new(1, 1),
	})
	p.LightEmission = 1
	p.LightInfluence = 0
	p.Rotation = NumberRange.new(0, 360)
	p.RotSpeed = NumberRange.new(-360, 360)
	p.Acceleration = Vector3.new(0, -2, 0)
	p.Enabled = true
	p.Parent = parent
	return p
end

local function buildBeamHost(): BasePart
	-- Invisible host Part. The Beam child is the actual visual; the
	-- two Attachments are the beam endpoints.
	local part = Instance.new("Part")
	part.Name = "BeamHost"
	part.Anchored = true
	part.CanCollide = false
	part.CastShadow = false
	part.Transparency = 1
	part.Size = Vector3.new(0.1, 0.1, 0.1)

	local origin = Instance.new("Attachment")
	origin.Name = "Origin"
	origin.Parent = part

	local impact = Instance.new("Attachment")
	impact.Name = "Impact"
	impact.Parent = part

	local beam = Instance.new("Beam")
	beam.Name = "Beam"
	beam.Attachment0 = origin
	beam.Attachment1 = impact
	beam.Width0 = Constants.COMBAT.BeamWidthStart
	beam.Width1 = Constants.COMBAT.BeamWidthEnd
	beam.Segments = Constants.COMBAT.BeamSegments
	beam.LightEmission = 1
	beam.LightInfluence = 0
	beam.FaceCamera = true
	-- Fade in at start, fade out at end — quick visual punch.
	beam.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.1),
		NumberSequenceKeypoint.new(0.5, 0.0),
		NumberSequenceKeypoint.new(1, 0.6),
	})
	beam.Parent = part

	buildMuzzleEmitter(origin)
	buildImpactEmitter(impact)

	return part
end

local function acquireHost(): BasePart
	local part: BasePart? = table.remove(available)
	if part then
		return part
	end
	-- Pool exhausted — graceful degradation. Phase H prep may bump
	-- BeamPoolSize if this warn fires regularly in production.
	warn("[BeamPool] Exhausted — spawning fresh BeamHost (tune BeamPoolSize)")
	return buildBeamHost()
end

local function releaseHost(part: BasePart)
	if not part.Parent then
		return
	end
	part.Parent = poolFolder
	table.insert(available, part)
end

function BeamPool.Acquire(from: Vector3, to: Vector3, color: Color3, lifetime: number?)
	ensurePool()
	if (to - from).Magnitude <= 0 then
		return
	end
	local part = acquireHost()
	-- Find the persistent children built at pool-Init time.
	local origin = part:FindFirstChild("Origin") :: Attachment
	local impact = part:FindFirstChild("Impact") :: Attachment
	local beam = part:FindFirstChild("Beam") :: Beam
	if not origin or not impact or not beam then
		-- Defensive: a host that somehow lost its children. Rebuild it.
		warn("[BeamPool] Host missing children; rebuilding")
		part:Destroy()
		part = buildBeamHost()
		origin = part:FindFirstChild("Origin") :: Attachment
		impact = part:FindFirstChild("Impact") :: Attachment
		beam = part:FindFirstChild("Beam") :: Beam
	end

	-- Position. The host Part itself sits at `from`; attachment WorldPosition
	-- writes the visual endpoints in world space.
	part.CFrame = CFrame.new(from)
	origin.WorldPosition = from
	impact.WorldPosition = to

	-- Color (uniform along the beam; particle sparks pick up from the
	-- emitters' default white).
	beam.Color = ColorSequence.new(color)

	part.Parent = Workspace

	-- One-shot particle bursts at both ends.
	local muzzle = origin:FindFirstChild("Muzzle") :: ParticleEmitter?
	local spark = impact:FindFirstChild("Impact") :: ParticleEmitter?
	if muzzle then
		muzzle:Emit(Constants.COMBAT.MuzzleParticleCount)
	end
	if spark then
		spark:Emit(Constants.COMBAT.ImpactParticleCount)
	end

	-- Schedule release. Using task.delay (vs Debris:AddItem with destroy)
	-- because we need to recycle, not destroy. Pool stays warm for the
	-- next shot.
	local effectiveLifetime = lifetime or Constants.COMBAT.BeamLifetimeSeconds
	task.delay(effectiveLifetime, function()
		releaseHost(part)
	end)
end

function BeamPool.Init()
	ensurePool()
	for _ = 1, Constants.COMBAT.BeamPoolSize do
		local part = buildBeamHost()
		part.Parent = poolFolder
		table.insert(available, part)
	end
	print(string.format("[BeamPool] Pre-allocated %d beam hosts (Beam + 2 emitters each).", #available))
end

return BeamPool
