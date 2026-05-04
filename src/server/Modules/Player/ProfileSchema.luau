--!strict
--[[
	Outpost-7 — versioned PlayerData schema.

	Phase A2: ships v1.0 with the minimum fields needed to verify
	round-trip persistence. Later phases add fields freely (additive
	changes are safe — ProfileStore's `:Reconcile()` merges defaults
	from this template into older saves).
	Phase B3: adds `baseLayout` (the player's persistent placed-buildings
	list). Additive — no migration needed; older saves get an empty
	array on next load via Reconcile().
	Phase C1: adds `lastDailyClaim` + `dailyStreak` for the daily-login
	mechanic. Additive — older saves get nil + 0 from defaults via
	Reconcile().
	Phase C2: adds `shopRotationSeen` + `shopBuysThisRotation` for the
	restocking blueprint shop. Additive — older saves get nil + {} on
	next load. Stale rotations reset lazily inside ShopService.
	Phase C3: adds `dailyQuests` + `lastQuestReset` for the daily-quest
	system. Additive. Stale quest sets reset lazily inside
	DailyQuestManager when the UTC day changes.
	Phase D2: adds `purchaseHistory: { [purchaseId]: true }` for
	`MarketplaceService.ProcessReceipt` idempotency. Additive — older
	saves get an empty table on next load via Reconcile. Keys are
	Roblox-issued purchase IDs (strings); values are always `true`.

	Renaming or removing a field requires:
	  1. Bump CURRENT_SCHEMA_VERSION
	  2. Add a migrator under MIGRATIONS keyed by the source version
	  3. Log the change in docs/architecture/DATA_SCHEMA.md
	  4. Escalate per docs/10_BUILD_PROTOCOL.md (schema changes after
	     Phase A require human approval before merge)
--]]

local ProfileSchema = {}

ProfileSchema.CURRENT_SCHEMA_VERSION = 1

export type SerializedBuilding = {
	id: string, -- buildable id from BuildableRegistry
	x: number, -- snap-grid cell X
	z: number, -- snap-grid cell Z
}

export type QuestProgress = {
	progress: number,
	claimed: boolean,
}

export type PlayerData = {
	_version: number,
	credits: number,
	cores: number,
	firstJoinAt: number?,
	lastJoinAt: number?,
	sessionsPlayed: number,
	baseLayout: { SerializedBuilding },
	-- Phase C1 — Retention / daily login
	lastDailyClaim: string?, -- "YYYY-MM-DD" UTC; nil = never claimed
	dailyStreak: number, -- 0 = no active streak; 1..N consecutive days
	-- Phase C2 — Retention / restocking shop
	shopRotationSeen: number?, -- last rotation index the player saw
	shopBuysThisRotation: { [string]: boolean }, -- item ids bought
	-- Phase C3 — Retention / daily quests
	dailyQuests: { [string]: QuestProgress }, -- 3 keys per active day
	lastQuestReset: string?, -- "YYYY-MM-DD" UTC of last roll
	-- Phase D2 — Monetization / receipt idempotency
	purchaseHistory: { [string]: boolean }, -- Roblox PurchaseId → true
}

ProfileSchema.DEFAULT_DATA = {
	_version = 1,
	credits = 0,
	cores = 0,
	firstJoinAt = nil,
	lastJoinAt = nil,
	sessionsPlayed = 0,
	baseLayout = {},
	lastDailyClaim = nil,
	dailyStreak = 0,
	shopRotationSeen = nil,
	shopBuysThisRotation = {},
	dailyQuests = {},
	lastQuestReset = nil,
	purchaseHistory = {},
} :: PlayerData

-- Each migrator mutates a profile in place from version K to version K+1.
-- v1.0 has no migrators yet — the table is intentionally empty.
local MIGRATIONS: { [number]: (any) -> () } = {
	-- [1] = function(data) data.newField = 0 end,  -- example: v1 -> v2
}

function ProfileSchema.Migrate(data: any): PlayerData
	local version: number = if typeof(data._version) == "number" then data._version else 0
	while version < ProfileSchema.CURRENT_SCHEMA_VERSION do
		local migrator = MIGRATIONS[version]
		if not migrator then
			break
		end
		migrator(data)
		version += 1
	end
	data._version = ProfileSchema.CURRENT_SCHEMA_VERSION
	return data
end

return ProfileSchema
