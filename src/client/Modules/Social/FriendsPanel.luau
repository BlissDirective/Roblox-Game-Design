--!strict
--[[
	Outpost-7 — friends panel (client).

	Phase E5. Toggle button + right-side panel showing the player's
	Roblox friends list with per-friend `inThisServer` flag (green
	dot = online here). Refresh button triggers a yielding server-
	side `RefreshFriends` invoke.

	V1 limitation per the FriendsService doc: only "online in this
	server" presence is shown. Cross-server friend presence is V1.5+.

	Public API:
	  Init  — wires Remote listener + builds UI
--]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Remotes = require(Shared:WaitForChild("Remotes"))

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

local function ensureScreenGui(): ScreenGui
	local pg = Players.LocalPlayer:WaitForChild("PlayerGui") :: PlayerGui
	local existing = pg:FindFirstChild("OutpostFriends")
	if existing and existing:IsA("ScreenGui") then
		return existing
	end
	local gui = Instance.new("ScreenGui")
	gui.Name = "OutpostFriends"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.Parent = pg
	return gui
end

local function refreshPanel()
	local gui = ensureScreenGui()
	local panel = gui:FindFirstChild("FriendsPanel")
	if not panel or not panel:IsA("Frame") then
		return
	end
	for _, child in panel:GetChildren() do
		if child:IsA("GuiObject") then
			child:Destroy()
		end
	end

	-- Header (title + refresh button)
	local title = Instance.new("TextLabel")
	title.Size = UDim2.new(1, -88, 0, 24)
	title.Position = UDim2.fromOffset(8, 8)
	title.BackgroundTransparency = 1
	title.TextColor3 = Color3.fromRGB(220, 220, 235)
	title.Font = Enum.Font.GothamBold
	title.TextSize = 16
	title.TextXAlignment = Enum.TextXAlignment.Left
	if current then
		title.Text = string.format("Friends (%d)", #current.friends)
	else
		title.Text = "Friends"
	end
	title.Parent = panel

	local refreshBtn = Instance.new("TextButton")
	refreshBtn.Size = UDim2.fromOffset(72, 24)
	refreshBtn.Position = UDim2.new(1, -80, 0, 8)
	refreshBtn.BackgroundColor3 = Color3.fromRGB(30, 30, 42)
	refreshBtn.BorderSizePixel = 0
	refreshBtn.TextColor3 = Color3.fromRGB(220, 220, 235)
	refreshBtn.Font = Enum.Font.GothamBold
	refreshBtn.TextSize = 12
	refreshBtn.Text = "Refresh"
	local refreshCorner = Instance.new("UICorner")
	refreshCorner.CornerRadius = UDim.new(0, 4)
	refreshCorner.Parent = refreshBtn
	refreshBtn.Parent = panel
	refreshBtn.MouseButton1Click:Connect(function()
		local remote = Remotes.RefreshFriends :: RemoteFunction
		pcall(function()
			remote:InvokeServer()
		end)
	end)

	-- List
	local list = Instance.new("ScrollingFrame")
	list.Size = UDim2.new(1, -16, 1, -44)
	list.Position = UDim2.fromOffset(8, 40)
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
	local listCorner = Instance.new("UICorner")
	listCorner.CornerRadius = UDim.new(0, 4)
	listCorner.Parent = list
	list.Parent = panel

	if not current then
		local empty = Instance.new("TextLabel")
		empty.Size = UDim2.new(1, -12, 0, 20)
		empty.BackgroundTransparency = 1
		empty.TextColor3 = Color3.fromRGB(140, 140, 150)
		empty.Font = Enum.Font.Gotham
		empty.TextSize = 12
		empty.Text = "Loading…"
		empty.Parent = list
		return
	end
	if #current.friends == 0 then
		local empty = Instance.new("TextLabel")
		empty.Size = UDim2.new(1, -12, 0, 20)
		empty.BackgroundTransparency = 1
		empty.TextColor3 = Color3.fromRGB(140, 140, 150)
		empty.Font = Enum.Font.Gotham
		empty.TextSize = 12
		empty.Text = "No friends yet."
		empty.Parent = list
		return
	end

	-- Sort: online-here first, then alpha by display name.
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
		row.Parent = list

		local dot = Instance.new("Frame")
		dot.Size = UDim2.fromOffset(8, 8)
		dot.Position = UDim2.fromOffset(2, 7)
		dot.BackgroundColor3 = if friend.inThisServer
			then Color3.fromRGB(80, 220, 120)
			else Color3.fromRGB(80, 80, 90)
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
			then Color3.fromRGB(220, 240, 220)
			else Color3.fromRGB(180, 180, 190)
		lbl.Font = Enum.Font.Gotham
		lbl.TextSize = 13
		lbl.TextXAlignment = Enum.TextXAlignment.Left
		lbl.Text = friend.displayName
		lbl.Parent = row
	end
end

local function ensurePanel(): Frame
	local gui = ensureScreenGui()
	local existing = gui:FindFirstChild("FriendsPanel")
	if existing and existing:IsA("Frame") then
		return existing
	end
	local panel = Instance.new("Frame")
	panel.Name = "FriendsPanel"
	panel.Size = UDim2.fromOffset(240, 320)
	panel.Position = UDim2.new(1, -256, 0, 460)
	panel.BackgroundColor3 = Color3.fromRGB(16, 16, 22)
	panel.BorderSizePixel = 0
	panel.Visible = false
	local stroke = Instance.new("UIStroke")
	stroke.Thickness = 2
	stroke.Color = Color3.fromRGB(80, 220, 120)
	stroke.Parent = panel
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 8)
	corner.Parent = panel
	panel.Parent = gui
	return panel
end

local function buildToggleButton()
	local gui = ensureScreenGui()
	if gui:FindFirstChild("FriendsToggle") then
		return
	end
	local btn = Instance.new("TextButton")
	btn.Name = "FriendsToggle"
	btn.Size = UDim2.fromOffset(96, 40)
	btn.Position = UDim2.new(0, 864, 0, 8)
	btn.BackgroundColor3 = Color3.fromRGB(28, 28, 36)
	btn.BorderSizePixel = 0
	btn.TextColor3 = Color3.fromRGB(220, 220, 235)
	btn.Font = Enum.Font.GothamBold
	btn.TextSize = 14
	btn.Text = "Friends"
	local stroke = Instance.new("UIStroke")
	stroke.Thickness = 2
	stroke.Color = Color3.fromRGB(80, 220, 120)
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

function FriendsPanel.Init()
	buildToggleButton()
	ensurePanel()

	local listRemote = Remotes.FriendsList :: RemoteEvent
	listRemote.OnClientEvent:Connect(function(state: any)
		if typeof(state) ~= "table" then
			return
		end
		current = state :: State
		if panelOpen then
			refreshPanel()
		end
	end)
end

return FriendsPanel
