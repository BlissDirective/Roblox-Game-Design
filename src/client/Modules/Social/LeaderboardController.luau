--!strict
--[[
	Outpost-7 — leaderboard panel (client).

	Phase E5 (original). Phase G5.2b theme migration + standalone-
	toggle teardown.

	G5.2b changes:
	  - Standalone LeaderboardToggle button removed. Panel is now
	    opened via the long-press Clan sub-menu — see ClanController.
	    `Toggle()` exported for that sub-menu.
	  - Panel + tab buttons + entries rebuilt on Components primitives
	    + Theme palette slots.
	  - Rank colors (gold/silver/bronze) come from Theme.highlight /
	    textPrimary / accent so they stay biome-aware.
--]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Constants = require(Shared:WaitForChild("Constants"))
local Remotes = require(Shared:WaitForChild("Remotes"))
local Components = require(Shared:WaitForChild("Modules"):WaitForChild("UI"):WaitForChild("Components"))
local Theme = require(Shared:WaitForChild("Modules"):WaitForChild("UI"):WaitForChild("Theme"))

local LeaderboardController = {}

type Entry = {
	userId: number,
	score: number,
	name: string?,
}

type Board = {
	id: string,
	displayName: string,
	bucket: string?,
	entries: { Entry },
	fetchedAt: number,
}

type BoardsState = {
	globalCredits: Board,
	weeklyRaidWins: Board,
}

local TOP_N_VISIBLE = 10
local current: BoardsState? = nil
local panelOpen = false
local activeBoard: "globalCredits" | "weeklyRaidWins" = "globalCredits"

local screenGui: ScreenGui? = nil
local panelFrame: Frame? = nil
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
	local existing = pg:FindFirstChild("OutpostLeaderboard")
	if existing and existing:IsA("ScreenGui") then
		screenGui = existing
		return existing
	end
	local gui = Instance.new("ScreenGui")
	gui.Name = "OutpostLeaderboard"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.DisplayOrder = 30
	gui.Parent = pg
	screenGui = gui
	return gui
end

local function rankColor(index: number): Color3
	local p = Theme.GetActive()
	if index == 1 then
		return p.highlight
	elseif index == 2 then
		return p.textPrimary
	elseif index == 3 then
		return p.accent
	end
	return p.textMuted
end

local function refreshPanel()
	if not panelFrame then
		return
	end
	-- Wipe everything except the persistent UIScale + UICorner +
	-- UIStroke that StrokedFrame attached to the panel root.
	for _, child in panelFrame:GetChildren() do
		if child:IsA("GuiObject") then
			child:Destroy()
		end
	end
	if not current then
		return
	end
	local board = current[activeBoard]

	local title = Instance.new("TextLabel")
	title.Size = UDim2.new(1, -16, 0, 24)
	title.Position = UDim2.fromOffset(8, 8)
	title.BackgroundTransparency = 1
	title.TextColor3 = Theme.GetActive().textPrimary
	title.Font = Enum.Font.GothamBold
	title.TextSize = 16
	title.TextXAlignment = Enum.TextXAlignment.Left
	title.Text = if board.bucket then string.format("%s — %s", board.displayName, board.bucket) else board.displayName
	title.Parent = panelFrame

	-- Tab toggle (Global / Weekly).
	local tabRow = Instance.new("Frame")
	tabRow.Size = UDim2.new(1, -16, 0, 28)
	tabRow.Position = UDim2.fromOffset(8, 36)
	tabRow.BackgroundTransparency = 1
	tabRow.Parent = panelFrame
	local layout = Instance.new("UIListLayout")
	layout.FillDirection = Enum.FillDirection.Horizontal
	layout.Padding = UDim.new(0, 6)
	layout.Parent = tabRow

	local function makeTab(boardId: "globalCredits" | "weeklyRaidWins", label: string)
		local isActive = activeBoard == boardId
		Components.Button({
			parent = tabRow,
			name = "Tab_" .. boardId,
			text = label,
			size = UDim2.new(0.5, -3, 1, 0),
			bgSlot = if isActive then "accent" else "background",
			textSlot = if isActive then "background" else "textPrimary",
			strokeSlot = if isActive then "accent" else "textMuted",
			onActivated = function()
				activeBoard = boardId
				refreshPanel()
			end,
		})
	end
	makeTab("globalCredits", "Global ¢")
	makeTab("weeklyRaidWins", "Weekly Raids")

	-- Entries list.
	local list = Instance.new("ScrollingFrame")
	list.Size = UDim2.new(1, -16, 1, -76)
	list.Position = UDim2.fromOffset(8, 72)
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
	list.Parent = panelFrame

	if #board.entries == 0 then
		local empty = Instance.new("TextLabel")
		empty.Size = UDim2.new(1, -12, 0, 20)
		empty.BackgroundTransparency = 1
		empty.TextColor3 = Theme.GetActive().textMuted
		empty.Font = Enum.Font.Gotham
		empty.TextSize = 12
		empty.Text = "No entries yet — be the first."
		empty.Parent = list
		return
	end

	for index, entry in board.entries do
		if index > TOP_N_VISIBLE then
			break
		end
		local row = Instance.new("TextLabel")
		row.Size = UDim2.new(1, -12, 0, 20)
		row.BackgroundTransparency = 1
		row.Font = Enum.Font.Gotham
		row.TextSize = 13
		row.TextXAlignment = Enum.TextXAlignment.Left
		row.TextColor3 = rankColor(index)
		local displayName = entry.name or string.format("user_%d", entry.userId)
		row.Text = string.format("%2d. %-20s  %s", index, displayName, tostring(entry.score))
		row.Parent = list
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
		name = "LeaderboardPanel",
		size = UDim2.fromOffset(280, 380),
		position = UDim2.new(1, -296, 0, 460),
		bgSlot = "panel",
		strokeSlot = "highlight",
		cornerAccent = true,
	})
	panel.Visible = false

	local scale = Instance.new("UIScale")
	scale.Scale = 1.0
	scale.Parent = panel
	panelScale = scale

	panelFrame = panel
	return panel
end

function LeaderboardController.Show()
	panelOpen = true
	ensurePanel()
	setPanelVisible(true)
	refreshPanel()
end

function LeaderboardController.Hide()
	panelOpen = false
	setPanelVisible(false)
end

function LeaderboardController.Toggle()
	if panelOpen then
		LeaderboardController.Hide()
	else
		LeaderboardController.Show()
	end
end

function LeaderboardController.Init()
	ensureScreenGui()
	ensurePanel()

	local stateRemote = Remotes.LeaderboardState :: RemoteEvent
	stateRemote.OnClientEvent:Connect(function(state: any)
		if typeof(state) ~= "table" then
			return
		end
		current = state :: BoardsState
		if panelOpen then
			refreshPanel()
		end
	end)
end

return LeaderboardController
