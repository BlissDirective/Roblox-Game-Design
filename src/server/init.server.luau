--!strict
-- Outpost-7 — server bootstrap.
--
-- Thin requires-and-Init() bootstrapper. Real logic lives in Modules/.
-- Order matters: persistence (DataManager) initializes before any module
-- that reads/writes player data.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Constants = require(Shared:WaitForChild("Constants"))

local DataManager = require(script.Modules.Player.DataManager)

DataManager.Init()

print(
	string.format(
		"[Outpost-7] Server bootstrap complete. store=%s, bindToCloseTimeout=%ds",
		Constants.DATASTORE.StoreName,
		Constants.DATASTORE.BindToCloseTimeoutSeconds
	)
)
