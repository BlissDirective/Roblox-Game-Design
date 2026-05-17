--!strict
--[[
	Outpost-7 — Battle Pass progress widget (client).

	Phase G5 (G5.2a). Top-left HUD widget showing tier + XP progress.
	Tap = open BattlePassPanel. Replaces the original BP toggle button.
	Phase G5.2c: refactored to accept an external parent so the
	HudController-owned "Wallet" cluster can host it alongside the
	Store button.

	Drives BP awareness during normal play (always visible during Build
	mode); on tier-up, a brief highlight pulse signals the unlock so
	the player taps through.
--]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Remotes = require(Shared:WaitForChild("Remotes"))
local Components = require(Shared:WaitForChild("Modules"):WaitForChild("UI"):WaitForChild("Components"))
local Theme = require(Shared:WaitForChild("Modules"):WaitForChild("UI"):WaitForChild("Theme"))

local BattlePassWidget = {}

type State = {
	seasonId: string?,
	xp: number,
	tier: number,
	maxTier: number,
	xpPerTier: number,
	premiumOwned: boolean,
	tiers: any,
}

local rootFrame: TextButton?
local tierLabel: TextLabel?
local xpBarFill: Frame?

local lastTier = -1

local function applyState(state: State)
	if not rootFrame or not tierLabel or not xpBarFill then
		return
	end
	tierLabel.Text = string.format("BP Tier %d", state.tier)
	local capacity = math.max(1, state.xpPerTier)
	local intoTier = state.xp - (state.tier * capacity)
	if state.tier >= state.maxTier then
		intoTier = capacity
	end
	intoTier = math.clamp(intoTier, 0, capacity)
	xpBarFill.Size = UDim2.new(intoTier / capacity, 0, 1, 0)

	if state.tier > lastTier and lastTier >= 0 then
		-- Tier-up: tap-through hint. Flash the widget border briefly.
		local stroke = rootFrame:FindFirstChildOfClass("UIStroke")
		if stroke then
			local restColor = Theme.GetActive().highlight
			stroke.Color = Color3.fromRGB(255, 240, 120)
			task.delay(0.6, function()
				if stroke.Parent then
					stroke.Color = restColor
				end
			end)
		end
	end
	lastTier = state.tier
end

local function build(parent: Instance, position: UDim2)
	local btn = Components.Button({
		parent = parent,
		name = "BattlePassWidget",
		text = "",
		size = UDim2.fromOffset(176, 48),
		position = position,
		strokeSlot = "highlight",
		onActivated = function()
			local ok, panel = pcall(require, script.Parent.Parent.Shop.BattlePassPanel)
			if ok and panel and type(panel.Toggle) == "function" then
				panel.Toggle()
			end
		end,
	})
	rootFrame = btn.instance
	-- Clear default centered button text; widget renders its own
	-- left-aligned label + XP bar below.
	btn.instance.Text = ""

	local label = Instance.new("TextLabel")
	label.Name = "TierLabel"
	label.BackgroundTransparency = 1
	label.Position = UDim2.new(0, 8, 0, 4)
	label.Size = UDim2.new(1, -16, 0, 22)
	label.Font = Enum.Font.GothamBold
	label.TextScaled = true
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.TextColor3 = Theme.GetActive().textPrimary
	label.Text = "BP Tier 0"
	label.Parent = btn.instance
	tierLabel = label

	-- Live re-tint the label on theme swap (Components doesn't auto-
	-- tint child instances we add manually).
	local conn = Theme.Changed:Connect(function()
		if label.Parent then
			label.TextColor3 = Theme.GetActive().textPrimary
		end
	end)
	btn.instance.Destroying:Connect(function()
		conn:Disconnect()
	end)

	-- XP bar.
	local barBg = Instance.new("Frame")
	barBg.Name = "BarBg"
	barBg.Position = UDim2.new(0, 8, 1, -16)
	barBg.Size = UDim2.new(1, -16, 0, 8)
	barBg.BackgroundColor3 = Color3.fromRGB(20, 20, 26)
	barBg.BorderSizePixel = 0
	barBg.Parent = btn.instance
	local barCorner = Instance.new("UICorner")
	barCorner.CornerRadius = UDim.new(0, 2)
	barCorner.Parent = barBg

	local fill = Instance.new("Frame")
	fill.Name = "Fill"
	fill.Size = UDim2.new(0, 0, 1, 0)
	fill.BackgroundColor3 = Theme.GetActive().highlight
	fill.BorderSizePixel = 0
	fill.Parent = barBg
	local fillCorner = Instance.new("UICorner")
	fillCorner.CornerRadius = UDim.new(0, 2)
	fillCorner.Parent = fill
	xpBarFill = fill

	-- Live re-tint the XP fill on theme swap.
	local fillConn = Theme.Changed:Connect(function()
		if fill.Parent then
			fill.BackgroundColor3 = Theme.GetActive().highlight
		end
	end)
	fill.Destroying:Connect(function()
		fillConn:Disconnect()
	end)
end

export type InitOpts = {
	parent: Instance?, -- if nil, widget builds its own ScreenGui (legacy)
	position: UDim2?, -- defaults to UDim2.new(0, 16, 0, 16) when standalone
}

function BattlePassWidget.Init(opts: InitOpts?)
	local options: InitOpts = opts or {}
	local parent: Instance
	if options.parent then
		parent = options.parent
	else
		local Players = game:GetService("Players")
		local player = Players.LocalPlayer
		local playerGui = player:WaitForChild("PlayerGui")
		local existing = playerGui:FindFirstChild("BattlePassWidget")
		if existing then
			existing:Destroy()
		end
		local gui = Instance.new("ScreenGui")
		gui.Name = "BattlePassWidget"
		gui.ResetOnSpawn = false
		gui.IgnoreGuiInset = true
		gui.DisplayOrder = 18
		gui.Parent = playerGui
		parent = gui
	end
	build(parent, options.position or UDim2.new(0, 16, 0, 16))
	Remotes.BattlePassState.OnClientEvent:Connect(function(state: State)
		applyState(state)
	end)
end

return BattlePassWidget
