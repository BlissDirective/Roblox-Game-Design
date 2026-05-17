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

local Theme = require(Shared:WaitForChild("Modules"):WaitForChild("UI"):WaitForChild("Theme"))

local HudController = require(script.Modules.HUD.HudController)
local ToastService = require(script.Modules.HUD.ToastService)
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
local CosmeticController = require(script.Modules.Cosmetics.CosmeticController)
local AudioController = require(script.Modules.Audio.AudioController)

-- G4: AudioController.Init wires the AudioCue Remote listener BEFORE
-- any other controller fires a local UI cue, so the throttle ledger
-- is live from frame 0.
AudioController.Init()

-- G5: Theme.BindClientReplication subscribes to the ReplicatedStorage
-- `OutpostActiveTheme` StringValue so server-side biome theme swaps
-- propagate to the client palette + every Components-built widget.
-- Must run BEFORE HUD pieces build so they read the active palette
-- on first frame.
Theme.BindClientReplication()

-- G5: ToastService builds the 3 split-by-severity containers (top-
-- center / bottom-center / right-column) and subscribes to
-- CosmeticUnlocked for the built-in info toast. Init early so any
-- controller can fire toasts during their own Init.
ToastService.Init()

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
CosmeticController.Init()

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
