--!strict
--[[
	Outpost-7 — pass + dev-product store (client UI).

	Phase D5. Combined panel listing all GamePasses (4) and Dev
	Products (4). Catalog comes from `Constants.MONETIZATION` (shared).
	Ownership comes from `Remotes.OwnershipState` (server is the source
	of truth per ADR-006).

	GamePass cards show "Owned" when the ownership map says so;
	otherwise a Buy button calls
	`MarketplaceService:PromptGamePassPurchase`. Dev Product cards
	always show a Buy button → `PromptProductPurchase` (consumables;
	no "owned" state).

	Visual style is debug-grade. Phase G replaces with neon-tactical
	theming + icons.

	Public API:
	  Init        — build GUI, subscribe to OwnershipState
	  Show / Hide — toggle visibility
--]]

local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Constants = require(Shared:WaitForChild("Constants"))
local Remotes = require(Shared:WaitForChild("Remotes"))

local GamePassPanel = {}

local screenGui: ScreenGui? = nil
local content: ScrollingFrame? = nil
local ownership: { [string]: boolean } = {}

local function setVisible(visible: boolean)
	if screenGui then
		screenGui.Enabled = visible
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
	local card = Instance.new("Frame")
	card.Size = UDim2.new(1, -16, 0, 96)
	card.BackgroundColor3 = Color3.fromRGB(28, 32, 40)
	card.BorderSizePixel = 0
	card.Parent = parent
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 8)
	corner.Parent = card
	local stroke = Instance.new("UIStroke")
	stroke.Color = if ownedOrBought then Color3.fromRGB(180, 220, 100) else Color3.fromRGB(120, 220, 180)
	stroke.Thickness = 1
	stroke.Transparency = 0.4
	stroke.Parent = card

	local name = Instance.new("TextLabel")
	name.Size = UDim2.new(1, -180, 0, 28)
	name.Position = UDim2.new(0, 12, 0, 8)
	name.BackgroundTransparency = 1
	name.TextColor3 = Color3.fromRGB(220, 240, 200)
	name.Font = Enum.Font.GothamBold
	name.TextScaled = true
	name.TextXAlignment = Enum.TextXAlignment.Left
	name.Text = displayName
	name.Parent = card

	local desc = Instance.new("TextLabel")
	desc.Size = UDim2.new(1, -180, 0, 50)
	desc.Position = UDim2.new(0, 12, 0, 40)
	desc.BackgroundTransparency = 1
	desc.TextColor3 = Color3.fromRGB(180, 200, 210)
	desc.Font = Enum.Font.Gotham
	desc.TextWrapped = true
	desc.TextScaled = false
	desc.TextSize = 14
	desc.TextXAlignment = Enum.TextXAlignment.Left
	desc.TextYAlignment = Enum.TextYAlignment.Top
	desc.Text = description
	desc.Parent = card

	local btn = Instance.new("TextButton")
	btn.Size = UDim2.new(0, 156, 0, 64)
	btn.Position = UDim2.new(1, -168, 0, 16)
	btn.BackgroundColor3 = if ownedOrBought then Color3.fromRGB(60, 60, 70) else Color3.fromRGB(120, 220, 180)
	btn.TextColor3 = if ownedOrBought then Color3.fromRGB(180, 220, 100) else Color3.fromRGB(20, 24, 32)
	btn.Font = Enum.Font.GothamBold
	btn.TextScaled = true
	btn.AutoButtonColor = not ownedOrBought
	btn.Active = not ownedOrBought
	btn.Text = if ownedOrBought then "Owned" else string.format("Buy\n%d R$", priceRobux)
	btn.Parent = card
	local btnCorner = Instance.new("UICorner")
	btnCorner.CornerRadius = UDim.new(0, 6)
	btnCorner.Parent = btn

	if not ownedOrBought then
		btn.Activated:Connect(onBuy)
	end
end

local function rebuild()
	if not content then
		return
	end
	for _, child in content:GetChildren() do
		if child:IsA("Frame") then
			child:Destroy()
		end
	end

	-- Section: Game Passes
	local passHeader = Instance.new("TextLabel")
	passHeader.Size = UDim2.new(1, -16, 0, 30)
	passHeader.BackgroundTransparency = 1
	passHeader.TextColor3 = Color3.fromRGB(120, 220, 180)
	passHeader.Font = Enum.Font.GothamBold
	passHeader.TextScaled = true
	passHeader.TextXAlignment = Enum.TextXAlignment.Left
	passHeader.Text = "GAME PASSES"
	passHeader.Parent = content

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

	-- Section: Dev Products
	local prodHeader = Instance.new("TextLabel")
	prodHeader.Size = UDim2.new(1, -16, 0, 30)
	prodHeader.BackgroundTransparency = 1
	prodHeader.TextColor3 = Color3.fromRGB(220, 180, 100)
	prodHeader.Font = Enum.Font.GothamBold
	prodHeader.TextScaled = true
	prodHeader.TextXAlignment = Enum.TextXAlignment.Left
	prodHeader.Text = "PRODUCTS"
	prodHeader.Parent = content

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
	gui.Parent = playerGui

	local panel = Instance.new("Frame")
	panel.Size = UDim2.new(0, 600, 0, 480)
	panel.Position = UDim2.new(0.5, -300, 0.5, -240)
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
	title.Text = "Store"
	title.Parent = panel

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
