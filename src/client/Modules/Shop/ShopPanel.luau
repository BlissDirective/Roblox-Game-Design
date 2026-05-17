--!strict
--[[
	Outpost-7 — restocking shop panel (client UI).

	Phase C2 (original). Phase G5.2b theme migration.

	Slide-up panel showing the current rotation's 3 items. Each card
	shows name, description, cost, and a Buy button (or "Sold Out" if
	already purchased this rotation). Listens to `Remotes.ShopState`;
	invokes `Remotes.BuyShopItem` on tap.

	G5.2b migration:
	  - Root panel + cards rebuilt on Components.StrokedFrame.
	  - Close button is a Components.Button (danger stroke).
	  - Buy buttons are Components.Button instances; rarity is
	    expressed via the per-card stroke slot mapping below.
	  - All colors via Theme palette; live re-tint on biome swap.

	Rarity mapping uses semantic palette slots:
	  Common   → textMuted (greyish across themes)
	  Uncommon → accent    (biome accent — teal/blue/orange)
	  Rare     → highlight (amber/magenta — celebratory across themes)
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

type ShopItemView = {
	id: string,
	displayName: string,
	description: string,
	rarity: string,
	cost: number,
	bought: boolean,
}

type State = {
	rotation: number,
	secondsUntilRestock: number,
	items: { ShopItemView },
}

local RARITY_SLOT: { [string]: string } = {
	Common = "textMuted",
	Uncommon = "accent",
	Rare = "highlight",
}

local ShopPanel = {}

local screenGui: ScreenGui? = nil
local panelScale: UIScale? = nil
local cardsRow: Frame? = nil
local titleLabel: TextLabel? = nil
local lastState: State? = nil
local pendingBuys: { [string]: boolean } = {}

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

local function formatCountdown(seconds: number): string
	if seconds <= 0 then
		return "restocking..."
	end
	local h = math.floor(seconds / 3600)
	local m = math.floor((seconds % 3600) / 60)
	if h > 0 then
		return string.format("Restocks in %dh %dm", h, m)
	end
	return string.format("Restocks in %dm", math.max(1, m))
end

local function buildCard(parent: Frame, item: ShopItemView, onBuy: () -> ())
	local raritySlot = RARITY_SLOT[item.rarity] or "textMuted"

	local card = Components.StrokedFrame({
		parent = parent,
		name = "Card_" .. item.id,
		size = UDim2.new(0, 200, 1, 0),
		bgSlot = "panel",
		strokeSlot = raritySlot,
		cornerAccent = false,
	})

	local name = Instance.new("TextLabel")
	name.Size = UDim2.new(1, -16, 0, 30)
	name.Position = UDim2.new(0, 8, 0, 8)
	name.BackgroundTransparency = 1
	name.TextColor3 = (Theme.GetActive() :: any)[raritySlot] or Theme.GetActive().textPrimary
	name.Font = Enum.Font.GothamBold
	name.TextScaled = true
	name.TextXAlignment = Enum.TextXAlignment.Left
	name.Text = item.displayName
	name.Parent = card

	local rarity = Instance.new("TextLabel")
	rarity.Size = UDim2.new(1, -16, 0, 16)
	rarity.Position = UDim2.new(0, 8, 0, 40)
	rarity.BackgroundTransparency = 1
	rarity.TextColor3 = Theme.GetActive().textMuted
	rarity.Font = Enum.Font.Gotham
	rarity.TextScaled = true
	rarity.TextXAlignment = Enum.TextXAlignment.Left
	rarity.Text = item.rarity
	rarity.Parent = card

	local desc = Instance.new("TextLabel")
	desc.Size = UDim2.new(1, -16, 0, 30)
	desc.Position = UDim2.new(0, 8, 0, 60)
	desc.BackgroundTransparency = 1
	desc.TextColor3 = Theme.GetActive().textPrimary
	desc.Font = Enum.Font.Gotham
	desc.TextScaled = true
	desc.TextXAlignment = Enum.TextXAlignment.Left
	desc.TextWrapped = true
	desc.Text = item.description
	desc.Parent = card

	local themeConn = Theme.Changed:Connect(function()
		if not name.Parent then
			return
		end
		local p = Theme.GetActive()
		name.TextColor3 = (p :: any)[raritySlot] or p.textPrimary
		rarity.TextColor3 = p.textMuted
		desc.TextColor3 = p.textPrimary
	end)
	card.Destroying:Connect(function()
		themeConn:Disconnect()
	end)

	local buyHandle = Components.Button({
		parent = card,
		name = "BuyButton",
		text = if item.bought then "Sold Out" else string.format("Buy — %s ¢", HudFormat.Abbreviated(item.cost)),
		size = UDim2.new(1, -16, 0, 44),
		position = UDim2.new(0, 8, 1, -52),
		bgSlot = if item.bought then "background" else raritySlot,
		textSlot = if item.bought then "textMuted" else "background",
		strokeSlot = raritySlot,
		onActivated = if item.bought then function() end else onBuy,
	})
	buyHandle:SetEnabled(not item.bought)
end

local function rebuildCards(state: State)
	if not cardsRow or not titleLabel then
		return
	end
	titleLabel.Text = string.format("Shop — %s", formatCountdown(state.secondsUntilRestock))
	for _, child in cardsRow:GetChildren() do
		if child:IsA("Frame") then
			child:Destroy()
		end
	end
	for _, item in state.items do
		local capturedId = item.id
		buildCard(cardsRow, item, function()
			if pendingBuys[capturedId] or item.bought then
				return
			end
			pendingBuys[capturedId] = true
			task.spawn(function()
				local remote = Remotes.BuyShopItem :: RemoteFunction
				pcall(function()
					remote:InvokeServer(capturedId)
				end)
				pendingBuys[capturedId] = nil
			end)
		end)
	end
end

local function build()
	local player = Players.LocalPlayer
	local playerGui = player:WaitForChild("PlayerGui")

	local existing = playerGui:FindFirstChild("ShopPanel")
	if existing then
		existing:Destroy()
	end

	local gui = Instance.new("ScreenGui")
	gui.Name = "ShopPanel"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.Enabled = false
	gui.DisplayOrder = 30
	gui.Parent = playerGui

	local panel = Components.StrokedFrame({
		parent = gui,
		name = "Panel",
		size = UDim2.fromOffset(680, 280),
		position = UDim2.fromScale(0.5, 0.5),
		anchorPoint = Vector2.new(0.5, 0.5),
		bgSlot = "panel",
		strokeSlot = "accent",
		cornerAccent = true,
	})

	local scale = Instance.new("UIScale")
	scale.Scale = 1.0
	scale.Parent = panel
	panelScale = scale

	local title = Instance.new("TextLabel")
	title.Size = UDim2.new(1, -60, 0, 40)
	title.Position = UDim2.new(0, 16, 0, 12)
	title.BackgroundTransparency = 1
	title.TextColor3 = Theme.GetActive().textPrimary
	title.Font = Enum.Font.GothamBold
	title.TextScaled = true
	title.TextXAlignment = Enum.TextXAlignment.Left
	title.Text = "Shop"
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
		position = UDim2.new(1, -14, 0, 14),
		anchorPoint = Vector2.new(1, 0),
		strokeSlot = "danger",
		onActivated = function()
			setVisible(false)
		end,
	})

	local row = Instance.new("Frame")
	row.Size = UDim2.new(1, -32, 0, 200)
	row.Position = UDim2.new(0, 16, 0, 64)
	row.BackgroundTransparency = 1
	row.Parent = panel
	local layout = Instance.new("UIListLayout")
	layout.FillDirection = Enum.FillDirection.Horizontal
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	layout.VerticalAlignment = Enum.VerticalAlignment.Center
	layout.Padding = UDim.new(0, 12)
	layout.Parent = row

	screenGui = gui
	cardsRow = row
end

function ShopPanel.Show()
	setVisible(true)
	if lastState then
		rebuildCards(lastState)
	end
end

function ShopPanel.Hide()
	setVisible(false)
end

function ShopPanel.Toggle()
	if screenGui and screenGui.Enabled then
		ShopPanel.Hide()
	else
		ShopPanel.Show()
	end
end

function ShopPanel.Init()
	build()
	local remote = Remotes.ShopState :: RemoteEvent
	remote.OnClientEvent:Connect(function(state: State)
		lastState = state
		if screenGui and screenGui.Enabled then
			rebuildCards(state)
		end
	end)
end

return ShopPanel
