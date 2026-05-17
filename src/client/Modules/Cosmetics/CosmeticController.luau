--!strict
--[[
	Outpost-7 — cosmetic equip panel (client).

	Phase G7 (original). Phase G5.2b theme migration.

	Toggle button + right-side panel showing the player's 8 cosmetic
	slots. Each slot lists owned cosmetics for that slot; clicking
	equips. "NEW!" badge shows on items acquired within the last 24h
	per Constants.COSMETIC.NewBadgeWindowSeconds.

	G5.2b changes:
	  - Toggle + panel + rows rebuilt on Components primitives + Theme
	    palette slots. Rarity → palette slot mapping below.
	  - The duplicate unlock-banner that previously fired here is
	    REMOVED — ToastService (G5.1) already subscribes to
	    `CosmeticUnlocked` and shows the toast via `ShowInfo`. Two
	    banners for one event is redundant.
	  - Mode-contextual: toggle hides in Combat/Raid mode (Build only,
	    consistent with the rest of the HUD).
--]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Constants = require(Shared:WaitForChild("Constants"))
local Enums = require(Shared:WaitForChild("Enums"))
local Remotes = require(Shared:WaitForChild("Remotes"))
local Components = require(Shared:WaitForChild("Modules"):WaitForChild("UI"):WaitForChild("Components"))
local Theme = require(Shared:WaitForChild("Modules"):WaitForChild("UI"):WaitForChild("Theme"))
local CosmeticRegistry =
	require(Shared:WaitForChild("Modules"):WaitForChild("Registry"):WaitForChild("CosmeticRegistry"))

local CosmeticController = {}

type State = {
	owned: { [string]: number },
	equipped: { [string]: string },
}

local SLOT_ORDER = {
	{ id = Constants.COSMETIC.Slots.Skin, label = "Operator Skin" },
	{ id = Constants.COSMETIC.Slots.HelmetDecal, label = "Helmet Decal" },
	{ id = Constants.COSMETIC.Slots.DroneTrail, label = "Drone Trail" },
	{ id = Constants.COSMETIC.Slots.NameplateFlair, label = "Nameplate" },
	{ id = Constants.COSMETIC.Slots.Emote, label = "Emote (V1.5+)" },
	{ id = Constants.COSMETIC.Slots.Banner, label = "Banner (V1.5+)" },
	{ id = Constants.COSMETIC.Slots.VehiclePaint, label = "Vehicle Paint (V1.5+)" },
	{ id = Constants.COSMETIC.Slots.MountCosmetic, label = "Mount (V2)" },
}

-- Rarity → palette slot. Maps cosmetic rarity to the existing Theme
-- palette so colors stay biome-aware:
--   common    → textMuted (greyish across themes)
--   uncommon  → secondary (cool-secondary across themes)
--   rare      → accent (biome accent — primary color)
--   legendary → highlight (celebratory/amber across themes)
local RARITY_SLOT: { [string]: string } = {
	common = "textMuted",
	uncommon = "secondary",
	rare = "accent",
	legendary = "highlight",
}

local currentState: State? = nil
local panelOpen = false
local screenGui: ScreenGui? = nil
local toggleHandle: any = nil
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

local function ensureScreenGui(): ScreenGui
	if screenGui and screenGui.Parent then
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
	gui.DisplayOrder = 25
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
	local raritySlot = RARITY_SLOT[cosmetic.rarity] or "textMuted"

	local handle = Components.Button({
		parent = parent,
		name = "Row_" .. cosmetic.id,
		text = "",
		size = UDim2.new(1, -12, 0, 36),
		bgSlot = if equipped then "panel" else "background",
		strokeSlot = raritySlot,
		onActivated = if owned and not equipped
			then function()
				local remote = Remotes.EquipCosmetic :: RemoteFunction
				pcall(function()
					remote:InvokeServer(cosmetic.slot, cosmetic.id)
				end)
			end
			else function() end,
	})
	handle:SetEnabled(owned and not equipped)

	local nameLbl = Instance.new("TextLabel")
	nameLbl.Size = UDim2.new(0.7, -8, 1, 0)
	nameLbl.Position = UDim2.fromOffset(8, 0)
	nameLbl.BackgroundTransparency = 1
	nameLbl.TextColor3 = if owned
		then (Theme.GetActive() :: any)[raritySlot]
		else Theme.GetActive().textMuted
	nameLbl.Font = Enum.Font.GothamBold
	nameLbl.TextSize = 13
	nameLbl.TextXAlignment = Enum.TextXAlignment.Left
	nameLbl.Text = cosmetic.displayName
	nameLbl.Parent = handle.instance

	local statusLbl = Instance.new("TextLabel")
	statusLbl.Size = UDim2.new(0.3, -8, 1, 0)
	statusLbl.Position = UDim2.new(0.7, 0, 0, 0)
	statusLbl.BackgroundTransparency = 1
	statusLbl.Font = Enum.Font.Gotham
	statusLbl.TextSize = 11
	statusLbl.TextXAlignment = Enum.TextXAlignment.Right
	if equipped then
		statusLbl.Text = "EQUIPPED"
		statusLbl.TextColor3 = Theme.GetActive().accent
	elseif owned then
		statusLbl.Text = if acquiredAt and isNew(acquiredAt) then "NEW!" else "Equip"
		statusLbl.TextColor3 = if acquiredAt and isNew(acquiredAt)
			then Theme.GetActive().highlight
			else Theme.GetActive().textMuted
	else
		statusLbl.Text = "Locked"
		statusLbl.TextColor3 = Theme.GetActive().textMuted
	end
	statusLbl.Parent = handle.instance

	-- Theme.Changed re-tint for the labels (the Button auto-tints itself).
	local conn = Theme.Changed:Connect(function()
		if not nameLbl.Parent then
			return
		end
		local p = Theme.GetActive()
		nameLbl.TextColor3 = if owned then (p :: any)[raritySlot] else p.textMuted
		if equipped then
			statusLbl.TextColor3 = p.accent
		elseif owned and acquiredAt and isNew(acquiredAt) then
			statusLbl.TextColor3 = p.highlight
		else
			statusLbl.TextColor3 = p.textMuted
		end
	end)
	handle.instance.Destroying:Connect(function()
		conn:Disconnect()
	end)
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
		local header = Instance.new("TextLabel")
		header.Size = UDim2.new(1, -8, 0, 22)
		header.BackgroundTransparency = 1
		header.TextColor3 = Theme.GetActive().textPrimary
		header.Font = Enum.Font.GothamBold
		header.TextSize = 14
		header.TextXAlignment = Enum.TextXAlignment.Left
		header.Text = slotInfo.label
		header.Parent = content

		if #cosmetics == 0 then
			local empty = Instance.new("TextLabel")
			empty.Size = UDim2.new(1, -8, 0, 22)
			empty.BackgroundTransparency = 1
			empty.TextColor3 = Theme.GetActive().textMuted
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
		local spacer = Instance.new("Frame")
		spacer.Size = UDim2.new(1, 0, 0, 8)
		spacer.BackgroundTransparency = 1
		spacer.Parent = content
	end
end

local function setPanelVisible(visible: boolean)
	local gui = ensureScreenGui()
	local panel = gui:FindFirstChild("CosmeticsPanel")
	if not panel or not panelScale then
		return
	end
	if visible then
		panel.Visible = true
		panelScale.Scale = 0.95
		TweenService:Create(panelScale, easingInfoFor("PanelOpen"), { Scale = 1.0 }):Play()
	else
		TweenService:Create(panelScale, easingInfoFor("PanelClose"), { Scale = 0.95 }):Play()
		task.delay((Constants.UI.Motion.PanelClose :: any).duration, function()
			if panel then
				panel.Visible = false
			end
		end)
	end
end

local function ensurePanel(): Frame
	local gui = ensureScreenGui()
	local existing = gui:FindFirstChild("CosmeticsPanel")
	if existing and existing:IsA("Frame") then
		return existing
	end
	local panel = Components.StrokedFrame({
		parent = gui,
		name = "CosmeticsPanel",
		size = UDim2.fromOffset(320, 520),
		position = UDim2.new(1, -336, 0, 100),
		bgSlot = "panel",
		strokeSlot = "highlight",
		cornerAccent = true,
	})
	panel.Visible = false

	local scale = Instance.new("UIScale")
	scale.Scale = 1.0
	scale.Parent = panel
	panelScale = scale

	local title = Instance.new("TextLabel")
	title.Size = UDim2.new(1, -16, 0, 24)
	title.Position = UDim2.fromOffset(8, 8)
	title.BackgroundTransparency = 1
	title.TextColor3 = Theme.GetActive().textPrimary
	title.Font = Enum.Font.GothamBold
	title.TextSize = 16
	title.TextXAlignment = Enum.TextXAlignment.Left
	title.Text = "Cosmetics"
	title.Parent = panel

	local themeConn = Theme.Changed:Connect(function()
		if title.Parent then
			title.TextColor3 = Theme.GetActive().textPrimary
		end
	end)
	panel.Destroying:Connect(function()
		themeConn:Disconnect()
	end)

	local content = Instance.new("ScrollingFrame")
	content.Name = "Content"
	content.Size = UDim2.new(1, -16, 1, -44)
	content.Position = UDim2.fromOffset(8, 36)
	content.BackgroundTransparency = 1
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
	content.Parent = panel
	return panel
end

local function buildToggleButton()
	local gui = ensureScreenGui()
	if toggleHandle then
		return
	end
	toggleHandle = Components.Button({
		parent = gui,
		name = "CosmeticsToggle",
		text = "Cosmetics",
		size = UDim2.fromOffset(112, 40),
		position = UDim2.new(0, 432, 0, 56),
		strokeSlot = "highlight",
		onActivated = function()
			panelOpen = not panelOpen
			ensurePanel()
			setPanelVisible(panelOpen)
			if panelOpen then
				refreshPanel()
			end
		end,
	})
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

	-- Mode-contextual visibility (Build only). Toggle button hides in
	-- Combat/Raid; if the panel is open when mode changes, close it.
	local ok, ModeController = pcall(require, script.Parent.Parent.Core.ModeController)
	if ok and ModeController and ModeController.OnModeChanged then
		local function applyMode(mode: string)
			if toggleHandle and toggleHandle.instance then
				toggleHandle.instance.Visible = (mode == Enums.Mode.Build)
			end
			if mode ~= Enums.Mode.Build and panelOpen then
				panelOpen = false
				setPanelVisible(false)
			end
		end
		ModeController.OnModeChanged(function(_oldMode: string, newMode: string)
			applyMode(newMode)
		end)
		applyMode(ModeController.GetMode())
	end

	-- NOTE: CosmeticUnlocked toast is handled by HUD/ToastService.
	-- The duplicate banner that lived here pre-G5.2b was removed.
end

return CosmeticController
