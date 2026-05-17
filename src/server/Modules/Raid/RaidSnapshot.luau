--!strict
--[[
	Outpost-7 — defender base snapshot capture + serialization.

	Phase E1. When the matchmaker pairs an attacker with a target, the
	target's home server is asked (via MessagingService topic
	"outpost.raid.matched") to capture a snapshot and write it to a
	MemoryStore SortedMap so the raid place can read it on attacker
	arrival. The defender's *home* server keeps running untouched —
	the raid place operates on the snapshot only.

	Snapshot fidelity (V1 minimum):
	  - defenderUserId / defenderName (display + reward routing)
	  - baseLayout (positions + ids, copied from ProfileSchema)
	  - creditsAtSnapshot (the upper bound the attacker can steal)

	V1.5 may add live drone / turret state. V1 raids run against a
	static defender base — the attacker can break / loot but the
	defender can't react in real time.

	Snapshot lives in MemoryStore SortedMap `OutpostRaidSnapshots`
	with a TTL of `Constants.RAID.SnapshotTtl`. Long enough for the
	raid place to load on teleport; short enough that abandoned
	matches don't accumulate.

	Public API:
	  Capture(player)                      — non-yielding capture
	  StoreInMemory(snapshotId, snapshot)  — yielding (MemoryStore write)
	  LoadFromMemory(snapshotId)           — yielding (MemoryStore read)
--]]

local MemoryStoreService = game:GetService("MemoryStoreService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Constants = require(Shared:WaitForChild("Constants"))

local DataManager = require(script.Parent.Parent.Player.DataManager)

local RaidSnapshot = {}

export type Snapshot = {
	snapshotId: string,
	defenderUserId: number,
	defenderName: string,
	baseLayout: { { id: string, x: number, z: number } },
	creditsAtSnapshot: number,
	capturedAt: number, -- os.time()
}

local snapshotMap: any = MemoryStoreService:GetSortedMap(Constants.RAID.SnapshotMapName)

-- Capture accepts an optional snapshotId so the matchmaker leader can
-- pre-assign a deterministic id that both the defender's home (writer)
-- and the attacker's home (reader) reference without needing to discover
-- it after the fact. Falls back to a userId+time string for ad-hoc captures.
function RaidSnapshot.Capture(player: Player, snapshotId: string?): Snapshot?
	local data = DataManager.GetData(player)
	if not data then
		return nil
	end
	-- Deep-ish copy of baseLayout: each entry is a flat table so a
	-- shallow copy of the outer + per-entry copy is sufficient.
	local layoutCopy: { { id: string, x: number, z: number } } = {}
	for _, entry in data.baseLayout do
		table.insert(layoutCopy, { id = entry.id, x = entry.x, z = entry.z })
	end
	return {
		snapshotId = snapshotId or string.format("snap_%d_%d", player.UserId, os.time()),
		defenderUserId = player.UserId,
		defenderName = player.Name,
		baseLayout = layoutCopy,
		creditsAtSnapshot = data.credits,
		capturedAt = os.time(),
	}
end

function RaidSnapshot.StoreInMemory(snapshot: Snapshot): boolean
	local ok, err = pcall(function()
		snapshotMap:SetAsync(snapshot.snapshotId, snapshot, Constants.RAID.SnapshotTtl)
	end)
	if not ok then
		warn(string.format("[RaidSnapshot] Failed to write snapshot %s: %s", snapshot.snapshotId, tostring(err)))
		return false
	end
	return true
end

function RaidSnapshot.LoadFromMemory(snapshotId: string): Snapshot?
	local ok, value = pcall(function()
		return snapshotMap:GetAsync(snapshotId)
	end)
	if not ok then
		warn(string.format("[RaidSnapshot] Failed to read snapshot %s: %s", snapshotId, tostring(value)))
		return nil
	end
	return value :: Snapshot?
end

return RaidSnapshot
