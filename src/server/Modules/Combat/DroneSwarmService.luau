--!strict
--[[
	Outpost-7 — drone swarm service.

	Phase E2.6. Auto-deploys a 3-drone Combat swarm per player on
	character spawn. Drones orbit the player at fixed radius (Heartbeat
	steered toward orbit slots), break orbit to chase aliens within
	`DroneAttackRange`, fire raycast damage via DamageService, and
	return to orbit when the target dies or moves out of range.

	V1 ships **only the Combat preset** as functional. Recon +
	Engineering are catalog-listed in DroneSwarmRegistry but have no
	gameplay until Phase G (Recon needs HUD overlay; Engineering
	needs turret HP first).

	Object pool per CLAUDE.md "anything spawned in bulk" rule. Pool
	sized for 20-server-cap × 3 drones + buffer. Pool overflow logs
	a warn + spawns fresh (graceful degradation).

	Trust boundary: drones are server-spawned, server-positioned,
	server-targeted. Clients only see the replicated Parts. No
	client → server drone Remote (V1.5+ may add a "deploy / recall"
	Remote when customization UI ships).

	Public API:
	  Init                       — wires PlayerAdded / CharacterAdded
	                               / PlayerRemoving + the steering &
	                               targeting loops + builds the pool
	  DeploySwarm(player)        — internal; called on CharacterAdded
	  RecallSwarm(player)        — internal; called on Died /
	                               PlayerRemoving
	  GetSwarmCount(player)      — non-yielding read; returns count of
	                               active drones for the player
--]]

