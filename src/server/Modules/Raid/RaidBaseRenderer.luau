--!strict
--[[
	Outpost-7 — render a defender snapshot into the raid arena (raid place).

	Phase R2. Closes audit §4.1: the E1 raid round was an empty timer that
	always declared the attacker the winner. This renders the defender's
	captured base into the raid arena as damageable structures and runs the
	loot-extraction objective (§7.1):

	  - Walls / turrets / extractors from `snapshot.baseLayout` are spawned as
	    HP-bearing Parts (reusing BuildableRegistry.BuildPart, which stamps
	    MaxHp/CurrentHp so the R3 weapon can damage them).
	  - The base is re-centered on Constants.RAID.RaidArenaOrigin — the
	    defender's real plot location is irrelevant.
	  - Extractors are the loot cores. The extractable pool
	    (min(credits × StealPct, StealCap)) is split evenly across them;
	    destroying one banks its share. Walls stand in the way (300 HP), so
	    the raid is a race against the 5-minute timer.

	This module never writes any profile — it only tracks the round's loot
	tally. RaidSession reads the tally at round end and RaidRewardService
	(main place) applies the credit moves on the authoritative home servers.

	Single active raid per reserved server (one attacker per raid round), so
	state is module-level.

	Public API:
	  Render(snapshot)            — build the arena + base; arm loot tracking
	  DamageStructure(pl, part, n)— weapon-hit handler (registered on WeaponService)
	  PositionAttacker(player)    — drop the attacker at the arena spawn
	  GetExtracted()              — credits banked from smashed extractors
	  GetStructuresDestroyed()    — count of any structures destroyed
	  GetTotalExtractors()        — extractors present at render time
	  Cleanup()                   — tear the arena down
--]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Constants = require(Shared:WaitForChild("Constants"))
local BuildableRegistry =
	require(Shared:WaitForChild("Modules"):WaitForChild("Registry"):WaitForChild("BuildableRegistry"))

local DamageService = require(script.Parent.Parent.Combat.DamageService)
local BeamPool = require(script.Parent.Parent.Combat.BeamPool)

local RaidBaseRenderer = {}

-- Raid turret tracer — orange, distinct from the attacker's blue rifle.
local TURRET_BEAM_COLOR = Color3.fromRGB(255, 150, 60)

type ActiveBase = {
	folder: Folder,
	totalExtractors: number,
	lootPerExtractor: number,
	extracted: number,
	extractorsDown: number,
	structuresDestroyed: number,
	turrets: { BasePart },
	defending: boolean,
}

local active: ActiveBase? = nil

local function computeLootPool(snapshot: any): (number, number)
	local layout = snapshot.baseLayout
	local extractorCount = 0
	for _, entry in layout do
		local buildable = BuildableRegistry.Get(entry.id)
		if buildable and buildable.income > 0 then
			extractorCount += 1
		end
	end
	local pool = math.min(snapshot.creditsAtSnapshot * Constants.RAID.RaidStealPct, Constants.RAID.RaidStealCap)
	pool = math.floor(math.max(0, pool))
	local perExtractor = if extractorCount > 0 then math.floor(pool / extractorCount) else 0
	return extractorCount, perExtractor
end

local function buildFloor(parent: Folder)
	local floor = Instance.new("Part")
	floor.Name = "ArenaFloor"
	floor.Anchored = true
	floor.CanCollide = true
	floor.Size = Vector3.new(Constants.RAID.RaidArenaFloorSize, 1, Constants.RAID.RaidArenaFloorSize)
	floor.Position = Constants.RAID.RaidArenaOrigin - Vector3.new(0, 0.5, 0)
	floor.Material = Enum.Material.Metal
	floor.Color = Color3.fromRGB(30, 30, 38)
	floor.TopSurface = Enum.SurfaceType.Smooth
	floor.Parent = parent
end

-- Re-center the snapshot cells on the arena origin so the base renders as a
-- compact cluster regardless of which plot the defender occupied.
local function cellCentroid(layout: { { id: string, x: number, z: number } }): (number, number)
	local n = #layout
	if n == 0 then
		return 0, 0
	end
	local sx, sz = 0, 0
	for _, e in layout do
		sx += e.x
		sz += e.z
	end
	return sx / n, sz / n
end

function RaidBaseRenderer.Render(snapshot: any)
	RaidBaseRenderer.Cleanup()

	local folder = Instance.new("Folder")
	folder.Name = "RaidArena"
	folder.Parent = Workspace

	buildFloor(folder)

	local totalExtractors, lootPerExtractor = computeLootPool(snapshot)

	local layout = snapshot.baseLayout
	local cx, cz = cellCentroid(layout)
	local grid = Constants.GRID.Size
	local origin = Constants.RAID.RaidArenaOrigin
	local turrets: { BasePart } = {}

	for _, entry in layout do
		local buildable = BuildableRegistry.Get(entry.id)
		if not buildable then
			continue
		end
		local part = BuildableRegistry.BuildPart(buildable, snapshot.defenderUserId)
		local offset = Vector3.new((entry.x - cx) * grid, 0, (entry.z - cz) * grid)
		part.Position = origin + offset + Vector3.new(0, buildable.size.Y / 2, 0)
		-- Tag raid structures so the weapon handler + loot accounting can
		-- classify a hit part in O(1).
		part:SetAttribute("RaidStructure", true)
		if buildable.income > 0 then
			part:SetAttribute("RaidExtractor", true)
		end
		if buildable.combatRole == "turret" then
			table.insert(turrets, part)
		end
		part.Parent = folder
	end

	active = {
		folder = folder,
		totalExtractors = totalExtractors,
		lootPerExtractor = lootPerExtractor,
		extracted = 0,
		extractorsDown = 0,
		structuresDestroyed = 0,
		turrets = turrets,
		defending = false,
	}

	print(
		string.format(
			"[RaidBaseRenderer] Rendered %d structures (%d extractors, %d loot each) for defender %s",
			#layout,
			totalExtractors,
			lootPerExtractor,
			tostring(snapshot.defenderName)
		)
	)
end

-- Weapon-hit handler. Registered on WeaponService in the raid bootstrap.
function RaidBaseRenderer.DamageStructure(_player: Player, part: BasePart, damage: number)
	local base = active
	if not base then
		return
	end
	if part:GetAttribute("RaidStructure") ~= true then
		return
	end
	local hp = part:GetAttribute("CurrentHp")
	if typeof(hp) ~= "number" or hp <= 0 then
		return
	end
	hp = math.max(0, hp - damage)
	part:SetAttribute("CurrentHp", hp)
	if hp > 0 then
		return
	end

	-- Destroyed.
	base.structuresDestroyed += 1
	if part:GetAttribute("RaidExtractor") == true then
		base.extracted += base.lootPerExtractor
		base.extractorsDown += 1
	end
	part:Destroy()
end

function RaidBaseRenderer.PositionAttacker(player: Player)
	local character = player.Character or player.CharacterAdded:Wait()
	local hrp = character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not hrp then
		return
	end
	local origin = Constants.RAID.RaidArenaOrigin
	local spawnPos = origin + Vector3.new(0, 4, -Constants.RAID.RaidAttackerSpawnOffset)
	hrp.CFrame = CFrame.lookAt(spawnPos, origin + Vector3.new(0, 4, 0))
end

function RaidBaseRenderer.GetExtracted(): number
	return if active then active.extracted else 0
end

function RaidBaseRenderer.GetStructuresDestroyed(): number
	return if active then active.structuresDestroyed else 0
end

function RaidBaseRenderer.GetTotalExtractors(): number
	return if active then active.totalExtractors else 0
end

function RaidBaseRenderer.GetExtractorsDown(): number
	return if active then active.extractorsDown else 0
end

-- R2b: the snapshot's surviving turrets shoot the attacker. Runs until the
-- base is cleaned up or the attacker leaves/dies. Turrets the attacker has
-- already destroyed (removed from the folder / 0 HP) stop firing. This makes
-- a well-defended base a real threat instead of a shooting gallery.
function RaidBaseRenderer.StartDefense(attacker: Player)
	local base = active
	if not base then
		return
	end
	base.defending = true
	task.spawn(function()
		local lastFire: { [BasePart]: number } = {}
		while active == base and base.defending do
			local character = attacker.Character
			local humanoid = if character then character:FindFirstChildOfClass("Humanoid") else nil
			local hrp = if character then character:FindFirstChild("HumanoidRootPart") else nil
			if humanoid and humanoid.Health > 0 and hrp and hrp:IsA("BasePart") then
				local now = os.clock()
				for _, turret in base.turrets do
					local hp = turret:GetAttribute("CurrentHp")
					if turret.Parent and typeof(hp) == "number" and hp > 0 then
						local dist = (turret.Position - hrp.Position).Magnitude
						if dist <= Constants.COMBAT.TurretRange then
							if now - (lastFire[turret] or 0) >= Constants.COMBAT.TurretFireSeconds then
								lastFire[turret] = now
								DamageService.ApplyToHumanoid(
									humanoid,
									Constants.COMBAT.TurretDamage,
									"raid_turret"
								)
								BeamPool.Acquire(turret.Position + Vector3.new(0, 2, 0), hrp.Position, TURRET_BEAM_COLOR)
							end
						end
					end
				end
			end
			task.wait(Constants.COMBAT.TurretTickSeconds)
		end
	end)
end

function RaidBaseRenderer.Cleanup()
	if active then
		active.defending = false
		active.folder:Destroy()
		active = nil
	end
end

return RaidBaseRenderer
