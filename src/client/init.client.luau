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

HudController.Init()
CameraController.Init()
InputRouter.Init()
BuildController.Init()
DailyLoginPopup.Init()
ShopController.Init()
DailyQuestsPanel.Init()
WelcomeBackPopup.Init()
MonetizationController.Init()

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
