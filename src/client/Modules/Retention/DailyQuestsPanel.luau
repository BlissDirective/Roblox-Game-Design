--!strict
--[[
	Outpost-7 — daily quests panel (client UI).

	Phase C3. Slide-in panel listing the day's 3 active quests with
	progress bars + Claim buttons. Auto-refreshes via DailyQuestState
	pushes from the server.

	Toggle button "Quests" sits next to the Shop toggle in the HUD
	row. Phase G aesthetic pass replaces with neon-tactical theming
	+ live countdown ticking + spring-tween bar fills.
--]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Remotes = require(Shared:WaitForChild("Remotes"))
local Components = require(Shared:WaitForChild("Modules"):WaitForChild("UI"):WaitForChild("Components"))
local HudFormat = require(Shared:WaitForChild("Modules"):WaitForChild("Lib"):WaitForChild("HudFormat"))

type QuestView = {
	id: string,
	displayName: string,
	description: string,
	progress: number,
	target: number,
	complete: boolean,
	claimed: boolean,
	rewardCredits: number,
	rewardCores: number,
}

type State = {
	dateUtc: string,
	secondsUntilReset: number,
	quests: { QuestView },
}

local DailyQuestsPanel = {}

local screenGui: ScreenGui? = nil
local list: Frame? = nil
local titleLabel: TextLabel? = nil
local lastState: State? = nil
local pendingClaims: { [string]: boolean } = {}

local function setVisible(visible: boolean)
	if screenGui then
		screenGui.Enabled = visible
	end
end

local function formatCountdown(seconds: number): string
	if seconds <= 0 then
		return "resetting..."
	end
	local h = math.floor(seconds / 3600)
	local m = math.floor((seconds % 3600) / 60)
	if h > 0 then
		return string.format("Resets in %dh %dm", h, m)
	end
	return string.format("Resets in %dm", math.max(1, m))
end

local function buildQuestRow(parent: Frame, quest: QuestView, onClaim: () -> ())
	local row = Instance.new("Frame")
	row.Size = UDim2.new(1, 0, 0, 90)
	row.BackgroundColor3 = Color3.fromRGB(28, 32, 40)
	row.BorderSizePixel = 0
	row.Parent = parent

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 8)
	corner.Parent = row

	local stroke = Instance.new("UIStroke")
	stroke.Color = if quest.claimed
		then Color3.fromRGB(80, 80, 90)
		elseif quest.complete then Color3.fromRGB(180, 220, 100)
		else Color3.fromRGB(120, 220, 180)
	stroke.Thickness = 1
	stroke.Transparency = 0.4
	stroke.Parent = row

	local name = Instance.new("TextLabel")
	name.Size = UDim2.new(1, -180, 0, 24)
	name.Position = UDim2.new(0, 12, 0, 8)
	name.BackgroundTransparency = 1
	name.TextColor3 = Color3.fromRGB(220, 240, 200)
	name.Font = Enum.Font.GothamBold
	name.TextScaled = true
	name.TextXAlignment = Enum.TextXAlignment.Left
	name.Text = quest.displayName
	name.Parent = row

	local desc = Instance.new("TextLabel")
	desc.Size = UDim2.new(1, -180, 0, 18)
	desc.Position = UDim2.new(0, 12, 0, 32)
	desc.BackgroundTransparency = 1
	desc.TextColor3 = Color3.fromRGB(180, 200, 210)
	desc.Font = Enum.Font.Gotham
	desc.TextScaled = true
	desc.TextXAlignment = Enum.TextXAlignment.Left
	desc.Text = quest.description
	desc.Parent = row

	-- Progress bar background.
	local barBg = Instance.new("Frame")
	barBg.Size = UDim2.new(1, -180, 0, 14)
	barBg.Position = UDim2.new(0, 12, 1, -22)
	barBg.BackgroundColor3 = Color3.fromRGB(40, 44, 54)
	barBg.BorderSizePixel = 0
	barBg.Parent = row
	local barCorner = Instance.new("UICorner")
	barCorner.CornerRadius = UDim.new(1, 0)
	barCorner.Parent = barBg

	-- Progress bar fill.
	local fillRatio = if quest.target > 0 then math.clamp(quest.progress / quest.target, 0, 1) else 0
	local barFill = Instance.new("Frame")
	barFill.Size = UDim2.new(fillRatio, 0, 1, 0)
	barFill.BackgroundColor3 = if quest.complete then Color3.fromRGB(180, 220, 100) else Color3.fromRGB(120, 220, 180)
	barFill.BorderSizePixel = 0
	barFill.Parent = barBg
	local fillCorner = Instance.new("UICorner")
	fillCorner.CornerRadius = UDim.new(1, 0)
	fillCorner.Parent = barFill

	local progressText = Instance.new("TextLabel")
	progressText.Size = UDim2.new(1, 0, 1, 0)
	progressText.BackgroundTransparency = 1
	progressText.TextColor3 = Color3.fromRGB(255, 255, 255)
	progressText.Font = Enum.Font.GothamBold
	progressText.TextScaled = true
	progressText.Text = string.format("%d / %d", quest.progress, quest.target)
	progressText.Parent = barBg

	-- Reward + Claim button.
	local btn = Instance.new("TextButton")
	btn.Size = UDim2.new(0, 156, 0, 64)
	btn.Position = UDim2.new(1, -168, 0, 12)
	btn.BackgroundColor3 = if quest.claimed
		then Color3.fromRGB(60, 60, 70)
		elseif quest.complete then Color3.fromRGB(120, 220, 180)
		else Color3.fromRGB(40, 44, 54)
	btn.TextColor3 = if quest.claimed
		then Color3.fromRGB(160, 160, 170)
		elseif quest.complete then Color3.fromRGB(20, 24, 32)
		else Color3.fromRGB(180, 190, 200)
	btn.Font = Enum.Font.GothamBold
	btn.TextScaled = true
	btn.AutoButtonColor = quest.complete and not quest.claimed
	btn.Active = quest.complete and not quest.claimed
	if quest.claimed then
		btn.Text = "Claimed"
	elseif quest.complete then
		btn.Text = string.format("Claim\n+%s ¢ +%d ♦", HudFormat.Abbreviated(quest.rewardCredits), quest.rewardCores)
	else
		btn.Text = string.format("+%s ¢ +%d ♦", HudFormat.Abbreviated(quest.rewardCredits), quest.rewardCores)
	end
	btn.Parent = row
	local btnCorner = Instance.new("UICorner")
	btnCorner.CornerRadius = UDim.new(0, 6)
	btnCorner.Parent = btn

	if quest.complete and not quest.claimed then
		btn.Activated:Connect(onClaim)
	end
