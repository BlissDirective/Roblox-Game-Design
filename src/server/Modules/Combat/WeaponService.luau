--!strict
--[[
	Outpost-7 — player weapon (server-authoritative hitscan rifle).

	Phase R3. Closes audit §4.3: the first-person combat camera existed but
	the player had no way to deal damage — turrets and drones did all the
	fighting. This gives the operator one rifle that works in PvE defense now
	and in R2 raids later (same service, same validation).

	Trust model (the whole point):
	  - The client sends ONLY an aim direction (its camera LookVector). It
	    never sends an origin or a hit result.
	  - The server raycasts from the player's OWN character head/root position
	    — a position the server already knows and the client cannot forge.
	  - Rate limiting (token bucket) + a hard per-player cooldown bound the
	    fire rate regardless of how fast the client spams the Remote.
	  - Only non-player Humanoids (aliens) take damage, so a player shooting
	    across their own base can't harm their own structures in PvE. (Raid
	    structure damage is R2, gated by the raid context, not this path.)

	The tracer is drawn server-side via BeamPool so every client sees the
	same shot (and it reuses the F3 pool — no per-shot Instance.new).

	Public API:
	  Init()  — wire the FireWeapon Remote + PlayerRemoving cleanup
--]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Constants = require(Shared:WaitForChild("Constants"))
local Remotes = require(Shared:WaitForChild("Remotes"))

local DamageService = require(script.Parent.DamageService)
local BeamPool = require(script.Parent.BeamPool)
local AntiExploit = require(script.Parent.Parent.Security.AntiExploit)
local AuditLog = require(script.Parent.Parent.Security.AuditLog)

local WeaponService = {}

-- Cool blue-white tracer, distinct from the turret/drone beams.
local BEAM_COLOR = Color3.fromRGB(140, 220, 255)

-- Per-player hard cooldown clock (os.clock). Backs the rate-limit bucket so
-- burst allowance can't translate into a faster-than-designed fire rate.
local lastFireAt: { [Player]: number } = {}

-- Optional structure-hit handler. Registered by the raid place (R2) so a
-- weapon shot that lands on a rendered defender structure deals damage to
-- it. In the main place no handler is set, so the weapon never damages
-- structures (you can't shoot your own base apart in PvE). Signature:
-- (player, hitPart, damage) -> ().
local structureHitHandler: ((Player, BasePart, number) -> ())? = nil

function WeaponService.SetStructureHitHandler(handler: (Player, BasePart, number) -> ())
	structureHitHandler = handler
end

local function originFor(character: Model): BasePart?
	local head = character:FindFirstChild("Head")
	if head and head:IsA("BasePart") then
		return head
	end
	local root = character:FindFirstChild("HumanoidRootPart")
	if root and root:IsA("BasePart") then
		return root
	end
	return nil
end

local function onFire(player: Player, direction: any)
	-- F1 token-bucket rate limit.
	if not AntiExploit.RateCheck(player, "FireWeapon") then
		AuditLog.Record(player, "rate_limited", "FireWeapon")
		return
	end
	-- Wire-shape validation: a Vector3 of roughly unit length.
	if typeof(direction) ~= "Vector3" then
		AuditLog.Record(player, "validation_failed", "FireWeapon: direction not a Vector3")
		return
	end
	local magnitude = direction.Magnitude
	if
		magnitude < Constants.COMBAT.WeaponDirMinMagnitude
		or magnitude > Constants.COMBAT.WeaponDirMaxMagnitude
	then
		AuditLog.Record(player, "validation_failed", "FireWeapon: direction magnitude out of range")
		return
	end

	-- Hard per-player cooldown (server clock — never trusts client timing).
	local now = os.clock()
	local last = lastFireAt[player]
	if last and now - last < Constants.COMBAT.WeaponFireCooldownSeconds then
		return
	end
	lastFireAt[player] = now

	local character = player.Character
	if not character then
		return
	end
	local originPart = originFor(character)
	if not originPart then
		return
	end
	local origin = originPart.Position
	local dir = direction.Unit

	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { character }
	local result = Workspace:Raycast(origin, dir * Constants.COMBAT.WeaponRange, params)

	local hitPoint = if result then result.Position else origin + dir * Constants.COMBAT.WeaponRange

	if result and result.Instance then
		local hitPart = result.Instance
		local model = hitPart:FindFirstAncestorOfClass("Model")
		local humanoid = if model then model:FindFirstChildOfClass("Humanoid") else nil
		if humanoid and humanoid.Health > 0 and not Players:GetPlayerFromCharacter(model :: Model) then
			-- Damage only living, non-player Humanoids (aliens).
			DamageService.ApplyToHumanoid(humanoid, Constants.COMBAT.WeaponDamage, "player_weapon")
		elseif structureHitHandler and hitPart:GetAttribute("MaxHp") ~= nil then
			-- Raid context: the shot hit a rendered defender structure.
			structureHitHandler(player, hitPart, Constants.COMBAT.WeaponDamage)
		end
	end

	-- Server-drawn tracer (all clients see it; pooled per F3).
	BeamPool.Acquire(origin, hitPoint, BEAM_COLOR)
end

function WeaponService.Init()
	local remote = Remotes.FireWeapon :: RemoteEvent
	remote.OnServerEvent:Connect(onFire)

	Players.PlayerRemoving:Connect(function(player)
		lastFireAt[player] = nil
	end)
end

return WeaponService
