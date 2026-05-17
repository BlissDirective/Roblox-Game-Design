--!strict
--[[
	Outpost-7 — leaderboards (global Credits + weekly raid wins).

	Phase E5. Two boards backed by `OrderedDataStore` per ADR-010:
	  - **Global Credits** — single perpetual store
	    (`Outpost_GlobalCredits_v1`); player's lifetime max credits
	    held. Pushed every `ScorePushIntervalSeconds` (60s) per online
	    player; reads top-N every `ReadCacheTtlSeconds` (5 min).
	  - **Weekly Raid Wins** — one store per ISO-week bucket
	    (`Outpost_RaidWins_v1_<isoYear>W<isoWeek>`). Resets implicitly
	    every Monday 00:00 UTC by switching to the next bucket. The
	    previous week's store stays read-only and addressable for
	    "last week's winners" displays.

	Trust boundary: scores are pulled from the player's profile
	(`profile.Data.credits` / `profile.Data.raidWins`) — never from a
	client Remote. The OrderedDataStore mirror is read-only from the
	client's perspective.

	Cross-server consistency: every home server pushes its own online
	players. A player who's been online on server A then logs off,
	then online on server B will have the latest score reflect server
	B's view. Acceptable for V1 — leaderboard freshness within a few
	minutes is fine.

	Public API:
	  Init                    — wires push + read loops + Remote push
	  GetCachedBoards()       — non-yielding read of top-N per board
	  PushStateToPlayer(p)    — fires LeaderboardState Remote to player
--]]

local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Constants = require(Shared:WaitForChild("Constants"))
local Remotes = require(Shared:WaitForChild("Remotes"))

local DataManager = require(script.Parent.Parent.Player.DataManager)

local LeaderboardService = {}

export type Entry = {
	userId: number,
	score: number,
	-- Display name resolved at read time via Players:GetNameFromUserIdAsync,
	-- cached per-server. May be nil if the lookup hasn't completed yet.
	name: string?,
}

export type Board = {
	id: string,
	displayName: string,
	bucket: string?, -- e.g. "2026W18" for weekly; nil for global
	entries: { Entry },
	fetchedAt: number,
}

export type BoardsState = {
	globalCredits: Board,
	weeklyRaidWins: Board,
}

-- Module-level state.
local globalCreditsStore: OrderedDataStore
local cachedBoards: BoardsState
local nameCache: { [number]: string } = {}

-- ISO 8601 week calculation. Roblox `os.date` doesn't expose ISO week,
-- so derive from the day-of-year + day-of-week:
-- Per ISO: week 1 contains the first Thursday of the year.
local function isoWeek(t: number): (number, number)
	-- Returns (isoYear, isoWeek). Algorithm: shift the timestamp by
	-- 3 days so the start of ISO-year falls on Mon. Then compute
	-- year-week from the shifted date.
	local d = os.date("!*t", t) :: any
	-- ISO weekday: Mon=1..Sun=7
	local isoWday = if d.wday == 1 then 7 else d.wday - 1
	-- Shift to Thursday of the same ISO week.
	local thursdayTs = t + (4 - isoWday) * 86400
	local thursday = os.date("!*t", thursdayTs) :: any
	local isoYear = thursday.year
	-- Day-of-year for that Thursday gives the ISO week.
	local thursdayDoY = thursday.yday
	local week = math.ceil(thursdayDoY / 7)
	return isoYear, week
end

local function weeklyStoreName(t: number): (string, string)
	local y, w = isoWeek(t)
	local bucket = string.format("%dW%02d", y, w)
	local store = string.format("%s_%s", Constants.LEADERBOARD.WeeklyRaidWinsStorePrefix, bucket)
	return store, bucket
end

local function getNameForUserId(userId: number): string?
	if nameCache[userId] then
		return nameCache[userId]
	end
	-- Try local players first (no DataStore call needed).
	local local_ = Players:GetPlayerByUserId(userId)
	if local_ then
		nameCache[userId] = local_.Name
		return local_.Name
	end
	-- Fall back to GetNameFromUserIdAsync — yielding, pcall-wrapped.
	local ok, name = pcall(function()
		return Players:GetNameFromUserIdAsync(userId)
	end)
	if ok and typeof(name) == "string" then
		nameCache[userId] = name
		return name
	end
	return nil
end

local function emptyBoard(id: string, displayName: string, bucket: string?): Board
	return {
		id = id,
		displayName = displayName,
		bucket = bucket,
		entries = {},
		fetchedAt = 0,
	}
