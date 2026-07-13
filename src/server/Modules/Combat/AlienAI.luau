--!strict
--[[
	Outpost-7 — alien behavior: pursue + melee.

	Phase E2. V1 ships the simplest possible AI: every Heartbeat tick,
	steer the alien toward the target player's HumanoidRootPart and
	melee on contact. No pathfinding (line-of-sight only) — the V1
	plot is a flat 64×64 square so straight-line approach is correct
	enough. Phase G upgrades to PathfindingService when biomes get real
	terrain.

	Movement: Humanoid:MoveTo is called once per second to dodge the
	"MoveTo timeout" (Roblox auto-cancels MoveTo after 8s without
	completion). Throttling at 1Hz instead of every Heartbeat avoids
	the per-frame replication cost.

	Damage: a per-Touched signal fires DamageService.ApplyToHumanoid on
	contact, gated by `lastMeleeAt + def.meleeCooldown < now` to prevent
	"frame-perfect spam" damage.

	Lifetime: the alien is "active" until its Humanoid.Health <= 0 OR
	the WaveDirector calls `Kill` (timer expiry / wave end). On death,
	WaveDirector releases it back to the pool.

	Public API:
	  Drive(alien, getTargetPosition) — returns a controller handle the
	                                    wave director can call :Stop()
	                                    on
--]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Constants = require(Shared:WaitForChild("Constants"))

local DamageService = require(script.Parent.DamageService)
local AlienPool = require(script.Parent.AlienPool)
local StructureHealthService = require(script.Parent.StructureHealthService)
local PlotManager = require(script.Parent.Parent.World.PlotManager)

type ActiveAlien = AlienPool.ActiveAlien

local AlienAI = {}

export type Controller = {
	Stop: (self: any) -> (),
	IsAlive: (self: any) -> boolean,
}

local MOVE_TICK_HZ = 1

local function getTargetPlayer(alien: ActiveAlien): Player?
	local userId = alien.targetUserId
	if not userId then
		return nil
	end
	return Players:GetPlayerByUserId(userId)
end

local function getTargetCharacter(alien: ActiveAlien): Model?
	local player = getTargetPlayer(alien)
	if not player or not player.Character then
		return nil
	end
	return player.Character
end

-- R1: gather the target player's damageable structures and return the one
-- nearest the alien plus its distance. Aliens march on structures (the base)
-- rather than straight at the player, so walls/turrets actually matter. Only
-- parts StructureHealthService is tracking (has HP, not yet destroyed) count.
local function nearestStructure(alien: ActiveAlien): (BasePart?, number)
	local player = getTargetPlayer(alien)
	if not player then
		return nil, math.huge
	end
	local plot = PlotManager.GetPlot(player)
	if not plot then
		return nil, math.huge
	end
	local origin = alien.root.Position
	local best: BasePart? = nil
	local bestDist = math.huge
	for _, child in plot.buildings:GetChildren() do
		if not child:IsA("BasePart") then
			continue
		end
		if not StructureHealthService.IsDamageable(child) then
			continue
		end
		-- Skip downed structures (a disabled extractor sits at 0 HP but
		-- stays in the world until repaired) so aliens advance past it to
		-- the next live target instead of piling on a corpse.
		if StructureHealthService.GetHp(child) <= 0 then
			continue
		end
		local dist = (child.Position - origin).Magnitude
		if dist < bestDist then
			best = child
			bestDist = dist
		end
	end
	return best, bestDist
end

function AlienAI.Drive(alien: ActiveAlien): Controller
	local connections: { RBXScriptConnection } = {}
	local stopped = false

	local function disconnectAll()
		for _, c in connections do
			c:Disconnect()
		end
		connections = {}
	end

	-- Damage path: alien-touches-player melee.
	local touched = alien.root.Touched:Connect(function(other: BasePart)
		if stopped or alien.humanoid.Health <= 0 then
			return
		end
		local model = other:FindFirstAncestorOfClass("Model")
		if not model then
			return
		end
		local victim = Players:GetPlayerFromCharacter(model)
		if not victim then
			return
		end
		-- Only damage the alien's current target. Prevents friendly-fire-
		-- on-bystanders if the alien path crosses a different player.
		if alien.targetUserId and victim.UserId ~= alien.targetUserId then
			return
		end
		local now = os.clock()
		if now - alien.lastMeleeAt < alien.def.meleeCooldown then
			return
		end
		alien.lastMeleeAt = now
		local victimHumanoid = model:FindFirstChildOfClass("Humanoid")
		if victimHumanoid then
			DamageService.ApplyToHumanoid(victimHumanoid, alien.def.meleeDamage, "alien_melee")
		end
	end)
	table.insert(connections, touched)

	-- Movement + structure-attack path: 1Hz steering. R1 behavior:
	--   1. If a damageable structure is within AlienStructureAttackRange,
	--      stop and chew it (breach fantasy) on a per-alien cooldown.
	--   2. Otherwise march toward the nearest structure (walls/turrets/
	--      extractors) — the swarm assaults the base, not just the player.
	--   3. If the base has no structures left, fall back to hunting the
	--      player directly (pre-R1 behavior). The player-melee Touched
	--      path above still handles damage when the alien reaches them.
	local moveAccumulator = 0
	local lastStructureHitAt = 0
	local heartbeat = RunService.Heartbeat:Connect(function(dt: number)
		if stopped or alien.humanoid.Health <= 0 then
			return
		end
		moveAccumulator += dt
		if moveAccumulator < (1 / MOVE_TICK_HZ) then
			return
		end
		moveAccumulator = 0

		local structure, structureDist = nearestStructure(alien)
		if structure and structureDist <= Constants.COMBAT.AlienStructureAttackRange then
			-- In range of a structure — attack it instead of walking past.
			local now = os.clock()
			if now - lastStructureHitAt >= Constants.COMBAT.AlienStructureAttackCooldownSeconds then
				lastStructureHitAt = now
				StructureHealthService.Damage(structure, Constants.COMBAT.AlienStructureDamage, "alien_melee")
			end
			-- Hold position at the structure (MoveTo its base keeps the
			-- alien pressed against the wall rather than clipping through).
			alien.humanoid:MoveTo(structure.Position)
			return
		end

		if structure and Constants.COMBAT.AliensPreferBlockingStructures then
			-- March on the base.
			alien.humanoid:MoveTo(structure.Position)
			return
		end

		-- No structures left (or the alien has broken through) — hunt the
		-- player directly.
		local targetCharacter = getTargetCharacter(alien)
		if not targetCharacter then
			return
		end
		local targetRoot = targetCharacter:FindFirstChild("HumanoidRootPart")
		if targetRoot and targetRoot:IsA("BasePart") then
			alien.humanoid:MoveTo(targetRoot.Position)
		end
	end)
	table.insert(connections, heartbeat)

	local controller = {} :: any
	function controller:Stop()
		stopped = true
		disconnectAll()
	end
	function controller:IsAlive(): boolean
		return not stopped and alien.humanoid.Health > 0
	end
	return controller
end

return AlienAI
