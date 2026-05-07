--!strict
--[[
	Outpost-7 — auto-targeting turret service.

	Phase E2.5. The first offensive option for the player. Turrets
	register on placement (via PlacementService → RegisterTurret),
	tick at `Constants.COMBAT.TurretTickSeconds`, and fire at the
	nearest alien within `TurretRange` whose Humanoid has Health > 0.
	Damage routes through `DamageService.ApplyToHumanoid` for the
	chokepoint invariant.

	V1 (E2.5) ships invincible turrets — aliens can't damage them.
	Phase G adds turret HP, alien priority targeting (turret > player
	when in range), and a turret-destroyed signal so the player has
	to actually defend their perimeter. For E2.5 this is fine: the
	gameplay loop becomes "place turrets in good positions, watch
	them shoot aliens, hope you placed enough."

	Visuals: brief red Part beam (0.1s lifetime) between turret muzzle
	and alien position via `BeamPool.Acquire` (F3 — pooled to avoid
	per-shot `Instance.new`). Phase G replaces with proper Beam +
	projectile VFX.

	Public API:
	  Init                        — wires PlayerRemoving cleanup +
	                                tick loop
	  RegisterTurret(player, part) — register a placed turret
	  UnregisterTurret(part)      — remove from the active set
	  GetTurretsForPlayer(player) — non-yielding read; returns the
	                                count of active turrets
--]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Constants = require(Shared:WaitForChild("Constants"))

local DataManager = require(script.Parent.Parent.Player.DataManager)
local DamageService = require(script.Parent.DamageService)
local BeamPool = require(script.Parent.BeamPool)

local TurretService = {}

type Turret = {
	part: BasePart,
	ownerUserId: number,
	lastFireAt: number,
}

-- Active turret registry. Keyed by Part instance for O(1) unregister.
local turrets: { [BasePart]: Turret } = {}

local ACTORS_FOLDER_NAME = "AlienActors"

local function getActorsFolder(): Folder?
	local folder = Workspace:FindFirstChild(ACTORS_FOLDER_NAME)
	if folder and folder:IsA("Folder") then
		return folder
	end
	return nil
end

local function findNearestAlien(turretPos: Vector3, range: number): (BasePart?, Humanoid?)
	local actorsFolder = getActorsFolder()
	if not actorsFolder then
		return nil, nil
	end
	local rangeSq = range * range
	local nearestRoot: BasePart? = nil
	local nearestHumanoid: Humanoid? = nil
	local nearestDistSq = rangeSq
	for _, model in actorsFolder:GetChildren() do
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
		local distSq = (root.Position - turretPos).Magnitude ^ 2
		if distSq <= nearestDistSq then
			nearestDistSq = distSq
			nearestRoot = root
			nearestHumanoid = humanoid
		end
	end
	return nearestRoot, nearestHumanoid
end

-- F3: BeamPool replaces the per-shot Instance.new("Part") + Debris:AddItem
-- pattern. Same visual; pooled lifecycle.
local TURRET_BEAM_COLOR = Color3.fromRGB(255, 80, 80)

local function fireTurret(turret: Turret, alienRoot: BasePart, alienHumanoid: Humanoid)
	local now = os.clock()
	if now - turret.lastFireAt < Constants.COMBAT.TurretFireSeconds then
		return
	end
	turret.lastFireAt = now

	local hpBefore = alienHumanoid.Health
	DamageService.ApplyToHumanoid(alienHumanoid, Constants.COMBAT.TurretDamage, "turret_raycast")
	local hpAfter = alienHumanoid.Health

	-- Muzzle origin: turret top center; target: alien root.
	local muzzle = turret.part.Position + Vector3.new(0, turret.part.Size.Y / 2, 0)
	BeamPool.Acquire(muzzle, alienRoot.Position, TURRET_BEAM_COLOR)

	-- Kill credit: only the shot that drops HP to 0 counts.
	if hpBefore > 0 and hpAfter <= 0 then
		local owner = Players:GetPlayerByUserId(turret.ownerUserId)
		if owner then
			local data = DataManager.GetData(owner)
			if data then
				data.turretsKilled += 1
			end
		end
	end
end

function TurretService.RegisterTurret(player: Player, part: BasePart)
	turrets[part] = {
		part = part,
		ownerUserId = player.UserId,
		lastFireAt = 0,
	}
end

function TurretService.UnregisterTurret(part: BasePart)
	turrets[part] = nil
end

function TurretService.GetTurretsForPlayer(player: Player): number
	local count = 0
	for _, t in turrets do
		if t.ownerUserId == player.UserId then
			count += 1
		end
	end
	return count
end

local function tickAllTurrets()
	for part, turret in turrets do
		-- Defensive: turret was Destroyed externally without unregister.
		if not part.Parent then
			turrets[part] = nil
			continue
		end
		local _alienRoot, alienHumanoid = findNearestAlien(part.Position, Constants.COMBAT.TurretRange)
		if alienHumanoid and _alienRoot then
			fireTurret(turret, _alienRoot, alienHumanoid)
		end
	end
end

function TurretService.Init()
	-- Cleanup turrets owned by departing players. The Parts may persist
	-- (the plot itself is wiped via PlotManager.release; turret Parts
	-- ride that wipe), but in case a player leaves before plot release
	-- runs, drop registry entries proactively.
	Players.PlayerRemoving:Connect(function(player)
		for part, turret in turrets do
			if turret.ownerUserId == player.UserId then
				turrets[part] = nil
			end
		end
	end)

	task.spawn(function()
		while true do
			task.wait(Constants.COMBAT.TurretTickSeconds)
			tickAllTurrets()
		end
	end)
end

return TurretService
