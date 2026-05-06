--!strict
--[[
	Outpost-7 — clan UI (client).

	Phase E3. Minimal V1 clan surface: a "Clan" button that toggles a
	right-side panel showing current state (or a "Create / Join"
	stub). Members list, deposit + withdraw inputs, pending-withdrawal
	approval rows for the leader. Chat is a single-line input + a 6-row
	scrolling readout.

	UI is placeholder (Phase G replaces with the neon-tactical theme).

	Public API:
	  Init  — wires Remote listeners + builds UI
--]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Remotes = require(Shared:WaitForChild("Remotes"))

local ClanController = {}

type ClanMember = {
	userId: number,
	name: string,
	role: string,
	joinedAt: number,
}

type PendingWithdrawal = {
	withdrawalId: string,
	requesterUserId: number,
	requesterName: string,
	amount: number,
	requestedAt: number,
}

type State = {
	clanId: string,
	name: string,
	tag: string,
	createdAt: number,
	leaderUserId: number,
	members: { ClanMember },
	stashCredits: number,
	stashCores: number,
	pendingWithdrawals: { PendingWithdrawal },
	youAre: string?,
}

type ChatEntry = {
	clanId: string,
	senderUserId: number,
	senderName: string,
	message: string,
	sentAt: number,
}

local currentState: State? = nil
local chatHistory: { ChatEntry } = {}
local screenGui: ScreenGui? = nil
local panelOpen = false

local function ensureScreenGui(): ScreenGui
	if screenGui then
		return screenGui
	end
	local pg = Players.LocalPlayer:WaitForChild("PlayerGui") :: PlayerGui
	local existing = pg:FindFirstChild("OutpostClan")
	if existing and existing:IsA("ScreenGui") then
		screenGui = existing
		return existing
	end
	local gui = Instance.new("ScreenGui")
	gui.Name = "OutpostClan"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.Parent = pg
	screenGui = gui
	return gui
end

local function styledFrame(name: string, parent: Instance, size: UDim2, position: UDim2): Frame
	local f = Instance.new("Frame")
	f.Name = name
	f.Size = size
	f.Position = position
	f.BackgroundColor3 = Color3.fromRGB(20, 20, 28)
	f.BorderSizePixel = 0
	local stroke = Instance.new("UIStroke")
	stroke.Thickness = 1
	stroke.Color = Color3.fromRGB(80, 130, 180)
	stroke.Parent = f
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 6)
	corner.Parent = f
	f.Parent = parent
	return f
end

local function styledButton(name: string, parent: Instance, text: string): TextButton
	local btn = Instance.new("TextButton")
	btn.Name = name
	btn.Size = UDim2.new(1, -8, 0, 28)
	btn.Position = UDim2.fromOffset(4, 0)
	btn.BackgroundColor3 = Color3.fromRGB(30, 30, 42)
	btn.BorderSizePixel = 0
	btn.TextColor3 = Color3.fromRGB(220, 220, 235)
	btn.Font = Enum.Font.GothamBold
	btn.TextSize = 14
	btn.Text = text
	btn.AutoButtonColor = true
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 4)
	corner.Parent = btn
	btn.Parent = parent
	return btn
end

local function styledLabel(parent: Instance, text: string, color: Color3?): TextLabel
	local lbl = Instance.new("TextLabel")
	lbl.BackgroundTransparency = 1
	lbl.TextColor3 = color or Color3.fromRGB(220, 220, 235)
	lbl.Font = Enum.Font.Gotham
	lbl.TextSize = 13
	lbl.TextXAlignment = Enum.TextXAlignment.Left
	lbl.Text = text
	lbl.Parent = parent
	return lbl
end

local function styledTextBox(parent: Instance, placeholder: string): TextBox
	local box = Instance.new("TextBox")
	box.BackgroundColor3 = Color3.fromRGB(30, 30, 42)
	box.BorderSizePixel = 0
	box.TextColor3 = Color3.fromRGB(220, 220, 235)
	box.PlaceholderText = placeholder
	box.PlaceholderColor3 = Color3.fromRGB(120, 120, 130)
	box.Font = Enum.Font.Gotham
	box.TextSize = 13
	box.ClearTextOnFocus = false
	box.Text = ""
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 4)
	corner.Parent = box
	box.Parent = parent
	return box
