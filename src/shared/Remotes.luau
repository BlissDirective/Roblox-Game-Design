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

	-- Phase E3 — Clans / squads / shared stash / chat:
	-- Server → Client. Args: (state: ClanService.State?).
	-- Pushed on join (after profile load), on every clan mutation
	-- (member join / leave / kick, deposit, withdraw, approve, chat),
	-- and on cross-server cache invalidations. nil = player has no clan.
	ClanState = getOrCreate("ClanState", "RemoteEvent") :: RemoteEvent,
	-- Client → Server (Function). Args: (name: string, tag: string).
	-- Returns ClanService.Result. Server validates name/tag length +
	-- character set; deducts the create cost (placeholder 0 in V1, tunable);
	-- writes ClanData via UpdateAsync; sets player.clanId.
	CreateClan = getOrCreate("CreateClan", "RemoteFunction") :: RemoteFunction,
	-- Client → Server (Function). Args: (clanId: string).
	-- Returns ClanService.Result. Server checks clan exists, has room,
	-- player isn't already in a clan; appends the player as a member via
	-- UpdateAsync; sets player.clanId.
	JoinClan = getOrCreate("JoinClan", "RemoteFunction") :: RemoteFunction,
	-- Client → Server (Function). Args: ().
	-- Returns ClanService.Result. Removes the player from their clan via
	-- UpdateAsync. If the player is the leader and other members exist,
	-- leadership transfers to the longest-tenured officer or oldest
	-- member. If they were the last member, the clan is deleted.
	LeaveClan = getOrCreate("LeaveClan", "RemoteFunction") :: RemoteFunction,
	-- Client → Server (Function). Args: (targetUserId: number).
	-- Returns ClanService.Result. Leader / officer can kick members
	-- (officer can't kick officer/leader). Removes target from clan via
	-- UpdateAsync; clears their profile.clanId on next push.
	KickFromClan = getOrCreate("KickFromClan", "RemoteFunction") :: RemoteFunction,
	-- Client → Server (Function). Args: (amount: number).
	-- Returns ClanStashLedger.Result. Atomically deducts player credits
	-- via CurrencyService.TrySpend, then UpdateAsync adds to clan
	-- stashCredits.
	ClanStashDeposit = getOrCreate("ClanStashDeposit", "RemoteFunction") :: RemoteFunction,
	-- Client → Server (Function). Args: (amount: number).
	-- Returns ClanStashLedger.Result. If amount <= AutoApproveWithdrawalThreshold,
	-- atomically deducts clan stash + grants player credits. Above the
	-- threshold, queues a PendingWithdrawal entry awaiting leader
	-- approval.
	ClanStashWithdraw = getOrCreate("ClanStashWithdraw", "RemoteFunction") :: RemoteFunction,
	-- Client → Server (Function). Args: (withdrawalId: string, approve: boolean).
	-- Returns ClanStashLedger.Result. Leader-only. On approve: removes
	-- pending entry, deducts stash, publishes WithdrawalGrantTopic so
	-- the requester's home server applies the credits. On deny:
	-- removes pending entry; no grant.
	ClanStashApprove = getOrCreate("ClanStashApprove", "RemoteFunction") :: RemoteFunction,
	-- Client → Server (Function). Args: (message: string).
	-- Returns ClanChatService.Result. Server validates length + sanitizes,
	-- publishes to MessagingService topic outpost.clan.chat.<clanId>
	-- (at-least-once delivery to all servers with members of this clan).
	ClanChatSend = getOrCreate("ClanChatSend", "RemoteFunction") :: RemoteFunction,
	-- Server → Client. Args: (entry: ClanChatService.Entry).
	-- Fired only to local clan members when a chat message lands on
	-- this server (either originated here or arrived via MessagingService).
	ClanChatReceived = getOrCreate("ClanChatReceived", "RemoteEvent") :: RemoteEvent,

	-- Phase G7 — Cosmetic system:
	-- Server → Client. Args: (state: CosmeticService.State).
	-- Pushed on join (after profile load), on every grant (BP claim,
	-- VIP pass purchase, first-join defaults), and on every equip
	-- change. Carries `owned` (map of cosmeticId → acquiredAt) and
	-- `equipped` (map of slot → cosmeticId). Notification-only;
	-- server is the source of truth.
	CosmeticState = getOrCreate("CosmeticState", "RemoteEvent") :: RemoteEvent,
	-- Client → Server (Function). Args: (slot: string, cosmeticId: string).
	-- Server validates: slot is in Constants.COSMETIC.Slots, cosmeticId
	-- is in CosmeticRegistry, cosmetic.slot matches the slot arg, player
	-- owns the cosmetic. On success, mutates profile.equippedCosmetics
	-- and re-applies the cosmetic to the character. Returns
	-- CosmeticService.Result.
	EquipCosmetic = getOrCreate("EquipCosmetic", "RemoteFunction") :: RemoteFunction,
	-- Server → Client. Args: (toast: CosmeticService.UnlockToast).
	-- Fired when a cosmetic is granted (BP claim, VIP unlock, etc.)
	-- so the client can show a "New cosmetic unlocked!" toast. Carries
	-- cosmeticId + source for display.
	CosmeticUnlocked = getOrCreate("CosmeticUnlocked", "RemoteEvent") :: RemoteEvent,

	-- Phase F4 — FTUE:
	-- Server → Client. Args: (state: FTUEService.State).
	-- Pushed on join (after profile load) for first-time players, and
	-- on every step transition. Carries `step`, `hint` (UI overlay
	-- copy), and step-specific payload (e.g., `targetCellX`, `targetCellZ`
	-- for the scout step's highlighted node). Server is authoritative —
	-- client renders hints + cinematic but cannot forge step transitions.
	-- For returning players (ftueCompleted == true), server fires nil
	-- once on join so the client clears any stale overlay.
	FTUEState = getOrCreate("FTUEState", "RemoteEvent") :: RemoteEvent,
	-- Client → Server (RemoteFunction). Args: (step: string).
	-- Client acks completion of a step it owns (e.g., the cinematic
	-- finishing or being skipped). Server validates the ack matches
	-- the player's current step and advances. Steps the server owns
	-- (auto-advance from PlacementService / CurrencyService events)
	-- ignore the ack — server is the sole authority. Returns
	-- FTUEService.AckResult.
	FTUEStepAck = getOrCreate("FTUEStepAck", "RemoteFunction") :: RemoteFunction,

	-- Phase E5 — Leaderboards + friends:
	-- Server → Client. Args: (boards: LeaderboardService.BoardsState).
	-- Pushed on join (after first board fetch) + on every cache refresh
	-- (~5 min). Carries top-N entries for both the Global Credits and
	-- Weekly Raid Wins boards. Notification-only — server is the source
	-- of truth, client renders.
	LeaderboardState = getOrCreate("LeaderboardState", "RemoteEvent") :: RemoteEvent,
	-- Server → Client. Args: (state: FriendsService.State).
	-- Pushed on join (after GetFriendsAsync resolves) + on every refresh
	-- (1hr) + on local presence change (a friend joins/leaves this
	-- server). Carries the full friend list with `inThisServer` flag
	-- per friend.
	FriendsList = getOrCreate("FriendsList", "RemoteEvent") :: RemoteEvent,
	-- Client → Server (Function). Args: ().
	-- Triggers a manual refresh of the player's friends list (yielding
	-- `GetFriendsAsync`). Returns FriendsService.Result. Rate-limited
	-- semantically: refreshes more often than every 60s no-op.
	RefreshFriends = getOrCreate("RefreshFriends", "RemoteFunction") :: RemoteFunction,

	-- Phase E4 — Spatial Voice gate:
	-- Server → Client. Args: (state: VoiceGate.State).
	-- Pushed on join (after the place identity is determined) + on every
	-- voice availability change. Carries `enabled` (place-level
	-- VoiceChatService.EnableDefaultVoice), `userVoiceAvailable` (this
	-- specific player's account has voice permission), and `inRaidPlace`
	-- (whether the indicator should render at all). Notification-only —
	-- the client HUD shows a mic indicator off this; mic toggle itself
	-- is owned by Roblox's native voice UI.
	VoiceState = getOrCreate("VoiceState", "RemoteEvent") :: RemoteEvent,

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

	-- Phase G4 — audio cue broadcast (one-shot SFX / music transitions).
	-- Server → Client. Args: (cueId: string, opts: AudioCueOptions?).
	-- AudioCueOptions: { position?: Vector3, volume?: number, pitch?: number,
	--                    targetPart?: BasePart, attachTo?: Instance, loopId?: string }.
	-- One-shot cues (turret fire, drone fire, claim chime) leave `loopId`
	-- nil. Looping music tracks set `loopId` so the client can crossfade
	-- to a new track keyed by the same id. AudioController throttles
	-- identical cueIds within Constants.AUDIO.ThrottleMs to coalesce
	-- sub-frame bursts.
	-- Pure-client UI sounds (button click, panel open) bypass this Remote
	-- entirely — AudioController.PlayLocal handles them directly.
	AudioCue = getOrCreate("AudioCue", "RemoteEvent") :: RemoteEvent,

	-- Phase G5 — UI preference push. Client → Server. Args: payload =
	-- { dominantThumb = "left" | "right" }. Server validates the
	-- enum, writes to profile.uiPrefs, no response (fire-and-forget).
	-- Rate-limited at Constants.RATE_LIMITS.Default (the value only
	-- changes once per session at most under the normal heuristic).
	UiPrefsUpdate = getOrCreate("UiPrefsUpdate", "RemoteEvent") :: RemoteEvent,
	-- Phase G5 — UI preference replication. Server → Client. Args:
	-- payload = { dominantThumb = "left" | "right" | nil }. Fires once
	-- per session right after DataManager loads the profile, so
	-- ActionBar can apply the persisted thumb layout before the player
	-- sees their first frame.
	UiPrefsState = getOrCreate("UiPrefsState", "RemoteEvent") :: RemoteEvent,
}

return Remotes
