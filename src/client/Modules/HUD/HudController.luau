--!strict
--[[
	Outpost-7 — top-level HUD orchestrator.

	Phase B4 (original). Phase G5.2a + G5.2c refactor.

	Owns the lifecycle of every on-screen HUD piece:
	  - Top-right: Credits + Cores pills (always visible)
	  - Top-left "Wallet" cluster: BP widget + Store button
	    (Build-mode-only; vertically stacked at x=16)
	  - Bottom: ActionBar (Build mode) / mode toggle (Build + Combat)

	The Wallet cluster is a single ScreenGui hosted here so the
	mode-contextual show/hide is a single subscription. BP widget and
	Store button each retain their own state/listener logic but parent
	their elements into the cluster's content frame.

	Init order:
	  1. Currency pills — mode-independent
	  2. ActionBar — subscribes to ModeController
	  3. Wallet cluster (BP widget + Store) — subscribes to ModeController
--]]

local Players = game:GetService("Players")

local CreditsDisplay = require(script.Parent.CreditsDisplay)
local CoresDisplay = require(script.Parent.CoresDisplay)
local ActionBar = require(script.Parent.ActionBar)
local BattlePassWidget = require(script.Parent.BattlePassWidget)
local StoreButton = require(script.Parent.StoreButton)
local Enums = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("Enums"))

local HudController = {}

local walletGui: ScreenGui?

local function buildWalletCluster()
	local player = Players.LocalPlayer
	local playerGui = player:WaitForChild("PlayerGui")

	local existing = playerGui:FindFirstChild("WalletCluster")
	if existing then
		existing:Destroy()
	end

	local gui = Instance.new("ScreenGui")
	gui.Name = "WalletCluster"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.DisplayOrder = 18
	gui.Parent = playerGui
	walletGui = gui

	-- Container frame at top-left holding BP widget + Store button.
	-- BP widget sits at y=0, Store button at y=56 (8px gap below the
	-- 48px BP widget). Both anchor x=0 inside the container.
	local container = Instance.new("Frame")
	container.Name = "Container"
	container.BackgroundTransparency = 1
	container.Position = UDim2.new(0, 16, 0, 16)
	container.Size = UDim2.fromOffset(176, 92) -- BP (48) + gap (8) + Store (36)
	container.Parent = gui

	BattlePassWidget.Init({
		parent = container,
		position = UDim2.fromOffset(0, 0),
	})
	StoreButton.Init({
		parent = container,
		position = UDim2.fromOffset(0, 56),
	})

	-- Mode-contextual visibility (Build only).
	local ok, ModeController = pcall(require, script.Parent.Parent.Core.ModeController)
	if ok and ModeController and ModeController.OnModeChanged then
		local function applyVisibility(mode: string)
			gui.Enabled = (mode == Enums.Mode.Build)
		end
		ModeController.OnModeChanged(function(_oldMode: string, newMode: string)
			applyVisibility(newMode)
		end)
		applyVisibility(ModeController.GetMode())
	end
end

function HudController.Init()
	CreditsDisplay.Init()
	CoresDisplay.Init()
	ActionBar.Init()
	buildWalletCluster()
end

return HudController
