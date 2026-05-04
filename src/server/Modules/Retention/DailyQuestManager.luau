--!strict
--[[
	Outpost-7 — daily quest system.

	Phase C3. 3 quests selected from the V1 pool of 10 per UTC day,
	deterministic so all players on all servers see the same set.
	Reset at 00:00 UTC; lazily applied on the first GetState/TryClaim
	call of a new day, plus a 60s online-rollover poll that pushes
	fresh state to active players.

	Variety > novelty: per finalized-brainstorm.md §4.4, the brainstorm
	calls for ~30 quest variants by V1 launch. C3 ships 10 to validate
	the system; Phase G expands the pool.

	Public API:
	  GetState(player)             — { quests, secondsUntilReset }
	  TryClaim(player, questId)    — Result-style
	  RecordProgress(p, event, n)  — internal (subscribes to QuestObjectives)
	  Init                         — wires Remotes + QuestObjectives + tick
--]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Remotes = require(Shared:WaitForChild("Remotes"))

local DataManager = require(script.Parent.Parent.Player.DataManager)
local ProfileSchema = require(script.Parent.Parent.Player.ProfileSchema)
local CurrencyService = require(script.Parent.Parent.Economy.CurrencyService)
local QuestObjectives = require(script.Parent.QuestObjectives)

type QuestProgress = ProfileSchema.QuestProgress

local DailyQuestManager = {}

export type QuestObjective = {
	event: string,
	target: number,
}

export type Quest = {
	id: string,
	displayName: string,
	description: string,
	objective: QuestObjective,
	rewardCredits: number,
	rewardCores: number,
}

export type QuestView = {
	id: string,
	displayName: string,
	description: string,
	progress: number,
	target: number,
	complete: boolean,
	claimed: boolean,
	rewardCredits: number,
	rewardCores: number,
}

export type State = {
	dateUtc: string,
	secondsUntilReset: number,
	quests: { QuestView },
}

export type ClaimResult = {
	ok: true,
	questId: string,
	rewardCredits: number,
	rewardCores: number,
} | {
	ok: false,
	error: string,
}

local QUEST_POOL: { [string]: Quest } = {
	construction_crew = {
		id = "construction_crew",
		displayName = "Construction Crew",
		description = "Place 3 extractors.",
		objective = { event = "place_extractor", target = 3 },
		rewardCredits = 500,
		rewardCores = 5,
	},
	fortifier = {
		id = "fortifier",
		displayName = "Fortifier",
		description = "Place 5 walls.",
		objective = { event = "place_wall", target = 5 },
		rewardCredits = 400,
		rewardCores = 3,
	},
	builders_dozen = {
		id = "builders_dozen",
		displayName = "Builder's Dozen",
		description = "Place 12 buildings of any kind.",
		objective = { event = "place_any", target = 12 },
		rewardCredits = 1500,
		rewardCores = 10,
	},
	big_spender = {
		id = "big_spender",
		displayName = "Big Spender",
		description = "Spend 1000 Credits.",
		objective = { event = "spend_credits", target = 1000 },
		rewardCredits = 800,
		rewardCores = 5,
	},
	frugal_engineer = {
		id = "frugal_engineer",
		displayName = "Frugal Engineer",
		description = "Spend 500 Credits.",
		objective = { event = "spend_credits", target = 500 },
		rewardCredits = 400,
		rewardCores = 3,
	},
	tycoon_surge = {
		id = "tycoon_surge",
		displayName = "Tycoon Surge",
		description = "Earn 2500 Credits.",
		objective = { event = "earn_credits", target = 2500 },
		rewardCredits = 1500,
		rewardCores = 8,
	},
	smart_shopper = {
		id = "smart_shopper",
		displayName = "Smart Shopper",
		description = "Buy 1 shop item.",
		objective = { event = "buy_shop_item", target = 1 },
		rewardCredits = 600,
		rewardCores = 5,
	},
	bargain_hunter = {
		id = "bargain_hunter",
		displayName = "Bargain Hunter",
		description = "Buy 2 shop items.",
		objective = { event = "buy_shop_item", target = 2 },
		rewardCredits = 1200,
		rewardCores = 10,
	},
	checked_in = {
		id = "checked_in",
		displayName = "Checked In",
		description = "Claim today's daily login.",
		objective = { event = "claim_daily", target = 1 },
		rewardCredits = 200,
		rewardCores = 2,
	},
	time_on_planet = {
		id = "time_on_planet",
		displayName = "Time on Planet",
		description = "Play for 15 minutes.",
		objective = { event = "play_session", target = 15 },
		rewardCredits = 1000,
		rewardCores = 5,
	},
}

local QUESTS_PER_DAY = 3

local function utcDateString(t: number): string
	return os.date("!%Y-%m-%d", t) :: string
end

local function getDaySeed(): number
	-- Stable per UTC day, seed-resistant to floating-point drift.
	return math.floor(os.time() / 86400)
end

local function secondsUntilReset(): number
	local nextBoundary = (getDaySeed() + 1) * 86400
	return nextBoundary - os.time()
end

-- Deterministic Fisher-Yates partial shuffle.
local function selectQuestsForDay(daySeed: number, count: number): { string }
	local rng = Random.new(daySeed)
	local pool: { string } = {}
	for id in QUEST_POOL do
		table.insert(pool, id)
	end
	-- Sort to ensure stable ordering across servers (table iteration
	-- order in Luau isn't guaranteed for string keys).
	table.sort(pool)
	for i = 1, math.min(count, #pool) do
		local j = rng:NextInteger(i, #pool)
		pool[i], pool[j] = pool[j], pool[i]
	end
	local picked: { string } = {}
	for i = 1, math.min(count, #pool) do
		table.insert(picked, pool[i])
	end
	return picked
end

local function ensureFreshDay(data: any)
	local today = utcDateString(os.time())
	if data.lastQuestReset == today then
		return
	end
	-- New day: pick 3 quests, reset progress + claimed flags.
	local ids = selectQuestsForDay(getDaySeed(), QUESTS_PER_DAY)
	local fresh: { [string]: QuestProgress } = {}
	for _, id in ids do
		fresh[id] = { progress = 0, claimed = false }
	end
	data.dailyQuests = fresh
	data.lastQuestReset = today
end

function DailyQuestManager.GetState(player: Player): State?
	local data = DataManager.GetData(player)
	if not data then
		return nil
	end
	ensureFreshDay(data)

	local quests: { QuestView } = {}
	for id, progress in data.dailyQuests do
		local quest = QUEST_POOL[id]
		if not quest then
			-- Quest removed from pool since save; skip silently.
			continue
		end
		table.insert(quests, {
			id = quest.id,
			displayName = quest.displayName,
			description = quest.description,
			progress = math.min(progress.progress, quest.objective.target),
			target = quest.objective.target,
			complete = progress.progress >= quest.objective.target,
			claimed = progress.claimed,
			rewardCredits = quest.rewardCredits,
			rewardCores = quest.rewardCores,
		})
	end
	-- Stable display order by id keeps the panel from reshuffling
	-- between progress pushes.
	table.sort(quests, function(a, b)
		return a.id < b.id
	end)

	return {
		dateUtc = utcDateString(os.time()),
		secondsUntilReset = secondsUntilReset(),
		quests = quests,
	}
end

function DailyQuestManager.TryClaim(player: Player, questId: string): ClaimResult
	local data = DataManager.GetData(player)
	if not data then
		return { ok = false, error = "no profile" }
	end
	ensureFreshDay(data)

	local quest = QUEST_POOL[questId]
	if not quest then
		return { ok = false, error = "unknown quest: " .. tostring(questId) }
	end
	local entry = data.dailyQuests[questId]
	if not entry then
		return { ok = false, error = "quest not active today" }
	end
	if entry.claimed then
		return { ok = false, error = "already claimed" }
	end
	if entry.progress < quest.objective.target then
		return { ok = false, error = "objective incomplete" }
	end

	entry.claimed = true
	if quest.rewardCredits > 0 then
		CurrencyService.Add(player, quest.rewardCredits)
	end
	if quest.rewardCores > 0 then
		CurrencyService.AddCores(player, quest.rewardCores)
	end

	print(
		string.format(
			"[DailyQuestManager] %s claimed %s (+%d credits, +%d cores)",
			player.Name,
			questId,
			quest.rewardCredits,
			quest.rewardCores
		)
	)
	return {
		ok = true,
		questId = questId,
		rewardCredits = quest.rewardCredits,
		rewardCores = quest.rewardCores,
	}
end

local function pushStateToClient(player: Player)
	local state = DailyQuestManager.GetState(player)
	if not state then
		return
	end
	local remote = Remotes.DailyQuestState :: RemoteEvent
	remote:FireClient(player, state)
end

-- Called by the QuestObjectives subscription. Mutates progress in
-- place + pushes state if anything advanced.
function DailyQuestManager.RecordProgress(player: Player, event: string, amount: number)
	if amount <= 0 then
		return
	end
	local data = DataManager.GetData(player)
	if not data then
		return
	end
	ensureFreshDay(data)

	local advanced = false
	for questId, entry in data.dailyQuests do
		if entry.claimed then
			continue
		end
		local quest = QUEST_POOL[questId]
		if not quest or quest.objective.event ~= event then
			continue
		end
		if entry.progress >= quest.objective.target then
			continue
		end
		entry.progress += amount
		if entry.progress > quest.objective.target then
			entry.progress = quest.objective.target
		end
		advanced = true
	end

	if advanced then
		pushStateToClient(player)
	end
end

function DailyQuestManager.Init()
	-- Push initial state on join (after profile loads).
	Players.PlayerAdded:Connect(function(player)
		task.spawn(function()
			DataManager.WaitForData(player)
			pushStateToClient(player)
		end)
	end)

	-- Subscribe to the global event bus.
	QuestObjectives.OnEmit(function(event, player, amount)
		DailyQuestManager.RecordProgress(player, event, amount)
	end)

	-- ClaimQuest is a RemoteFunction.
	local claimRemote = Remotes.ClaimQuest :: RemoteFunction
	claimRemote.OnServerInvoke = function(player: Player, questId: any): ClaimResult
		if typeof(questId) ~= "string" then
			return { ok = false, error = "invalid quest id" }
		end
		local result = DailyQuestManager.TryClaim(player, questId)
		pushStateToClient(player)
		return result
	end

	-- Per-minute tick: emit play_session for every online player and
	-- detect UTC day rollover so panels refresh without rejoining.
	task.spawn(function()
		local lastDate = utcDateString(os.time())
		while true do
			task.wait(60)
			for _, player in Players:GetPlayers() do
				QuestObjectives.Emit("play_session", player, 1)
			end
			local current = utcDateString(os.time())
			if current ~= lastDate then
				lastDate = current
				for _, player in Players:GetPlayers() do
					pushStateToClient(player)
				end
			end
		end
	end)
end

return DailyQuestManager
