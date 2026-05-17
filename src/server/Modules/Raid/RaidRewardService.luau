--!strict
--[[
	Outpost-7 — raid outcome relay (main place only).

	Phase E1. Subscribes to MessagingService topic
	`outpost.raid.outcome` (universe-wide). Each main server inspects
	the payload and applies the credits + counter changes for whichever
	side (attacker, defender, or both) is currently on this server.

	ADR-008 invariant: only the home server holding the player's
	authoritative profile applies the writes. The raid server *fires*
	the outcome but never writes any profile directly.

	V1 caveats:
	  - If the defender went offline between the snapshot and the
	    outcome, the defender-side reward is dropped (acceptable for
	    V1; V1.5+ may persist via a `PendingRaidRewards` DataStore).
	  - Duplicate outcomes (MessagingService at-least-once delivery)
	    are deduped by `(attackerUserId, defenderUserId, endedAt)`
	    in a per-server in-memory set with a 10-minute TTL. The
	    duplicate window is bounded by the outcome's age so memory
	    use stays flat.

	Public API:
	  Init  — subscribes to TopicOutcome on the main place
--]]

local Players = game:GetService("Players")
local MessagingService = game:GetService("MessagingService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Constants = require(Shared:WaitForChild("Constants"))
local Remotes = require(Shared:WaitForChild("Remotes"))

local DataManager = require(script.Parent.Parent.Player.DataManager)
local CurrencyService = require(script.Parent.Parent.Economy.CurrencyService)
local RaidSession = require(script.Parent.RaidSession)

type Outcome = RaidSession.Outcome

local RaidRewardService = {}

-- Per-server idempotency. Bounded by `pruneSeenOutcomes` below — runs
-- every 5 minutes, drops entries older than DEDUPE_WINDOW seconds.
local seenOutcomes: { [string]: number } = {}
local DEDUPE_WINDOW = 600

local function outcomeKey(o: Outcome): string
	return string.format("%d:%d:%d", o.attackerUserId, o.defenderUserId, o.endedAt)
end

local function pruneSeenOutcomes()
	while true do
		task.wait(300)
		local now = os.time()
		for k, ts in seenOutcomes do
			if now - ts > DEDUPE_WINDOW then
				seenOutcomes[k] = nil
			end
		end
	end
end

local function applyAttackerSide(player: Player, outcome: Outcome)
	local data = DataManager.GetData(player)
	if not data then
		return
	end
	if outcome.attackerCreditsDelta > 0 then
		CurrencyService.Add(player, outcome.attackerCreditsDelta)
	end
	if outcome.attackerWon then
		data.raidWins += 1
	else
		data.raidLosses += 1
	end
	local endedRemote = Remotes.RaidEnded :: RemoteEvent
	endedRemote:FireClient(player, outcome)
	print(
		string.format(
			"[RaidRewardService] Attacker home applied outcome for %s: won=%s, +%d credits",
			player.Name,
			tostring(outcome.attackerWon),
			outcome.attackerCreditsDelta
		)
	)
end

local function applyDefenderSide(player: Player, outcome: Outcome)
	local data = DataManager.GetData(player)
	if not data then
		return
	end
	if outcome.defenderCreditsDelta > 0 then
		CurrencyService.Add(player, outcome.defenderCreditsDelta)
	end
	data.raidsRaided += 1
	-- "Defended" semantics in V1: attacker lost (i.e., bailed mid-round
	-- or — once E2 ships — was killed by the snapshot's wave defenders).
	if not outcome.attackerWon then
		data.raidsDefended += 1
	end
	local endedRemote = Remotes.RaidEnded :: RemoteEvent
	endedRemote:FireClient(player, outcome)
	print(
		string.format(
			"[RaidRewardService] Defender home applied outcome for %s: defended=%s, +%d credits",
			player.Name,
			tostring(not outcome.attackerWon),
			outcome.defenderCreditsDelta
		)
	)
end

local function handleOutcome(outcome: Outcome)
	local key = outcomeKey(outcome)
	if seenOutcomes[key] then
		return
	end
	seenOutcomes[key] = os.time()

	local attacker = Players:GetPlayerByUserId(outcome.attackerUserId)
	if attacker then
		-- Profile may not be ready yet if the attacker just teleported
		-- back from raid; wait briefly.
		task.spawn(function()
			DataManager.WaitForData(attacker)
			if attacker:IsDescendantOf(Players) then
				applyAttackerSide(attacker, outcome)
			end
		end)
	end

	local defender = Players:GetPlayerByUserId(outcome.defenderUserId)
	if defender then
		applyDefenderSide(defender, outcome)
	end
end

function RaidRewardService.Init()
	local ok, err = pcall(function()
		MessagingService:SubscribeAsync(Constants.RAID.TopicOutcome, function(message)
			local payload = message.Data
			if typeof(payload) ~= "table" then
				return
			end
			-- Defensive type checks at the wire boundary.
			if typeof(payload.attackerUserId) ~= "number" or typeof(payload.defenderUserId) ~= "number" then
				return
			end
			handleOutcome(payload :: Outcome)
		end)
	end)
	if not ok then
		warn(string.format("[RaidRewardService] SubscribeAsync(outcome) failed: %s", tostring(err)))
	end
	task.spawn(pruneSeenOutcomes)
end

return RaidRewardService
