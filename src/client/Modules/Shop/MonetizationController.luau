--!strict
--[[
	Outpost-7 — monetization UI orchestrator (client).

	Phase D5 (original). Phase G5.2a refactor.

	Previously owned two HUD toggle buttons (Store + Battle Pass).
	Phase G5.2a removes both:

	  - Battle Pass: replaced by the always-visible top-left
	    `BattlePassWidget` (in `HUD/BattlePassWidget.luau`) which
	    shows tier + XP bar and taps through to BattlePassPanel.
	  - Store (GamePass): the on-screen toggle is replaced by a small
	    top-left button sitting below the BP widget. Implementation
	    deferred to G5.2c (where it gets the full Components.Button
	    treatment alongside the BP widget). For G5.2a we keep the
	    original Store toggle but reposition it just below the BP
	    widget to free up the top-row real estate for the currency
	    pills.

	This controller's only remaining job is `GamePassPanel.Init()` +
	`BattlePassPanel.Init()` for the panel surfaces themselves; the
	HUD entry-points migrate to the new HUD modules.
--]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Components = require(Shared:WaitForChild("Modules"):WaitForChild("UI"):WaitForChild("Components"))

local GamePassPanel = require(script.Parent.GamePassPanel)
local BattlePassPanel = require(script.Parent.BattlePassPanel)

local MonetizationController = {}

local function buildStoreToggle()
	local player = Players.LocalPlayer
	local playerGui = player:WaitForChild("PlayerGui")

	local existing = playerGui:FindFirstChild("StoreToggle")
	if existing then
		existing:Destroy()
	end

	local gui = Instance.new("ScreenGui")
	gui.Name = "StoreToggle"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.DisplayOrder = 18
	gui.Parent = playerGui

	-- Sits just below the BattlePass widget (BP widget = y=16, h=48 →
	-- store toggle at y=72 in the same top-left column).
	Components.Button({
		parent = gui,
		name = "Store",
		text = "Store",
		size = UDim2.fromOffset(96, 36),
		position = UDim2.new(0, 16, 0, 72),
		strokeSlot = "secondary",
		onActivated = function()
			GamePassPanel.Toggle()
		end,
	})
end

function MonetizationController.Init()
	GamePassPanel.Init()
	BattlePassPanel.Init()
	buildStoreToggle()
end

return MonetizationController
