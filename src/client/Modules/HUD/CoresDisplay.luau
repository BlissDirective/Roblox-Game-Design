--!strict
--[[
	Outpost-7 — Cores HUD readout.

	Phase D5. Top-right ScreenGui showing the player's current Cores
	(premium currency). Listens to `Remotes.CoresChanged`. Same
	pattern + visual style as `CreditsDisplay` (CreditsDisplay sits at
	x=-240; CoresDisplay sits at x=-470 so the two readouts stack
	left-to-right with a small gap).

	Phase G aesthetic pass replaces with neon-tactical theming +
	spring tween on value changes.
--]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Remotes = require(Shared:WaitForChild("Remotes"))
local HudFormat = require(Shared:WaitForChild("Modules"):WaitForChild("Lib"):WaitForChild("HudFormat"))

local CoresDisplay = {}

local label: TextLabel? = nil

local function setText(value: number)
	if label then
		label.Text = string.format("%s Cores", HudFormat.Abbreviated(value))
	end
end

local function build()
	local player = Players.LocalPlayer
	local playerGui = player:WaitForChild("PlayerGui")

	local existing = playerGui:FindFirstChild("CoresHud")
	if existing then
		existing:Destroy()
	end

	local gui = Instance.new("ScreenGui")
	gui.Name = "CoresHud"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.Parent = playerGui

	local frame = Instance.new("Frame")
	frame.Size = UDim2.new(0, 220, 0, 56)
	-- CreditsDisplay sits at (1, -240, 0, 16). Place this just to its
	-- left with a 10-stud gap.
	frame.Position = UDim2.new(1, -470, 0, 16)
	frame.BackgroundColor3 = Color3.fromRGB(20, 24, 32)
	frame.BackgroundTransparency = 0.2
	frame.BorderSizePixel = 0
	frame.Parent = gui

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 8)
	corner.Parent = frame

	local stroke = Instance.new("UIStroke")
	stroke.Color = Color3.fromRGB(220, 180, 100)
	stroke.Thickness = 1
	stroke.Transparency = 0.5
	stroke.Parent = frame

	local txt = Instance.new("TextLabel")
	txt.Name = "Value"
	txt.Size = UDim2.new(1, -20, 1, 0)
	txt.Position = UDim2.new(0, 10, 0, 0)
	txt.BackgroundTransparency = 1
	txt.TextColor3 = Color3.fromRGB(240, 220, 180)
	txt.Font = Enum.Font.GothamBold
	txt.TextScaled = true
	txt.TextXAlignment = Enum.TextXAlignment.Right
	txt.Text = "0 Cores"
	txt.Parent = frame

	label = txt
end

function CoresDisplay.Init()
	build()
	local remote = Remotes.CoresChanged :: RemoteEvent
	remote.OnClientEvent:Connect(function(newCores: number)
		setText(newCores)
	end)
end

return CoresDisplay