end

-- Forward decl.
local refreshPanel: () -> ()

local function buildNoClanPanel(panel: Frame)
	for _, child in panel:GetChildren() do
		if child:IsA("GuiObject") then
			child:Destroy()
		end
	end

	local title = styledLabel(panel, "No Clan")
	title.Size = UDim2.new(1, -16, 0, 24)
	title.Position = UDim2.fromOffset(8, 8)
	title.TextSize = 16
	title.Font = Enum.Font.GothamBold

	local nameBox = styledTextBox(panel, "Clan name (3-24 chars)")
	nameBox.Size = UDim2.new(1, -16, 0, 28)
	nameBox.Position = UDim2.fromOffset(8, 40)

	local tagBox = styledTextBox(panel, "Tag (2-5 chars, alnum)")
	tagBox.Size = UDim2.new(1, -16, 0, 28)
	tagBox.Position = UDim2.fromOffset(8, 76)

	local createBtn = styledButton("Create", panel, "Create Clan")
	createBtn.Position = UDim2.fromOffset(4, 112)
	createBtn.Size = UDim2.new(1, -8, 0, 28)
	createBtn.MouseButton1Click:Connect(function()
		local remote = Remotes.CreateClan :: RemoteFunction
		local ok, result = pcall(function()
			return remote:InvokeServer(nameBox.Text, tagBox.Text)
		end)
		if not ok then
			warn(string.format("[ClanController] CreateClan invoke failed: %s", tostring(result)))
			return
		end
		if typeof(result) == "table" and not result.ok then
			title.Text = "Error: " .. tostring(result.error)
		end
	end)

	local joinBox = styledTextBox(panel, "Join by clan ID")
	joinBox.Size = UDim2.new(1, -16, 0, 28)
	joinBox.Position = UDim2.fromOffset(8, 152)

	local joinBtn = styledButton("Join", panel, "Join Clan")
	joinBtn.Position = UDim2.fromOffset(4, 188)
	joinBtn.Size = UDim2.new(1, -8, 0, 28)
	joinBtn.MouseButton1Click:Connect(function()
		local remote = Remotes.JoinClan :: RemoteFunction
		local ok, result = pcall(function()
			return remote:InvokeServer(joinBox.Text)
		end)
		if not ok then
			warn(string.format("[ClanController] JoinClan invoke failed: %s", tostring(result)))
			return
		end
		if typeof(result) == "table" and not result.ok then
			title.Text = "Error: " .. tostring(result.error)
		end
	end)
end