local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerStorage = game:GetService("ServerStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Constants = require(Shared:WaitForChild("Constants"))
local DroneSwarmRegistry =
	require(Shared:WaitForChild("Modules"):WaitForChild("Registry"):WaitForChild("DroneSwarmRegistry"))

local DataManager = require(script.Parent.Parent.Player.DataManager)
local DamageService = require(script.Parent.DamageService)

type SwarmPreset = DroneSwarmRegistry.SwarmPreset

local DroneSwarmService = {}

local POOL_FOLDER_NAME = "OutpostDronePool"
local ACTORS_FOLDER_NAME = "DroneActors"
local ALIEN_ACTORS_FOLDER = "AlienActors"

type Drone = {
	part: BasePart,
	-- Slot index within this player's swarm; determines orbit phase offset.
	slot: number,
	ownerUserId: number,
	preset: SwarmPreset,
	-- Targeting state.
	targetRoot: BasePart?,
	targetHumanoid: Humanoid?,
	lastFireAt: number,
}

type Swarm = {
	player: Player,
	preset: SwarmPreset,
	drones: { Drone },
	deployedAt: number, -- os.clock(); used for orbit phase
}

local poolFolder: Folder?
local actorsFolder: Folder?
local available: { BasePart } = {}
local swarms: { [Player]: Swarm } = {}

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

local function buildDronePart(preset: SwarmPreset): BasePart
	local part = Instance.new("Part")
	part.Name = "Drone_" .. preset.id
	part.Size = Vector3.new(0.8, 0.4, 1.2)
	part.Anchored = true -- server-controlled; CFrame snap each Heartbeat
	part.CanCollide = false
	part.CastShadow = false
	part.Color = preset.color
	part.Material = Enum.Material.Neon
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	return part
end

local function acquireDrone(preset: SwarmPreset): BasePart
	local part: BasePart? = table.remove(available)
	if not part then
		warn("[DroneSwarmService] Pool exhausted — spawning fresh drone (tune DronePoolSize)")
		part = buildDronePart(preset)
	end
	-- Re-tint in case a future preset swap reuses the pool.
	part.Color = preset.color
	part.Parent = actorsFolder
	return part
end

local function releaseDrone(part: BasePart)
	if not part.Parent then
		return
	end
	part.Parent = poolFolder
	table.insert(available, part)
end

local function getAlienActorsFolder(): Folder?
	local folder = Workspace:FindFirstChild(ALIEN_ACTORS_FOLDER)
	if folder and folder:IsA("Folder") then
		return folder
	end
	return nil
end

local function findNearestAlien(origin: Vector3, range: number): (BasePart?, Humanoid?)
	local actors = getAlienActorsFolder()
	if not actors then
		return nil, nil
	end
	local rangeSq = range * range
	local nearestRoot: BasePart? = nil
	local nearestHumanoid: Humanoid? = nil
	local nearestDistSq = rangeSq
	for _, model in actors:GetChildren() do
		if not model:IsA("Model") then
			continue
		end
		local root = model.PrimaryPart
		if not root then
			continue
		end
		local humanoid = model:FindFirstChildOfClass("Humanoid")
		if not humanoid or humanoid.Health <= 0 then
			continue
		end
		local distSq = (root.Position - origin).Magnitude ^ 2
		if distSq <= nearestDistSq then
			nearestDistSq = distSq
			nearestRoot = root
			nearestHumanoid = humanoid
		end
	end
	return nearestRoot, nearestHumanoid
end

local function spawnBeam(from: Vector3, to: Vector3, color: Color3)
	local diff = to - from
	local length = diff.Magnitude
	if length <= 0 then
		return
	end
	local part = Instance.new("Part")
	part.Name = "DroneBeam"
	part.Anchored = true
	part.CanCollide = false
	part.CastShadow = false
	part.Material = Enum.Material.Neon
	part.Color = color
	part.Size = Vector3.new(0.15, 0.15, length)
	part.CFrame = CFrame.lookAt(from + diff / 2, to)
	part.Parent = Workspace
	Debris:AddItem(part, 0.08)
end

-- Orbit slot: the resting position around the player when no target.
local function orbitSlotPosition(playerPos: Vector3, slotIndex: number, totalSlots: number, clockSec: number): Vector3
	local baseAngleRad = math.rad((Constants.COMBAT.DroneOrbitSpeedDeg :: number) * clockSec)
	local slotPhase = (slotIndex - 1) * (2 * math.pi / totalSlots)
	local angle = baseAngleRad + slotPhase
	local r = Constants.COMBAT.DroneOrbitRadius
	return playerPos
		+ Vector3.new(math.cos(angle) * r, Constants.COMBAT.DroneOrbitHeight, math.sin(angle) * r)
end

local function getCharacterRoot(player: Player): BasePart?
	local character = player.Character
	if not character then
		return nil
	end
	local hrp = character:FindFirstChild("HumanoidRootPart")
	if hrp and hrp:IsA("BasePart") then
		return hrp
	end
	return nil
end

function DroneSwarmService.DeploySwarm(player: Player)
	if swarms[player] then
		return
	end
	local presetId = DroneSwarmRegistry.DefaultV1Preset
	local preset = DroneSwarmRegistry.Get(presetId)
	if not preset or not preset.v1Active then
		warn(
			string.format(
				"[DroneSwarmService] Default preset %s missing / not v1Active",
				tostring(presetId)
			)
		)
		return
	end

	local count = Constants.COMBAT.DroneSwarmCount
	local drones: { Drone } = {}
	for i = 1, count do
		local part = acquireDrone(preset)
		-- Park near the player's current root if any; the orbit lerp
		-- will pull it into position over the next few frames.
		local origin = getCharacterRoot(player)
		if origin then
			part.CFrame = CFrame.new(origin.Position + Vector3.new(0, Constants.COMBAT.DroneOrbitHeight, 0))
		end
		table.insert(drones, {
			part = part,
			slot = i,
			ownerUserId = player.UserId,
			preset = preset,
			targetRoot = nil,
			targetHumanoid = nil,
			lastFireAt = 0,
		})
	end
	swarms[player] = {
		player = player,
		preset = preset,
		drones = drones,
		deployedAt = os.clock(),
	}
	print(
		string.format(
			"[DroneSwarmService] Deployed %s swarm (%d drones) for %s",
			preset.id,
			count,
			player.Name
		)
	)
end

function DroneSwarmService.RecallSwarm(player: Player)
	local swarm = swarms[player]
	if not swarm then
		return
	end
	for _, drone in swarm.drones do
		releaseDrone(drone.part)
	end
	swarms[player] = nil
end

function DroneSwarmService.GetSwarmCount(player: Player): number
	local swarm = swarms[player]
	if not swarm then
		return 0
	end
	return #swarm.drones
end

local function steerSwarm(swarm: Swarm, dt: number)
	local origin = getCharacterRoot(swarm.player)
	if not origin then
		-- Character missing (mid-respawn). Just hold position.
		return
	end
	local moveStep = Constants.COMBAT.DroneMoveSpeed * dt
	local now = os.clock()
	local clockOffset = now - swarm.deployedAt
	local count = #swarm.drones
	for _, drone in swarm.drones do
		local goal: Vector3
		if drone.targetRoot and drone.targetHumanoid and drone.targetHumanoid.Health > 0 then
			-- Lead-in: stop short of the target so we don't overlap geometry.
			local toTarget = drone.targetRoot.Position - drone.part.Position
			if toTarget.Magnitude > 4 then
				goal = drone.targetRoot.Position + Vector3.new(0, 2, 0)
			else
				goal = drone.part.Position -- hold and shoot
			end
		else
			goal = orbitSlotPosition(origin.Position, drone.slot, count, clockOffset)
		end
		local current = drone.part.Position
		local toGoal = goal - current
		local distance = toGoal.Magnitude
		if distance > 0.01 then
			local step = math.min(distance, moveStep)
			drone.part.CFrame = CFrame.new(current + toGoal.Unit * step)
		end
	end
end

local function tickTargetingFor(swarm: Swarm)
	for _, drone in swarm.drones do
		-- Re-acquire if current target is dead / out of range.
		local refresh = false
		if not drone.targetHumanoid or drone.targetHumanoid.Health <= 0 then
			refresh = true
		elseif drone.targetRoot then
			local distSq = (drone.targetRoot.Position - drone.part.Position).Magnitude ^ 2
			if distSq > Constants.COMBAT.DroneAttackRange * Constants.COMBAT.DroneAttackRange then
				refresh = true
			end
		end
		if refresh then
			local root, humanoid = findNearestAlien(drone.part.Position, Constants.COMBAT.DroneAttackRange)
			drone.targetRoot = root
			drone.targetHumanoid = humanoid
		end

		-- Fire if in range + cooldown elapsed.
		local target = drone.targetRoot
		local humanoid = drone.targetHumanoid
		if target and humanoid and humanoid.Health > 0 then
			local now = os.clock()
			if now - drone.lastFireAt >= Constants.COMBAT.DroneFireSeconds then
				local distSq = (target.Position - drone.part.Position).Magnitude ^ 2
				if distSq <= Constants.COMBAT.DroneAttackRange * Constants.COMBAT.DroneAttackRange then
					drone.lastFireAt = now
					local hpBefore = humanoid.Health
					DamageService.ApplyToHumanoid(humanoid, Constants.COMBAT.DroneDamage, "drone_raycast")
					local hpAfter = humanoid.Health
					spawnBeam(drone.part.Position, target.Position, drone.preset.color)
					if hpBefore > 0 and hpAfter <= 0 then
						local owner = Players:GetPlayerByUserId(drone.ownerUserId)
						if owner then
							local data = DataManager.GetData(owner)
							if data then
								data.dronesKilled += 1
							end
						end
					end
				end
			end
		end
	end
end

local function targetingLoop()
	while true do
		task.wait(Constants.COMBAT.DroneTickSeconds)
		for _, swarm in swarms do
			tickTargetingFor(swarm)
		end
	end
end

local function steeringLoop()
	RunService.Heartbeat:Connect(function(dt: number)
		for _, swarm in swarms do
			steerSwarm(swarm, dt)
		end
	end)
end

local function bindCharacter(player: Player, character: Model)
	-- Defer 0.1s so HumanoidRootPart and the character's parts are all
	-- present before we orbit around them.
	task.delay(0.1, function()
		if player.Character ~= character then
			return
		end
		DroneSwarmService.DeploySwarm(player)
	end)

	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoid.Died:Connect(function()
			DroneSwarmService.RecallSwarm(player)
		end)
	end
end

function DroneSwarmService.Init()
	ensureFolders()

	-- Pre-allocate the drone pool with the default V1 preset's color.
	local defaultPreset = DroneSwarmRegistry.Get(DroneSwarmRegistry.DefaultV1Preset)
	if not defaultPreset then
		warn("[DroneSwarmService] No default preset; pool not initialized")
		return
	end
	for _ = 1, Constants.COMBAT.DronePoolSize do
		local part = buildDronePart(defaultPreset)
		part.Parent = poolFolder
		table.insert(available, part)
	end
	print(string.format("[DroneSwarmService] Pre-allocated %d drone parts.", #available))

	Players.PlayerAdded:Connect(function(player)
		player.CharacterAdded:Connect(function(character)
			bindCharacter(player, character)
		end)
		if player.Character then
			bindCharacter(player, player.Character)
		end
	end)
	Players.PlayerRemoving:Connect(function(player)
		DroneSwarmService.RecallSwarm(player)
	end)
	-- Existing players (Studio reload during dev).
	for _, player in Players:GetPlayers() do
		if player.Character then
			bindCharacter(player, player.Character)
		end
		player.CharacterAdded:Connect(function(character)
			bindCharacter(player, character)
		end)
	end

	steeringLoop()
	task.spawn(targetingLoop)
end

return DroneSwarmService
