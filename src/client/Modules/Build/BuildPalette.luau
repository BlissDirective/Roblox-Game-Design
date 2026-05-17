--!strict
--[[
	Outpost-7 — build-mode buildable picker (client UI).

	Phase B4. Bottom-center ScreenGui with a button per buildable
	(extractor, wall). Tap a button to select it (preview activates);
	tap again to deselect. BuildController subscribes to selection
	changes via `OnSelectionChanged`.

	Catalog data comes from the shared BuildableRegistry — the same
	source the server uses, so palette labels and costs can never
	drift from server-side validation.
--]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local BuildableRegistry =
	require(Shared:WaitForChild("Modules"):WaitForChild("Registry"):WaitForChild("BuildableRegistry"))

local BuildPalette = {}

export type SelectionChangedHandler = (buildableId: string?) -> ()

local selected: string? = nil
local buttons: { [string]: TextButton } = {}
local handlers: { SelectionChangedHandler } = {}
local screenGui: ScreenGui? = nil

-- Order matters for the palette's left-to-right layout. V1 ships with
-- three entries (E2.5 added turret); Phase G/V1.5 adds drone-bay, decor.
local PALETTE_ORDER = { "extractor", "wall", "turret" }

local function notify(id: string?)
	for _, handler in handlers do
		handler(id)
	end
end

local function setSelected(id: string?)
	if selected == id then
		return
	end
	selected = id
	for buttonId, button in buttons do
		button.BackgroundTransparency = if buttonId == id then 0 else 0.5
	end
	notify(id)
end

local function build()
	local player = Players.LocalPlayer
	local playerGui = player:WaitForChild("PlayerGui")

	local existing = playerGui:FindFirstChild("BuildPalette")
	if existing then
		existing:Destroy()
	end

	local gui = Instance.new("ScreenGui")
	gui.Name = "BuildPalette"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.Parent = playerGui
	screenGui = gui

	local container = Instance.new("Frame")
	container.Size = UDim2.new(0, 460, 0, 80)
	container.Position = UDim2.new(0.5, -230, 1, -100)
	container.BackgroundTransparency = 1
	container.Parent = gui

	local layout = Instance.new("UIListLayout")
	layout.FillDirection = Enum.FillDirection.Horizontal
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	layout.VerticalAlignment = Enum.VerticalAlignment.Center
	layout.Padding = UDim.new(0, 12)
	layout.Parent = container

	for _, id in PALETTE_ORDER do
		local buildable = BuildableRegistry.Get(id)
		if not buildable then
			continue
		end

		local btn = Instance.new("TextButton")
		btn.Name = id
		btn.Size = UDim2.new(0, 140, 0, 64)
		btn.BackgroundColor3 = buildable.color
		btn.BackgroundTransparency = 0.5
		btn.TextColor3 = Color3.fromRGB(255, 255, 255)
		btn.TextScaled = true
		btn.Font = Enum.Font.GothamBold
		btn.Text = string.format("%s\n%d ¢", buildable.displayName, buildable.cost)
		btn.AutoButtonColor = false
		btn.Parent = container

		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(0, 8)
		corner.Parent = btn

		btn.Activated:Connect(function()
			if selected == id then
				setSelected(nil)
			else
				setSelected(id)
			end
		end)

		buttons[id] = btn
	end
end

function BuildPalette.GetSelected(): string?
	return selected
end

function BuildPalette.SetSelected(id: string?)
	setSelected(id)
end

function BuildPalette.OnSelectionChanged(handler: SelectionChangedHandler)
	table.insert(handlers, handler)
end

function BuildPalette.Show()
	if screenGui then
		screenGui.Enabled = true
	end
end

function BuildPalette.Hide()
	if screenGui then
		screenGui.Enabled = false
	end
end

function BuildPalette.Init()
	build()
end

return BuildPalette
