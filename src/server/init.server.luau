--!strict
-- Outpost-7 — server bootstrap.
--
-- Thin requires-and-Init() bootstrapper. Real logic lives in Modules/.
-- Order matters:
--   1. Server Authority Beta props (must apply before anything reads
--      Workspace.AuthorityMode or relies on the auth model — see ADR-005)
--   2. Persistence (DataManager)
--   3. World structure (PlotManager, ResourceNodeSpawner)
--   4. Systems that depend on the world being built (PlacementService)

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Constants = require(Shared:WaitForChild("Constants"))

local ServerAuthorityBootstrap = require(script.Modules.Lifecycle.ServerAuthorityBootstrap)
local DataManager = require(script.Modules.Player.DataManager)
local PlotManager = require(script.Modules.World.PlotManager)
local ResourceNodeSpawner = require(script.Modules.World.ResourceNodeSpawner)
local CurrencyService = require(script.Modules.Economy.CurrencyService)
local PlacementService = require(script.Modules.Build.PlacementService)
local BuildRestorer = require(script.Modules.Build.BuildRestorer)
local DailyLoginManager = require(script.Modules.Retention.DailyLoginManager)
local ShopService = require(script.Modules.Economy.ShopService)
local DailyQuestManager = require(script.Modules.Retention.DailyQuestManager)
local OfflineProgression = require(script.Modules.Retention.OfflineProgression)

ServerAuthorityBootstrap.Apply()
DataManager.Init()
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

print(
	string.format(
		"[Outpost-7] Server bootstrap complete. store=%s, bindToCloseTimeout=%ds, plots=%d",
		Constants.DATASTORE.StoreName,
		Constants.DATASTORE.BindToCloseTimeoutSeconds,
		Constants.WORLD.PlotCount
	)
)
