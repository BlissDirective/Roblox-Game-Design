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
local RaidBaseRenderer = require(script.Parent.RaidBaseRenderer)

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
	-- R2: credits actually stolen from the defender (drained on their home
	-- server by RaidRewardService). Distinct from defenderCreditsDelta, which
	-- is the consolation grant. Defaults to 0 for pre-R2 payloads.
	defenderCreditsStolen: number,
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
	-- ADR-009: true two-PlaceId split. Configured `MainPlaceId` is the
	-- public-facing place; we teleport the attacker there and Roblox's
	-- matchmaker routes them into a public server. If the placeholder
	-- value is still 0 (V1 dev before Phase H), fall back to the
	-- current PlaceId so dev sessions don't soft-lock the attacker.
	local mainPlaceId = if Constants.RAID.MainPlaceId > 0 then Constants.RAID.MainPlaceId else game.PlaceId
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

	-- R2: render the defender's snapshot base into the arena and drop the
	-- attacker in front of it. The weapon's structure-hit handler
	-- (registered on WeaponService in the raid bootstrap) routes shots into
	-- RaidBaseRenderer, which tracks the loot tally. R2b: the base's turrets
	-- shoot back at the attacker.
	RaidBaseRenderer.Render(snapshot)
	RaidBaseRenderer.PositionAttacker(player)
	RaidBaseRenderer.StartDefense(player)

	-- Push StartInfo to the client (the client flips to Combat mode on this).
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

	-- Round loop: end on timer, attacker leaving, or all extractors smashed.
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
	local progressRemote = Remotes.RaidProgress :: RemoteEvent
	local function pushProgress()
		progressRemote:FireClient(player, {
			extracted = RaidBaseRenderer.GetExtracted(),
			extractorsDown = RaidBaseRenderer.GetExtractorsDown(),
			totalExtractors = RaidBaseRenderer.GetTotalExtractors(),
			endsAt = endsAt,
		})
	end
	pushProgress()

	while os.time() < endsAt and stillIn do
		local total = RaidBaseRenderer.GetTotalExtractors()
		if total > 0 and RaidBaseRenderer.GetExtractorsDown() >= total then
			break -- nothing left to loot; end early
		end
		-- R2b: the attacker can be killed by the base's turrets — that ends
		-- the round (they keep whatever they already extracted).
		local character = player.Character
		local humanoid = if character then character:FindFirstChildOfClass("Humanoid") else nil
		if humanoid and humanoid.Health <= 0 then
			break
		end
		pushProgress()
		task.wait(1)
	end
	if connection then
		connection:Disconnect()
	end

	-- R2 outcome: the attacker keeps whatever they extracted. A base with no
	-- extractors yields a flat consolation haul if any structure was broken.
	local extracted = RaidBaseRenderer.GetExtracted()
	if RaidBaseRenderer.GetTotalExtractors() == 0 and RaidBaseRenderer.GetStructuresDestroyed() > 0 then
		extracted = Constants.RAID.RaidBaseLootNoExtractors
	end
	local attackerWon = extracted > 0
	local outcome: Outcome = {
		attackerUserId = player.UserId,
		defenderUserId = defenderUserId,
		attackerWon = attackerWon,
		attackerCreditsDelta = if attackerWon then extracted else Constants.RAID.AttackerLossCredits,
		defenderCreditsDelta = Constants.RAID.DefenderRaidedCredits,
		defenderCreditsStolen = if attackerWon then extracted else 0,
		endedAt = os.time(),
	}

	RaidBaseRenderer.Cleanup()
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
