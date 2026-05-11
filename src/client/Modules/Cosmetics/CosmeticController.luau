--!strict
--[[
	Outpost-7 — cosmetic equip panel (client).

	Phase G7. Toggle button + right-side panel showing the player's
	8 cosmetic slots. Each slot lists owned cosmetics for that slot;
	clicking equips. "NEW!" badge shows on items acquired within the
	last 24h per Constants.COSMETIC.NewBadgeWindowSeconds.

	Also handles unlock toast (CosmeticUnlocked Remote) — pops a
	5-second banner when a cosmetic is granted (BP claim, VIP unlock,
	first-join default).

	V1 visuals are placeholder per the Phase G aesthetic queue. Phase G
	art queue replaces with neon-tactical icons + animated equip flair.

	Public API:
	  Init  — wires Remote listeners + builds panel scaffolding
--]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Constants = require(Shared:WaitForChild("Constants"))
local Remotes = require(Shared:WaitForChild("Remotes"))
local CosmeticRegistry =
	require(Shared:WaitForChild("Modules"):WaitForChild("Registry"):WaitForChild("CosmeticRegistry"))

local CosmeticController = {}

type State = {
	owned: { [string]: number },
	equipped: { [string]: string },
}

type UnlockToast = {
	cosmeticId: string,
	source: string,
}

local SLOT_ORDER = {
	{ id = Constants.COSMETIC.Slots.Skin, label = "Operator Skin" },
	{ id = Constants.COSMETIC.Slots.HelmetDecal, label = "Helmet Decal" },
	{ id = Constants.COSMETIC.Slots.DroneTrail, label = "Drone Trail" },
	{ id = Constants.COSMETIC.Slots.NameplateFlair, label = "Nameplate" },
	-- V1.5+ slots are listed but greyed out until catalog entries exist:
	{ id = Constants.COSMETIC.Slots.Emote, label = "Emote (V1.5+)" },
	{ id = Constants.COSMETIC.Slots.Banner, label = "Banner (V1.5+)" },
	{ id = Constants.COSMETIC.Slots.VehiclePaint, label = "Vehicle Paint (V1.5+)" },
	{ id = Constants.COSMETIC.Slots.MountCosmetic, label = "Mount (V2)" },
}

local RARITY_COLORS = {
	common = Color3.fromRGB(180, 180, 195),
	uncommon = Color3.fromRGB(120, 220, 120),
	rare = Color3.fromRGB(120, 180, 255),
	legendary = Color3.fromRGB(255, 215, 100),
}

local currentState: State? = nil
local panelOpen = false
local screenGui: ScreenGui? = nil

local function ensureScreenGui(): ScreenGui
	if screenGui then
		return screenGui
	end
	local pg = Players.LocalPlayer:WaitForChild("PlayerGui") :: PlayerGui
	local existing = pg:FindFirstChild("OutpostCosmetics")
	if existing and existing:IsA("ScreenGui") then
		screenGui = existing
		return existing
	end
	local gui = Instance.new("ScreenGui")
	gui.Name = "OutpostCosmetics"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.Parent = pg
	screenGui = gui
	return gui
end

local function isNew(acquiredAt: number): boolean
	return os.time() - acquiredAt < Constants.COSMETIC.NewBadgeWindowSeconds
end

local function buildCosmeticRow(
	parent: Instance,
	cosmetic: any,
	owned: boolean,
	equipped: boolean,
	acquiredAt: number?
)
	local row = Instance.new("TextButton")
	row.Size = UDim2.new(1, -12, 0, 36)
	row.BackgroundColor3 = if equipped then Color3.fromRGB(48, 56, 80) else Color3.fromRGB(28, 28, 36)
	row.BackgroundTransparency = if owned then 0 else 0.4
	row.BorderSizePixel = 0
	row.AutoButtonColor = owned

	local stroke = Instance.new("UIStroke")
	stroke.Thickness = if equipped then 2 else 1
	stroke.Color = RARITY_COLORS[cosmetic.rarity] or RARITY_COLORS.common
	stroke.Parent = row

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 4)
	corner.Parent = row

	row.Text = ""
	row.Parent = parent

	local nameLbl = Instance.new("TextLabel")
	nameLbl.Size = UDim2.new(0.7, -8, 1, 0)
	nameLbl.Position = UDim2.fromOffset(8, 0)
	nameLbl.BackgroundTransparency = 1
	nameLbl.TextColor3 = if owned then RARITY_COLORS[cosmetic.rarity] or RARITY_COLORS.common else Color3.fromRGB(120, 120, 130)
	nameLbl.Font = Enum.Font.GothamBold
	nameLbl.TextSize = 13
	nameLbl.TextXAlignment = Enum.TextXAlignment.Left
	nameLbl.Text = cosmetic.displayName
	nameLbl.Parent = row

	local statusLbl = Instance.new("TextLabel")
	statusLbl.Size = UDim2.new(0.3, -8, 1, 0)
	statusLbl.Position = UDim2.new(0.7, 0, 0, 0)
	statusLbl.BackgroundTransparency = 1
	statusLbl.Font = Enum.Font.Gotham
	statusLbl.TextSize = 11
	statusLbl.TextXAlignment = Enum.TextXAlignment.Right
	if equipped then
		statusLbl.Text = "EQUIPPED"
		statusLbl.TextColor3 = Color3.fromRGB(120, 220, 255)
	elseif owned then
		statusLbl.Text = if acquiredAt and isNew(acquiredAt) then "NEW!" else "Equip"
		statusLbl.TextColor3 = if acquiredAt and isNew(acquiredAt) then Color3.fromRGB(255, 215, 100) else Color3.fromRGB(180, 180, 195)
	else
		statusLbl.Text = "Locked"
		statusLbl.TextColor3 = Color3.fromRGB(120, 120, 130)
	end
	statusLbl.Parent = row

	if owned and not equipped then
		row.MouseButton1Click:Connect(function()
			local remote = Remotes.EquipCosmetic :: RemoteFunction
			pcall(function()
				remote:InvokeServer(cosmetic.slot, cosmetic.id)
			end)
		end)
	end
