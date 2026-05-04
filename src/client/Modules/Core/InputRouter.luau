--!strict
--[[
	Outpost-7 — input → action mapping.

	Phase B5. For now, a single binding: the **M** key cycles
	ModeController.SetMode between Build and Combat. Gated by
	`Constants.FEATURES.debugModeToggle` — flip false in Phase F4
	once Combat content makes the toggle a real gameplay decision
	rather than a debug aid.

	Subsequent phases append bindings here:
	  - Combat hot bar (B6+/E2)
	  - Drone swarm command keys (E2)
	  - Pause menu / shop hotkeys (D1)
--]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Constants = require(Shared:WaitForChild("Constants"))
local Enums = require(Shared:WaitForChild("Enums"))

local ModeController = require(script.Parent.ModeController)

local InputRouter = {}

local function toggleMode()
	local current = ModeController.GetMode()
	if current == Enums.Mode.Build then
		ModeController.SetMode(Enums.Mode.Combat)
	else
		ModeController.SetMode(Enums.Mode.Build)
	end
end

function InputRouter.Init()
	if not Constants.FEATURES.debugModeToggle then
		return
	end

	UserInputService.InputBegan:Connect(function(input: InputObject, processed: boolean)
		if processed then
			return
		end
		if input.KeyCode == Enum.KeyCode.M then
			toggleMode()
		end
	end)
end

return InputRouter
