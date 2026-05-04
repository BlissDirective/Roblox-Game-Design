--!strict
-- Outpost-7 — server bootstrap.
--
-- Thin requires-and-Init() bootstrapper. Real logic lives in Modules/.
-- Order matters: persistence (DataManager) initializes before any module
-- that reads/writes player data.

local DataManager = require(script.Modules.Player.DataManager)

DataManager.Init()

print("[Outpost-7] Server bootstrap complete.")
