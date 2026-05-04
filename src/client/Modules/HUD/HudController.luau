--!strict
--[[
	Outpost-7 — top-level HUD orchestrator.

	Phase B4. Owns the lifecycle of the on-screen HUD pieces. B4 ships
	with CreditsDisplay only; later phases append (HealthDisplay,
	WaveTimerDisplay, MinimapDisplay, etc.) by adding Init calls here.
--]]

local CreditsDisplay = require(script.Parent.CreditsDisplay)

local HudController = {}

function HudController.Init()
	CreditsDisplay.Init()
end

return HudController
