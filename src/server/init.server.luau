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

local IS_RAID_SERVER = game.PrivateServerId ~= ""

ServerAuthorityBootstrap.Apply()
DataManager.Init()

if IS_RAID_SERVER then
	-- Raid place: minimal stack. No plots, no currency tick, no shop —
	-- the round runs against a snapshot, not a persistent base.
	local RaidSession = require(script.Modules.Raid.RaidSession)
	RaidSession.Init()
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
	local WaveDirector = require(script.Modules.Combat.WaveDirector)

	PlotManager.Init()
	ResourceNodeSpawner.Init()
	CurrencyService.Init()
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

	print(
		string.format(
			"[Outpost-7] Server bootstrap complete. store=%s, bindToCloseTimeout=%ds, plots=%d",
			Constants.DATASTORE.StoreName,
			Constants.DATASTORE.BindToCloseTimeoutSeconds,
			Constants.WORLD.PlotCount
		)
	)
end
