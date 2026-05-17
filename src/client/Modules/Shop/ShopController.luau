--!strict
--[[
	Outpost-7 — shop orchestrator (client).

	Phase C2 (original). Phase G5.2a refactor: the local toggle button
	is gone — the new HudController action bar owns the Shop toggle and
	calls `ShopPanel.Toggle()` directly. Controller's only remaining
	job is `ShopPanel.Init()` for the panel surface itself.

	The panel's internal theme migration (Components.Panel + Theme
	palette slots) lands in G5.2b.
--]]

local ShopPanel = require(script.Parent.ShopPanel)

local ShopController = {}

function ShopController.Init()
	ShopPanel.Init()
end

return ShopController
