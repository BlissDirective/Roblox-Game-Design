--!strict
--[[
	Outpost-7 — pass + dev-product store (client UI).

	Phase D5 (original). Phase G5.2b theme migration.

	Combined panel listing all GamePasses (4) and Dev Products (4).
	Catalog comes from `Constants.MONETIZATION` (shared). Ownership
	comes from `Remotes.OwnershipState` (server is the source of
	truth per ADR-006).

	GamePass cards show "Owned" when the ownership map says so;
	otherwise a Buy button calls `PromptGamePassPurchase`. Dev Product
	cards always show a Buy button → `PromptProductPurchase`.

	G5.2b migration:
	  - Root panel + cards + buttons rebuilt on Components.StrokedFrame /
	    Components.Button.
	  - State-driven palette slots:
	      owned   → secondary (premium-cyan/magenta — distinct from
	                accent)
	      buy     → accent (biome accent — primary CTA)
	  - Live re-tint on biome swap.
--]]

local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Constants = require(Shared:WaitForChild("Constants"))
local Remotes = require(Shared:WaitForChild("Remotes"))
local Components = require(Shared:WaitForChild("Modules"):WaitForChild("UI"):WaitForChild("Components"))
local Theme = require(Shared:WaitForChild("Modules"):WaitForChild("UI"):WaitForChild("Theme"))

local GamePassPanel = {}

local screenGui: ScreenGui? = nil
local panelScale: UIScale? = nil
local content: ScrollingFrame? = nil
local ownership: { [string]: boolean } = {}

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

local function buildCard(
	parent: Instance,
	displayName: string,
	description: string,
	priceRobux: number,
	ownedOrBought: boolean,
	onBuy: () -> ()
)
	local strokeSlot = if ownedOrBought then "secondary" else "accent"
	local card = Components.StrokedFrame({
		parent = parent,
		name = "Card_" .. displayName,
		size = UDim2.new(1, -16, 0, 96),
		bgSlot = "panel",
		strokeSlot = strokeSlot,
		cornerAccent = false,
	})

	local name = Instance.new("TextLabel")
	name.Size = UDim2.new(1, -180, 0, 28)
	name.Position = UDim2.new(0, 12, 0, 8)
	name.BackgroundTransparency = 1
	name.TextColor3 = Theme.GetActive().textPrimary
	name.Font = Enum.Font.GothamBold
	name.TextScaled = true
	name.TextXAlignment = Enum.TextXAlignment.Left
	name.Text = displayName
	name.Parent = card

	local desc = Instance.new("TextLabel")
	desc.Size = UDim2.new(1, -180, 0, 50)
	desc.Position = UDim2.new(0, 12, 0, 40)
	desc.BackgroundTransparency = 1
	desc.TextColor3 = Theme.GetActive().textMuted
	desc.Font = Enum.Font.Gotham
	desc.TextWrapped = true
	desc.TextSize = 14
	desc.TextXAlignment = Enum.TextXAlignment.Left
	desc.TextYAlignment = Enum.TextYAlignment.Top
	desc.Text = description
	desc.Parent = card

	local themeConn = Theme.Changed:Connect(function()
		if name.Parent then
			local p = Theme.GetActive()
			name.TextColor3 = p.textPrimary
			desc.TextColor3 = p.textMuted
		end
	end)
	card.Destroying:Connect(function()
		themeConn:Disconnect()
	end)

	local btnHandle = Components.Button({
		parent = card,
		name = "BuyButton",
		text = if ownedOrBought then "Owned" else string.format("Buy\n%d R$", priceRobux),
		size = UDim2.fromOffset(156, 64),
		position = UDim2.new(1, -168, 0, 16),
		bgSlot = if ownedOrBought then "background" else strokeSlot,
		textSlot = if ownedOrBought then "secondary" else "background",
		strokeSlot = strokeSlot,
		onActivated = if ownedOrBought then function() end else onBuy,
	})
	btnHandle:SetEnabled(not ownedOrBought)
