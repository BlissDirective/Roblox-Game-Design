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
	Phase D3: extends `QuestProgress` with optional `vipOnly: boolean`
	for the VIP Operator pass's "+1 daily quest slot" effect. The 4th
	quest rolled per day is flagged at reset; only VIP-owning players
	can see / claim it. Additive — older entries default to non-vipOnly.
	Phase D4: adds `battlePassXP`, `battlePassTier`,
	`battlePassClaimed`, `battlePassSeasonId` for the Battle Pass.
	Premium-track ownership is **not** a profile field — it's a
	GamePass (`Constants.MONETIZATION.GamePasses.BattlePassPremium`)
	read on demand via `GamePassService.Owns`. Season transitions
	reset XP/tier/claims lazily on the next GetState/GrantXP/TryClaim
	when `battlePassSeasonId != Constants.BATTLE_PASS.SeasonId`.
	Phase E1: adds `raidWins`, `raidLosses`, `raidsDefended`,
	`raidsRaided` for offensive + defensive raid counters. These are
	the canonical inputs for E5's weekly leaderboard. Additive; older
	saves get 0 from defaults via Reconcile.
	Phase E2: adds `wavesSurvived` for the PvE wave system's lifetime
	counter. Drives a future "wave_survived" quest objective entry
	(Phase G expands the quest pool) and a possible E5 leaderboard
	column. Additive; older saves get 0.
	Phase E2.5: adds `turretsKilled` — lifetime aliens killed by
	this player's turrets. Mutated only by `TurretService` on the
	frame the alien's HP transitions from > 0 to <= 0 from a turret
	shot. Future quest objective ("turret_kill") and Phase G "PvE
	hero" leaderboard candidate.
	Phase E2.6: adds `dronesKilled` — same semantics as turretsKilled
	but for the drone swarm (DroneSwarmService). Counted separately
	so future "PvE hero" leaderboards can weight player-owned vs
	autonomous-defender kills differently.
	Phase E3: adds `clanId: string?` — the player's current clan
	membership. nil = no clan. Mutated only by `ClanService` on
	successful create / join / leave / kick / disband. Clan member
	role + the clan's full state lives in the separate `ClanData_v1`
	DataStore keyed by clanId.
	Phase F0 (V1.5 expansion prep): adds `creditsInvestedLifetime`
	for the V1.5 Tier system gate (60% weight per
	`docs/architecture/V1_5_TIER_PROGRESSION.md` §3). Mutated only by
	`PlacementService` on successful (non-trusted) placement; never
	decremented on demolish/refund — sticky tycoon-spend signal.
	Tracking starts in V1 so V1.5 doesn't need a lossy backfill from
	`baseLayout`. Also adds `tier: number` (default 0) — gates the
	tier UI hidden in V1, set by `TierService` in V1.5; V1→V1.5
	migration sets to 4 (Outpost) for existing V1 profiles.
	Phase F4 (FTUE): adds `ftueCompleted` (sticky boolean) +
	`ftueStep` (string?, current step). The step field lets a
	disconnected mid-FTUE player resume from their last checkpoint
	on rejoin. ftueCompleted is the gate that hides the FTUE flow
	for returning players.

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
	vipOnly: boolean?, -- D3: 4th-rolled quest each day; visible/claimable only with VIP Operator pass
}

-- D4: per-tier, per-track claim flags. Keys are stringified tier
-- numbers ("1".."30") so JSON serialization in DataStore round-trips
-- cleanly regardless of Lua/JSON integer-key edge cases.
export type BattlePassClaimEntry = {
	free: boolean,
	premium: boolean,
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
	-- Phase D4 — Battle Pass (premium ownership reads from GamePassService)
	battlePassXP: number, -- accumulated XP for the current season
	battlePassTier: number, -- derived from XP; capped at MaxTier
	battlePassClaimed: { [string]: BattlePassClaimEntry }, -- key = tostring(tier)
	battlePassSeasonId: string?, -- season-reset detector
	-- Phase E1 — Raid stats (E5 reads these for the weekly leaderboard).
	raidWins: number, -- offensive raids won
	raidLosses: number, -- offensive raids lost
	raidsDefended: number, -- successful defenses (defender survived a raid)
	raidsRaided: number, -- total times this player has been raided
	-- Phase E2 — PvE wave stats.
	wavesSurvived: number, -- lifetime count of waves survived
	-- Phase E2.5 — turret kill stats.
	turretsKilled: number, -- lifetime aliens killed by this player's turrets
	-- Phase E2.6 — drone swarm kill stats.
	dronesKilled: number, -- lifetime aliens killed by this player's drone swarm
	-- Phase E3 — clan membership.
	clanId: string?, -- nil = unaffiliated; set by ClanService on join, cleared on leave / disband / kick
	-- Phase F0 — V1.5 expansion prep (foundation tracking; no V1 UI).
	creditsInvestedLifetime: number, -- sticky tycoon-spend signal for V1.5 Tier gate
	tier: number, -- 0 = Drop Pod (V1 default); V1.5 TierService sets > 0
	-- Phase F4 — FTUE state.
	ftueCompleted: boolean, -- true = onboarding done; FTUE flow skipped on rejoin
	ftueStep: string?, -- current FTUE step; nil when completed; resumes mid-flow on rejoin
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
	battlePassXP = 0,
	battlePassTier = 0,
	battlePassClaimed = {},
	battlePassSeasonId = nil,
	raidWins = 0,
	raidLosses = 0,
	raidsDefended = 0,
	raidsRaided = 0,
	wavesSurvived = 0,
	turretsKilled = 0,
	dronesKilled = 0,
	clanId = nil,
	creditsInvestedLifetime = 0,
	tier = 0,
	ftueCompleted = false,
	ftueStep = nil,
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
