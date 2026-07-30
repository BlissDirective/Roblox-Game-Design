--!strict
--[[
	Outpost-7 — player weapon input (client).

	Phase R3. The client half of the rifle. In Combat (first-person) mode a
	fire input sends the camera's aim direction to the server, which does all
	the authoritative work (raycast from the real character position, damage,
	tracer). This controller sends ONLY a direction — never an origin, hit, or
	damage value — so there is nothing here worth spoofing.

	Fire gating:
	  - Only fires in Combat mode (ModeController). Build/Raid taps are ignored
	    so weapon fire never fights placement or menu input.
	  - A client-side cooldown matches the server's hard cooldown so we don't
	    spam the Remote past what the server will honor anyway.

	Public API:
	  Init()  — bind fire input
--]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Constants = require(Shared:WaitForChild("Constants"))
local Enums = require(Shared:WaitForChild("Enums"))
local Remotes = require(Shared:WaitForChild("Remotes"))

local ModeController = require(script.Parent.Parent.Core.ModeController)

local WeaponController = {}

local lastFireAt = 0

local function fire()
	if ModeController.GetMode() ~= Enums.Mode.Combat then
		return
	end
	-- Client-side cooldown mirrors the server's hard cooldown (Remote spam
	-- past this is dropped server-side anyway).
	local now = os.clock()
	if now - lastFireAt < Constants.COMBAT.WeaponFireCooldownSeconds then
		return
	end
	local camera = Workspace.CurrentCamera
	if not camera then
		return
	end
	-- Aim = where the first-person camera looks. The server ignores our
	-- origin and raycasts from the character, so we only need the direction.
	local direction = camera.CFrame.LookVector
	if direction.Magnitude <= 0 then
		return
	end
	lastFireAt = now
	local remote = Remotes.FireWeapon :: RemoteEvent
	remote:FireServer(direction.Unit)
end

function WeaponController.Init()
	UserInputService.InputBegan:Connect(function(input: InputObject, processed: boolean)
		if processed then
			return
		end
		if
			input.UserInputType == Enum.UserInputType.MouseButton1
			or input.UserInputType == Enum.UserInputType.Touch
		then
			fire()
		end
	end)
end

return WeaponController