end

local function sectionHeader(parent: Instance, text: string, slot: string)
	local header = Instance.new("TextLabel")
	header.Size = UDim2.new(1, -16, 0, 30)
	header.BackgroundTransparency = 1
	header.TextColor3 = (Theme.GetActive() :: any)[slot]
	header.Font = Enum.Font.GothamBold
	header.TextScaled = true
	header.TextXAlignment = Enum.TextXAlignment.Left
	header.Text = text
	header.Parent = parent
	local conn = Theme.Changed:Connect(function()
		if header.Parent then
			header.TextColor3 = (Theme.GetActive() :: any)[slot]
		end
	end)
	header.Destroying:Connect(function()
		conn:Disconnect()
	end)
end

local function rebuild()
	if not content then
		return
	end
	for _, child in content:GetChildren() do
		if child:IsA("Frame") or child:IsA("TextLabel") then
			child:Destroy()
		end
	end

	sectionHeader(content, "GAME PASSES", "accent")
	for key, def in Constants.MONETIZATION.GamePasses do
		local owned = ownership[key] == true
		buildCard(content, def.displayName, def.description, def.priceRobux, owned, function()
			if def.id <= 0 then
				warn(string.format("[GamePassPanel] %s has placeholder ID — REPLACE_BEFORE_LAUNCH", key))
				return
			end
			pcall(function()
				MarketplaceService:PromptGamePassPurchase(Players.LocalPlayer, def.id)
			end)
		end)
	end

	sectionHeader(content, "PRODUCTS", "highlight")
	for key, def in Constants.MONETIZATION.DevProducts do
		buildCard(content, def.displayName, def.description, def.priceRobux, false, function()
			if def.id <= 0 then
				warn(string.format("[GamePassPanel] %s has placeholder ID — REPLACE_BEFORE_LAUNCH", key))
				return
			end
			pcall(function()
				MarketplaceService:PromptProductPurchase(Players.LocalPlayer, def.id)
			end)
		end)
	end
end

local function build()
	local player = Players.LocalPlayer
	local playerGui = player:WaitForChild("PlayerGui")

	local existing = playerGui:FindFirstChild("GamePassPanel")
	if existing then
		existing:Destroy()
	end

	local gui = Instance.new("ScreenGui")
	gui.Name = "GamePassPanel"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.Enabled = false
	gui.DisplayOrder = 30
	gui.Parent = playerGui

	local panel = Components.StrokedFrame({
		parent = gui,
		name = "Panel",
		size = UDim2.fromOffset(600, 480),
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
	title.Text = "Store"
	title.Parent = panel

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

	local scroll = Instance.new("ScrollingFrame")
	scroll.Size = UDim2.new(1, -32, 1, -72)
	scroll.Position = UDim2.new(0, 16, 0, 60)
	scroll.BackgroundTransparency = 1
	scroll.BorderSizePixel = 0
	scroll.ScrollBarThickness = 6
	scroll.CanvasSize = UDim2.new(0, 0, 0, 0)
	scroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
	scroll.Parent = panel

	local layout = Instance.new("UIListLayout")
	layout.FillDirection = Enum.FillDirection.Vertical
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	layout.Padding = UDim.new(0, 12)
	layout.Parent = scroll

	screenGui = gui
	content = scroll
end

function GamePassPanel.Show()
	setVisible(true)
	rebuild()
end

function GamePassPanel.Hide()
	setVisible(false)
end

function GamePassPanel.Toggle()
	if screenGui and screenGui.Enabled then
		GamePassPanel.Hide()
	else
		GamePassPanel.Show()
	end
end

function GamePassPanel.Init()
	build()
	local remote = Remotes.OwnershipState :: RemoteEvent
	remote.OnClientEvent:Connect(function(newOwnership: { [string]: boolean })
		ownership = newOwnership
		if screenGui and screenGui.Enabled then
			rebuild()
		end
	end)
end

return GamePassPanel
