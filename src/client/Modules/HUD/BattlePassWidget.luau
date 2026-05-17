--!strict
--[[
	Outpost-7 — Battle Pass progress widget (client).

	Phase G5. Small top-left HUD widget showing the player's current BP
	tier + XP progress to next tier. Tap = open the BattlePassPanel.
	Replaces the original "Battle Pass" toggle button that MonetizationController
	built at x=320 in the top row.

	Drives BP awareness during normal play (always visible during Build
	mode); on tier-up, a brief highlight pulse signals the unlock so
	the player taps through.

	State source: `Remotes.BattlePassState` (same Remote that
	BattlePassPanel subscribes to). The widget caches the latest state
	and re-renders on every push.
--]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Remotes = require(Shared:WaitForChild("Remotes"))
local Components = require(Shared:WaitForChild("Modules"):WaitForChild("UI"):WaitForChild("Components"))

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

local function setText(label: TextLabel, value: string)
	label.Text = value
end

local function applyState(state: State)
	if not rootFrame or not tierLabel or not xpBarFill then
		return
	end
	setText(tierLabel, string.format("BP Tier %d", state.tier))
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
			local original = stroke.Color
			stroke.Color = Color3.fromRGB(255, 220, 80) -- highlight pulse
			task.delay(0.6, function()
				if stroke.Parent then
					stroke.Color = original
				end
			end)
		end
	end
	lastTier = state.tier
end

local function build()
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

	-- Use Components.Button so the press feedback + ui_button_click +
	-- StrokedFrame styling are free.
	local btn = Components.Button({
		parent = gui,
		name = "Widget",
		text = "",
		size = UDim2.fromOffset(176, 48),
		position = UDim2.new(0, 16, 0, 16),
		strokeSlot = "highlight",
		onActivated = function()
			local ok, panel = pcall(require, script.Parent.Parent.Shop.BattlePassPanel)
			if ok and panel and type(panel.Toggle) == "function" then
				panel.Toggle()
			end
		end,
	})
	rootFrame = btn.instance

	-- Override default button center-aligned text with a tier label +
	-- XP bar layered inside. Clear the button text first.
	btn.instance.Text = ""

	local label = Instance.new("TextLabel")
	label.Name = "TierLabel"
	label.BackgroundTransparency = 1
	label.Position = UDim2.new(0, 8, 0, 4)
	label.Size = UDim2.new(1, -16, 0, 22)
	label.Font = Enum.Font.GothamBold
	label.TextScaled = true
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.TextColor3 = Color3.fromRGB(230, 230, 220)
	label.Text = "BP Tier 0"
	label.Parent = btn.instance
	tierLabel = label

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
	fill.BackgroundColor3 = Color3.fromRGB(255, 200, 80)
	fill.BorderSizePixel = 0
	fill.Parent = barBg
	local fillCorner = Instance.new("UICorner")
	fillCorner.CornerRadius = UDim.new(0, 2)
	fillCorner.Parent = fill
	xpBarFill = fill
end

function BattlePassWidget.Init()
	build()
	Remotes.BattlePassState.OnClientEvent:Connect(function(state: State)
		applyState(state)
	end)
end

return BattlePassWidget
