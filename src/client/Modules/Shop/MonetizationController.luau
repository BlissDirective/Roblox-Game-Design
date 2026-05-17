--!strict
--[[
	Outpost-7 — monetization UI orchestrator (client).

	Phase D5 (original). Phase G5.2a removed the BP toggle (replaced
	by BattlePassWidget). Phase G5.2c removes the Store toggle too
	(now owned by HudController's "Wallet" cluster via the
	`HUD/StoreButton` module).

	The only remaining responsibility is `GamePassPanel.Init()` +
	`BattlePassPanel.Init()` so the panel surfaces exist for the HUD
	triggers to flip visible.
--]]

local GamePassPanel = require(script.Parent.GamePassPanel)
local BattlePassPanel = require(script.Parent.BattlePassPanel)

local MonetizationController = {}

function MonetizationController.Init()
	GamePassPanel.Init()
	BattlePassPanel.Init()
end

return MonetizationController