end

local function readTopN(store: OrderedDataStore, count: number): { Entry }
	local out: { Entry } = {}
	local ok, pages = pcall(function()
		return store:GetSortedAsync(false, count)
	end)
	if not ok or not pages then
		return out
	end
	local okPage, page = pcall(function()
		return pages:GetCurrentPage()
	end)
	if not okPage or typeof(page) ~= "table" then
		return out
	end
	for _, entry in page do
		local userId = tonumber(entry.key)
		local score = tonumber(entry.value)
		if userId and score then
			table.insert(out, {
				userId = userId,
				score = score,
				name = getNameForUserId(userId),
			})
		end
	end
	return out
end

local function pushScoreFor(player: Player)
	local data = DataManager.GetData(player)
	if not data then
		return
	end
	-- Global Credits — best-of-current. OrderedDataStore stores integers.
	local credits = math.floor(data.credits)
	if credits > 0 then
		pcall(function()
			globalCreditsStore:SetAsync(tostring(player.UserId), credits)
		end)
	end
	-- Weekly raid wins — current week's bucket only.
	local wins = math.floor(data.raidWins)
	if wins > 0 then
		local storeName = weeklyStoreName(os.time())
		local weekly = DataStoreService:GetOrderedDataStore(storeName)
		pcall(function()
			weekly:SetAsync(tostring(player.UserId), wins)
		end)
	end
end

local function refreshBoards()
	local now = os.time()
	local _, weekBucket = weeklyStoreName(now)
	local weeklyName = weeklyStoreName(now)
	local weeklyStore = DataStoreService:GetOrderedDataStore(weeklyName)

	local globalEntries = readTopN(globalCreditsStore, Constants.LEADERBOARD.TopN)
	local weeklyEntries = readTopN(weeklyStore, Constants.LEADERBOARD.TopN)

	cachedBoards = {
		globalCredits = {
			id = "globalCredits",
			displayName = "Global Credits",
			bucket = nil,
			entries = globalEntries,
			fetchedAt = now,
		},
		weeklyRaidWins = {
			id = "weeklyRaidWins",
			displayName = "Weekly Raid Wins",
			bucket = weekBucket,
			entries = weeklyEntries,
			fetchedAt = now,
		},
	}
end

function LeaderboardService.GetCachedBoards(): BoardsState
	return cachedBoards
end

function LeaderboardService.PushStateToPlayer(player: Player)
	local remote = Remotes.LeaderboardState :: RemoteEvent
	remote:FireClient(player, cachedBoards)
end

local function pushAllPlayers()
	for _, player in Players:GetPlayers() do
		LeaderboardService.PushStateToPlayer(player)
	end
end

local function pushLoop()
	while true do
		task.wait(Constants.LEADERBOARD.ScorePushIntervalSeconds)
		for _, player in Players:GetPlayers() do
			pushScoreFor(player)
		end
	end
end

local function readLoop()
	while true do
		task.wait(Constants.LEADERBOARD.ReadCacheTtlSeconds)
		refreshBoards()
		pushAllPlayers()
	end
end

function LeaderboardService.Init()
	globalCreditsStore = DataStoreService:GetOrderedDataStore(Constants.LEADERBOARD.GlobalCreditsStoreName)

	-- Initial empty boards so PushStateToPlayer never sends nil.
	local _, initialBucket = weeklyStoreName(os.time())
	cachedBoards = {
		globalCredits = emptyBoard("globalCredits", "Global Credits", nil),
		weeklyRaidWins = emptyBoard("weeklyRaidWins", "Weekly Raid Wins", initialBucket),
	}

	-- Initial fetch (yielding) before pushing to clients.
	task.spawn(function()
		refreshBoards()
		for _, player in Players:GetPlayers() do
			LeaderboardService.PushStateToPlayer(player)
		end
	end)

	Players.PlayerAdded:Connect(function(player)
		task.spawn(function()
			DataManager.WaitForData(player)
			-- Push current cached boards immediately; the next cache
			-- refresh will re-fire to all clients.
			if player:IsDescendantOf(Players) then
				LeaderboardService.PushStateToPlayer(player)
			end
		end)
	end)
	Players.PlayerRemoving:Connect(function(player)
		-- Final score push so the leaderboard reflects this session's
		-- gains immediately (rather than waiting for the next pushLoop tick).
		task.spawn(function()
			pushScoreFor(player)
		end)
	end)

	task.spawn(pushLoop)
	task.spawn(readLoop)
end

return LeaderboardService
