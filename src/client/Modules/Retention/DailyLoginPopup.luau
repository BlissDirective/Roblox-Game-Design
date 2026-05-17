--!strict
--[[
	Outpost-7 — daily login popup (client UI).

	Phase C1 (original). Phase G5.2b theme migration.

	Listens to `Remotes.DailyLoginState`. When canClaim is true, shows
	a centered popup with the streak day + reward + Claim button.
	Tapping Claim invokes `Remotes.ClaimDailyReward` RemoteFunction,
	blocks until the server response, then closes.

	G5.2b changes:
	  - Panel + button rebuilt on Components.StrokedFrame / Button so
	    the sharp-angular-sci-fi frame style + biome-aware palette
	    apply automatically.
	  - Claim button suppresses the default ui_button_click (playSound
	    = false); the claim chime from G5.2c is the only audio cue.
	  - Title / reward labels resolve their color from Theme palette
	    slots; live re-tint on biome swap.
--]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Constants = require(Shared:WaitForChild("Constants"))
local Remotes = require(Shared:WaitForChild("Remotes"))
local HudFormat = require(Shared:WaitForChild("Modules"):WaitForChild("Lib"):WaitForChild("HudFormat"))
local Components = require(Shared:WaitForChild("Modules"):WaitForChild("UI"):WaitForChild("Components"))
local Theme = require(Shared:WaitForChild("Modules"):WaitForChild("UI"):WaitForChild("Theme"))

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
local claimBtn: any = nil -- Components.ButtonHandle
local panelScale: UIScale? = nil
local pendingClaim = false

local function easingInfoFor(presetName: string): TweenInfo
	local preset: any = Constants.UI.Motion[presetName]
	return TweenInfo.new(
		preset.duration,
		Theme.EasingStyleFor(preset.easing),
		Theme.EasingDirectionFor(preset.easing),
		0,
		false,
		0
	)
end

local function setVisible(visible: boolean)
	if not screenGui or not panelScale then
		return
	end
	if visible then
		screenGui.Enabled = true
		panelScale.Scale = 0.95
		TweenService:Create(panelScale, easingInfoFor("PanelOpen"), { Scale = 1.0 }):Play()
	else
		local closeInfo = easingInfoFor("PanelClose")
		TweenService:Create(panelScale, closeInfo, { Scale = 0.95 }):Play()
		task.delay((Constants.UI.Motion.PanelClose :: any).duration, function()
			if screenGui then
				screenGui.Enabled = false
			end
		end)
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
	gui.DisplayOrder = 40
	gui.Parent = playerGui

	-- Dim background.
	local backdrop = Instance.new("Frame")
	backdrop.Size = UDim2.fromScale(1, 1)
	backdrop.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
	backdrop.BackgroundTransparency = 0.5
	backdrop.BorderSizePixel = 0
	backdrop.Parent = gui

	local panel = Components.StrokedFrame({
		parent = gui,
		name = "Panel",
		size = UDim2.fromOffset(360, 220),
		position = UDim2.fromScale(0.5, 0.5),
		anchorPoint = Vector2.new(0.5, 0.5),
		bgSlot = "panel",
		strokeSlot = "accent",
		cornerAccent = true,
	})

	-- UIScale for open/close tween (snappier than tweening Position).
	local scale = Instance.new("UIScale")
	scale.Scale = 1.0
	scale.Parent = panel

	local title = Instance.new("TextLabel")
	title.Name = "Title"
	title.Size = UDim2.new(1, -20, 0, 50)
	title.Position = UDim2.new(0, 10, 0, 12)
	title.BackgroundTransparency = 1
	title.TextColor3 = Theme.GetActive().textPrimary
	title.Font = Enum.Font.GothamBold
	title.TextScaled = true
	title.Text = "Daily Login"
	title.Parent = panel

	local reward = Instance.new("TextLabel")
	reward.Name = "Reward"
	reward.Size = UDim2.new(1, -20, 0, 60)
	reward.Position = UDim2.new(0, 10, 0, 70)
	reward.BackgroundTransparency = 1
	reward.TextColor3 = Theme.GetActive().highlight
	reward.Font = Enum.Font.GothamBold
	reward.TextScaled = true
	reward.Text = "Day 1 — 500 Credits"
	reward.Parent = panel

	-- Theme.Changed live re-tint for the labels (StrokedFrame auto-
	-- tints its own bg + stroke).
	local conn = Theme.Changed:Connect(function()
		if title.Parent then
			title.TextColor3 = Theme.GetActive().textPrimary
		end
		if reward.Parent then
			reward.TextColor3 = Theme.GetActive().highlight
		end
	end)
	panel.Destroying:Connect(function()
		conn:Disconnect()
	end)

	local btn = Components.Button({
		parent = panel,
		name = "ClaimButton",
		text = "Claim",
		size = UDim2.fromOffset(200, 56),
		position = UDim2.new(0.5, 0, 1, -20),
		anchorPoint = Vector2.new(0.5, 1),
		bgSlot = "accent",
		textSlot = "background", -- dark text on light accent button
		strokeSlot = "accent",
		playSound = false, -- claim chime supersedes the click sound
		onActivated = function()
			if pendingClaim then
				return
			end
			pendingClaim = true
			btn:SetText("...")
			local remote = Remotes.ClaimDailyReward :: RemoteFunction
			local ok, result = pcall(function()
				return remote:InvokeServer()
			end)
			pendingClaim = false
			if ok and typeof(result) == "table" and result.ok then
				Components.PlayClaimChime()
				btn:SetText(string.format("+%s ✓", HudFormat.Abbreviated(result.reward)))
			else
				btn:SetText("Claim")
			end
		end,
	})

	screenGui = gui
	titleLabel = title
	rewardLabel = reward
	claimBtn = btn
	panelScale = scale
end

local function showFromState(state: State)
	if not titleLabel or not rewardLabel or not claimBtn then
		return
	end
	if not state.canClaim then
		setVisible(false)
		return
	end
	titleLabel.Text = string.format("Daily Login — Streak %d", state.currentStreakDay)
	rewardLabel.Text = string.format("Day %d: +%s Credits", state.nextStreakDay, HudFormat.Abbreviated(state.reward))
	claimBtn:SetText("Claim")
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
