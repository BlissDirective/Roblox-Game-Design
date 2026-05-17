--!strict
--[[
	Outpost-7 — Battle Pass panel (client UI).

	Phase D5 (original). Phase G5.2b theme migration.

	XP header + scrollable 30-tier list. Each tier row shows the free
	reward + premium reward; per-track Claim buttons gated on tier-
	reached + ownership + not-already-claimed. Listens to
	`Remotes.BattlePassState`; invokes `Remotes.ClaimBattlePassTier`
	on tap.

	Premium ownership comes from the BattlePassState's `premiumOwned`
	field (server is the source of truth). When a player buys premium
	mid-session, `BattlePassService` re-pushes state and the panel
	re-renders with newly-claimable premium rewards.

	G5.2b migration:
	  - Root panel + tier rows + track buttons rebuilt on
	    Components.StrokedFrame + Components.Button.
	  - State-driven palette slots:
	      claimed   → background bg + textMuted text  (greyed)
	      claimable → highlight  bg + background text  (CTA)
	      not-yet   → background bg + textMuted text  (waiting)
	  - XP bar fill resolves from Theme.highlight (amber/magenta).
	  - Live re-tint on biome swap.
--]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Constants = require(Shared:WaitForChild("Constants"))
local Remotes = require(Shared:WaitForChild("Remotes"))
local Components = require(Shared:WaitForChild("Modules"):WaitForChild("UI"):WaitForChild("Components"))
local Theme = require(Shared:WaitForChild("Modules"):WaitForChild("UI"):WaitForChild("Theme"))
local HudFormat = require(Shared:WaitForChild("Modules"):WaitForChild("Lib"):WaitForChild("HudFormat"))

type TierReward = { credits: number, cores: number }
type TierView = {
	tier: number,
	freeReward: TierReward,
	premiumReward: TierReward,
	freeClaimed: boolean,
	premiumClaimed: boolean,
}
type State = {
	seasonId: string,
	xp: number,
	tier: number,
	maxTier: number,
	xpPerTier: number,
	premiumOwned: boolean,
	tiers: { TierView },
}

local BattlePassPanel = {}

local screenGui: ScreenGui? = nil
local panelScale: UIScale? = nil
local titleLabel: TextLabel? = nil
local xpBarFill: Frame? = nil
local xpText: TextLabel? = nil
local tiersList: ScrollingFrame? = nil
local lastState: State? = nil
local pendingClaims: { [string]: boolean } = {}

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
		TweenService:Create(panelScale, easingInfoFor("PanelClose"), { Scale = 0.95 }):Play()
		task.delay((Constants.UI.Motion.PanelClose :: any).duration, function()
			if screenGui then
				screenGui.Enabled = false
			end
		end)
	end
end

local function claimKey(tier: number, track: string): string
	return string.format("%d/%s", tier, track)
end

local function formatReward(reward: TierReward): string
	if reward.cores > 0 and reward.credits > 0 then
		return string.format("%s ¢ + %d ♦", HudFormat.Abbreviated(reward.credits), reward.cores)
	elseif reward.credits > 0 then
		return string.format("%s ¢", HudFormat.Abbreviated(reward.credits))
	elseif reward.cores > 0 then
		return string.format("%d ♦", reward.cores)
	end
	return "—"
end

local function buildTrackButton(
	parent: Instance,
	label: string,
	reward: TierReward,
	claimable: boolean,
	claimed: boolean,
	onClaim: () -> ()
)
	local btnBgSlot: string
	local btnTextSlot: string
	local btnStrokeSlot: string
	local btnText: string
	if claimed then
		btnBgSlot = "background"
		btnTextSlot = "textMuted"
		btnStrokeSlot = "textMuted"
		btnText = string.format("%s\nClaimed", label)
	elseif claimable then
		btnBgSlot = "highlight"
		btnTextSlot = "background"
		btnStrokeSlot = "highlight"
		btnText = string.format("Claim\n%s", formatReward(reward))
	else
		btnBgSlot = "background"
		btnTextSlot = "textMuted"
		btnStrokeSlot = "textMuted"
		btnText = string.format("%s\n%s", label, formatReward(reward))
	end

	local handle = Components.Button({
		parent = parent,
		name = label .. "_Button",
		text = btnText,
		size = UDim2.new(0, 200, 1, -8),
		bgSlot = btnBgSlot,
		textSlot = btnTextSlot,
		strokeSlot = btnStrokeSlot,
		playSound = false, -- claim chime supersedes click
		onActivated = if claimable and not claimed then onClaim else function() end,
	})
	handle:SetEnabled(claimable and not claimed)
end

local function buildTierRow(parent: Instance, tier: TierView, currentTier: number, premiumOwned: boolean)
	local reached = tier.tier <= currentTier
	local row = Components.StrokedFrame({
		parent = parent,
		name = "Tier_" .. tier.tier,
		size = UDim2.new(1, -16, 0, 80),
		bgSlot = if reached then "panel" else "background",
		strokeSlot = if reached then "highlight" else "textMuted",
		cornerAccent = false,
	})

	-- Tier number badge — small Components.StrokedFrame inset.
	local badgeBgSlot = if reached then "highlight" else "background"
	local badgeTextSlot = if reached then "background" else "textMuted"
	local badge = Components.StrokedFrame({
		parent = row,
		name = "TierBadge",
		size = UDim2.new(0, 60, 1, -16),
		position = UDim2.new(0, 12, 0, 8),
		bgSlot = badgeBgSlot,
		strokeSlot = if reached then "highlight" else "textMuted",
		cornerAccent = false,
	})
	local badgeText = Instance.new("TextLabel")
	badgeText.Size = UDim2.fromScale(1, 1)
	badgeText.BackgroundTransparency = 1
	badgeText.Font = Enum.Font.GothamBold
	badgeText.TextScaled = true
	badgeText.TextColor3 = (Theme.GetActive() :: any)[badgeTextSlot]
	badgeText.Text = "T" .. tier.tier
	badgeText.Parent = badge

	local themeConn = Theme.Changed:Connect(function()
		if badgeText.Parent then
			badgeText.TextColor3 = (Theme.GetActive() :: any)[badgeTextSlot]
		end
	end)
	row.Destroying:Connect(function()
		themeConn:Disconnect()
	end)

	local btnRow = Instance.new("Frame")
	btnRow.Size = UDim2.new(1, -88, 1, 0)
	btnRow.Position = UDim2.new(0, 80, 0, 0)
	btnRow.BackgroundTransparency = 1
	btnRow.Parent = row
	local btnLayout = Instance.new("UIListLayout")
	btnLayout.FillDirection = Enum.FillDirection.Horizontal
	btnLayout.HorizontalAlignment = Enum.HorizontalAlignment.Left
	btnLayout.VerticalAlignment = Enum.VerticalAlignment.Center
	btnLayout.Padding = UDim.new(0, 8)
	btnLayout.Parent = btnRow

	local freeReached = tier.tier <= currentTier
	buildTrackButton(btnRow, "Free", tier.freeReward, freeReached, tier.freeClaimed, function()
		local key = claimKey(tier.tier, "free")
		if pendingClaims[key] then
			return
		end
		pendingClaims[key] = true
		task.spawn(function()
			local remote = Remotes.ClaimBattlePassTier :: RemoteFunction
			local ok, result = pcall(function()
				return remote:InvokeServer(tier.tier, "free")
			end)
			if ok and typeof(result) == "table" and result.ok then
				Components.PlayClaimChime()
			end
			pendingClaims[key] = nil
		end)
	end)

	local premiumReached = freeReached and premiumOwned
	buildTrackButton(btnRow, "Premium", tier.premiumReward, premiumReached, tier.premiumClaimed, function()
		local key = claimKey(tier.tier, "premium")
		if pendingClaims[key] then
			return
		end
		pendingClaims[key] = true
		task.spawn(function()
			local remote = Remotes.ClaimBattlePassTier :: RemoteFunction
			local ok, result = pcall(function()
				return remote:InvokeServer(tier.tier, "premium")
			end)
			if ok and typeof(result) == "table" and result.ok then
				Components.PlayClaimChime()
			end
			pendingClaims[key] = nil
		end)
	end)
end

local function rebuild(state: State)
	if not titleLabel or not xpBarFill or not xpText or not tiersList then
		return
	end

	titleLabel.Text =
		string.format("Battle Pass — Season %s%s", state.seasonId, if state.premiumOwned then " (Premium)" else "")

	local xpInTier = state.xp - state.tier * state.xpPerTier
	if state.tier >= state.maxTier then
		xpInTier = state.xpPerTier
	end
	local progress = math.clamp(xpInTier / state.xpPerTier, 0, 1)
	xpBarFill.Size = UDim2.new(progress, 0, 1, 0)
	xpText.Text = string.format("Tier %d / %d  —  %d / %d XP", state.tier, state.maxTier, xpInTier, state.xpPerTier)

	for _, child in tiersList:GetChildren() do
		if child:IsA("Frame") then
			child:Destroy()
		end
	end
	for _, tier in state.tiers do
		buildTierRow(tiersList, tier, state.tier, state.premiumOwned)
	end
end

local function build()
	local player = Players.LocalPlayer
	local playerGui = player:WaitForChild("PlayerGui")

	local existing = playerGui:FindFirstChild("BattlePassPanel")
	if existing then
		existing:Destroy()
	end

	local gui = Instance.new("ScreenGui")
	gui.Name = "BattlePassPanel"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.Enabled = false
	gui.DisplayOrder = 30
	gui.Parent = playerGui

	local panel = Components.StrokedFrame({
		parent = gui,
		name = "Panel",
		size = UDim2.fromOffset(640, 540),
		position = UDim2.fromScale(0.5, 0.5),
		anchorPoint = Vector2.new(0.5, 0.5),
		bgSlot = "panel",
		strokeSlot = "highlight",
		cornerAccent = true,
	})

	local scale = Instance.new("UIScale")
	scale.Scale = 1.0
	scale.Parent = panel
	panelScale = scale

	local title = Instance.new("TextLabel")
	title.Size = UDim2.new(1, -60, 0, 32)
	title.Position = UDim2.new(0, 16, 0, 10)
	title.BackgroundTransparency = 1
	title.TextColor3 = Theme.GetActive().textPrimary
	title.Font = Enum.Font.GothamBold
	title.TextScaled = true
	title.TextXAlignment = Enum.TextXAlignment.Left
	title.Text = "Battle Pass"
	title.Parent = panel
	titleLabel = title

	local themeConn = Theme.Changed:Connect(function()
		if title.Parent then
			title.TextColor3 = Theme.GetActive().textPrimary
		end
	end)
	panel.Destroying:Connect(function()
		themeConn:Disconnect()
	end)

	Components.Button({
		parent = panel,
		name = "CloseButton",
		text = "X",
		size = UDim2.fromOffset(36, 36),
		position = UDim2.new(1, -14, 0, 12),
		anchorPoint = Vector2.new(1, 0),
		strokeSlot = "danger",
		onActivated = function()
			setVisible(false)
		end,
	})

	-- XP header bar.
	local barBg = Instance.new("Frame")
	barBg.Size = UDim2.new(1, -32, 0, 24)
	barBg.Position = UDim2.new(0, 16, 0, 52)
	barBg.BackgroundColor3 = Theme.GetActive().background
	barBg.BorderSizePixel = 0
	barBg.Parent = panel
	local barCorner = Instance.new("UICorner")
	barCorner.CornerRadius = UDim.new(1, 0)
	barCorner.Parent = barBg

	local fill = Instance.new("Frame")
	fill.Size = UDim2.new(0, 0, 1, 0)
	fill.BackgroundColor3 = Theme.GetActive().highlight
	fill.BorderSizePixel = 0
	fill.Parent = barBg
	local fillCorner = Instance.new("UICorner")
	fillCorner.CornerRadius = UDim.new(1, 0)
	fillCorner.Parent = fill
	xpBarFill = fill

	local xpLbl = Instance.new("TextLabel")
	xpLbl.Size = UDim2.fromScale(1, 1)
	xpLbl.BackgroundTransparency = 1
	xpLbl.TextColor3 = Theme.GetActive().textPrimary
	xpLbl.Font = Enum.Font.GothamBold
	xpLbl.TextScaled = true
	xpLbl.Text = "Tier 0 / 30 — 0 / 1000 XP"
	xpLbl.Parent = barBg
	xpText = xpLbl

	local barConn = Theme.Changed:Connect(function()
		if not barBg.Parent then
			return
		end
		local p = Theme.GetActive()
		barBg.BackgroundColor3 = p.background
		fill.BackgroundColor3 = p.highlight
		xpLbl.TextColor3 = p.textPrimary
	end)
	barBg.Destroying:Connect(function()
		barConn:Disconnect()
	end)

	-- Scrolling tier list.
	local scroll = Instance.new("ScrollingFrame")
	scroll.Size = UDim2.new(1, -32, 1, -100)
	scroll.Position = UDim2.new(0, 16, 0, 92)
	scroll.BackgroundTransparency = 1
	scroll.BorderSizePixel = 0
	scroll.ScrollBarThickness = 6
	scroll.CanvasSize = UDim2.new(0, 0, 0, 0)
	scroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
	scroll.Parent = panel
	local layout = Instance.new("UIListLayout")
	layout.FillDirection = Enum.FillDirection.Vertical
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	layout.Padding = UDim.new(0, 8)
	layout.Parent = scroll

	screenGui = gui
	tiersList = scroll
end

function BattlePassPanel.Show()
	setVisible(true)
	if lastState then
		rebuild(lastState)
	end
end

function BattlePassPanel.Hide()
	setVisible(false)
end

function BattlePassPanel.Toggle()
	if screenGui and screenGui.Enabled then
		BattlePassPanel.Hide()
	else
		BattlePassPanel.Show()
	end
end

function BattlePassPanel.Init()
	build()
	local remote = Remotes.BattlePassState :: RemoteEvent
	remote.OnClientEvent:Connect(function(state: State)
		lastState = state
		if screenGui and screenGui.Enabled then
			rebuild(state)
		end
	end)
end

return BattlePassPanel
