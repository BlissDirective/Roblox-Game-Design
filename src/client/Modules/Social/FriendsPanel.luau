--!strict
--[[
	Outpost-7 — friends panel (client).

	Phase E5 (original). Phase G5.2b theme migration + standalone-
	toggle teardown.

	G5.2b changes:
	  - Standalone FriendsToggle button removed. Friends panel is now
	    opened via the long-press Clan sub-menu (G5.2b) — see
	    ClanController for the trigger. The panel itself exports
	    `Toggle()` for the sub-menu to call.
	  - Panel + refresh button rebuilt on Components.StrokedFrame /
	    Components.Button.
	  - Status dot color resolves from Theme (online = secondary,
	    offline = textMuted).
	  - Open/close UIScale tween via G5 motion presets.
--]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Constants = require(Shared:WaitForChild("Constants"))
local Remotes = require(Shared:WaitForChild("Remotes"))
local Components = require(Shared:WaitForChild("Modules"):WaitForChild("UI"):WaitForChild("Components"))
local Theme = require(Shared:WaitForChild("Modules"):WaitForChild("UI"):WaitForChild("Theme"))

local FriendsPanel = {}

type Friend = {
	userId: number,
	username: string,
	displayName: string,
	inThisServer: boolean,
}

type State = {
	friends: { Friend },
	fetchedAt: number,
}

local current: State? = nil
local panelOpen = false
local screenGui: ScreenGui? = nil
local panelFrame: Frame? = nil
local panelScale: UIScale? = nil
local listFrame: ScrollingFrame? = nil
local titleLabel: TextLabel? = nil

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
	local existing = pg:FindFirstChild("OutpostFriends")
	if existing and existing:IsA("ScreenGui") then
		screenGui = existing
		return existing
	end
	local gui = Instance.new("ScreenGui")
	gui.Name = "OutpostFriends"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.DisplayOrder = 30
	gui.Parent = pg
	screenGui = gui
	return gui
end

local function rebuildList()
	if not listFrame or not titleLabel then
		return
	end
	for _, child in listFrame:GetChildren() do
		if child:IsA("GuiObject") and not child:IsA("UIListLayout") and not child:IsA("UIPadding") then
			child:Destroy()
		end
	end

	if current then
		titleLabel.Text = string.format("Friends (%d)", #current.friends)
	else
		titleLabel.Text = "Friends"
	end

	if not current then
		local empty = Instance.new("TextLabel")
		empty.Size = UDim2.new(1, -12, 0, 20)
		empty.BackgroundTransparency = 1
		empty.TextColor3 = Theme.GetActive().textMuted
		empty.Font = Enum.Font.Gotham
		empty.TextSize = 12
		empty.Text = "Loading…"
		empty.Parent = listFrame
		return
	end
	if #current.friends == 0 then
		local empty = Instance.new("TextLabel")
		empty.Size = UDim2.new(1, -12, 0, 20)
		empty.BackgroundTransparency = 1
		empty.TextColor3 = Theme.GetActive().textMuted
		empty.Font = Enum.Font.Gotham
		empty.TextSize = 12
		empty.Text = "No friends yet."
		empty.Parent = listFrame
		return
	end

	table.sort(current.friends, function(a, b)
		if a.inThisServer ~= b.inThisServer then
			return a.inThisServer
		end
		return string.lower(a.displayName) < string.lower(b.displayName)
	end)

	for _, friend in current.friends do
		local row = Instance.new("Frame")
		row.Size = UDim2.new(1, -12, 0, 22)
		row.BackgroundTransparency = 1
		row.Parent = listFrame

		local dot = Instance.new("Frame")
		dot.Size = UDim2.fromOffset(8, 8)
		dot.Position = UDim2.fromOffset(2, 7)
		dot.BackgroundColor3 = if friend.inThisServer
			then Theme.GetActive().secondary
			else Theme.GetActive().textMuted
		dot.BorderSizePixel = 0
		local dotCorner = Instance.new("UICorner")
		dotCorner.CornerRadius = UDim.new(1, 0)
		dotCorner.Parent = dot
		dot.Parent = row

		local lbl = Instance.new("TextLabel")
		lbl.Size = UDim2.new(1, -16, 1, 0)
		lbl.Position = UDim2.fromOffset(16, 0)
		lbl.BackgroundTransparency = 1
		lbl.TextColor3 = if friend.inThisServer
			then Theme.GetActive().textPrimary
			else Theme.GetActive().textMuted
		lbl.Font = Enum.Font.Gotham
		lbl.TextSize = 13
		lbl.TextXAlignment = Enum.TextXAlignment.Left
		lbl.Text = friend.displayName
		lbl.Parent = row
	end
end

local function setPanelVisible(visible: boolean)
	if not panelFrame or not panelScale then
		return
	end
	if visible then
		panelFrame.Visible = true
		panelScale.Scale = 0.95
		TweenService:Create(panelScale, easingInfoFor("PanelOpen"), { Scale = 1.0 }):Play()
	else
		TweenService:Create(panelScale, easingInfoFor("PanelClose"), { Scale = 0.95 }):Play()
		task.delay((Constants.UI.Motion.PanelClose :: any).duration, function()
			if panelFrame then
				panelFrame.Visible = false
			end
		end)
	end
end

local function ensurePanel(): Frame
	if panelFrame and panelFrame.Parent then
		return panelFrame
	end
	local gui = ensureScreenGui()
	local panel = Components.StrokedFrame({
		parent = gui,
		name = "FriendsPanel",
		size = UDim2.fromOffset(240, 320),
		position = UDim2.new(1, -256, 0, 460),
		bgSlot = "panel",
		strokeSlot = "secondary",
		cornerAccent = true,
	})
	panel.Visible = false

	local scale = Instance.new("UIScale")
	scale.Scale = 1.0
	scale.Parent = panel
	panelScale = scale

	local title = Instance.new("TextLabel")
	title.Size = UDim2.new(1, -88, 0, 24)
	title.Position = UDim2.fromOffset(8, 8)
	title.BackgroundTransparency = 1
	title.TextColor3 = Theme.GetActive().textPrimary
	title.Font = Enum.Font.GothamBold
	title.TextSize = 16
	title.TextXAlignment = Enum.TextXAlignment.Left
	title.Text = "Friends"
	title.Parent = panel
	titleLabel = title

	Components.Button({
		parent = panel,
		name = "RefreshButton",
		text = "Refresh",
		size = UDim2.fromOffset(72, 24),
		position = UDim2.new(1, -80, 0, 8),
		strokeSlot = "accent",
		onActivated = function()
			local remote = Remotes.RefreshFriends :: RemoteFunction
			pcall(function()
				remote:InvokeServer()
			end)
		end,
	})

	local list = Instance.new("ScrollingFrame")
	list.Size = UDim2.new(1, -16, 1, -44)
	list.Position = UDim2.fromOffset(8, 40)
	list.BackgroundTransparency = 1
	list.BorderSizePixel = 0
	list.ScrollBarThickness = 4
	list.AutomaticCanvasSize = Enum.AutomaticSize.Y
	list.CanvasSize = UDim2.new(0, 0, 0, 0)
	local listLayout = Instance.new("UIListLayout")
	listLayout.Padding = UDim.new(0, 2)
	listLayout.Parent = list
	local pad = Instance.new("UIPadding")
	pad.PaddingTop = UDim.new(0, 4)
	pad.PaddingLeft = UDim.new(0, 6)
	pad.PaddingRight = UDim.new(0, 6)
	pad.Parent = list
	list.Parent = panel
	listFrame = list

	local themeConn = Theme.Changed:Connect(function()
		if title.Parent then
			title.TextColor3 = Theme.GetActive().textPrimary
		end
		-- Re-render list rows on biome swap to re-apply dot/label colors.
		if panelOpen then
			rebuildList()
		end
	end)
	panel.Destroying:Connect(function()
		themeConn:Disconnect()
	end)

	panelFrame = panel
	return panel
end

function FriendsPanel.Show()
	panelOpen = true
	ensurePanel()
	setPanelVisible(true)
	rebuildList()
end

function FriendsPanel.Hide()
	panelOpen = false
	setPanelVisible(false)
end

function FriendsPanel.Toggle()
	if panelOpen then
		FriendsPanel.Hide()
	else
		FriendsPanel.Show()
	end
end

function FriendsPanel.Init()
	ensureScreenGui()
	ensurePanel()

	local listRemote = Remotes.FriendsList :: RemoteEvent
	listRemote.OnClientEvent:Connect(function(state: any)
		if typeof(state) ~= "table" then
			return
		end
		current = state :: State
		if panelOpen then
			rebuildList()
		end
	end)
end

return FriendsPanel