end

local function rebuildList(state: State)
	if not list or not titleLabel then
		return
	end
	titleLabel.Text = string.format("Daily Quests — %s", formatCountdown(state.secondsUntilReset))
	for _, child in list:GetChildren() do
		if child:IsA("Frame") then
			child:Destroy()
		end
	end
	for _, quest in state.quests do
		local capturedId = quest.id
		buildQuestRow(list, quest, function()
			if pendingClaims[capturedId] or quest.claimed then
				return
			end
			pendingClaims[capturedId] = true
			task.spawn(function()
				local remote = Remotes.ClaimQuest :: RemoteFunction
				local ok, result = pcall(function()
					return remote:InvokeServer(capturedId)
				end)
				-- G5.2c: claim chime fires on confirmed success.
				if ok and typeof(result) == "table" and result.ok then
					Components.PlayClaimChime()
				end
				pendingClaims[capturedId] = nil
			end)
		end)
	end
end

local function build()
	local player = Players.LocalPlayer
	local playerGui = player:WaitForChild("PlayerGui")

	local existing = playerGui:FindFirstChild("DailyQuestsPanel")
	if existing then
		existing:Destroy()
	end

	local gui = Instance.new("ScreenGui")
	gui.Name = "DailyQuestsPanel"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.Enabled = false
	gui.Parent = playerGui

	local panel = Instance.new("Frame")
	panel.Size = UDim2.new(0, 560, 0, 400)
	panel.Position = UDim2.new(0.5, -280, 0.5, -200)
	panel.BackgroundColor3 = Color3.fromRGB(20, 24, 32)
	panel.BorderSizePixel = 0
	panel.Parent = gui

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 12)
	corner.Parent = panel

	local stroke = Instance.new("UIStroke")
	stroke.Color = Color3.fromRGB(120, 220, 180)
	stroke.Thickness = 2
	stroke.Transparency = 0.3
	stroke.Parent = panel

	local title = Instance.new("TextLabel")
	title.Size = UDim2.new(1, -60, 0, 40)
	title.Position = UDim2.new(0, 16, 0, 12)
	title.BackgroundTransparency = 1
	title.TextColor3 = Color3.fromRGB(220, 240, 200)
	title.Font = Enum.Font.GothamBold
	title.TextScaled = true
	title.TextXAlignment = Enum.TextXAlignment.Left
	title.Text = "Daily Quests"
	title.Parent = panel
	titleLabel = title

	local closeBtn = Instance.new("TextButton")
	closeBtn.Size = UDim2.new(0, 36, 0, 36)
	closeBtn.Position = UDim2.new(1, -44, 0, 14)
	closeBtn.BackgroundColor3 = Color3.fromRGB(40, 44, 54)
	closeBtn.TextColor3 = Color3.fromRGB(200, 200, 200)
	closeBtn.Font = Enum.Font.GothamBold
	closeBtn.TextScaled = true
	closeBtn.Text = "X"
	closeBtn.Parent = panel
	local closeCorner = Instance.new("UICorner")
	closeCorner.CornerRadius = UDim.new(0, 6)
	closeCorner.Parent = closeBtn
	closeBtn.Activated:Connect(function()
		setVisible(false)
	end)

	local listFrame = Instance.new("Frame")
	listFrame.Size = UDim2.new(1, -32, 0, 320)
	listFrame.Position = UDim2.new(0, 16, 0, 64)
	listFrame.BackgroundTransparency = 1
	listFrame.Parent = panel

	local layout = Instance.new("UIListLayout")
	layout.FillDirection = Enum.FillDirection.Vertical
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	layout.Padding = UDim.new(0, 12)
	layout.Parent = listFrame

	screenGui = gui
	list = listFrame
end

-- G5.2a: ActionBar owns the Quests button trigger. The toggle logic
-- the original on-screen button used moves here as Toggle() so the
-- action bar can fire it.
function DailyQuestsPanel.Toggle()
	if screenGui and screenGui.Enabled then
		setVisible(false)
	else
		setVisible(true)
		if lastState then
			rebuildList(lastState)
		end
	end
end

function DailyQuestsPanel.Init()
	build()
	local remote = Remotes.DailyQuestState :: RemoteEvent
	remote.OnClientEvent:Connect(function(state: State)
		lastState = state
		if screenGui and screenGui.Enabled then
			rebuildList(state)
		end
	end)
end

return DailyQuestsPanel
