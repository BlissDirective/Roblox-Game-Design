--!strict
--[[
	Outpost-7 — Battle Pass tier claim Remote handler.

	Phase D4. Wires `Remotes.ClaimBattlePassTier` (RemoteFunction) to
	`BattlePassService.TryClaim`. The handler is intentionally thin:
	type-check the args server-side, route to TryClaim, return the
	Result. All validation (tier reached, track gate, already-claimed
	guard) lives in BattlePassService.

	Args from client: `(tier: number, track: "free" | "premium")`.
	Result: `BattlePassService.ClaimResult`.
--]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Remotes = require(Shared:WaitForChild("Remotes"))

local BattlePassService = require(script.Parent.BattlePassService)
local AntiExploit = require(script.Parent.Parent.Parent.Security.AntiExploit)

local ClaimService = {}

function ClaimService.Init()
	local remote = Remotes.ClaimBattlePassTier :: RemoteFunction
	remote.OnServerInvoke = function(player: Player, tier: any, track: any)
		-- F1 token-bucket rate limit.
		if not AntiExploit.RateCheck(player, "ClaimBattlePassTier") then
			return { ok = false, error = "rate-limited" }
		end
		if typeof(tier) ~= "number" then
			return { ok = false, error = "invalid tier" }
		end
		if track ~= "free" and track ~= "premium" then
			return { ok = false, error = "invalid track" }
		end
		return BattlePassService.TryClaim(player, tier, track)
	end
end

return ClaimService
