--!strict
--[[
	Outpost-7 — raid round lifecycle (raid place only).

	Phase E1. Boots only when `game.PrivateServerId ~= ""`. Reads
	teleport data on attacker join, runs a 5-min round timer, fires
	the outcome via MessagingService back to both home servers, and
	teleports the attacker back to main on round end.

	V1 (E1) ships the *infrastructure* layer: the round is currently
	just a timer with placeholder reward bands. E2 fills in actual
	gameplay (PvE waves attacking the snapshot during the raid; Phase G
	renders the snapshot's base layout into the world). The reward
	`AttackerWinCredits` ships to all attackers in V1 — outcome is
	decided as a fixed "attacker wins" until E2's wave system gives
	the snapshot teeth.

	Trust boundary (ADR-008): this server **never** writes the
	defender's profile. All defender-side state changes (raidsRaided
	count, consolation reward) flow back via MessagingService topic
	`outpost.raid.outcome` to the defender's home server, which is
	the sole writer.

	Public API:
	  Init  — connects PlayerAdded + reads JoinData; never call from main place
--]]

local Players = game:GetService("Players")
local MessagingService = game:GetService("MessagingService")
local TeleportService = game:GetService("TeleportService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Constants = require(Shared:WaitForChild("Constants"))
local Remotes = require(Shared:WaitForChild("Remotes"))

local RaidSnapshot = require(script.Parent.RaidSnapshot)

local RaidSession = {}

export type StartInfo = {
	defenderName: string,
	roundSeconds: number,
	endsAt: number, -- os.time()
}

export type Outcome = {
	attackerUserId: number,
	defenderUserId: number,
	attackerWon: boolean,
	attackerCreditsDelta: number,
	defenderCreditsDelta: number,
	endedAt: number,
}

local function announceOutcome(outcome: Outcome)
	local ok, err = pcall(function()
		MessagingService:PublishAsync(Constants.RAID.TopicOutcome, outcome)
	end)
	if not ok then
		warn(string.format("[RaidSession] PublishAsync(outcome) failed: %s", tostring(err)))
	end
end

local function teleportAttackerHome(player: Player)
	-- V1: teleport back to the same main place id. ReserveServerAsync
	-- only reserves *raid* servers; the main place uses regular public
	-- servers, so we use Teleport (auto-route to a public server).
	-- placeId 0 fallback: stay in the raid place (dev-only path).
	-- We use the universe's main PlaceId, which for the
	-- single-PlaceId pattern equals game.PlaceId of the original main
	-- place. Players:GetPlayerByUserId on the home server is what
	-- routes the player back to *their* server via Roblox's matchmaker.
	local mainPlaceId = game.PlaceId -- raid place == reserved instance of same id (V1)
	if Constants.RAID.RaidPlaceId > 0 and Constants.RAID.RaidPlaceId ~= game.PlaceId then
		-- Two-PlaceId mode: route to the configured main place. For V1
		-- this is symmetric (same PlaceId), so this branch is unreached
		-- until V1.5+ split lands.
		mainPlaceId = game.PlaceId -- placeholder; configure once true split lands
	end
	local ok, err = pcall(function()
		TeleportService:Teleport(mainPlaceId, player)
	end)
	if not ok then
		warn(string.format("[RaidSession] Teleport home failed for %s: %s", player.Name, tostring(err)))
	end
end

local function runRound(player: Player, joinData: any)
	local snapshotId = joinData.snapshotId
	local defenderUserId = joinData.defenderUserId
	local defenderName = joinData.defenderName
	local roundSeconds = joinData.roundSeconds or Constants.RAID.RoundSeconds
	local startedAt = joinData.startedAt or os.time()
	local endsAt = startedAt + roundSeconds

	local snapshot = RaidSnapshot.LoadFromMemory(snapshotId)
	if not snapshot then
		warn(
			string.format(
				"[RaidSession] Snapshot %s not found in MemoryStore — kicking %s back to main",
				tostring(snapshotId),
				player.Name
			)
		)
		teleportAttackerHome(player)
		return
	end

	-- Push StartInfo to the client. E2/G will render the snapshot.baseLayout
	-- into the world on the server side; for E1 we ship the timer+outcome
	-- shell only.
	local startedRemote = Remotes.RaidStarted :: RemoteEvent
	startedRemote:FireClient(player, {
		defenderName = defenderName,
		roundSeconds = roundSeconds,
		endsAt = endsAt,
	} :: StartInfo)

	print(
		string.format(
			"[RaidSession] Round started: %s raids %s (snapshot=%s, endsAt=%d)",
			player.Name,
			defenderName,
			snapshotId,
			endsAt
		)
	)

	-- Wait until round end OR player leaves (e.g. closes Roblox).
	local stillIn = true
	local connection: RBXScriptConnection?
	connection = Players.PlayerRemoving:Connect(function(p)
		if p == player then
			stillIn = false
			if connection then
				connection:Disconnect()
				connection = nil
			end
		end
	end)
	while os.time() < endsAt and stillIn do
		task.wait(1)
	end
	if connection then
		connection:Disconnect()
	end

	-- Outcome decision (V1 placeholder): attacker always "wins" because
	-- the snapshot has no offensive AI in E1. E2 wires WaveDirector
	-- defenders that can kill the attacker, flipping this to a real
	-- decision tied to player health / objective progress.
	local attackerWon = stillIn -- if they bailed mid-round, count as a loss
	local outcome: Outcome = {
		attackerUserId = player.UserId,
		defenderUserId = defenderUserId,
		attackerWon = attackerWon,
		attackerCreditsDelta = if attackerWon
			then Constants.RAID.AttackerWinCredits
			else Constants.RAID.AttackerLossCredits,
		defenderCreditsDelta = Constants.RAID.DefenderRaidedCredits,
		endedAt = os.time(),
	}

	announceOutcome(outcome)

	-- Brief in-place results window before kicking the attacker home.
	if stillIn then
		local endedRemote = Remotes.RaidEnded :: RemoteEvent
		endedRemote:FireClient(player, outcome)
		task.wait(Constants.RAID.PostRoundGraceSeconds)
		teleportAttackerHome(player)
	end
end

function RaidSession.Init()
	if game.PrivateServerId == "" then
		warn("[RaidSession] Init called in non-raid server; refusing.")
		return
	end

	local function onPlayerAdded(player: Player)
		local joinData = player:GetJoinData().TeleportData
		if typeof(joinData) ~= "table" then
			warn(
				string.format(
					"[RaidSession] %s joined raid place without teleport data — kicking home",
					player.Name
				)
			)
			teleportAttackerHome(player)
			return
		end
		if typeof(joinData.snapshotId) ~= "string" or typeof(joinData.defenderUserId) ~= "number" then
			warn(
				string.format(
					"[RaidSession] %s teleport data malformed — kicking home",
					player.Name
				)
			)
			teleportAttackerHome(player)
			return
		end
		runRound(player, joinData)
	end

	Players.PlayerAdded:Connect(function(player)
		task.spawn(onPlayerAdded, player)
	end)
	-- Existing players (Studio reload during dev).
	for _, player in Players:GetPlayers() do
		task.spawn(onPlayerAdded, player)
	end

	print(
		string.format(
			"[RaidSession] Raid place ready. privateServerId=%s, roundSeconds=%d",
			game.PrivateServerId,
			Constants.RAID.RoundSeconds
		)
	)
end

return RaidSession
