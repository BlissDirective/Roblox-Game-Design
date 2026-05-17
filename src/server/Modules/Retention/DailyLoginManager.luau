--!strict
--[[
	Outpost-7 — daily login bonus + streak tracking.

	Phase C1. Server-authoritative claim path. All time logic uses
	server `os.time()` — clients never send a date; an exploiter can
	change their system clock all they want and still gets one claim
	per UTC day.

	Streak rules (per finalized-brainstorm.md §2.4):
	  - Last claim today (UTC): no-op (already claimed).
	  - Last claim yesterday (UTC): streak += 1.
	  - Anything older (or no prior claim): streak = 1 (fresh start).
	The "24h grace" the brainstorm mentions is interpreted as the
	one-day-late tolerance built into "last claim was yesterday" —
	a player who logs in on day N+1 still keeps the streak.

	Reward by day from `Constants.RETENTION.DailyRewards`. Days past
	7 default to day-7's value; milestones (14, 30) are explicit.

	Public API:
	  GetState(player)     — { canClaim, nextStreakDay, reward, ... }
	  TryClaim(player)     — Result<{ reward, day }>
	  Init                 — connects PlayerAdded to push the state
	                         Remote on join + handles ClaimDailyReward
	                         invocations
--]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Constants = require(Shared:WaitForChild("Constants"))
local Remotes = require(Shared:WaitForChild("Remotes"))

local DataManager = require(script.Parent.Parent.Player.DataManager)
local CurrencyService = require(script.Parent.Parent.Economy.CurrencyService)
local QuestObjectives = require(script.Parent.QuestObjectives)
local AntiExploit = require(script.Parent.Parent.Security.AntiExploit)
local AuditLog = require(script.Parent.Parent.Security.AuditLog)

local DailyLoginManager = {}

export type State = {
	canClaim: boolean,
	-- The day the player would advance to if they claimed *now*.
	-- For UI: "Day 4 reward: 1500 Credits".
	nextStreakDay: number,
	reward: number,
	-- Already-claimed day (for display when canClaim is false).
	currentStreakDay: number,
}

export type ClaimResult = {
	ok: true,
	reward: number,
	day: number,
} | {
	ok: false,
	error: string,
}

local function utcDateString(t: number): string
	-- "%Y-%m-%d" with the leading "!" forces UTC.
	return os.date("!%Y-%m-%d", t) :: string
end

-- Returns the gap in days between two date strings ("YYYY-MM-DD"),
-- positive when `b` is later than `a`. Negative or 0 if equal/earlier.
local function daysBetween(a: string, b: string): number
	local ay, am, ad = string.match(a, "^(%d+)-(%d+)-(%d+)$")
	local by, bm, bd = string.match(b, "^(%d+)-(%d+)-(%d+)$")
	if not (ay and am and ad and by and bm and bd) then
		return math.huge -- corrupt date string; treat as "long ago"
	end
	-- UTC noon parse anchor avoids any DST edges (UTC has no DST, but
	-- parsing tables differ across Lua builds — this is defensive).
	local at = os.time({
		year = tonumber(ay) :: number,
		month = tonumber(am) :: number,
		day = tonumber(ad) :: number,
		hour = 12,
		min = 0,
		sec = 0,
	})
	local bt = os.time({
		year = tonumber(by) :: number,
		month = tonumber(bm) :: number,
		day = tonumber(bd) :: number,
		hour = 12,
		min = 0,
		sec = 0,
	})
	return math.floor((bt - at) / 86400 + 0.5)
end

local function rewardForDay(day: number): number
	local explicit = Constants.RETENTION.DailyRewards[day]
	if explicit then
		return explicit
	end
	-- Fallback for non-milestone days past day 7.
	return Constants.RETENTION.DailyRewards[7]
end

-- Compute the streak-day a claim NOW would land on, given the saved
-- profile. Returns nil if the player has already claimed today.
local function computeNextStreakDay(data: any): number?
	local today = utcDateString(os.time())
	if data.lastDailyClaim == today then
		return nil
	end
	if not data.lastDailyClaim then
		return 1
	end
	local gap = daysBetween(data.lastDailyClaim, today)
	if gap <= Constants.RETENTION.StreakGraceDays then
		return data.dailyStreak + 1
	end
	return 1 -- streak broken; fresh start
end

function DailyLoginManager.GetState(player: Player): State?
	local data = DataManager.GetData(player)
	if not data then
		return nil
	end
	local nextDay = computeNextStreakDay(data)
	if nextDay then
		return {
			canClaim = true,
			nextStreakDay = nextDay,
			reward = rewardForDay(nextDay),
			currentStreakDay = data.dailyStreak,
		}
	end
	return {
		canClaim = false,
		nextStreakDay = data.dailyStreak,
		reward = rewardForDay(data.dailyStreak),
		currentStreakDay = data.dailyStreak,
	}
end

function DailyLoginManager.TryClaim(player: Player): ClaimResult
	local data = DataManager.GetData(player)
	if not data then
		return { ok = false, error = "no profile" }
	end
	local nextDay = computeNextStreakDay(data)
	if not nextDay then
		return { ok = false, error = "already claimed today" }
	end
	local reward = rewardForDay(nextDay)

	data.dailyStreak = nextDay
	data.lastDailyClaim = utcDateString(os.time())
	CurrencyService.Add(player, reward)

	-- C3: emit for "claim_daily" quest objectives.
	QuestObjectives.Emit("claim_daily", player, 1)

	print(string.format("[DailyLoginManager] %s claimed day %d (+%d credits)", player.Name, nextDay, reward))
	return { ok = true, reward = reward, day = nextDay }
end

local function pushStateToClient(player: Player)
	local state = DailyLoginManager.GetState(player)
	if not state then
		return
	end
	local remote = Remotes.DailyLoginState :: RemoteEvent
	remote:FireClient(player, state)
end

function DailyLoginManager.Init()
	-- Push the initial state once data has loaded.
	Players.PlayerAdded:Connect(function(player)
		task.spawn(function()
			DataManager.WaitForData(player)
			pushStateToClient(player)
		end)
	end)

	-- ClaimDailyReward is a RemoteFunction so the client gets the
	-- result inline (cleaner UX than a paired event).
	local claimRemote = Remotes.ClaimDailyReward :: RemoteFunction
	claimRemote.OnServerInvoke = function(player: Player): ClaimResult
		-- F1: token-bucket rate limit. Server-side semantic limit
		-- (1/UTC-day) is dominant, but the rate check rejects spam
		-- before we even compute eligibility.
		if not AntiExploit.RateCheck(player, "ClaimDailyReward") then
			AuditLog.Record(player, "rate_limited", "ClaimDailyReward")
			return { ok = false, error = "rate-limited" }
		end
		local result = DailyLoginManager.TryClaim(player)
		-- Re-push the state (canClaim now false, currentStreakDay
		-- updated) so the client UI can roll to the "claimed" view.
		pushStateToClient(player)
		return result
	end
end

return DailyLoginManager
