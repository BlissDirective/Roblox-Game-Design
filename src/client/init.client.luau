--!strict
-- Outpost-7 — client bootstrap.
--
-- Thin requires-and-Init() bootstrapper. Real logic lives in Modules/.
-- Order:
--   1. HUD pieces (CreditsDisplay, ...) — no deps; up first
--   2. Camera + Input + Mode (B5) — apply initial mode before user
--      input can override
--   3. Build mode (palette + preview + input) — listens to mode
--      changes from ModeController

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Constants = require(Shared:WaitForChild("Constants"))
local Enums = require(Shared:WaitForChild("Enums"))

local HudController = require(script.Modules.HUD.HudController)
local CameraController = require(script.Modules.Core.CameraController)
local InputRouter = require(script.Modules.Core.InputRouter)
local BuildController = require(script.Modules.Build.BuildController)
local DailyLoginPopup = require(script.Modules.Retention.DailyLoginPopup)
local ShopController = require(script.Modules.Shop.ShopController)
local DailyQuestsPanel = require(script.Modules.Retention.DailyQuestsPanel)
local WelcomeBackPopup = require(script.Modules.Retention.WelcomeBackPopup)
local MonetizationController = require(script.Modules.Shop.MonetizationController)
local RaidController = require(script.Modules.Raid.RaidController)
local CombatController = require(script.Modules.Combat.CombatController)
local ClanController = require(script.Modules.Social.ClanController)
local LeaderboardController = require(script.Modules.Social.LeaderboardController)
local FriendsPanel = require(script.Modules.Social.FriendsPanel)
local VoiceController = require(script.Modules.Voice.VoiceController)
local FTUEController = require(script.Modules.FTUE.FTUEController)

HudController.Init()
CameraController.Init()
InputRouter.Init()
BuildController.Init()
DailyLoginPopup.Init()
ShopController.Init()
DailyQuestsPanel.Init()
WelcomeBackPopup.Init()
MonetizationController.Init()
RaidController.Init()
CombatController.Init()
ClanController.Init()
LeaderboardController.Init()
FriendsPanel.Init()
VoiceController.Init()
FTUEController.Init()

print(
	string.format(
		"[Outpost-7] Client bootstrap complete. tickRate=%ds, gridSize=%d, defaultRateLimit=%d, defaultMode=%s, defaultBiome=%s, debugModeToggle=%s",
		Constants.TICK.Currency,
		Constants.GRID.Size,
		Constants.RATE_LIMITS.Default,
		Enums.Mode.Build,
		Enums.Biome.Jungle,
		tostring(Constants.FEATURES.debugModeToggle)
	)
)