local function buildClanPanel(panel: Frame, state: State)
	for _, child in panel:GetChildren() do
		if child:IsA("GuiObject") then
			child:Destroy()
		end
	end

	local headerY = 8
	local title = styledLabel(panel, string.format("[%s] %s", state.tag, state.name))
	title.Size = UDim2.new(1, -16, 0, 22)
	title.Position = UDim2.fromOffset(8, headerY)
	title.TextSize = 16
	title.Font = Enum.Font.GothamBold

	local roleLbl = styledLabel(
		panel,
		string.format("You: %s · Stash: %d ¢ / %d ◆", state.youAre or "?", state.stashCredits, state.stashCores),
		Color3.fromRGB(120, 200, 255)
	)
	roleLbl.Size = UDim2.new(1, -16, 0, 18)
	roleLbl.Position = UDim2.fromOffset(8, headerY + 24)
	roleLbl.TextSize = 12

	-- Members list
	local membersFrame = styledFrame(
		"Members",
		panel,
		UDim2.new(1, -16, 0, 92),
		UDim2.fromOffset(8, headerY + 48)
	)
	local memberLayout = Instance.new("UIListLayout")
	memberLayout.FillDirection = Enum.FillDirection.Vertical
	memberLayout.SortOrder = Enum.SortOrder.LayoutOrder
	memberLayout.Padding = UDim.new(0, 2)
	memberLayout.Parent = membersFrame
	local pad = Instance.new("UIPadding")
	pad.PaddingTop = UDim.new(0, 4)
	pad.PaddingLeft = UDim.new(0, 6)
	pad.PaddingRight = UDim.new(0, 6)
	pad.Parent = membersFrame

	local canKick = state.youAre == "leader" or state.youAre == "officer"
	local localUserId = Players.LocalPlayer.UserId
	for _, member in state.members do
		local row = Instance.new("Frame")
		row.Size = UDim2.new(1, 0, 0, 18)
		row.BackgroundTransparency = 1
		row.Parent = membersFrame

		local lbl = styledLabel(row, string.format("%s (%s)", member.name, member.role))
		lbl.Size = UDim2.new(1, -60, 1, 0)

		if canKick and member.userId ~= localUserId and member.role ~= "leader" then
			local kickBtn = Instance.new("TextButton")
			kickBtn.Size = UDim2.new(0, 50, 1, 0)
			kickBtn.Position = UDim2.new(1, -54, 0, 0)
			kickBtn.BackgroundColor3 = Color3.fromRGB(120, 30, 30)
			kickBtn.BorderSizePixel = 0
			kickBtn.TextColor3 = Color3.fromRGB(255, 220, 220)
			kickBtn.Font = Enum.Font.GothamBold
			kickBtn.TextSize = 11
			kickBtn.Text = "Kick"
			local corner = Instance.new("UICorner")
			corner.CornerRadius = UDim.new(0, 3)
			corner.Parent = kickBtn
			kickBtn.Parent = row
			kickBtn.MouseButton1Click:Connect(function()
				local remote = Remotes.KickFromClan :: RemoteFunction
				pcall(function()
					remote:InvokeServer(member.userId)
				end)
			end)
		end
	end

	-- Stash deposit / withdraw row
	local stashY = headerY + 148
	local depositBox = styledTextBox(panel, "Amount")
	depositBox.Size = UDim2.new(0.5, -12, 0, 24)
	depositBox.Position = UDim2.fromOffset(8, stashY)
	local depositBtn = styledButton("Deposit", panel, "Deposit")
	depositBtn.Size = UDim2.new(0.5, -12, 0, 24)
	depositBtn.Position = UDim2.new(0.5, 4, 0, stashY)
	depositBtn.MouseButton1Click:Connect(function()
		local n = tonumber(depositBox.Text)
		if not n then
			return
		end
		local remote = Remotes.ClanStashDeposit :: RemoteFunction
		pcall(function()
			remote:InvokeServer(n)
		end)
	end)

	local withdrawBox = styledTextBox(panel, "Amount")
	withdrawBox.Size = UDim2.new(0.5, -12, 0, 24)
	withdrawBox.Position = UDim2.fromOffset(8, stashY + 30)
	local withdrawBtn = styledButton("Withdraw", panel, "Withdraw")
	withdrawBtn.Size = UDim2.new(0.5, -12, 0, 24)
	withdrawBtn.Position = UDim2.new(0.5, 4, 0, stashY + 30)
	withdrawBtn.MouseButton1Click:Connect(function()
		local n = tonumber(withdrawBox.Text)
		if not n then
			return
		end
		local remote = Remotes.ClanStashWithdraw :: RemoteFunction
		pcall(function()
			remote:InvokeServer(n)
		end)
	end)

	-- Pending withdrawals (leader-only approve)
	local pendingY = stashY + 64
	if #state.pendingWithdrawals > 0 then
		local hdr = styledLabel(
			panel,
			string.format("Pending withdrawals (%d):", #state.pendingWithdrawals),
			Color3.fromRGB(255, 200, 100)
		)
		hdr.Size = UDim2.new(1, -16, 0, 16)
		hdr.Position = UDim2.fromOffset(8, pendingY)
		hdr.TextSize = 12
		hdr.Font = Enum.Font.GothamBold
		pendingY += 20

		for _, pending in state.pendingWithdrawals do
			local row = Instance.new("Frame")
			row.Size = UDim2.new(1, -16, 0, 22)
			row.Position = UDim2.fromOffset(8, pendingY)
			row.BackgroundTransparency = 1
			row.Parent = panel

			local lbl = styledLabel(
				row,
				string.format("%s: %d", pending.requesterName, pending.amount)
			)
			lbl.Size = UDim2.new(1, -110, 1, 0)
			lbl.TextSize = 12

			if state.youAre == "leader" then
				local approveBtn = Instance.new("TextButton")
				approveBtn.Size = UDim2.new(0, 50, 1, 0)
				approveBtn.Position = UDim2.new(1, -104, 0, 0)
				approveBtn.BackgroundColor3 = Color3.fromRGB(30, 120, 60)
				approveBtn.TextColor3 = Color3.fromRGB(220, 255, 220)
				approveBtn.Font = Enum.Font.GothamBold
				approveBtn.TextSize = 11
				approveBtn.Text = "Allow"
				approveBtn.BorderSizePixel = 0
				local c1 = Instance.new("UICorner")
				c1.CornerRadius = UDim.new(0, 3)
				c1.Parent = approveBtn
				approveBtn.Parent = row
				approveBtn.MouseButton1Click:Connect(function()
					local remote = Remotes.ClanStashApprove :: RemoteFunction
					pcall(function()
						remote:InvokeServer(pending.withdrawalId, true)
					end)
				end)

				local denyBtn = Instance.new("TextButton")
				denyBtn.Size = UDim2.new(0, 50, 1, 0)
				denyBtn.Position = UDim2.new(1, -50, 0, 0)
				denyBtn.BackgroundColor3 = Color3.fromRGB(120, 40, 40)
				denyBtn.TextColor3 = Color3.fromRGB(255, 220, 220)
				denyBtn.Font = Enum.Font.GothamBold
				denyBtn.TextSize = 11
				denyBtn.Text = "Deny"
				denyBtn.BorderSizePixel = 0
				local c2 = Instance.new("UICorner")
				c2.CornerRadius = UDim.new(0, 3)
				c2.Parent = denyBtn
				denyBtn.Parent = row
				denyBtn.MouseButton1Click:Connect(function()
					local remote = Remotes.ClanStashApprove :: RemoteFunction
					pcall(function()
						remote:InvokeServer(pending.withdrawalId, false)
					end)
				end)
			end
			pendingY += 24
		end
	end

	-- Chat
	local chatY = pendingY + 8
	local chatBox = Instance.new("ScrollingFrame")
	chatBox.Size = UDim2.new(1, -16, 0, 100)
	chatBox.Position = UDim2.fromOffset(8, chatY)
	chatBox.BackgroundColor3 = Color3.fromRGB(12, 12, 18)
	chatBox.BorderSizePixel = 0
	chatBox.ScrollBarThickness = 4
	chatBox.CanvasSize = UDim2.new(0, 0, 0, 0)
	chatBox.AutomaticCanvasSize = Enum.AutomaticSize.Y
	chatBox.Name = "ChatLog"
	local cCorner = Instance.new("UICorner")
	cCorner.CornerRadius = UDim.new(0, 4)
	cCorner.Parent = chatBox
	local cLayout = Instance.new("UIListLayout")
	cLayout.FillDirection = Enum.FillDirection.Vertical
	cLayout.SortOrder = Enum.SortOrder.LayoutOrder
	cLayout.Padding = UDim.new(0, 2)
	cLayout.Parent = chatBox
	local cPad = Instance.new("UIPadding")
	cPad.PaddingTop = UDim.new(0, 4)
	cPad.PaddingLeft = UDim.new(0, 6)
	cPad.PaddingRight = UDim.new(0, 6)
	cPad.Parent = chatBox
	chatBox.Parent = panel

	for _, entry in chatHistory do
		local lbl = styledLabel(chatBox, string.format("%s: %s", entry.senderName, entry.message))
		lbl.Size = UDim2.new(1, -12, 0, 16)
		lbl.TextSize = 12
		lbl.TextWrapped = true
	end

	local sendBox = styledTextBox(panel, "Message…")
	sendBox.Size = UDim2.new(1, -78, 0, 24)
	sendBox.Position = UDim2.fromOffset(8, chatY + 108)
	local sendBtn = styledButton("Send", panel, "Send")
	sendBtn.Size = UDim2.new(0, 60, 0, 24)
	sendBtn.Position = UDim2.new(1, -68, 0, chatY + 108)
	local function sendChat()
		if #sendBox.Text == 0 then
			return
		end
		local remote = Remotes.ClanChatSend :: RemoteFunction
		pcall(function()
			remote:InvokeServer(sendBox.Text)
		end)
		sendBox.Text = ""
	end
	sendBtn.MouseButton1Click:Connect(sendChat)
	sendBox.FocusLost:Connect(function(enterPressed: boolean)
		if enterPressed then
			sendChat()
		end
	end)

	-- Leave button at bottom
	local leaveBtn = styledButton("Leave", panel, "Leave Clan")
	leaveBtn.BackgroundColor3 = Color3.fromRGB(120, 40, 40)
	leaveBtn.Size = UDim2.new(1, -16, 0, 24)
	leaveBtn.Position = UDim2.fromOffset(8, chatY + 144)
	leaveBtn.MouseButton1Click:Connect(function()
		local remote = Remotes.LeaveClan :: RemoteFunction
		pcall(function()
			remote:InvokeServer()
		end)
	end)
end

refreshPanel = function()
	if not panelOpen then
		return
	end
	local gui = ensureScreenGui()
	local panel = gui:FindFirstChild("ClanPanel")
	if not panel or not panel:IsA("Frame") then
		return
	end
	if currentState then
		buildClanPanel(panel, currentState)
	else
		buildNoClanPanel(panel)
	end
end

local function ensurePanel(): Frame
	local gui = ensureScreenGui()
	local existing = gui:FindFirstChild("ClanPanel")
	if existing and existing:IsA("Frame") then
		return existing
	end
	local panel = Instance.new("Frame")
	panel.Name = "ClanPanel"
	panel.Size = UDim2.fromOffset(280, 540)
	panel.Position = UDim2.new(1, -296, 0, 60)
	panel.BackgroundColor3 = Color3.fromRGB(16, 16, 22)
	panel.BorderSizePixel = 0
	panel.Visible = false
	local stroke = Instance.new("UIStroke")
	stroke.Thickness = 2
	stroke.Color = Color3.fromRGB(80, 130, 180)
	stroke.Parent = panel
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 8)
	corner.Parent = panel
	panel.Parent = gui
	return panel
