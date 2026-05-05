--!strict
--[[
	Outpost-7 — Game Pass effect composition.

	Phase D3. Subscribes to `GamePassService.OnOwnershipChanged`,
	composes the income multiplier from owned passes, and writes
	the result via `CurrencyService.SetMultiplier`.

	Composition is **multiplicative across owned passes** that have
	a `multiplier` field in `Constants.MONETIZATION.GamePasses`:

	    DoubleCredits.multiplier = 2.0
	    AutoCollect.multiplier   = 1.5
	    VipOperator              — no multiplier (effect is +1
	                               quest slot, handled in
	                               DailyQuestManager directly)

	Maxmum stack: DoubleCredits (×2.0) × AutoCollect (×1.5) = ×3.0.
	`CurrencyService.SetMultiplier` clamps to (0, 10] defensively
	so even a future buggy 6-pass stack can't push us past the cap.

	Pass effects beyond the multiplier (VIP's +1 quest slot, future
	cosmetic skins) are owned by the systems they affect — those
	systems subscribe to `GamePassService.OnOwnershipChanged`
	independently. PassEffects is the single chokepoint for income
	multipliers only.

	Public API:
	  RecomputeFor(player) — recompute and apply multiplier
	  Init                 — subscribes; primes once per player on join
--]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Constants = require(Shared:WaitForChild("Constants"))

local CurrencyService = require(script.Parent.Parent.Economy.CurrencyService)
local GamePassService = require(script.Parent.GamePassService)

local PassEffects = {}

local function computeMultiplierFor(player: Player): number
	local total = 1.0
	for key, def in Constants.MONETIZATION.GamePasses do
		local pm = (def :: any).multiplier
		if pm and pm > 0 and GamePassService.Owns(player, key) then
			total *= pm
		end
	end
	return total
end

function PassEffects.RecomputeFor(player: Player)
	local total = computeMultiplierFor(player)
	CurrencyService.SetMultiplier(player, total)
end

function PassEffects.Init()
	-- Recompute on every ownership flip (initial prime fires once
	-- per pass, mid-session purchases fire once with wasPurchased=true).
	GamePassService.OnOwnershipChanged:Connect(function(player, _passKey, _owned)
		PassEffects.RecomputeFor(player)
	end)

	-- Defensive: prime any players already in the server when
	-- PassEffects.Init runs (e.g. after a script reload during dev).
	-- Their ownership cache may already be primed; if not, the
	-- subsequent OnOwnershipChanged events will recompute.
	for _, player in Players:GetPlayers() do
		PassEffects.RecomputeFor(player)
	end
end

return PassEffects
