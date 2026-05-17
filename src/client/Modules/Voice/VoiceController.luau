--!strict
--[[
	Outpost-7 — voice indicator (client).

	Phase E4 (original). Phase G5.2c theme migration.

	Listens to `VoiceState` and renders a mic indicator top-right when
	the player is in the raid place AND voice is available. Three
	visual states:

	  - Hidden (`inRaidPlace == false`): main place; no indicator
	  - Muted: grey stroke + "Voice Off" label
	  - Active: danger-slot (red across all themes) stroke + label

	The active-state color is intentionally pulled from the Theme's
	`danger` slot — the universal "mic broadcasting" visual is red
	regardless of biome, and the Theme's danger slot is the red-family
	color across all 4 palettes.

	The mic toggle itself lives in Roblox's native voice UI; this
	indicator is read-only.
--]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Remotes = require(Shared:WaitForChild("Remotes"))
local Components = require(Shared:WaitForChild("Modules"):WaitForChild("UI"):WaitForChild("Components"))
local Theme = require(Shared:WaitForChild("Modules"):WaitForChild("UI"):WaitForChild("Theme"))

local VoiceController = {}

type State = {
	enabled: boolean,
	userVoiceAvailable: boolean,
	inRaidPlace: boolean,
}

local current: State = { enabled = false, userVoiceAvailable = false, inRaidPlace = false }

local screenGui: ScreenGui?
local indicatorFrame: Frame?
local labelInst: TextLabel?

local function ensureScreenGui(): ScreenGui
	if screenGui and screenGui.Parent then
		return screenGui
	end
	local pg = Players.LocalPlayer:WaitForChild("PlayerGui") :: PlayerGui
	local existing = pg:FindFirstChild("OutpostVoice")
	if existing and existing:IsA("ScreenGui") then
		screenGui = existing
		return existing
	end
	local gui = Instance.new("ScreenGui")
	gui.Name = "OutpostVoice"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.DisplayOrder = 19
	gui.Parent = pg
	screenGui = gui
	return gui
end

local function isActive(): boolean
	return current.userVoiceAvailable and current.enabled
end

local function ensureIndicator()
	if indicatorFrame and indicatorFrame.Parent then
		return
	end
	local gui = ensureScreenGui()
	-- Sharp-angular sci-fi frame in the danger-slot color when active,
	-- textMuted when off. StrokedFrame handles the corner+stroke
	-- bookkeeping and live-tints on theme swap.
	local frame = Components.StrokedFrame({
		parent = gui,
		name = "VoiceIndicator",
		size = UDim2.fromOffset(160, 32),
		position = UDim2.new(1, -176, 0, 8),
		bgSlot = "panel",
		strokeSlot = "danger", -- overridden in refresh() based on active state
		cornerAccent = false,
	})
	indicatorFrame = frame

	local label = Instance.new("TextLabel")
	label.Name = "Label"
	label.BackgroundTransparency = 1
	label.Size = UDim2.new(1, -16, 1, 0)
	label.Position = UDim2.new(0, 8, 0, 0)
	label.Font = Enum.Font.GothamBold
	label.TextSize = 13
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.Parent = frame
	labelInst = label
end

local function refresh()
	if not current.inRaidPlace then
		if indicatorFrame then
			indicatorFrame:Destroy()
			indicatorFrame = nil
			labelInst = nil
		end
		return
	end
	ensureIndicator()
	if not labelInst or not indicatorFrame then
		return
	end
	local stroke = indicatorFrame:FindFirstChildOfClass("UIStroke")
	if isActive() then
		labelInst.Text = "MIC  Voice Active"
		labelInst.TextColor3 = Theme.GetActive().danger
		if stroke then
			stroke.Color = Theme.GetActive().danger
		end
	else
		labelInst.Text = "MIC  Voice Off"
		labelInst.TextColor3 = Theme.GetActive().textMuted
		if stroke then
			stroke.Color = Theme.GetActive().textMuted
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
	-- Live re-tint on biome theme swap (the active/muted colors are
	-- biome-aware via Theme.danger / Theme.textMuted).
	Theme.Changed:Connect(function()
		refresh()
	end)
end

return VoiceController
