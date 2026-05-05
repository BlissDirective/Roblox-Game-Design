--!strict
--[[
	Outpost-7 — client-side mode state machine.

	Phase B5. Single source of truth for the player's current mode
	(Build / Combat / Raid). CameraController reacts to mode changes
	by transitioning camera CFrame; BuildController hides the palette
	out of Build mode; InputRouter publishes via SetMode in response
	to the debug keybind.

	The mode is **client-only state** — Outpost-7's V1 design is that
	the server doesn't care which camera/UX mode the player is in.
	What the server cares about is what Remotes the client sends
	(PlaceBuilding only fires from Build mode); the server validates
	authoritatively regardless. Phase E1 raid orchestration may add
	a server-driven mode push (TeleportService:ReserveServer + force
	Combat) — when it does, that path goes through this same SetMode.
--]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Enums = require(Shared:WaitForChild("Enums"))

local ModeController = {}

export type ModeChangedHandler = (newMode: string, oldMode: string) -> ()

local current: string = Enums.Mode.Build
local handlers: { ModeChangedHandler } = {}

local function isValid(mode: string): boolean
	return mode == Enums.Mode.Build or mode == Enums.Mode.Combat or mode == Enums.Mode.Raid
end

function ModeController.GetMode(): string
	return current
end

function ModeController.SetMode(mode: string)
	if mode == current then
		return
	end
	if not isValid(mode) then
		warn(string.format("[ModeController] Refusing unknown mode: %s", tostring(mode)))
		return
	end
	local old = current
	current = mode
	-- Notify subscribers. task.spawn isolates each handler so a
	-- thrown error in one doesn't block the others.
	for _, handler in handlers do
		task.spawn(handler, mode, old)
	end
end

function ModeController.OnModeChanged(handler: ModeChangedHandler)
	table.insert(handlers, handler)
end

return ModeController