end

local function refreshPanel()
	if not panelOpen then
		return
	end
	local gui = ensureScreenGui()
	local panel = gui:FindFirstChild("CosmeticsPanel")
	if not panel or not panel:IsA("Frame") then
		return
	end
	-- Find the inner scrolling content frame; clear + rebuild rows.
	local content = panel:FindFirstChild("Content")
	if not content then
		return
	end
	for _, child in content:GetChildren() do
		if child:IsA("GuiObject") then
			child:Destroy()
		end
	end

	local state = currentState or { owned = {}, equipped = {} }

	for _, slotInfo in SLOT_ORDER do
		local cosmetics = CosmeticRegistry.GetForSlot(slotInfo.id)
		-- Slot header
		local header = Instance.new("TextLabel")
		header.Size = UDim2.new(1, -8, 0, 22)
		header.BackgroundTransparency = 1
		header.TextColor3 = Color3.fromRGB(220, 220, 235)
		header.Font = Enum.Font.GothamBold
		header.TextSize = 14
		header.TextXAlignment = Enum.TextXAlignment.Left
		header.Text = slotInfo.label
		header.Parent = content

		if #cosmetics == 0 then
			local empty = Instance.new("TextLabel")
			empty.Size = UDim2.new(1, -8, 0, 22)
			empty.BackgroundTransparency = 1
			empty.TextColor3 = Color3.fromRGB(120, 120, 130)
			empty.Font = Enum.Font.Gotham
			empty.TextSize = 11
			empty.TextXAlignment = Enum.TextXAlignment.Left
			empty.Text = "  No cosmetics in catalog yet."
			empty.Parent = content
			continue
		end
		table.sort(cosmetics, function(a, b)
			return a.id < b.id
		end)
		for _, cosmetic in cosmetics do
			local owned = state.owned[cosmetic.id] ~= nil
			local equipped = state.equipped[cosmetic.slot] == cosmetic.id
			buildCosmeticRow(content, cosmetic, owned, equipped, state.owned[cosmetic.id])
		end
		-- spacer
		local spacer = Instance.new("Frame")
		spacer.Size = UDim2.new(1, 0, 0, 8)
		spacer.BackgroundTransparency = 1
		spacer.Parent = content
	end
end

