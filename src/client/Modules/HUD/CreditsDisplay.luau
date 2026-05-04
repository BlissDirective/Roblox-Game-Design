--!strict
--[[
	Outpost-7 — Credits HUD readout.

	Phase B4. Top-right ScreenGui showing the player's current Credits.
	Server fires `Remotes.CreditsChanged` per change — this module is
	a pure listener; the value displayed is never the source of truth.

	Visual style is debug-grade for V1; Phase G aesthetic pass replaces
	with neon-tactical theming (consistent fonts, color, spring-based
	tween on value changes).
--]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Remotes = require(Shared:WaitForChild("Remotes"))
local HudFormat = require(Shared:WaitForChild("Modules"):WaitForChild("Lib"):WaitForChild("HudFormat"))

local CreditsDisplay = {}

local label: TextLabel? = nil

local function setText(value: number)
	if label then
		label.Text = string.format("%s Credits", HudFormat.Abbreviated(value))
	end
end

local function build()
	local player = Players.LocalPlayer
	local playerGui = player:WaitForChild("PlayerGui")

	local existing = playerGui:FindFirstChild("CreditsHud")
	if existing then
		existing:Destroy()
	end

	local gui = Instance.new("ScreenGui")
	gui.Name = "CreditsHud"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.Parent = playerGui

	local frame = Instance.new("Frame")
	frame.Size = UDim2.new(0, 220, 0, 56)
	frame.Position = UDim2.new(1, -240, 0, 16)
	frame.BackgroundColor3 = Color3.fromRGB(20, 24, 32)
	frame.BackgroundTransparency = 0.2
	frame.BorderSizePixel = 0
	frame.Parent = gui

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 8)
	corner.Parent = frame

	local stroke = Instance.new("UIStroke")
	stroke.Color = Color3.fromRGB(120, 220, 180)
	stroke.Thickness = 1
	stroke.Transparency = 0.5
	stroke.Parent = frame

	local txt = Instance.new("TextLabel")
	txt.Name = "Value"
	txt.Size = UDim2.new(1, -20, 1, 0)
	txt.Position = UDim2.new(0, 10, 0, 0)
	txt.BackgroundTransparency = 1
	txt.TextColor3 = Color3.fromRGB(220, 240, 200)
	txt.Font = Enum.Font.GothamBold
	txt.TextScaled = true
	txt.TextXAlignment = Enum.TextXAlignment.Right
	txt.Text = "0 Credits"
	txt.Parent = frame

	label = txt
end

function CreditsDisplay.Init()
	build()
	local remote = Remotes.CreditsChanged :: RemoteEvent
	remote.OnClientEvent:Connect(function(newCredits: number)
		setText(newCredits)
	end)
end

return CreditsDisplay
