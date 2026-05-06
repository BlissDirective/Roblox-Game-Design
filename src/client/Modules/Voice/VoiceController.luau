--!strict
--[[
	Outpost-7 — voice indicator (client).

	Phase E4. Listens to `VoiceState` and renders a minimal mic
	indicator top-right when the player is in the raid place AND voice
	is available for their account. Three visual states:

	  - Hidden (`inRaidPlace == false`): main place; no indicator
	  - Muted (`inRaidPlace == true` AND voice unavailable): grey mic
	    icon with "voice unavailable" tooltip — surfaces account-level
	    blockers (under-13 / region / Roblox-side voice off)
	  - Active (`inRaidPlace == true` AND voice available): red mic
	    icon with "voice active" label

	The mic toggle itself lives in Roblox's native voice UI; this
	indicator is read-only. Phase G replaces with proper mic icons +
	speaker amplitude visualization.

	Public API:
	  Init  — wires VoiceState listener + builds indicator
--]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Remotes = require(Shared:WaitForChild("Remotes"))

local VoiceController = {}

type State = {
	enabled: boolean,
	userVoiceAvailable: boolean,
	inRaidPlace: boolean,
}

local current: State = { enabled = false, userVoiceAvailable = false, inRaidPlace = false }

local function ensureScreenGui(): ScreenGui
	local pg = Players.LocalPlayer:WaitForChild("PlayerGui") :: PlayerGui
	local gui = pg:FindFirstChild("OutpostVoice")
	if gui and gui:IsA("ScreenGui") then
		return gui
	end
	gui = Instance.new("ScreenGui")
	gui.Name = "OutpostVoice"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.Parent = pg
	return gui :: ScreenGui
end

local function refresh()
	local gui = ensureScreenGui()
	local existing = gui:FindFirstChild("VoiceIndicator")
	if not current.inRaidPlace then
		if existing then
			existing:Destroy()
		end
		return
	end

	local label: TextLabel
	if existing and existing:IsA("TextLabel") then
		label = existing
	else
		if existing then
			existing:Destroy()
		end
		label = Instance.new("TextLabel")
		label.Name = "VoiceIndicator"
		label.Size = UDim2.fromOffset(160, 32)
		label.Position = UDim2.new(1, -176, 0, 8)
		label.BackgroundColor3 = Color3.fromRGB(20, 20, 28)
		label.BorderSizePixel = 0
		label.Font = Enum.Font.GothamBold
		label.TextSize = 13

		local stroke = Instance.new("UIStroke")
		stroke.Thickness = 2
		stroke.Parent = label

		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(0, 6)
		corner.Parent = label

		label.Parent = gui
	end

	local stroke = label:FindFirstChildOfClass("UIStroke")
	if current.userVoiceAvailable and current.enabled then
		label.Text = "🎤  Voice Active"
		label.TextColor3 = Color3.fromRGB(255, 100, 100)
		if stroke then
			stroke.Color = Color3.fromRGB(220, 80, 90)
		end
	else
		label.Text = "🎤  Voice Off"
		label.TextColor3 = Color3.fromRGB(140, 140, 140)
		if stroke then
			stroke.Color = Color3.fromRGB(80, 80, 90)
		end
	end
end

function VoiceController.Init()
	local stateRemote = Remotes.VoiceState :: RemoteEvent
	stateRemote.OnClientEvent:Connect(function(state: any)
		if typeof(state) ~= "table" then
			return
		end
		current = state :: State
		refresh()
	end)
end

return VoiceController
