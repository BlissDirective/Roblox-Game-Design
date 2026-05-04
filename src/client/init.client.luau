--!strict
-- Outpost-7 — client bootstrap.
--
-- Thin requires-and-Init() bootstrapper. Real logic lives in Modules/.
-- Order:
--   1. HUD (CreditsDisplay etc.) — no dependencies; up first.
--   2. Build mode (palette + preview + input) — listens for Remotes
--      that the HUD also reads, but no direct dep.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Constants = require(Shared:WaitForChild("Constants"))
local Enums = require(Shared:WaitForChild("Enums"))

local HudController = require(script.Modules.HUD.HudController)
local BuildController = require(script.Modules.Build.BuildController)

HudController.Init()
BuildController.Init()

print(
	string.format(
		"[Outpost-7] Client bootstrap complete. tickRate=%ds, gridSize=%d, defaultRateLimit=%d, defaultMode=%s, defaultBiome=%s",
		Constants.TICK.Currency,
		Constants.GRID.Size,
		Constants.RATE_LIMITS.Default,
		Enums.Mode.Build,
		Enums.Biome.Jungle
	)
)
