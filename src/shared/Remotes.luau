--!strict
--[[
	Outpost-7 — shared RemoteEvent / RemoteFunction registry.

	Every Remote in the game lives here. The registry pattern means:
	  1. The trust boundary is auditable from a single file.
	  2. Studio's reload cycle (Rojo re-syncing while a place is open)
	     doesn't create duplicate Instances — getOrCreate reuses.
	  3. Adding a Remote = one entry here + one row in
	     docs/architecture/REMOTES_REGISTRY.md.

	Rate limits and validation rules live with the consumers
	(Server/Security/AntiExploit + RemoteValidator). This file is just
	the wire-shape declaration.
--]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CONTAINER_NAME = "OutpostRemotes"

local function ensureContainer(): Folder
	local existing = ReplicatedStorage:FindFirstChild(CONTAINER_NAME)
	if existing and existing:IsA("Folder") then
		return existing
	end
	if existing then
		-- Unexpected non-Folder under that name. Reclaim it.
		existing:Destroy()
	end
	local folder = Instance.new("Folder")
	folder.Name = CONTAINER_NAME
	folder.Parent = ReplicatedStorage
	return folder
end

local function getOrCreate(name: string, className: "RemoteEvent" | "RemoteFunction"): Instance
	local container = ensureContainer()
	local existing = container:FindFirstChild(name)
	if existing and existing:IsA(className) then
		return existing
	end
	if existing then
		-- Type-shape mismatch (e.g. RemoteEvent where we expected
		-- RemoteFunction). Rebuild.
		existing:Destroy()
	end
	local instance = Instance.new(className)
	instance.Name = name
	instance.Parent = container
	return instance
end

local Remotes = {
	-- Phase B1 — Build:
	-- Client → Server. Args: (buildableId: string, cellX: number, cellZ: number).
	-- Server validates and places (or silently rejects). Phase B4 may
	-- add a paired PlacementResult event for UI feedback.
	PlaceBuilding = getOrCreate("PlaceBuilding", "RemoteEvent") :: RemoteEvent,

	-- Phase B2 — Economy:
	-- Server → Client. Args: (newCredits: number).
	-- Notification only — the client renders this for HUD display; it
	-- is not the source of truth. CurrencyService fires per affected
	-- player on every credit change (income tick, spend, grant).
	CreditsChanged = getOrCreate("CreditsChanged", "RemoteEvent") :: RemoteEvent,

	-- Phase D5 — Economy / Cores HUD:
	-- Server → Client. Args: (newCores: number).
	-- Same shape and contract as CreditsChanged. Fires from
	-- CurrencyService.AddCores (quest claim rewards in C3, BP tier
	-- claims in D4, Core Pack purchases in D2 once real IDs land).
	CoresChanged = getOrCreate("CoresChanged", "RemoteEvent") :: RemoteEvent,

	-- Phase C1 — Retention / daily login:
	-- Server → Client. Args: (state: DailyLoginManager.State).
	-- Server pushes the current claim state on join + after each
	-- successful claim. Client renders the popup off this.
	DailyLoginState = getOrCreate("DailyLoginState", "RemoteEvent") :: RemoteEvent,
	-- Client → Server (RemoteFunction). Args: ().
	-- Server validates (server-side os.time, exploit-proof), grants,
	-- returns DailyLoginManager.ClaimResult.
	ClaimDailyReward = getOrCreate("ClaimDailyReward", "RemoteFunction") :: RemoteFunction,

	-- Phase C2 — Retention / restocking shop:
	-- Server → Client. Args: (state: ShopService.State).
	-- Pushed on join + after every successful BuyShopItem + on
	-- rotation boundary crossings.
	ShopState = getOrCreate("ShopState", "RemoteEvent") :: RemoteEvent,
	-- Client → Server (RemoteFunction). Args: (blueprintId: string).
	-- Returns ShopService.BuyResult.
	BuyShopItem = getOrCreate("BuyShopItem", "RemoteFunction") :: RemoteFunction,

	-- Phase C3 — Retention / daily quests:
	-- Server → Client. Args: (state: DailyQuestManager.State).
	-- Pushed on join, on every quest progress advance, after each
	-- claim, and on UTC day rollovers.
	DailyQuestState = getOrCreate("DailyQuestState", "RemoteEvent") :: RemoteEvent,
	-- Client → Server (RemoteFunction). Args: (questId: string).
	-- Returns DailyQuestManager.ClaimResult.
	ClaimQuest = getOrCreate("ClaimQuest", "RemoteFunction") :: RemoteFunction,

	-- Phase C4 — Retention / offline progression:
	-- Server → Client. Args: (payload: OfflineProgression.WelcomeBack).
	-- Fired once per join when the player has accrued offline income.
	-- Skipped silently for new players or players with no extractors.
	WelcomeBack = getOrCreate("WelcomeBack", "RemoteEvent") :: RemoteEvent,

	-- Phase D4 — Monetization / Battle Pass:
	-- Server → Client. Args: (state: BattlePassService.State).
	-- Pushed on join, on every GrantXP that bumps the tier or XP,
	-- after every successful ClaimBattlePassTier, and when premium
	-- ownership flips mid-session.
	BattlePassState = getOrCreate("BattlePassState", "RemoteEvent") :: RemoteEvent,
	-- Client → Server (RemoteFunction). Args: (tier: number, track: "free" | "premium").
	-- Returns BattlePassService.ClaimResult.
	ClaimBattlePassTier = getOrCreate("ClaimBattlePassTier", "RemoteFunction") :: RemoteFunction,

	-- Phase D5 — Monetization / GamePass ownership replication:
	-- Server → Client. Args: (ownership: { [passKey: string]: boolean }).
	-- Pushed on join (after first prime) and on every flip via
	-- GamePassService.OnOwnershipChanged. Client uses this to render
	-- "Owned" badges on the GamePass shop panel without needing to
	-- call UserOwnsGamePassAsync (which has the staleness bug per
	-- ADR-006). Server is the source of truth.
	OwnershipState = getOrCreate("OwnershipState", "RemoteEvent") :: RemoteEvent,

	-- Phase E2 — PvE waves:
	-- Server → Client. Args: (info: WaveDirector.StartInfo).
	-- Fires when a wave begins for this player. Carries `waveNumber`,
	-- `alienCount`, `endsAt` (os.time). Client renders the wave HUD off
	-- this. Server is authoritative — the client renders countdown but
	-- can't end the wave early.
	WaveStarted = getOrCreate("WaveStarted", "RemoteEvent") :: RemoteEvent,
	-- Server → Client. Args: (result: WaveDirector.EndResult).
	-- Fires when a wave ends (timer expired, all aliens dead, or player
	-- character died). Client uses this to clear the wave HUD + fire
	-- the result toast.
	WaveEnded = getOrCreate("WaveEnded", "RemoteEvent") :: RemoteEvent,

	-- Phase E1 — Raid / matchmaking + match flow:
	-- Client → Server (RemoteFunction). Args: ("queue" | "cancel").
	-- Returns RaidMatchmaker.QueueResult. Server enqueues / cancels via
	-- MemoryStoreService SortedMap; never trusts the client for any
	-- match outcome.
	RaidQueue = getOrCreate("RaidQueue", "RemoteFunction") :: RemoteFunction,
	-- Server → Client. Args: (state: RaidMatchmaker.QueueState).
	-- Pushed on enqueue, cancel, match, deadline-pop, raid-end. Client
	-- renders queue UI off this; server is authoritative.
	RaidQueueState = getOrCreate("RaidQueueState", "RemoteEvent") :: RemoteEvent,
	-- Server → Client. Args: (info: RaidSession.StartInfo).
	-- Fires once in the raid place when the round actually begins.
	RaidStarted = getOrCreate("RaidStarted", "RemoteEvent") :: RemoteEvent,
	-- Server → Client. Args: (outcome: RaidSession.Outcome).
	-- Fires for the attacker at round end (raid place) AND for the
	-- defender on their home server when the outcome MessagingService
	-- payload arrives (so they see a "Your colony was raided" toast).
	RaidEnded = getOrCreate("RaidEnded", "RemoteEvent") :: RemoteEvent,
}

return Remotes
