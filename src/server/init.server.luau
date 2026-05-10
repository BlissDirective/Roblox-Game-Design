--!strict
-- Outpost-7 — server bootstrap.
--
-- Thin requires-and-Init() bootstrapper. Real logic lives in Modules/.
-- Branches on `game.PrivateServerId` per ADR-007: an empty string means
-- this is a public main place server, non-empty means a reserved raid
-- instance. The two paths share DataManager + ServerAuthorityBootstrap;
-- everything else is path-specific.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Constants = require(Shared:WaitForChild("Constants"))

local ServerAuthorityBootstrap = require(script.Modules.Lifecycle.ServerAuthorityBootstrap)
local DataManager = require(script.Modules.Player.DataManager)
local AntiExploit = require(script.Modules.Security.AntiExploit)
local AuditLog = require(script.Modules.Security.AuditLog)

local IS_RAID_SERVER = game.PrivateServerId ~= ""

ServerAuthorityBootstrap.Apply()
DataManager.Init()
-- F1: AntiExploit init runs before any C->S Remote handler is wired.
-- Per-Remote handlers call AntiExploit.RateCheck on every invoke.
AntiExploit.Init()
-- F2: AuditLog connects PlayerRemoving cleanup; per-Remote handlers
-- call AuditLog.Record on rate-limit denials and validation failures.
AuditLog.Init()

if IS_RAID_SERVER then
	-- Raid place: minimal stack. No plots, no currency tick, no shop —
	-- the round runs against a snapshot, not a persistent base.
	local RaidSession = require(script.Modules.Raid.RaidSession)
	local VoiceGate = require(script.Modules.Voice.VoiceGate)
	local BiomeLightingService = require(script.Modules.World.BiomeLightingService)
	RaidSession.Init()
	-- Voice is enabled at the place level via raid.project.json's
	-- VoiceChatService.EnableDefaultVoice = true. VoiceGate.Init is
	-- the defensive verifier + state pusher.
	VoiceGate.Init()
	-- G1: biome lighting profile. Raid place inherits the snapshot
	-- defender's biome via teleport data (V1.5+); V1 ships default
	-- jungle.
	BiomeLightingService.Init()
	print(
		string.format(
			"[Outpost-7] Raid bootstrap complete. privateServerId=%s, roundSeconds=%d",
			game.PrivateServerId,
			Constants.RAID.RoundSeconds
		)
	)
else
	-- Main place: full chain.
	local PlotManager = require(script.Modules.World.PlotManager)
	local BiomeLightingService = require(script.Modules.World.BiomeLightingService)
	local ResourceNodeSpawner = require(script.Modules.World.ResourceNodeSpawner)
	local CurrencyService = require(script.Modules.Economy.CurrencyService)
	local PlacementService = require(script.Modules.Build.PlacementService)
	local BuildRestorer = require(script.Modules.Build.BuildRestorer)
	local DailyLoginManager = require(script.Modules.Retention.DailyLoginManager)
	local ShopService = require(script.Modules.Economy.ShopService)
	local DailyQuestManager = require(script.Modules.Retention.DailyQuestManager)
	local OfflineProgression = require(script.Modules.Retention.OfflineProgression)
	local MonetizationService = require(script.Modules.Monetization.MonetizationService)
	local RaidMatchmaker = require(script.Modules.Raid.RaidMatchmaker)
	local RaidRewardService = require(script.Modules.Raid.RaidRewardService)
	local BeamPool = require(script.Modules.Combat.BeamPool)
	local TurretService = require(script.Modules.Combat.TurretService)
	local WaveDirector = require(script.Modules.Combat.WaveDirector)
	local DroneSwarmService = require(script.Modules.Combat.DroneSwarmService)
	local ClanService = require(script.Modules.Social.ClanService)
	local ClanStashLedger = require(script.Modules.Social.ClanStashLedger)
	local ClanChatService = require(script.Modules.Social.ClanChatService)
	local LeaderboardService = require(script.Modules.Social.LeaderboardService)
	local FriendsService = require(script.Modules.Social.FriendsService)
	local VoiceGate = require(script.Modules.Voice.VoiceGate)
	local FTUEService = require(script.Modules.FTUE.FTUEService)

	-- G1: biome lighting profile applied at boot before plot build so
	-- the world Lighting state is set before players see anything.
	BiomeLightingService.Init()
	PlotManager.Init()
	ResourceNodeSpawner.Init()
	CurrencyService.Init()
	-- BeamPool (F3) must Init before TurretService + DroneSwarmService
	-- so the pool is pre-allocated when the first shot fires.
	BeamPool.Init()
	-- TurretService must Init BEFORE PlacementService because turret
	-- placements register with the service synchronously at place time.
	-- (Init only sets up loops + cleanup; RegisterTurret is callable
	-- before Init too — but ordering this way makes the dependency
	-- explicit.)
	TurretService.Init()
	PlacementService.Init()
	BuildRestorer.Init()
	DailyLoginManager.Init()
	ShopService.Init()
	DailyQuestManager.Init()
	-- OfflineProgression must Init AFTER BuildRestorer so the
	-- OnRestoreComplete subscription is registered before the first
	-- player's restore fires.
	OfflineProgression.Init()
	MonetizationService.Init()
	-- Raid hooks live in main place so attackers can queue and the
	-- outcome relay routes credits to home profiles.
	RaidMatchmaker.Init()
	RaidRewardService.Init()
	-- WaveDirector must Init AFTER RaidMatchmaker so OnDeadlinePop
	-- subscription registers against an existing BindableEvent.
	WaveDirector.Init()
	-- DroneSwarmService is independent of wave/raid init order — it
	-- listens to PlayerAdded / CharacterAdded directly. Init last in
	-- the combat group so the alien actors folder exists when the
	-- targeting loop first runs.
	DroneSwarmService.Init()
	-- Social layer (E3). ClanService owns the cache + DataStore RW;
	-- StashLedger and ChatService route through it. ClanService.Init
	-- runs first so its MessagingService subscribe is in place before
	-- the stash ledger's WithdrawalGrant subscribe (avoids ordering
	-- footguns if a leader approves a withdrawal during boot).
	ClanService.Init()
	ClanStashLedger.Init()
	ClanChatService.Init()
	-- Leaderboards + friends (E5). Independent of the rest of the
	-- social stack — own DataStore keyspaces, own Remotes. Init last
	-- in the social group; the score-push loop reads from already-
	-- loaded profiles via DataManager.WaitForData.
	LeaderboardService.Init()
	FriendsService.Init()
	-- VoiceGate (E4) — main-place init pushes `inRaidPlace = false` so
	-- the client clears any stale indicator. Voice is OFF in main per
	-- brainstorm §2.6 (build mode is silent; voice opens during raids
	-- only).
	VoiceGate.Init()
	-- FTUE (F4) — first-time onboarding state machine. Subscribes to
	-- QuestObjectives `place_extractor` + `earn_credits` for auto-
	-- advance; pushes FTUEState on PlayerAdded for first-timers.
	-- Init last so the QuestObjectives handlers it depends on are wired.
	FTUEService.Init()

	print(
		string.format(
			"[Outpost-7] Server bootstrap complete. store=%s, bindToCloseTimeout=%ds, plots=%d",
			Constants.DATASTORE.StoreName,
			Constants.DATASTORE.BindToCloseTimeoutSeconds,
			Constants.WORLD.PlotCount
		)
	)
end
