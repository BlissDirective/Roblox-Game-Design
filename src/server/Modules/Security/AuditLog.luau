--!strict
--[[
	Outpost-7 — security audit log (per-player ring buffer).

	Phase F2. In-memory audit log of suspicious activity per player.
	Categories: rate-limit denials (F1 hook), validation failures
	(F2 hook), domain-validation rejects, future Phase H signals.

	V1 ships in-memory only; per-player ring buffer of `MaxRecordsPerPlayer`
	entries (default 50) with FIFO eviction. Cleared on PlayerRemoving.
	Phase H prep adds DataStore-backed persistence + cross-server
	aggregation for live-monitoring dashboards.

	Threat model addressed:
	  - Distributed exploiter probes — multiple sub-threshold attempts
	    add up to a pattern; the ring buffer surfaces it for review
	  - Compliance / moderation reports — "what did this player do
	    that got them rate-limited at 14:32 UTC"

	Public API:
	  Init                                   — connects PlayerRemoving cleanup
	  Record(player, category, details)      — non-yielding append
	  GetRecords(player) -> { Record }       — non-yielding read for diagnostics
	  GetCategoryCount(player, category)     — quick count for triage
--]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Constants = require(Shared:WaitForChild("Constants"))

local AuditLog = {}

export type Category = "rate_limited" | "validation_failed" | "suspicious_activity"

export type Record = {
	category: Category,
	details: string, -- short human-readable; e.g. "PlaceBuilding: cellX above max (32)"
	timestamp: number, -- os.time()
}

-- Ring buffer per player. Keyed by UserId (survives Player Instance churn
-- across rare Studio reload edge cases, though we still clear on
-- PlayerRemoving).
local records: { [number]: { Record } } = {}

function AuditLog.Record(player: Player, category: Category, details: string)
	local userId = player.UserId
	local list = records[userId]
	if not list then
		list = {}
		records[userId] = list
	end
	table.insert(list, {
		category = category,
		details = details,
		timestamp = os.time(),
	})
	-- FIFO eviction at cap.
	while #list > Constants.AUDIT_LOG.MaxRecordsPerPlayer do
		table.remove(list, 1)
	end
end

function AuditLog.GetRecords(player: Player): { Record }
	return records[player.UserId] or {}
end

function AuditLog.GetCategoryCount(player: Player, category: Category): number
	local list = records[player.UserId]
	if not list then
		return 0
	end
	local count = 0
	for _, r in list do
		if r.category == category then
			count += 1
		end
	end
	return count
end

function AuditLog.Init()
	Players.PlayerRemoving:Connect(function(player)
		records[player.UserId] = nil
	end)
end

return AuditLog
