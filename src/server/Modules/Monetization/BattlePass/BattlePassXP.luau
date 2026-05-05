--!strict
--[[
	Outpost-7 — Battle Pass XP grant rules.

	Phase D4. Subscribes to the global QuestObjectives event bus and
	translates whitelisted events into XP grants via
	BattlePassService.GrantXP.

	The bus already carries the events we need:
	  - quest_claimed (emitted by DailyQuestManager.TryClaim)
	  - claim_daily   (emitted by DailyLoginManager.TryClaim)
	  - Phase E will add raid_won and wave_survived

	Per-event XP amounts live in `Constants.BATTLE_PASS.XpRewards` so
	tuning is a single-file edit. An event without an entry is
	ignored (prevents accidental double-grant if the same event drives
	both quest progress and BP XP — quests use the source amount,
	BP uses the table's value).

	Rate-of-change: at 1000 XP per tier and ~100 XP per claimed quest,
	a player completing all 3 daily quests + daily login = 325 XP/day.
	30-tier season ≈ ~92 days at base rate. Premium (and Phase E
	raid/wave events) accelerates progression to ~30 days for active
	players. Tunable in Phase G after playtest.
--]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Constants = require(Shared:WaitForChild("Constants"))

local QuestObjectives = require(script.Parent.Parent.Parent.Retention.QuestObjectives)
local BattlePassService = require(script.Parent.BattlePassService)

local BattlePassXP = {}

local function xpFor(event: string): number
	local explicit = Constants.BATTLE_PASS.XpRewards[event]
	if typeof(explicit) ~= "number" then
		return 0
	end
	return explicit
end

function BattlePassXP.Init()
	QuestObjectives.OnEmit(function(event, player, amount)
		local perEvent = xpFor(event)
		if perEvent <= 0 then
			return
		end
		-- amount = 1 for count-based events (quest_claimed, claim_daily),
		-- so XP = perEvent. For sum-based events (spend_credits etc.)
		-- we currently don't grant XP, but the structure supports
		-- weighting if Phase G wants spend → BP XP.
		BattlePassService.GrantXP(player, perEvent * amount)
	end)
end

return BattlePassXP
