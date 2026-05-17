--!strict
--[[
	Outpost-7 — "Welcome Back" popup (client UI).

	Phase C4 (original). Phase G5.2b theme migration.

	One-shot popup shown when the server fires `Remotes.WelcomeBack`
	after computing offline progression on join. Displays elapsed time
	(with capped flag if the player was away longer than the cap), the
	income rate that produced the grant, and the granted Credits total.

	Tap "Collect" plays the claim chime (this IS a reward grant — the
	player isn't choosing to claim, they're acknowledging the auto-
	grant that already happened server-side) and dismisses the popup.

	G5.2b migration:
	  - Panel + button on Components.StrokedFrame / Button.
	  - Labels resolve color from Theme palette; live re-tint on biome swap.
	  - Open/close tween via UIScale + PanelOpen/PanelClose presets.
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
local panelScale: UIScale? = nil

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
	gui.DisplayOrder = 40
	gui.Parent = playerGui

	local backdrop = Instance.new("Frame")
	backdrop.Size = UDim2.fromScale(1, 1)
	backdrop.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
	backdrop.BackgroundTransparency = 0.5
	backdrop.BorderSizePixel = 0
	backdrop.Parent = gui

	local panel = Components.StrokedFrame({
		parent = gui,
		name = "Panel",
		size = UDim2.fromOffset(380, 280),
		position = UDim2.fromScale(0.5, 0.5),
		anchorPoint = Vector2.new(0.5, 0.5),
		bgSlot = "panel",
		strokeSlot = "secondary",
		cornerAccent = true,
	})

	local scale = Instance.new("UIScale")
	scale.Scale = 1.0
	scale.Parent = panel

	local title = Instance.new("TextLabel")
	title.Name = "Title"
	title.Size = UDim2.new(1, -20, 0, 40)
	title.Position = UDim2.new(0, 10, 0, 12)
	title.BackgroundTransparency = 1
	title.TextColor3 = Theme.GetActive().textPrimary
	title.Font = Enum.Font.GothamBold
	title.TextScaled = true
	title.Text = "Welcome Back, Operator"
	title.Parent = panel

	local away = Instance.new("TextLabel")
	away.Size = UDim2.new(1, -20, 0, 24)
	away.Position = UDim2.new(0, 10, 0, 60)
	away.BackgroundTransparency = 1
	away.TextColor3 = Theme.GetActive().textMuted
	away.Font = Enum.Font.Gotham
	away.TextScaled = true
	away.Text = "Away: ..."
	away.Parent = panel

	local rate = Instance.new("TextLabel")
	rate.Size = UDim2.new(1, -20, 0, 24)
	rate.Position = UDim2.new(0, 10, 0, 88)
	rate.BackgroundTransparency = 1
	rate.TextColor3 = Theme.GetActive().textMuted
	rate.Font = Enum.Font.Gotham
	rate.TextScaled = true
	rate.Text = "Income: ..."
	rate.Parent = panel

	local grant = Instance.new("TextLabel")
	grant.Size = UDim2.new(1, -20, 0, 60)
	grant.Position = UDim2.new(0, 10, 0, 130)
	grant.BackgroundTransparency = 1
	grant.TextColor3 = Theme.GetActive().highlight
	grant.Font = Enum.Font.GothamBold
	grant.TextScaled = true
	grant.Text = "+0 Credits"
	grant.Parent = panel

	local themeConn = Theme.Changed:Connect(function()
		if not title.Parent then
			return
		end
		local p = Theme.GetActive()
		title.TextColor3 = p.textPrimary
		away.TextColor3 = p.textMuted
		rate.TextColor3 = p.textMuted
		grant.TextColor3 = p.highlight
	end)
	panel.Destroying:Connect(function()
		themeConn:Disconnect()
	end)

	Components.Button({
		parent = panel,
		name = "CollectButton",
		text = "Collect",
		size = UDim2.fromOffset(200, 56),
		position = UDim2.new(0.5, 0, 1, -20),
		anchorPoint = Vector2.new(0.5, 1),
		bgSlot = "secondary",
		textSlot = "background",
		strokeSlot = "secondary",
		playSound = false, -- claim chime supersedes the click sound
		onActivated = function()
			Components.PlayClaimChime()
			setVisible(false)
		end,
	})

	screenGui = gui
	titleLabel = title
	awayLabel = away
	rateLabel = rate
	grantLabel = grant
	panelScale = scale
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
