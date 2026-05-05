--!strict
--[[
	Outpost-7 — Battle Pass panel (client UI).

	Phase D5. XP header + scrollable 30-tier list. Each tier row shows
	the free reward + premium reward; per-track Claim buttons gated
	on tier-reached + ownership + not-already-claimed. Listens to
	`Remotes.BattlePassState`; invokes `Remotes.ClaimBattlePassTier`
	on tap.

	Premium ownership comes from the BattlePassState's `premiumOwned`
	field (server is the source of truth). When a player buys premium
	mid-session, `BattlePassService` re-pushes state and the panel
	re-renders with newly-claimable premium rewards.

	Visual style is debug-grade. Phase G replaces with neon-tactical
	theming + tier reward icons + animated XP bar fill.
--]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Remotes = require(Shared:WaitForChild("Remotes"))
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
local titleLabel: TextLabel? = nil
local xpBarFill: Frame? = nil
local xpText: TextLabel? = nil
local tiersList: ScrollingFrame? = nil
local lastState: State? = nil
local pendingClaims: { [string]: boolean } = {}

local function setVisible(visible: boolean)
	if screenGui then
		screenGui.Enabled = visible
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
): TextButton
	local btn = Instance.new("TextButton")
	btn.Size = UDim2.new(0, 200, 1, -8)
	btn.BackgroundColor3 = if claimed
		then Color3.fromRGB(60, 60, 70)
		elseif claimable then Color3.fromRGB(120, 220, 180)
		else Color3.fromRGB(40, 44, 54)
	btn.TextColor3 = if claimed
		then Color3.fromRGB(160, 160, 170)
		elseif claimable then Color3.fromRGB(20, 24, 32)
		else Color3.fromRGB(160, 170, 180)
	btn.Font = Enum.Font.GothamBold
	btn.TextScaled = true
	btn.AutoButtonColor = claimable and not claimed
	btn.Active = claimable and not claimed
	if claimed then
		btn.Text = string.format("%s\nClaimed", label)
	elseif claimable then
		btn.Text = string.format("Claim\n%s", formatReward(reward))
	else
		btn.Text = string.format("%s\n%s", label, formatReward(reward))
	end
	btn.Parent = parent
	local btnCorner = Instance.new("UICorner")
	btnCorner.CornerRadius = UDim.new(0, 6)
	btnCorner.Parent = btn
	if claimable and not claimed then
		btn.Activated:Connect(onClaim)
	end
	return btn
end

local function buildTierRow(parent: Instance, tier: TierView, currentTier: number, premiumOwned: boolean)
	local row = Instance.new("Frame")
	row.Size = UDim2.new(1, -16, 0, 80)
	row.BackgroundColor3 = if tier.tier <= currentTier then Color3.fromRGB(28, 32, 40) else Color3.fromRGB(22, 24, 28)
	row.BorderSizePixel = 0
	row.Parent = parent
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 8)
	corner.Parent = row

	-- Tier number badge
	local tierBadge = Instance.new("TextLabel")
	tierBadge.Size = UDim2.new(0, 60, 1, -16)
	tierBadge.Position = UDim2.new(0, 12, 0, 8)
	tierBadge.BackgroundColor3 = if tier.tier <= currentTier
		then Color3.fromRGB(120, 220, 180)
		else Color3.fromRGB(40, 44, 54)
	tierBadge.TextColor3 = if tier.tier <= currentTier
		then Color3.fromRGB(20, 24, 32)
		else Color3.fromRGB(160, 170, 180)
	tierBadge.Font = Enum.Font.GothamBold
	tierBadge.TextScaled = true
	tierBadge.Text = "T" .. tier.tier
	tierBadge.Parent = row
	local badgeCorner = Instance.new("UICorner")
	badgeCorner.CornerRadius = UDim.new(0, 6)
	badgeCorner.Parent = tierBadge

	-- Buttons row (free + premium)
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
			pcall(function()
				remote:InvokeServer(tier.tier, "free")
			end)
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
			pcall(function()
				remote:InvokeServer(tier.tier, "premium")
			end)
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
	gui.Parent = playerGui

	local panel = Instance.new("Frame")
	panel.Size = UDim2.new(0, 640, 0, 540)
	panel.Position = UDim2.new(0.5, -320, 0.5, -270)
	panel.BackgroundColor3 = Color3.fromRGB(20, 24, 32)
	panel.BorderSizePixel = 0
	panel.Parent = gui
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 12)
	corner.Parent = panel
	local stroke = Instance.new("UIStroke")
	stroke.Color = Color3.fromRGB(220, 180, 100)
	stroke.Thickness = 2
	stroke.Transparency = 0.3
	stroke.Parent = panel

	local title = Instance.new("TextLabel")
	title.Size = UDim2.new(1, -60, 0, 32)
	title.Position = UDim2.new(0, 16, 0, 10)
	title.BackgroundTransparency = 1
	title.TextColor3 = Color3.fromRGB(220, 240, 200)
	title.Font = Enum.Font.GothamBold
	title.TextScaled = true
	title.TextXAlignment = Enum.TextXAlignment.Left
	title.Text = "Battle Pass"
	title.Parent = panel
	titleLabel = title

	local closeBtn = Instance.new("TextButton")
	closeBtn.Size = UDim2.new(0, 36, 0, 36)
	closeBtn.Position = UDim2.new(1, -44, 0, 12)
	closeBtn.BackgroundColor3 = Color3.fromRGB(40, 44, 54)
	closeBtn.TextColor3 = Color3.fromRGB(200, 200, 200)
	closeBtn.Font = Enum.Font.GothamBold
	closeBtn.TextScaled = true
	closeBtn.Text = "X"
	closeBtn.Parent = panel
	local closeCorner = Instance.new("UICorner")
	closeCorner.CornerRadius = UDim.new(0, 6)
	closeCorner.Parent = closeBtn
	closeBtn.Activated:Connect(function()
		setVisible(false)
	end)

	-- XP header
	local barBg = Instance.new("Frame")
	barBg.Size = UDim2.new(1, -32, 0, 24)
	barBg.Position = UDim2.new(0, 16, 0, 52)
	barBg.BackgroundColor3 = Color3.fromRGB(40, 44, 54)
	barBg.BorderSizePixel = 0
	barBg.Parent = panel
	local barCorner = Instance.new("UICorner")
	barCorner.CornerRadius = UDim.new(1, 0)
	barCorner.Parent = barBg

	local fill = Instance.new("Frame")
	fill.Size = UDim2.new(0, 0, 1, 0)
	fill.BackgroundColor3 = Color3.fromRGB(220, 180, 100)
	fill.BorderSizePixel = 0
	fill.Parent = barBg
	local fillCorner = Instance.new("UICorner")
	fillCorner.CornerRadius = UDim.new(1, 0)
	fillCorner.Parent = fill
	xpBarFill = fill

	local xpLbl = Instance.new("TextLabel")
	xpLbl.Size = UDim2.new(1, 0, 1, 0)
	xpLbl.BackgroundTransparency = 1
	xpLbl.TextColor3 = Color3.fromRGB(255, 255, 255)
	xpLbl.Font = Enum.Font.GothamBold
	xpLbl.TextScaled = true
	xpLbl.Text = "Tier 0 / 30 — 0 / 1000 XP"
	xpLbl.Parent = barBg
	xpText = xpLbl

	-- Scrolling tier list
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
