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

local LONG_PRESS_SECONDS = 0.5

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

-- G5.2b: Social sub-menu (Friends + Leaderboard) opened by long-
-- pressing the Clan action-bar button. Short-tap on Clan still calls
-- ClanController.Toggle().
local socialMenuFrame: Frame? = nil
local socialMenuVisible = false

local function ensureSocialMenu(): Frame
	if socialMenuFrame and socialMenuFrame.Parent then
		return socialMenuFrame
	end
	-- Parent to the ActionBar's ScreenGui (not the bar Frame) so the
	-- bar's UIListLayout doesn't lay the menu out as a sibling button.
	local menu = Components.StrokedFrame({
		parent = screenGui :: Instance,
		name = "SocialMenu",
		size = UDim2.fromOffset(140, 96),
		bgSlot = "panel",
		strokeSlot = "highlight",
		cornerAccent = false,
	})
	menu.Visible = false
	-- Position immediately above the Clan button. The bar is anchored
	-- bottom-LEFT (right thumb) or bottom-RIGHT (left thumb); the menu
	-- sits ABOVE the Clan button regardless.
	menu.AnchorPoint = Vector2.new(0.5, 1)

	local layout = Instance.new("UIListLayout")
	layout.FillDirection = Enum.FillDirection.Vertical
	layout.Padding = UDim.new(0, 4)
	layout.Parent = menu
	local pad = Instance.new("UIPadding")
	pad.PaddingTop = UDim.new(0, 4)
	pad.PaddingBottom = UDim.new(0, 4)
	pad.PaddingLeft = UDim.new(0, 4)
	pad.PaddingRight = UDim.new(0, 4)
	pad.Parent = menu

	local function hideMenu()
		socialMenuVisible = false
		menu.Visible = false
	end

	Components.Button({
		parent = menu,
		name = "Friends",
		text = "Friends",
		size = UDim2.new(1, 0, 0, 36),
		strokeSlot = "secondary",
		onActivated = function()
			hideMenu()
			local ok, mod = pcall(require, script.Parent.Parent.Social.FriendsPanel)
			if ok and mod and type(mod.Toggle) == "function" then
				mod.Toggle()
			end
		end,
	})
	Components.Button({
		parent = menu,
		name = "Leaderboard",
		text = "Leaderboard",
		size = UDim2.new(1, 0, 0, 36),
		strokeSlot = "highlight",
		onActivated = function()
			hideMenu()
			local ok, mod = pcall(require, script.Parent.Parent.Social.LeaderboardController)
			if ok and mod and type(mod.Toggle) == "function" then
				mod.Toggle()
			end
		end,
	})

	socialMenuFrame = menu
	return menu
end

local function showSocialMenu(clanBtn: GuiObject)
	local menu = ensureSocialMenu()
	-- Position the menu centered above the Clan button. The menu's
	-- AnchorPoint is (0.5, 1) so Position = top-center of the menu.
	local btnAbs = clanBtn.AbsolutePosition
	local btnSize = clanBtn.AbsoluteSize
	local centerX = btnAbs.X + btnSize.X * 0.5
	local topY = btnAbs.Y - 6 -- 6px gap above the button
	menu.Position = UDim2.fromOffset(centerX, topY)
	menu.Visible = true
	socialMenuVisible = true

	-- Auto-dismiss on tap-outside: a one-shot InputBegan listener.
	local dismiss: RBXScriptConnection?
	dismiss = UserInputService.InputBegan:Connect(function(input)
		if not socialMenuVisible then
			if dismiss then
				dismiss:Disconnect()
			end
			return
		end
		if input.UserInputType ~= Enum.UserInputType.MouseButton1 and input.UserInputType ~= Enum.UserInputType.Touch then
			return
		end
		-- Tap inside the menu? Let the menu buttons handle it.
		local pos = input.Position
		local menuAbs = menu.AbsolutePosition
		local menuSize = menu.AbsoluteSize
		local inside = pos.X >= menuAbs.X
			and pos.X <= menuAbs.X + menuSize.X
			and pos.Y >= menuAbs.Y
			and pos.Y <= menuAbs.Y + menuSize.Y
		if not inside then
			socialMenuVisible = false
			menu.Visible = false
			if dismiss then
				dismiss:Disconnect()
			end
		end
	end)
end

local function attachClanLongPress(btn: GuiObject, shortTapHandler: () -> ())
	local pressStart: number? = nil
	local longPressFired = false

	btn.MouseButton1Down:Connect(function()
		pressStart = os.clock()
		longPressFired = false
		task.delay(LONG_PRESS_SECONDS, function()
			if pressStart and not longPressFired and os.clock() - pressStart >= LONG_PRESS_SECONDS then
				longPressFired = true
				showSocialMenu(btn)
			end
		end)
	end)
	btn.MouseButton1Up:Connect(function()
		if pressStart and not longPressFired then
			shortTapHandler()
		end
		pressStart = nil
	end)
	btn.MouseLeave:Connect(function()
		pressStart = nil
	end)
	btn.TouchTap:Connect(function()
		-- Touch path: TouchTap fires on short tap. Long-press on touch
		-- is detected by the same MouseButton1Down/Up bridge (Roblox
		-- forwards touch to mouse). The TouchTap fire is a no-op since
		-- the Down/Up already triggered the short-tap branch.
	end)
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
		-- G5.2b: Clan button special-cases long-press → social sub-
		-- menu. Disable Components.Button's auto onActivated so we
		-- can attach our own press-duration logic.
		local handle = Components.Button({
			parent = bar,
			name = def.name,
			text = def.text,
			size = UDim2.fromOffset(BTN_SIZE, BTN_SIZE),
			strokeSlot = def.strokeSlot,
			onActivated = if def.name == "Clan" then function() end else def.onActivated,
		})
		handle.instance.LayoutOrder = i
		btnHandles[def.name] = handle
		if def.name == "Clan" then
			attachClanLongPress(handle.instance, def.onActivated)
		end
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
