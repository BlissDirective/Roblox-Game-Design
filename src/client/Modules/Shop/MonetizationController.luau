--!strict
--[[
	Outpost-7 — monetization UI orchestrator (client).

	Phase D5. Builds two HUD toggle buttons — "Store" (passes + dev
	products) and "Battle Pass" — and wires them to the corresponding
	panels. Both panels are created here at Init.

	Position: top-row right of the existing Shop / Quests toggles.
	V1 mobile UX has 4 toggles in a row (Shop, Quests, Store,
	Battle Pass); Phase G repositions per device.
--]]

local Players = game:GetService("Players")

local GamePassPanel = require(script.Parent.GamePassPanel)
local BattlePassPanel = require(script.Parent.BattlePassPanel)

local MonetizationController = {}

local function buildToggle(name: string, label: string, x: number, strokeColor: Color3, onActivate: () -> ())
	local player = Players.LocalPlayer
	local playerGui = player:WaitForChild("PlayerGui")

	local existing = playerGui:FindFirstChild(name)
	if existing then
		existing:Destroy()
	end

	local gui = Instance.new("ScreenGui")
	gui.Name = name
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.Parent = playerGui

	local btn = Instance.new("TextButton")
	btn.Size = UDim2.new(0, 96, 0, 40)
	btn.Position = UDim2.new(0, x, 0, 16)
	btn.BackgroundColor3 = Color3.fromRGB(20, 24, 32)
	btn.BackgroundTransparency = 0.2
	btn.TextColor3 = Color3.fromRGB(220, 240, 200)
	btn.Font = Enum.Font.GothamBold
	btn.TextScaled = true
	btn.Text = label
	btn.AutoButtonColor = true
	btn.Parent = gui

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 8)
	corner.Parent = btn

	local stroke = Instance.new("UIStroke")
	stroke.Color = strokeColor
	stroke.Thickness = 1
	stroke.Transparency = 0.5
	stroke.Parent = btn

	btn.Activated:Connect(onActivate)
end

function MonetizationController.Init()
	GamePassPanel.Init()
	BattlePassPanel.Init()

	-- Layout: ShopController places "Shop" at x=16 (w=80).
	-- DailyQuestsPanel places "Quests" at x=104 (w=88).
	-- Continue right: Store at x=208, Battle Pass at x=320.
	buildToggle("StoreToggle", "Store", 208, Color3.fromRGB(120, 220, 180), function()
		GamePassPanel.Toggle()
	end)
	buildToggle("BattlePassToggle", "Battle Pass", 320, Color3.fromRGB(220, 180, 100), function()
		BattlePassPanel.Toggle()
	end)
end

return MonetizationController
