--!strict
-- Outpost-7 — client bootstrap.
--
-- Thin requires-and-Init() bootstrapper. Real logic lives in Modules/.
-- A4: requires the shared modules to verify replication. The print is
-- the audit signal — if it lands in Studio's Output, ReplicatedStorage
-- is replicating the Shared tree to the client.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Constants = require(Shared:WaitForChild("Constants"))
local Enums = require(Shared:WaitForChild("Enums"))

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
