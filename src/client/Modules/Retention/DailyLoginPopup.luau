--!strict
--[[
	Outpost-7 — daily login popup (client UI).

	Phase C1. Listens to `Remotes.DailyLoginState`. When canClaim is
	true, shows a centered popup with the streak day + reward + Claim
	button. Tapping Claim invokes `Remotes.ClaimDailyReward`
	RemoteFunction, blocks until the server response, then closes.

	Visual style is debug-grade. Phase G aesthetic pass replaces with
	neon-tactical theming (synthwave palette, spring-tween entry,
	day-7 / 14 / 30 milestone variants).
--]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Remotes = require(Shared:WaitForChild("Remotes"))
local HudFormat = require(Shared:WaitForChild("Modules"):WaitForChild("Lib"):WaitForChild("HudFormat"))

type State = {
	canClaim: boolean,
	nextStreakDay: number,
	reward: number,
	currentStreakDay: number,
}

local DailyLoginPopup = {}

local screenGui: ScreenGui? = nil
local titleLabel: TextLabel? = nil
local rewardLabel: TextLabel? = nil
local claimButton: TextButton? = nil
local pendingClaim = false

local function setVisible(visible: boolean)
	if screenGui then
		screenGui.Enabled = visible
	end
end

local function build()
	local player = Players.LocalPlayer
	local playerGui = player:WaitForChild("PlayerGui")

	local existing = playerGui:FindFirstChild("DailyLoginPopup")
	if existing then
		existing:Destroy()
	end

	local gui = Instance.new("ScreenGui")
	gui.Name = "DailyLoginPopup"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.Enabled = false
	gui.Parent = playerGui

	-- Dim background (taps pass through; only the panel buttons
	-- consume input).
	local backdrop = Instance.new("Frame")
	backdrop.Size = UDim2.new(1, 0, 1, 0)
	backdrop.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
	backdrop.BackgroundTransparency = 0.5
	backdrop.BorderSizePixel = 0
	backdrop.Parent = gui

	local panel = Instance.new("Frame")
	panel.Size = UDim2.new(0, 360, 0, 220)
	panel.Position = UDim2.new(0.5, -180, 0.5, -110)
	panel.BackgroundColor3 = Color3.fromRGB(20, 24, 32)
	panel.BorderSizePixel = 0
	panel.Parent = gui

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 12)
	corner.Parent = panel

	local stroke = Instance.new("UIStroke")
	stroke.Color = Color3.fromRGB(120, 220, 180)
	stroke.Thickness = 2
	stroke.Transparency = 0.3
	stroke.Parent = panel

	local title = Instance.new("TextLabel")
	title.Name = "Title"
	title.Size = UDim2.new(1, -20, 0, 50)
	title.Position = UDim2.new(0, 10, 0, 12)
	title.BackgroundTransparency = 1
	title.TextColor3 = Color3.fromRGB(220, 240, 200)
	title.Font = Enum.Font.GothamBold
	title.TextScaled = true
	title.Text = "Daily Login"
	title.Parent = panel

	local reward = Instance.new("TextLabel")
	reward.Name = "Reward"
	reward.Size = UDim2.new(1, -20, 0, 60)
	reward.Position = UDim2.new(0, 10, 0, 70)
	reward.BackgroundTransparency = 1
	reward.TextColor3 = Color3.fromRGB(180, 220, 100)
	reward.Font = Enum.Font.GothamBold
	reward.TextScaled = true
	reward.Text = "Day 1 — 500 Credits"
	reward.Parent = panel

	local btn = Instance.new("TextButton")
	btn.Name = "ClaimButton"
	btn.Size = UDim2.new(0, 200, 0, 56)
	btn.Position = UDim2.new(0.5, -100, 1, -76)
	btn.BackgroundColor3 = Color3.fromRGB(120, 220, 180)
	btn.TextColor3 = Color3.fromRGB(20, 24, 32)
	btn.Font = Enum.Font.GothamBold
	btn.TextScaled = true
	btn.Text = "Claim"
	btn.AutoButtonColor = true
	btn.Parent = panel

	local btnCorner = Instance.new("UICorner")
	btnCorner.CornerRadius = UDim.new(0, 8)
	btnCorner.Parent = btn

	screenGui = gui
	titleLabel = title
	rewardLabel = reward
	claimButton = btn

	btn.Activated:Connect(function()
		if pendingClaim then
			return
		end
		pendingClaim = true
		btn.AutoButtonColor = false
		btn.Text = "..."
		local remote = Remotes.ClaimDailyReward :: RemoteFunction
		local ok, result = pcall(function()
			return remote:InvokeServer()
		end)
		pendingClaim = false
		btn.AutoButtonColor = true
		if ok and typeof(result) == "table" and result.ok then
			-- Server-pushed DailyLoginState will hide the popup via
			-- the next showFromState call; until then, show "Claimed!".
			btn.Text = string.format("+%s ✓", HudFormat.Abbreviated(result.reward))
		else
			btn.Text = "Claim"
		end
	end)
end

local function showFromState(state: State)
	if not titleLabel or not rewardLabel or not claimButton then
		return
	end
	if not state.canClaim then
		setVisible(false)
		return
	end
	titleLabel.Text = string.format("Daily Login — Streak %d", state.currentStreakDay)
	rewardLabel.Text = string.format("Day %d: +%s Credits", state.nextStreakDay, HudFormat.Abbreviated(state.reward))
	claimButton.Text = "Claim"
	setVisible(true)
end

function DailyLoginPopup.Init()
	build()
	local remote = Remotes.DailyLoginState :: RemoteEvent
	remote.OnClientEvent:Connect(function(state: State)
		showFromState(state)
	end)
end

return DailyLoginPopup
