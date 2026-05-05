--!strict
--[[
	Outpost-7 — cross-server raid matchmaker.

	Phase E1. Owns the queue + leader-elected matchmaker loop in the
	main place. Architecture per ADR-008:

	  1. Attacker invokes the `RaidQueue` Remote → server adds an entry
	     to MemoryStore SortedMap `OutpostRaidQueue` keyed by attacker
	     UserId.
	  2. Every main server publishes its online players to MemoryStore
	     SortedMap `OutpostRaidableTargets` every TargetsHeartbeatSeconds
	     (TTL 2× heartbeat). The attacker himself is excluded.
	  3. The elected matchmaker (one server per universe per
	     MatchmakerSentinelTtl seconds) ticks every MatchmakerTickSeconds:
	       - pulls queue + targets pools
	       - pairs each queued attacker with a random raidable target
	         (V1: round-robin random; E5+ may add ELO/skill-based)
	       - publishes `outpost.raid.matched` with
	         `{ attackerUserId, defenderUserId, snapshotId, accessCode }`
	         after `ReservedServerLauncher.ReserveAndTeleport` succeeds
	         on the attacker's home server (the leader sends a
	         "reserve+teleport please" trigger; the home server
	         executes — the leader doesn't have the attacker Player
	         object unless they're queued from the leader's own server)
	  4. Home servers listen to the topic; the one matching
	     `attackerUserId` does the snapshot capture + reserve + teleport.

	Defender's home server, in parallel, captures and stores the
	snapshot in MemoryStore so the raid place can read it. Defender's
	live profile is **never** mutated by the raid server.

	Leader election:
	  - Sentinel key in MemoryStore HashMap `OutpostRaidSentinels` with
	    TTL = MatchmakerSentinelTtl. First server to write it (using
	    ConditionalSet so concurrent writes don't override) wins.
	  - Leader extends its lease each tick by re-writing with the same
	    JobId. If the leader crashes, sentinel TTL expires and the
	    next ticker takes over.

	Public API:
	  Init                        — Remotes + heartbeat + matchmaker loop
	  Enqueue(player)             — server-side enqueue
	  Cancel(player)              — server-side dequeue
	  GetQueueState(player)       — non-yielding read
	  ExecuteMatchOnHome(payload) — called by MessagingService listener;
	                                runs snapshot/reserve/teleport for
	                                the attacker on this server
--]]

