--!strict
--[[
	Outpost-7 — shop orchestrator (client).

	Phase C2. Builds the ShopPanel and adds a toggle button to the
	HUD layer. Single binding: tap the button → ShopPanel.Toggle().

	Phase G aesthetic pass replaces the placeholder button with a
	proper iconography pass + spring-tween entry on the panel.
--]]

local Players = game:GetService("Players")

local ShopPanel = require(script.Parent.ShopPanel)

local ShopController = {}

local function buildToggleButton()
	local player = Players.LocalPlayer
	local playerGui = player:WaitForChild("PlayerGui")

	local existing = playerGui:FindFirstChild("ShopToggle")
	if existing then
		existing:Destroy()
	end

	local gui = Instance.new("ScreenGui")
	gui.Name = "ShopToggle"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.Parent = playerGui

	local btn = Instance.new("TextButton")
	btn.Size = UDim2.new(0, 80, 0, 40)
	btn.Position = UDim2.new(0, 16, 0, 16)
	btn.BackgroundColor3 = Color3.fromRGB(20, 24, 32)
	btn.BackgroundTransparency = 0.2
	btn.TextColor3 = Color3.fromRGB(220, 240, 200)
	btn.Font = Enum.Font.GothamBold
	btn.TextScaled = true
	btn.Text = "Shop"
	btn.AutoButtonColor = true
	btn.Parent = gui

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 8)
	corner.Parent = btn

	local stroke = Instance.new("UIStroke")
	stroke.Color = Color3.fromRGB(120, 220, 180)
	stroke.Thickness = 1
	stroke.Transparency = 0.5
	stroke.Parent = btn

	btn.Activated:Connect(function()
		ShopPanel.Toggle()
	end)
end

function ShopController.Init()
	ShopPanel.Init()
	buildToggleButton()
end

return ShopController