end

local function buildToggleButton()
	local gui = ensureScreenGui()
	if gui:FindFirstChild("ClanToggle") then
		return
	end
	local btn = Instance.new("TextButton")
	btn.Name = "ClanToggle"
	btn.Size = UDim2.fromOffset(120, 40)
	btn.Position = UDim2.new(0, 608, 0, 8)
	btn.BackgroundColor3 = Color3.fromRGB(28, 28, 36)
	btn.BorderSizePixel = 0
	btn.TextColor3 = Color3.fromRGB(220, 220, 235)
	btn.Font = Enum.Font.GothamBold
	btn.TextSize = 14
	btn.Text = "Clan"
	local stroke = Instance.new("UIStroke")
	stroke.Thickness = 2
	stroke.Color = Color3.fromRGB(80, 130, 180)
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

function ClanController.Init()
	buildToggleButton()
	ensurePanel()

	local stateRemote = Remotes.ClanState :: RemoteEvent
	stateRemote.OnClientEvent:Connect(function(state: any)
		if state == nil then
			currentState = nil
		elseif typeof(state) == "table" then
			currentState = state :: State
		end
		refreshPanel()
	end)

	local chatRemote = Remotes.ClanChatReceived :: RemoteEvent
	chatRemote.OnClientEvent:Connect(function(entry: any)
		if typeof(entry) ~= "table" then
			return
		end
		table.insert(chatHistory, entry :: ChatEntry)
		-- Cap history to last 50 messages.
		while #chatHistory > 50 do
			table.remove(chatHistory, 1)
		end
		refreshPanel()
	end)
end

return ClanController