local Players = game:GetService("Players")
local MemoryStoreService = game:GetService("MemoryStoreService")
local MessagingService = game:GetService("MessagingService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Constants = require(Shared:WaitForChild("Constants"))
local Remotes = require(Shared:WaitForChild("Remotes"))

local RaidSnapshot = require(script.Parent.RaidSnapshot)
local ReservedServerLauncher = require(script.Parent.ReservedServerLauncher)

local RaidMatchmaker = {}

export type QueueState = {
	queued: boolean,
	deadlineAt: number?, -- os.time() at which queue auto-pops to PvE fallback
	matched: boolean,
	error: string?,
}

export type QueueResult = {
	ok: true,
	state: QueueState,
} | {
	ok: false,
	error: string,
}

type MatchedPayload = {
	attackerUserId: number,
	defenderUserId: number,
	-- The leader pre-assigns the snapshotId so both home servers (the
	-- defender's home is the writer, the attacker's home is the reader)
	-- reference the same MemoryStore key without out-of-band discovery.
	snapshotId: string,
	matchedAt: number,
}

type QueueEntry = {
	userId: number,
	enqueuedAt: number,
	jobId: string, -- attacker's home server JobId
}

type TargetEntry = {
	userId: number,
	jobId: string,
}

local queueMap: any = MemoryStoreService:GetSortedMap(Constants.RAID.QueueMapName)
local targetsMap: any = MemoryStoreService:GetSortedMap(Constants.RAID.TargetsMapName)
local sentinelMap: any = MemoryStoreService:GetHashMap(Constants.RAID.SentinelMapName)

-- Per-server in-memory mirror of the queue — used to push QueueState
-- to the local client before the global state catches up.
local localQueueState: { [Player]: QueueState } = {}

-- Fires when a player's queue entry expires without a match. Phase E2's
-- WaveDirector subscribes here for the "PvE wave fallback" hook
-- (brainstorm §2.1: "NPC alien wave fallback when raid queue is empty").
-- Decoupled via signal to avoid a Raid → Combat require dependency.
local onDeadlinePop = Instance.new("BindableEvent")
RaidMatchmaker.OnDeadlinePop = onDeadlinePop.Event

local function pushQueueState(player: Player)
	local state = localQueueState[player] or { queued = false, matched = false }
	local remote = Remotes.RaidQueueState :: RemoteEvent
	remote:FireClient(player, state)
end

local function setLocalState(player: Player, state: QueueState)
	localQueueState[player] = state
	pushQueueState(player)
end

-- Yielding. Returns true on success.
local function writeQueueEntry(player: Player): boolean
	local entry: QueueEntry = {
		userId = player.UserId,
		enqueuedAt = os.time(),
		jobId = game.JobId,
	}
	local ok, err = pcall(function()
		queueMap:SetAsync(tostring(player.UserId), entry, Constants.RAID.QueueEntryTtl)
	end)
	if not ok then
		warn(string.format("[RaidMatchmaker] Queue write failed for %s: %s", player.Name, tostring(err)))
		return false
	end
	return true
end

local function removeQueueEntry(userId: number): boolean
	local ok, err = pcall(function()
		queueMap:RemoveAsync(tostring(userId))
	end)
	if not ok then
		warn(string.format("[RaidMatchmaker] Queue remove failed for userId=%d: %s", userId, tostring(err)))
		return false
	end
	return true
end

function RaidMatchmaker.Enqueue(player: Player): QueueResult
	if Constants.RAID.RaidPlaceId <= 0 then
		return { ok = false, error = "raid place id not configured" }
	end
	if localQueueState[player] and localQueueState[player].queued then
		return { ok = true, state = localQueueState[player] }
	end
	if not writeQueueEntry(player) then
		return { ok = false, error = "queue write failed" }
	end
	local state: QueueState = {
		queued = true,
		matched = false,
		deadlineAt = os.time() + Constants.RAID.QueueDeadlineSeconds,
	}
	setLocalState(player, state)
	print(string.format("[RaidMatchmaker] %s enqueued", player.Name))
	return { ok = true, state = state }
end

function RaidMatchmaker.Cancel(player: Player): QueueResult
	removeQueueEntry(player.UserId)
	local state: QueueState = { queued = false, matched = false }
	setLocalState(player, state)
	print(string.format("[RaidMatchmaker] %s cancelled queue", player.Name))
	return { ok = true, state = state }
end

function RaidMatchmaker.GetQueueState(player: Player): QueueState
	return localQueueState[player] or { queued = false, matched = false }
end

-- Heartbeat: every TargetsHeartbeatSeconds, this server publishes its
-- online players to the global raidable-targets pool. Players in the
-- queue are excluded (they're attacking, not defending).
local function targetsHeartbeat()
	while true do
		task.wait(Constants.RAID.TargetsHeartbeatSeconds)
		for _, player in Players:GetPlayers() do
			local localState = localQueueState[player]
			if localState and localState.queued then
				continue
			end
			local entry: TargetEntry = { userId = player.UserId, jobId = game.JobId }
			local ok, err = pcall(function()
				targetsMap:SetAsync(tostring(player.UserId), entry, Constants.RAID.TargetsTtlSeconds)
			end)
			if not ok then
				warn(string.format("[RaidMatchmaker] Targets heartbeat failed for %s: %s", player.Name, tostring(err)))
			end
		end
	end
end

local function tryClaimLeader(): boolean
	-- ConditionalSet via UpdateAsync: write only if absent or expired.
	-- HashMap UpdateAsync(key, transform) where transform receives the
	-- current value and returns the new value (nil to skip).
	local ok, didWrite = pcall(function()
		return sentinelMap:UpdateAsync(Constants.RAID.MatchmakerSentinelKey, function(current)
			if current and current.jobId ~= game.JobId then
				return nil
			end
			return { jobId = game.JobId, claimedAt = os.time() }
		end, Constants.RAID.MatchmakerSentinelTtl)
	end)
	if not ok then
		return false
	end
	return didWrite ~= nil
end

local function pullQueueEntries(): { QueueEntry }
	local entries: { QueueEntry } = {}
	local ok, items = pcall(function()
		return queueMap:GetRangeAsync(Enum.SortDirection.Ascending, 100)
	end)
	if not ok or typeof(items) ~= "table" then
		return entries
	end
	for _, item in items do
		if typeof(item.value) == "table" then
			table.insert(entries, item.value)
		end
	end
	return entries
end

local function pullTargetEntries(): { TargetEntry }
	local entries: { TargetEntry } = {}
	local ok, items = pcall(function()
		return targetsMap:GetRangeAsync(Enum.SortDirection.Ascending, 200)
	end)
	if not ok or typeof(items) ~= "table" then
		return entries
	end
	for _, item in items do
		if typeof(item.value) == "table" then
			table.insert(entries, item.value)
		end
	end
	return entries
end

local function publishMatched(payload: MatchedPayload): boolean
	local ok, err = pcall(function()
		MessagingService:PublishAsync(Constants.RAID.TopicMatched, payload)
	end)
	if not ok then
		warn(string.format("[RaidMatchmaker] PublishAsync failed: %s", tostring(err)))
		return false
	end
	return true
end

-- Runs only on the elected leader.
local function runMatchmakerTick(rng: Random)
	local queue = pullQueueEntries()
	if #queue == 0 then
		return
	end
	local targets = pullTargetEntries()
	-- Build a set of queued userIds for cheap exclusion.
	local queuedSet: { [number]: boolean } = {}
	for _, q in queue do
		queuedSet[q.userId] = true
	end
	-- Filter targets: not the attacker themselves, not currently queued.
	for _, attacker in queue do
		local viableTargets: { TargetEntry } = {}
		for _, t in targets do
			if t.userId ~= attacker.userId and not queuedSet[t.userId] then
				table.insert(viableTargets, t)
			end
		end
		if #viableTargets == 0 then
			-- No viable opponent. Leave the attacker in queue; the
			-- deadline-pop loop will eject them after QueueDeadlineSeconds
			-- and the client falls back to a PvE wave (E2 wires the
			-- fallback Remote).
			continue
		end
		local choice = viableTargets[rng:NextInteger(1, #viableTargets)]
		-- Remove attacker from queue *before* publish so concurrent
		-- ticks don't re-pair the same attacker.
		removeQueueEntry(attacker.userId)
		local snapshotId = string.format("snap_%d_%d_%d", attacker.userId, choice.userId, os.time())
		publishMatched({
			attackerUserId = attacker.userId,
			defenderUserId = choice.userId,
			snapshotId = snapshotId,
			matchedAt = os.time(),
		})
		print(
			string.format(
				"[RaidMatchmaker] Leader %s paired attacker=%d ↔ defender=%d",
				game.JobId,
				attacker.userId,
				choice.userId
			)
		)
	end
end

local function matchmakerLoop()
	-- Each leader maintains its own RNG for fair viable-target picks
	-- across the leader's session.
	local rng = Random.new()
	while true do
		task.wait(Constants.RAID.MatchmakerTickSeconds)
		if tryClaimLeader() then
			runMatchmakerTick(rng)
		end
	end
end

-- Per-second deadline pop: any local queued player past their deadline
-- gets cancelled with a "deadline" hint AND the OnDeadlinePop signal
-- fires so WaveDirector can launch a PvE fallback (brainstorm §2.1).
-- The MemoryStore TTL also expires the row, but we enforce here for
-- prompt UI reaction + the wave hook.
local function deadlineLoop()
	while true do
		task.wait(1)
		local now = os.time()
		for player, state in localQueueState do
			if state.queued and state.deadlineAt and now >= state.deadlineAt then
				removeQueueEntry(player.UserId)
				localQueueState[player] = {
					queued = false,
					matched = false,
					error = "deadline",
				}
				pushQueueState(player)
				onDeadlinePop:Fire(player)
			end
		end
	end
end

-- Called on a home server when MessagingService delivers `outpost.raid.matched`.
-- Each home server checks if it owns either side of the match and acts:
--   - Defender's home: capture + StoreInMemory under payload.snapshotId
--   - Attacker's home: poll LoadFromMemory until snapshot lands, then
--                      reserve + teleport
-- A single server may own both sides (small-pop V1); both branches run.
function RaidMatchmaker.ExecuteMatchOnHome(payload: MatchedPayload)
	-- Defender side: capture and write snapshot under the leader-assigned id.
	local defender = Players:GetPlayerByUserId(payload.defenderUserId)
	if defender then
		local snapshot = RaidSnapshot.Capture(defender, payload.snapshotId)
		if snapshot then
			RaidSnapshot.StoreInMemory(snapshot)
			print(
				string.format(
					"[RaidMatchmaker] Defender home published snapshot %s for raid by %d",
					snapshot.snapshotId,
					payload.attackerUserId
				)
			)
		end
	end

	-- Attacker side: poll for the snapshot, then reserve + teleport.
	local attacker = Players:GetPlayerByUserId(payload.attackerUserId)
	if attacker then
		task.spawn(function()
			local deadline = os.clock() + 5
			local snapshot: RaidSnapshot.Snapshot?
			while os.clock() < deadline do
				snapshot = RaidSnapshot.LoadFromMemory(payload.snapshotId)
				if snapshot then
					break
				end
				task.wait(0.5)
			end
			if not snapshot or not attacker:IsDescendantOf(Players) then
				localQueueState[attacker] = {
					queued = false,
					matched = false,
					error = "snapshot unavailable",
				}
				pushQueueState(attacker)
				return
			end
			-- Push "matched" state before teleport so the UI shows the
			-- transition. State refreshes when the player re-joins main
			-- after the round.
			localQueueState[attacker] = { queued = false, matched = true }
			pushQueueState(attacker)
			ReservedServerLauncher.ReserveAndTeleport(attacker, snapshot)
		end)
	end
end

local function subscribeMatched()
	local ok, err = pcall(function()
		MessagingService:SubscribeAsync(Constants.RAID.TopicMatched, function(message)
			local payload = message.Data
			if typeof(payload) ~= "table" then
				return
			end
			RaidMatchmaker.ExecuteMatchOnHome(payload :: MatchedPayload)
		end)
	end)
	if not ok then
		warn(string.format("[RaidMatchmaker] SubscribeAsync(matched) failed: %s", tostring(err)))
	end
end

function RaidMatchmaker.Init()
	-- Wire RaidQueue Remote.
	local queueRemote = Remotes.RaidQueue :: RemoteFunction
	queueRemote.OnServerInvoke = function(player: Player, action: any): QueueResult
		if typeof(action) ~= "string" then
			return { ok = false, error = "invalid action" }
		end
		if action == "queue" then
			return RaidMatchmaker.Enqueue(player)
		elseif action == "cancel" then
			return RaidMatchmaker.Cancel(player)
		end
		return { ok = false, error = "unknown action" }
	end

	-- Push initial empty state on join so the client renders correctly.
	Players.PlayerAdded:Connect(function(player)
		task.spawn(function()
			task.wait(0.5)
			pushQueueState(player)
		end)
	end)
	Players.PlayerRemoving:Connect(function(player)
		-- Remove their queue entry if any. The TTL would also clear it,
		-- but explicit cleanup avoids a brief window where they're
		-- "queued" while disconnected.
		if localQueueState[player] and localQueueState[player].queued then
			removeQueueEntry(player.UserId)
		end
		localQueueState[player] = nil
	end)

	subscribeMatched()
	task.spawn(targetsHeartbeat)
	task.spawn(matchmakerLoop)
	task.spawn(deadlineLoop)
end

return RaidMatchmaker
