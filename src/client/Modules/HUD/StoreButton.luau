--!strict
--[[
	Outpost-7 — Store (GamePass) entry button (client).

	Phase G5 (G5.2c). Top-left HUD button sitting under the
	BattlePassWidget in the "Wallet" cluster. Taps open
	GamePassPanel.Toggle(). Replaces the original StoreToggle that
	MonetizationController built; the cluster restructure unifies the
	two monetization-facing HUD widgets into a single visual column.

	The panel migration of GamePassPanel itself (Components.Panel + Theme
	palette slots) is deferred — this button only handles the trigger
	surface.
--]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Components = require(Shared:WaitForChild("Modules"):WaitForChild("UI"):WaitForChild("Components"))

local StoreButton = {}

local handle: any = nil

export type InitOpts = {
	parent: Instance?,
	position: UDim2?,
}

function StoreButton.Init(opts: InitOpts?)
	local options: InitOpts = opts or {}
	local parent: Instance
	if options.parent then
		parent = options.parent
	else
		local Players = game:GetService("Players")
		local player = Players.LocalPlayer
		local playerGui = player:WaitForChild("PlayerGui")
		local existing = playerGui:FindFirstChild("StoreButton")
		if existing then
			existing:Destroy()
		end
		local gui = Instance.new("ScreenGui")
		gui.Name = "StoreButton"
		gui.ResetOnSpawn = false
		gui.IgnoreGuiInset = true
		gui.DisplayOrder = 18
		gui.Parent = playerGui
		parent = gui
	end

	handle = Components.Button({
		parent = parent,
		name = "Store",
		text = "Store",
		size = UDim2.fromOffset(176, 36),
		position = options.position or UDim2.new(0, 16, 0, 72),
		strokeSlot = "secondary",
		onActivated = function()
			local ok, panel = pcall(require, script.Parent.Parent.Shop.GamePassPanel)
			if ok and panel and type(panel.Toggle) == "function" then
				panel.Toggle()
			end
		end,
	})
end

return StoreButton
