--!strict
--[[
	Outpost-7 — "Welcome Back" popup (client UI).

	Phase C4. One-shot popup shown when the server fires
	`Remotes.WelcomeBack` after computing offline progression on join.
	Displays elapsed time (with capped flag if the player was away
	longer than the cap), the income rate that produced the grant,
	and the granted Credits total.

	The popup auto-hides on close. Phase G replaces with neon-tactical
	theming + spring-tween entry + animated coin spill on close.
--]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Remotes = require(Shared:WaitForChild("Remotes"))
local HudFormat = require(Shared:WaitForChild("Modules"):WaitForChild("Lib"):WaitForChild("HudFormat"))

type Payload = {
	elapsedSeconds: number,
	cappedSeconds: number,
	incomePerSecond: number,
	grantedCredits: number,
	wasCapped: boolean,
}

local WelcomeBackPopup = {}

local screenGui: ScreenGui? = nil
local titleLabel: TextLabel? = nil
local awayLabel: TextLabel? = nil
local rateLabel: TextLabel? = nil
local grantLabel: TextLabel? = nil

local function setVisible(visible: boolean)
	if screenGui then
		screenGui.Enabled = visible
	end
end

local function formatDuration(seconds: number): string
	local h = math.floor(seconds / 3600)
	local m = math.floor((seconds % 3600) / 60)
	if h > 0 then
		return string.format("%dh %dm", h, m)
	end
	if m > 0 then
		return string.format("%dm", m)
	end
	return string.format("%ds", seconds)
end

local function build()
	local player = Players.LocalPlayer
	local playerGui = player:WaitForChild("PlayerGui")

	local existing = playerGui:FindFirstChild("WelcomeBackPopup")
	if existing then
		existing:Destroy()
	end

	local gui = Instance.new("ScreenGui")
	gui.Name = "WelcomeBackPopup"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.Enabled = false
	gui.Parent = playerGui

	local backdrop = Instance.new("Frame")
	backdrop.Size = UDim2.new(1, 0, 1, 0)
	backdrop.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
	backdrop.BackgroundTransparency = 0.5
	backdrop.BorderSizePixel = 0
	backdrop.Parent = gui

	local panel = Instance.new("Frame")
	panel.Size = UDim2.new(0, 380, 0, 280)
	panel.Position = UDim2.new(0.5, -190, 0.5, -140)
	panel.BackgroundColor3 = Color3.fromRGB(20, 24, 32)
	panel.BorderSizePixel = 0
	panel.Parent = gui

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 12)
	corner.Parent = panel

	local stroke = Instance.new("UIStroke")
	stroke.Color = Color3.fromRGB(180, 220, 100)
	stroke.Thickness = 2
	stroke.Transparency = 0.3
	stroke.Parent = panel

	local title = Instance.new("TextLabel")
	title.Size = UDim2.new(1, -20, 0, 40)
	title.Position = UDim2.new(0, 10, 0, 12)
	title.BackgroundTransparency = 1
	title.TextColor3 = Color3.fromRGB(220, 240, 200)
	title.Font = Enum.Font.GothamBold
	title.TextScaled = true
	title.Text = "Welcome Back, Operator"
	title.Parent = panel

	local away = Instance.new("TextLabel")
	away.Size = UDim2.new(1, -20, 0, 24)
	away.Position = UDim2.new(0, 10, 0, 60)
	away.BackgroundTransparency = 1
	away.TextColor3 = Color3.fromRGB(180, 200, 210)
	away.Font = Enum.Font.Gotham
	away.TextScaled = true
	away.Text = "Away: ..."
	away.Parent = panel

	local rate = Instance.new("TextLabel")
	rate.Size = UDim2.new(1, -20, 0, 24)
	rate.Position = UDim2.new(0, 10, 0, 88)
	rate.BackgroundTransparency = 1
	rate.TextColor3 = Color3.fromRGB(180, 200, 210)
	rate.Font = Enum.Font.Gotham
	rate.TextScaled = true
	rate.Text = "Income: ..."
	rate.Parent = panel

	local grant = Instance.new("TextLabel")
	grant.Size = UDim2.new(1, -20, 0, 60)
	grant.Position = UDim2.new(0, 10, 0, 130)
	grant.BackgroundTransparency = 1
	grant.TextColor3 = Color3.fromRGB(180, 220, 100)
	grant.Font = Enum.Font.GothamBold
	grant.TextScaled = true
	grant.Text = "+0 Credits"
	grant.Parent = panel

	local btn = Instance.new("TextButton")
	btn.Size = UDim2.new(0, 200, 0, 56)
	btn.Position = UDim2.new(0.5, -100, 1, -76)
	btn.BackgroundColor3 = Color3.fromRGB(120, 220, 180)
	btn.TextColor3 = Color3.fromRGB(20, 24, 32)
	btn.Font = Enum.Font.GothamBold
	btn.TextScaled = true
	btn.Text = "Collect"
	btn.AutoButtonColor = true
	btn.Parent = panel
	local btnCorner = Instance.new("UICorner")
	btnCorner.CornerRadius = UDim.new(0, 8)
	btnCorner.Parent = btn

	btn.Activated:Connect(function()
		setVisible(false)
	end)

	screenGui = gui
	titleLabel = title
	awayLabel = away
	rateLabel = rate
	grantLabel = grant
end

local function showFromPayload(payload: Payload)
	if not titleLabel or not awayLabel or not rateLabel or not grantLabel then
		return
	end
	local awayText = string.format("Away: %s", formatDuration(payload.elapsedSeconds))
	if payload.wasCapped then
		awayText ..= string.format(" (capped at %s)", formatDuration(payload.cappedSeconds))
	end
	awayLabel.Text = awayText
	rateLabel.Text = string.format("Income rate: %d / sec", payload.incomePerSecond)
	grantLabel.Text = string.format("+%s Credits", HudFormat.Abbreviated(payload.grantedCredits))
	setVisible(true)
end

function WelcomeBackPopup.Init()
	build()
	local remote = Remotes.WelcomeBack :: RemoteEvent
	remote.OnClientEvent:Connect(function(payload: Payload)
		showFromPayload(payload)
	end)
end

return WelcomeBackPopup
