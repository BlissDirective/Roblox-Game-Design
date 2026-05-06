--!strict
--[[
	Outpost-7 — leaderboard panel (client).

	Phase E5. Toggle button + right-side panel showing top 10 of the
	two boards (Global Credits, Weekly Raid Wins). Server-pushed via
	`LeaderboardState` Remote ~5 minutes; the client renders off
	whatever the latest state is.

	Placeholder visuals — Phase G replaces with neon-tactical theme +
	medal icons for the top 3.

	Public API:
	  Init  — wires Remote listener + builds UI
--]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Remotes = require(Shared:WaitForChild("Remotes"))

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

local function ensureScreenGui(): ScreenGui
	local pg = Players.LocalPlayer:WaitForChild("PlayerGui") :: PlayerGui
	local existing = pg:FindFirstChild("OutpostLeaderboard")
	if existing and existing:IsA("ScreenGui") then
		return existing
	end
	local gui = Instance.new("ScreenGui")
	gui.Name = "OutpostLeaderboard"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.Parent = pg
	return gui
end

local function refreshPanel()
	local gui = ensureScreenGui()
	local panel = gui:FindFirstChild("LeaderboardPanel")
	if not panel or not panel:IsA("Frame") then
		return
	end
	for _, child in panel:GetChildren() do
		if child:IsA("GuiObject") then
			child:Destroy()
		end
	end
	if not current then
		return
	end
	local board = current[activeBoard]

	-- Title
	local title = Instance.new("TextLabel")
	title.Size = UDim2.new(1, -16, 0, 24)
	title.Position = UDim2.fromOffset(8, 8)
	title.BackgroundTransparency = 1
	title.TextColor3 = Color3.fromRGB(220, 220, 235)
	title.Font = Enum.Font.GothamBold
	title.TextSize = 16
	title.TextXAlignment = Enum.TextXAlignment.Left
	title.Text = if board.bucket then string.format("%s — %s", board.displayName, board.bucket) else board.displayName
	title.Parent = panel

	-- Tab toggle (Global / Weekly)
	local tabRow = Instance.new("Frame")
	tabRow.Size = UDim2.new(1, -16, 0, 28)
	tabRow.Position = UDim2.fromOffset(8, 36)
	tabRow.BackgroundTransparency = 1
	tabRow.Parent = panel
	local layout = Instance.new("UIListLayout")
	layout.FillDirection = Enum.FillDirection.Horizontal
	layout.Padding = UDim.new(0, 6)
	layout.Parent = tabRow

	local function makeTab(boardId: "globalCredits" | "weeklyRaidWins", label: string)
		local btn = Instance.new("TextButton")
		btn.Size = UDim2.new(0.5, -3, 1, 0)
		btn.BackgroundColor3 = if activeBoard == boardId
			then Color3.fromRGB(80, 130, 180)
			else Color3.fromRGB(30, 30, 42)
		btn.BorderSizePixel = 0
		btn.TextColor3 = Color3.fromRGB(220, 220, 235)
		btn.Font = Enum.Font.GothamBold
		btn.TextSize = 13
		btn.Text = label
		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(0, 4)
		corner.Parent = btn
		btn.Parent = tabRow
		btn.MouseButton1Click:Connect(function()
			activeBoard = boardId
			refreshPanel()
		end)
	end
	makeTab("globalCredits", "Global ¢")
	makeTab("weeklyRaidWins", "Weekly Raids")

	-- Entries list
	local list = Instance.new("ScrollingFrame")
	list.Size = UDim2.new(1, -16, 1, -76)
	list.Position = UDim2.fromOffset(8, 72)
	list.BackgroundColor3 = Color3.fromRGB(12, 12, 18)
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
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 4)
	corner.Parent = list
	list.Parent = panel

	if #board.entries == 0 then
		local empty = Instance.new("TextLabel")
		empty.Size = UDim2.new(1, -12, 0, 20)
		empty.BackgroundTransparency = 1
		empty.TextColor3 = Color3.fromRGB(140, 140, 150)
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
		local rankColor = if index == 1
			then Color3.fromRGB(255, 215, 100)
			elseif index == 2
				then Color3.fromRGB(220, 220, 230)
				elseif index == 3 then Color3.fromRGB(220, 160, 90) else Color3.fromRGB(180, 180, 190)
		row.TextColor3 = rankColor
		local displayName = entry.name or string.format("user_%d", entry.userId)
		row.Text = string.format("%2d. %-20s  %s", index, displayName, tostring(entry.score))
		row.Parent = list
	end
end

local function ensurePanel(): Frame
	local gui = ensureScreenGui()
	local existing = gui:FindFirstChild("LeaderboardPanel")
	if existing and existing:IsA("Frame") then
		return existing
	end
	local panel = Instance.new("Frame")
	panel.Name = "LeaderboardPanel"
	panel.Size = UDim2.fromOffset(280, 380)
	panel.Position = UDim2.new(1, -296, 0, 460)
	panel.BackgroundColor3 = Color3.fromRGB(16, 16, 22)
	panel.BorderSizePixel = 0
	panel.Visible = false
	local stroke = Instance.new("UIStroke")
	stroke.Thickness = 2
	stroke.Color = Color3.fromRGB(255, 215, 100)
	stroke.Parent = panel
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 8)
	corner.Parent = panel
	panel.Parent = gui
	return panel
end

local function buildToggleButton()
	local gui = ensureScreenGui()
	if gui:FindFirstChild("LeaderboardToggle") then
		return
	end
	local btn = Instance.new("TextButton")
	btn.Name = "LeaderboardToggle"
	btn.Size = UDim2.fromOffset(120, 40)
	btn.Position = UDim2.new(0, 736, 0, 8)
	btn.BackgroundColor3 = Color3.fromRGB(28, 28, 36)
	btn.BorderSizePixel = 0
	btn.TextColor3 = Color3.fromRGB(220, 220, 235)
	btn.Font = Enum.Font.GothamBold
	btn.TextSize = 14
	btn.Text = "Leaderboard"
	local stroke = Instance.new("UIStroke")
	stroke.Thickness = 2
	stroke.Color = Color3.fromRGB(255, 215, 100)
	stroke.Parent = btn
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 6)
	corner.Parent = btn
	btn.Parent = gui

	btn.MouseButton1Click:Connect(function()
		panelOpen = not panelOpen
		local panel = ensurePanel()
		panel.Visible = panelOpen
		if panelOpen then
			refreshPanel()
		end
	end)
end

function LeaderboardController.Init()
	buildToggleButton()
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
