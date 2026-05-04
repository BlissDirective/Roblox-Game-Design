--!strict
--[[
	Outpost-7 — restocking shop panel (client UI).

	Phase C2. Slide-up panel showing the current rotation's 3 items.
	Each card shows name, description, cost, and a Buy button (or
	"Sold Out" if already purchased this rotation). Listens to
	`Remotes.ShopState`; invokes `Remotes.BuyShopItem` on tap.

	Visual style is debug-grade. Phase G aesthetic pass replaces with
	neon-tactical theming + rarity tints + restock countdown.

	Public API:
	  Init       — build the GUI (hidden)
	  Show / Hide — toggle visibility (HudController exposes a button)
--]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Remotes = require(Shared:WaitForChild("Remotes"))
local HudFormat = require(Shared:WaitForChild("Modules"):WaitForChild("Lib"):WaitForChild("HudFormat"))

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

local RARITY_COLORS: { [string]: Color3 } = {
	Common = Color3.fromRGB(160, 170, 180),
	Uncommon = Color3.fromRGB(120, 220, 180),
	Rare = Color3.fromRGB(220, 180, 100),
}

local ShopPanel = {}

local screenGui: ScreenGui? = nil
local cardsRow: Frame? = nil
local titleLabel: TextLabel? = nil
local lastState: State? = nil
local pendingBuys: { [string]: boolean } = {}

local function setVisible(visible: boolean)
	if screenGui then
		screenGui.Enabled = visible
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
	local card = Instance.new("Frame")
	card.Size = UDim2.new(0, 200, 1, 0)
	card.BackgroundColor3 = Color3.fromRGB(28, 32, 40)
	card.BorderSizePixel = 0
	card.Parent = parent

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 8)
	corner.Parent = card

	local stroke = Instance.new("UIStroke")
	stroke.Color = RARITY_COLORS[item.rarity] or RARITY_COLORS.Common
	stroke.Thickness = 2
	stroke.Transparency = 0.3
	stroke.Parent = card

	local name = Instance.new("TextLabel")
	name.Size = UDim2.new(1, -16, 0, 30)
	name.Position = UDim2.new(0, 8, 0, 8)
	name.BackgroundTransparency = 1
	name.TextColor3 = RARITY_COLORS[item.rarity] or RARITY_COLORS.Common
	name.Font = Enum.Font.GothamBold
	name.TextScaled = true
	name.TextXAlignment = Enum.TextXAlignment.Left
	name.Text = item.displayName
	name.Parent = card

	local rarity = Instance.new("TextLabel")
	rarity.Size = UDim2.new(1, -16, 0, 16)
	rarity.Position = UDim2.new(0, 8, 0, 40)
	rarity.BackgroundTransparency = 1
	rarity.TextColor3 = Color3.fromRGB(150, 160, 170)
	rarity.Font = Enum.Font.Gotham
	rarity.TextScaled = true
	rarity.TextXAlignment = Enum.TextXAlignment.Left
	rarity.Text = item.rarity
	rarity.Parent = card

	local desc = Instance.new("TextLabel")
	desc.Size = UDim2.new(1, -16, 0, 30)
	desc.Position = UDim2.new(0, 8, 0, 60)
	desc.BackgroundTransparency = 1
	desc.TextColor3 = Color3.fromRGB(220, 230, 240)
	desc.Font = Enum.Font.Gotham
	desc.TextScaled = true
	desc.TextXAlignment = Enum.TextXAlignment.Left
	desc.Text = item.description
	desc.Parent = card

	local btn = Instance.new("TextButton")
	btn.Size = UDim2.new(1, -16, 0, 44)
	btn.Position = UDim2.new(0, 8, 1, -52)
	btn.BackgroundColor3 = if item.bought then Color3.fromRGB(60, 60, 70) else Color3.fromRGB(120, 220, 180)
	btn.TextColor3 = if item.bought then Color3.fromRGB(180, 180, 180) else Color3.fromRGB(20, 24, 32)
	btn.Font = Enum.Font.GothamBold
	btn.TextScaled = true
	btn.AutoButtonColor = not item.bought
	btn.Active = not item.bought
	btn.Text = if item.bought then "Sold Out" else string.format("Buy — %s ¢", HudFormat.Abbreviated(item.cost))
	btn.Parent = card

	local btnCorner = Instance.new("UICorner")
	btnCorner.CornerRadius = UDim.new(0, 6)
	btnCorner.Parent = btn

	if not item.bought then
		btn.Activated:Connect(onBuy)
	end
end

local function rebuildCards(state: State)
	if not cardsRow or not titleLabel then
		return
	end
	titleLabel.Text = string.format("Shop — %s", formatCountdown(state.secondsUntilRestock))
	-- Clear old cards
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
				-- Server-pushed ShopState will refresh the UI; the
				-- spinner is short-lived enough that we don't need
				-- explicit "...buying..." UI for V1.
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
	gui.Parent = playerGui

	local panel = Instance.new("Frame")
	panel.Size = UDim2.new(0, 680, 0, 280)
	panel.Position = UDim2.new(0.5, -340, 0.5, -140)
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
	title.Size = UDim2.new(1, -60, 0, 40)
	title.Position = UDim2.new(0, 16, 0, 12)
	title.BackgroundTransparency = 1
	title.TextColor3 = Color3.fromRGB(220, 240, 200)
	title.Font = Enum.Font.GothamBold
	title.TextScaled = true
	title.TextXAlignment = Enum.TextXAlignment.Left
	title.Text = "Shop"
	title.Parent = panel
	titleLabel = title

	local closeBtn = Instance.new("TextButton")
	closeBtn.Size = UDim2.new(0, 36, 0, 36)
	closeBtn.Position = UDim2.new(1, -44, 0, 14)
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