local function ensurePanel(): Frame
	local gui = ensureScreenGui()
	local existing = gui:FindFirstChild("CosmeticsPanel")
	if existing and existing:IsA("Frame") then
		return existing
	end
	local panel = Instance.new("Frame")
	panel.Name = "CosmeticsPanel"
	panel.Size = UDim2.fromOffset(320, 520)
	panel.Position = UDim2.new(1, -336, 0, 100)
	panel.BackgroundColor3 = Color3.fromRGB(16, 16, 22)
	panel.BorderSizePixel = 0
	panel.Visible = false
	local stroke = Instance.new("UIStroke")
	stroke.Thickness = 2
	stroke.Color = Color3.fromRGB(255, 215, 100)
	stroke.Parent = panel
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 8)
	corner.Parent = panel

	local title = Instance.new("TextLabel")
	title.Size = UDim2.new(1, -16, 0, 24)
	title.Position = UDim2.fromOffset(8, 8)
	title.BackgroundTransparency = 1
	title.TextColor3 = Color3.fromRGB(220, 220, 235)
	title.Font = Enum.Font.GothamBold
	title.TextSize = 16
	title.TextXAlignment = Enum.TextXAlignment.Left
	title.Text = "Cosmetics"
	title.Parent = panel

	local content = Instance.new("ScrollingFrame")
	content.Name = "Content"
	content.Size = UDim2.new(1, -16, 1, -44)
	content.Position = UDim2.fromOffset(8, 36)
	content.BackgroundColor3 = Color3.fromRGB(12, 12, 18)
	content.BorderSizePixel = 0
	content.ScrollBarThickness = 4
	content.AutomaticCanvasSize = Enum.AutomaticSize.Y
	content.CanvasSize = UDim2.new(0, 0, 0, 0)
	local layout = Instance.new("UIListLayout")
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Padding = UDim.new(0, 4)
	layout.Parent = content
	local pad = Instance.new("UIPadding")
	pad.PaddingTop = UDim.new(0, 4)
	pad.PaddingLeft = UDim.new(0, 6)
	pad.PaddingRight = UDim.new(0, 6)
	pad.Parent = content
	local cCorner = Instance.new("UICorner")
	cCorner.CornerRadius = UDim.new(0, 4)
	cCorner.Parent = content

	content.Parent = panel
	panel.Parent = gui
	return panel
end

local function buildToggleButton()
	local gui = ensureScreenGui()
	if gui:FindFirstChild("CosmeticsToggle") then
		return
	end
	local btn = Instance.new("TextButton")
	btn.Name = "CosmeticsToggle"
	btn.Size = UDim2.fromOffset(112, 40)
	btn.Position = UDim2.new(0, 432, 0, 56)
	btn.BackgroundColor3 = Color3.fromRGB(28, 28, 36)
	btn.BorderSizePixel = 0
	btn.TextColor3 = Color3.fromRGB(220, 220, 235)
	btn.Font = Enum.Font.GothamBold
	btn.TextSize = 14
	btn.Text = "Cosmetics"
	local stroke = Instance.new("UIStroke")
	stroke.Thickness = 2
	stroke.Color = Color3.fromRGB(255, 215, 100)
	stroke.Parent = btn
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 6)
	corner.Parent = btn
	btn.Parent = gui

	btn.MouseButton1Click:Connect(function()
		panelOpen = not panelOpen
		local panel = ensurePanel()
		panel.Visible = panelOpen
		if panelOpen then
			refreshPanel()
		end
	end)
end

local function showUnlockToast(toast: UnlockToast)
	local def = CosmeticRegistry.Get(toast.cosmeticId)
	if not def then
		return
	end
	local gui = ensureScreenGui()
	local banner = Instance.new("TextLabel")
	banner.Size = UDim2.fromOffset(360, 56)
	banner.Position = UDim2.new(0.5, -180, 0, 120)
	banner.BackgroundColor3 = Color3.fromRGB(20, 20, 28)
	banner.BorderSizePixel = 0
	banner.TextColor3 = RARITY_COLORS[def.rarity] or RARITY_COLORS.common
	banner.Font = Enum.Font.GothamBold
	banner.TextSize = 14
	banner.Text = string.format("🎁 NEW COSMETIC UNLOCKED\n%s", def.displayName)

	local stroke = Instance.new("UIStroke")
	stroke.Thickness = 2
	stroke.Color = RARITY_COLORS[def.rarity] or RARITY_COLORS.common
	stroke.Parent = banner

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 6)
	corner.Parent = banner

	banner.Parent = gui
	task.delay(5, function()
		if banner.Parent then
			banner:Destroy()
		end
	end)
end

function CosmeticController.Init()
	buildToggleButton()
	ensurePanel()

	local stateRemote = Remotes.CosmeticState :: RemoteEvent
	stateRemote.OnClientEvent:Connect(function(state: any)
		if typeof(state) ~= "table" then
			return
		end
		currentState = state :: State
		refreshPanel()
	end)

	local unlockRemote = Remotes.CosmeticUnlocked :: RemoteEvent
	unlockRemote.OnClientEvent:Connect(function(toast: any)
		if typeof(toast) ~= "table" then
			return
		end
		showUnlockToast(toast :: UnlockToast)
	end)
end

return CosmeticController
