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

local DamageService = require(script.Parent.DamageService)
local AlienPool = require(script.Parent.AlienPool)

type ActiveAlien = AlienPool.ActiveAlien

local AlienAI = {}

export type Controller = {
	Stop: (self: any) -> (),
	IsAlive: (self: any) -> boolean,
}

local MOVE_TICK_HZ = 1

local function getTargetCharacter(alien: ActiveAlien): Model?
	local userId = alien.targetUserId
	if not userId then
		return nil
	end
	local player = Players:GetPlayerByUserId(userId)
	if not player or not player.Character then
		return nil
	end
	return player.Character
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

	-- Movement path: 1Hz steering.
	local moveAccumulator = 0
	local heartbeat = RunService.Heartbeat:Connect(function(dt: number)
		if stopped or alien.humanoid.Health <= 0 then
			return
		end
		moveAccumulator += dt
		if moveAccumulator < (1 / MOVE_TICK_HZ) then
			return
		end
		moveAccumulator = 0
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
