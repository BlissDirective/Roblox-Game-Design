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

local Constants = require(Shared:WaitForChild("Constants"))

local BattlePassService = require(script.Parent.BattlePassService)
local AntiExploit = require(script.Parent.Parent.Parent.Security.AntiExploit)
local AuditLog = require(script.Parent.Parent.Parent.Security.AuditLog)
local RemoteValidator = require(script.Parent.Parent.Parent.Security.RemoteValidator)

local ClaimService = {}

function ClaimService.Init()
	local remote = Remotes.ClaimBattlePassTier :: RemoteFunction
	remote.OnServerInvoke = function(player: Player, tier: any, track: any)
		if not AntiExploit.RateCheck(player, "ClaimBattlePassTier") then
			AuditLog.Record(player, "rate_limited", "ClaimBattlePassTier")
			return { ok = false, error = "rate-limited" }
		end
		-- F2 central validation: tier integer in MaxTier range; track enum.
		local tierOk, tierValue = RemoteValidator.IsInteger(tier, 1, Constants.BATTLE_PASS.MaxTier)
		if not tierOk then
			AuditLog.Record(player, "validation_failed", "ClaimBattlePassTier: tier invalid")
			return { ok = false, error = "invalid tier" }
		end
		local trackOk = RemoteValidator.IsOption(track, { "free", "premium" })
		if not trackOk then
			AuditLog.Record(player, "validation_failed", "ClaimBattlePassTier: track invalid")
			return { ok = false, error = "invalid track" }
		end
		return BattlePassService.TryClaim(player, tierValue :: number, track)
	end
end

return ClaimService
