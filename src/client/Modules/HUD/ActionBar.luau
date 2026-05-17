--!strict
--[[
	Outpost-7 — bottom-of-screen action bar (client).

	Phase G5. Consolidates the per-controller toggle buttons (Shop,
	Daily Quests, Clan) into a single mode-contextual surface. Replaces
	the four hardcoded HUD toggle buttons (ShopToggle, QuestsToggle,
	BattlePassToggle, ClanToggle) that the original Phase C/D/E
	controllers each built independently.

	Mode-contextual visibility (per Round 2 design call):
	  Build  — Shop / Quests / Clan + Combat-mode toggle visible
	  Combat — Build-mode toggle only (Shop / Quests / Clan hidden)
	  Raid   — fully hidden (raid place has its own minimal HUD)

	Dominant-thumb layout (per Round 3 design call):
	  Detect first-input X coordinate on the first frame. If
	  touch.X < screen.X/2 → "left"; else "right". Persist via
	  Remotes.UiPrefsUpdate. On rejoin, profile.uiPrefs.dominantThumb
	  drives the layout flip:
	    right (default) — action bar bottom-LEFT, mode toggle bottom-RIGHT
	    left            — action bar bottom-RIGHT, mode toggle bottom-LEFT

	Long-press on Clan opens the social sub-menu (Friends / Leaderboard
	access) — implemented in G5.2b. For G5.2a the long-press handler
	is a stub; short-tap toggles the Clan panel as before.

	Buttons reference the appropriate controllers' Toggle() entry point
	so behavior is unchanged from the V1 implementation. The action bar
	merely consolidates the *trigger* surface — panels themselves
	migrate to the Theme/Components style in G5.2b.
--]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Constants = require(Shared:WaitForChild("Constants"))
local Enums = require(Shared:WaitForChild("Enums"))
local Remotes = require(Shared:WaitForChild("Remotes"))
local Components = require(Shared:WaitForChild("Modules"):WaitForChild("UI"):WaitForChild("Components"))

-- Forward-required controllers. Each owns a Toggle() entry point that
-- the action bar fires on activation. The bar never imports panel
-- internals.
local function lazyToggle(modulePath: { string }): () -> ()
	-- Resolve at activation time so circular requires aren't a problem
	-- and the bar can be required from anywhere in client init order.
	return function()
		local node: any = script.Parent.Parent
		for _, segment in modulePath do
			node = node:FindFirstChild(segment)
			if not node then
				warn(string.format("[ActionBar] Could not resolve module path: %s", table.concat(modulePath, ".")))
				return
			end
		end
		local ok, mod = pcall(require, node)
		if not ok or not mod or type(mod.Toggle) ~= "function" then
			warn(string.format("[ActionBar] Module %s has no Toggle()", table.concat(modulePath, ".")))
			return
		end
		mod.Toggle()
	end
end

local ActionBar = {}

-- Layout state. Recomputed on dominant thumb detection.
local screenGui: ScreenGui?
local rootFrame: Frame?
local btnHandles: { [string]: any } = {} -- name → Components.ButtonHandle
local modeBtnHandle: any = nil

local currentMode: string = Enums.Mode.Build
local dominantThumb: string = "right" -- default until profile load or first-tap detection

local BTN_SIZE = Constants.UI.Hud.ActionBarButtonSize
local GAP = Constants.UI.Hud.ActionBarGapPx
local BOTTOM_OFFSET = Constants.UI.Hud.ActionBarBottomOffsetPx
local MODE_PADDING = Constants.UI.Hud.ModeTogglePaddingPx

-- Button definitions. Each entry resolves its Toggle() at fire time
-- (lazyToggle) so we don't pull controller modules into the action
-- bar's own require graph.
type ButtonDef = {
	name: string,
	text: string,
	strokeSlot: string,
	onActivated: () -> (),
}

local BUTTON_DEFS: { ButtonDef } = {
	{
		name = "Shop",
		text = "Shop",
		strokeSlot = "accent",
		onActivated = lazyToggle({ "Shop", "ShopPanel" }),
	},
	{
		name = "Quests",
		text = "Quests",
		strokeSlot = "secondary",
		onActivated = lazyToggle({ "Retention", "DailyQuestsPanel" }),
	},
	{
		name = "Clan",
		text = "Clan",
		strokeSlot = "highlight",
		onActivated = lazyToggle({ "Social", "ClanController" }),
	},
}

local function actionBarAnchor(): (Vector2, UDim2)
	-- Returns AnchorPoint + Position for the action bar root.
	-- Right-thumb default: action bar bottom-LEFT (mode toggle right).
	-- Left-thumb override: action bar bottom-RIGHT (mode toggle left).
	if dominantThumb == "left" then
		return Vector2.new(1, 1),
			UDim2.new(1, -MODE_PADDING, 1, -BOTTOM_OFFSET)
	end
	return Vector2.new(0, 1),
		UDim2.new(0, MODE_PADDING, 1, -BOTTOM_OFFSET)
end

local function modeBtnAnchor(): (Vector2, UDim2)
	if dominantThumb == "left" then
		return Vector2.new(0, 1),
			UDim2.new(0, MODE_PADDING, 1, -BOTTOM_OFFSET)
	end
	return Vector2.new(1, 1),
		UDim2.new(1, -MODE_PADDING, 1, -BOTTOM_OFFSET)
end

local function applyLayout()
	if not rootFrame or not modeBtnHandle then
		return
	end
	local anchor, pos = actionBarAnchor()
	rootFrame.AnchorPoint = anchor
	rootFrame.Position = pos
	local mAnchor, mPos = modeBtnAnchor()
	modeBtnHandle.instance.AnchorPoint = mAnchor
	modeBtnHandle.instance.Position = mPos
end

local function modeLabel(): string
	-- Build mode → "COMBAT" (tap switches to combat)
	-- Combat mode → "BUILD" (tap switches back)
	-- Raid mode → empty (mode toggle hidden in raid place)
	if currentMode == Enums.Mode.Build then
		return "COMBAT"
	elseif currentMode == Enums.Mode.Combat then
		return "BUILD"
	end
	return ""
end

local function nextMode(): string
	if currentMode == Enums.Mode.Build then
		return Enums.Mode.Combat
	end
	return Enums.Mode.Build
end

local function applyVisibility()
	-- Build mode: action bar + mode toggle visible.
	-- Combat mode: action bar hidden, mode toggle visible.
	-- Raid mode: everything hidden.
	if not rootFrame or not modeBtnHandle then
		return
	end
	if currentMode == Enums.Mode.Build then
		rootFrame.Visible = true
		modeBtnHandle.instance.Visible = true
		modeBtnHandle:SetText(modeLabel())
	elseif currentMode == Enums.Mode.Combat then
		rootFrame.Visible = false
		modeBtnHandle.instance.Visible = true
		modeBtnHandle:SetText(modeLabel())
	else
		-- Raid or any unknown future mode.
		rootFrame.Visible = false
		modeBtnHandle.instance.Visible = false
	end
end

local function buildActionBar()
	local player = Players.LocalPlayer
	local playerGui = player:WaitForChild("PlayerGui")

	local existing = playerGui:FindFirstChild("ActionBar")
	if existing then
		existing:Destroy()
	end

	local gui = Instance.new("ScreenGui")
	gui.Name = "ActionBar"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.DisplayOrder = 20 -- above HUD pills, below ToastService
	gui.Parent = playerGui
	screenGui = gui

	-- Bar root holds the 3 action buttons in a horizontal row.
	local bar = Instance.new("Frame")
	bar.Name = "Bar"
	bar.BackgroundTransparency = 1
	bar.Size = UDim2.fromOffset(#BUTTON_DEFS * BTN_SIZE + (#BUTTON_DEFS - 1) * GAP, BTN_SIZE)
	bar.Parent = gui
	rootFrame = bar

	local layout = Instance.new("UIListLayout")
	layout.FillDirection = Enum.FillDirection.Horizontal
	layout.Padding = UDim.new(0, GAP)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = bar

	for i, def in BUTTON_DEFS do
		local handle = Components.Button({
			parent = bar,
			name = def.name,
			text = def.text,
			size = UDim2.fromOffset(BTN_SIZE, BTN_SIZE),
			strokeSlot = def.strokeSlot,
			onActivated = def.onActivated,
		})
		handle.instance.LayoutOrder = i
		btnHandles[def.name] = handle
	end

	-- Mode toggle. Anchored opposite the action bar.
	modeBtnHandle = Components.Button({
		parent = gui,
		name = "ModeToggle",
		text = modeLabel(),
		size = UDim2.fromOffset(96, BTN_SIZE),
		strokeSlot = "danger", -- combat = danger color
		onActivated = function()
			local target = nextMode()
			local ok = pcall(function()
				local mc = require(script.Parent.Parent.Core.ModeController) :: any
				mc.SetMode(target)
			end)
			if not ok then
				warn("[ActionBar] ModeController.SetMode failed")
			end
		end,
	})

	applyLayout()
	applyVisibility()
end

local thumbDetected = false
local function pushThumbPref(thumb: string)
	if thumb ~= "left" and thumb ~= "right" then
		return
	end
	if dominantThumb == thumb then
		thumbDetected = true
		return
	end
	dominantThumb = thumb
	thumbDetected = true
	applyLayout()
	Remotes.UiPrefsUpdate:FireServer({ dominantThumb = thumb })
end

local function bindFirstInputDetection()
	-- Single-fire on the first Touch input. Mouse + keyboard users skip
	-- the detection (they get the right-thumb-default layout — which on
	-- desktop is a non-issue since both corners are equally reachable).
	local connection: RBXScriptConnection?
	connection = UserInputService.InputBegan:Connect(function(input)
		if thumbDetected then
			if connection then
				connection:Disconnect()
			end
			return
		end
		if input.UserInputType ~= Enum.UserInputType.Touch then
			return
		end
		local camera = workspace.CurrentCamera
		if not camera then
			return
		end
		local screenX = camera.ViewportSize.X
		if screenX <= 0 then
			return
		end
		local touchX = input.Position.X
		local thumb = if touchX < screenX * 0.5 then "left" else "right"
		pushThumbPref(thumb)
		if connection then
			connection:Disconnect()
		end
	end)
end

function ActionBar.SetDominantThumbFromProfile(value: string?)
	-- Called by HudController.Init after DataManager.WaitForData
	-- equivalent is unavailable on client. In V1 the client doesn't
	-- have a direct profile-read surface — the heuristic re-detects
	-- per session unless we replicate the stored value.
	if value == "left" or value == "right" then
		dominantThumb = value
		thumbDetected = true
		applyLayout()
	end
end

function ActionBar.Init()
	if RunService:IsStudio() then
		-- No harm in running in Studio, but keep the print quiet.
	end
	buildActionBar()
	bindFirstInputDetection()

	-- Subscribe to mode changes for the visibility swap.
	local ok, ModeController = pcall(require, script.Parent.Parent.Core.ModeController)
	if ok and ModeController and ModeController.OnModeChanged then
		ModeController.OnModeChanged(function(_oldMode: string, newMode: string)
			currentMode = newMode
			applyVisibility()
		end)
		currentMode = ModeController.GetMode()
		applyVisibility()
	end

	-- G5: apply persisted dominant thumb from profile (server pushes
	-- UiPrefsState once after profile load).
	Remotes.UiPrefsState.OnClientEvent:Connect(function(payload: any)
		if type(payload) == "table" then
			ActionBar.SetDominantThumbFromProfile(payload.dominantThumb)
		end
	end)
end

return ActionBar
