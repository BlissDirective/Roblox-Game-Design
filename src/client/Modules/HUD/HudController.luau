--!strict
--[[
	Outpost-7 — top-level HUD orchestrator.

	Phase B4 (original). Phase G5.2a refactor.

	Owns the lifecycle of every on-screen HUD piece. G5.2a adds:
	  - ActionBar: mode-contextual bottom action bar (Shop / Quests /
	    Clan + mode toggle) replacing the per-controller hardcoded
	    toggle buttons.
	  - BattlePassWidget: always-visible top-left BP progress widget,
	    tap-through to BattlePassPanel.

	Init order is deliberate:
	  1. Currency pills (Credits, Cores) — independent of mode
	  2. ActionBar — subscribes to ModeController for visibility swap
	  3. BattlePassWidget — subscribes to BattlePassState Remote

	The currency pills + BP widget + action bar comprise the "always-
	visible" surface; combat overlay (wave timer + drones) is owned by
	CombatController and shows on top of these in Combat mode.
--]]

local CreditsDisplay = require(script.Parent.CreditsDisplay)
local CoresDisplay = require(script.Parent.CoresDisplay)
local ActionBar = require(script.Parent.ActionBar)
local BattlePassWidget = require(script.Parent.BattlePassWidget)

local HudController = {}

function HudController.Init()
	CreditsDisplay.Init()
	CoresDisplay.Init()
	ActionBar.Init()
	BattlePassWidget.Init()
end

return HudController
