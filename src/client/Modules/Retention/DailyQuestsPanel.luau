--!strict
--[[
	Outpost-7 — daily quests panel (client UI).

	Phase C3 (original). Phase G5.2b theme migration.

	Slide-in panel listing the day's 3 active quests with progress
	bars + Claim buttons. Auto-refreshes via DailyQuestState pushes
	from the server.

	G5.2b migration:
	  - Root panel + quest rows rebuilt on Components.StrokedFrame.
	  - Claim button uses Components.Button with playSound=false so
	    only the claim chime fires (G5.2c).
	  - State-driven stroke colors via Theme palette slots:
	      claimed   → textMuted (greyish/done)
	      complete  → highlight (celebratory ready-to-claim)
	      in-progress → accent (biome accent — neutral progress)
	  - Live re-tint on biome swap.
--]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Constants = require(Shared:WaitForChild("Constants"))
local Remotes = require(Shared:WaitForChild("Remotes"))
local Components = require(Shared:WaitForChild("Modules"):WaitForChild("UI"):WaitForChild("Components"))
local Theme = require(Shared:WaitForChild("Modules"):WaitForChild("UI"):WaitForChild("Theme"))
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
local panelScale: UIScale? = nil
local list: Frame? = nil
local titleLabel: TextLabel? = nil
local lastState: State? = nil
local pendingClaims: { [string]: boolean } = {}

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

local function setVisible(visible: boolean)
	if not screenGui or not panelScale then
		return
	end
	if visible then
		screenGui.Enabled = true
		panelScale.Scale = 0.95
		TweenService:Create(panelScale, easingInfoFor("PanelOpen"), { Scale = 1.0 }):Play()
	else
		TweenService:Create(panelScale, easingInfoFor("PanelClose"), { Scale = 0.95 }):Play()
		task.delay((Constants.UI.Motion.PanelClose :: any).duration, function()
			if screenGui then
				screenGui.Enabled = false
			end
		end)
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

local function questStrokeSlot(quest: QuestView): string
	if quest.claimed then
		return "textMuted"
	elseif quest.complete then
		return "highlight"
	end
	return "accent"
end

local function buildQuestRow(parent: Frame, quest: QuestView, onClaim: () -> ())
	local strokeSlot = questStrokeSlot(quest)
	local row = Components.StrokedFrame({
		parent = parent,
		name = "Quest_" .. quest.id,
		size = UDim2.new(1, 0, 0, 90),
		bgSlot = "panel",
		strokeSlot = strokeSlot,
		cornerAccent = false,
	})

	local name = Instance.new("TextLabel")
	name.Size = UDim2.new(1, -180, 0, 24)
	name.Position = UDim2.new(0, 12, 0, 8)
	name.BackgroundTransparency = 1
	name.TextColor3 = Theme.GetActive().textPrimary
	name.Font = Enum.Font.GothamBold
	name.TextScaled = true
	name.TextXAlignment = Enum.TextXAlignment.Left
	name.Text = quest.displayName
	name.Parent = row

	local desc = Instance.new("TextLabel")
	desc.Size = UDim2.new(1, -180, 0, 18)
	desc.Position = UDim2.new(0, 12, 0, 32)
	desc.BackgroundTransparency = 1
	desc.TextColor3 = Theme.GetActive().textMuted
	desc.Font = Enum.Font.Gotham
	desc.TextScaled = true
	desc.TextXAlignment = Enum.TextXAlignment.Left
	desc.TextWrapped = true
	desc.Text = quest.description
	desc.Parent = row

	-- Progress bar background.
	local barBg = Instance.new("Frame")
	barBg.Size = UDim2.new(1, -180, 0, 14)
	barBg.Position = UDim2.new(0, 12, 1, -22)
	barBg.BackgroundColor3 = Theme.GetActive().background
	barBg.BorderSizePixel = 0
	barBg.Parent = row
	local barCorner = Instance.new("UICorner")
	barCorner.CornerRadius = UDim.new(1, 0)
	barCorner.Parent = barBg

	local fillRatio = if quest.target > 0 then math.clamp(quest.progress / quest.target, 0, 1) else 0
	local fillSlot = if quest.complete then "highlight" else "accent"
	local barFill = Instance.new("Frame")
	barFill.Size = UDim2.new(fillRatio, 0, 1, 0)
	barFill.BackgroundColor3 = (Theme.GetActive() :: any)[fillSlot]
	barFill.BorderSizePixel = 0
	barFill.Parent = barBg
	local fillCorner = Instance.new("UICorner")
	fillCorner.CornerRadius = UDim.new(1, 0)
	fillCorner.Parent = barFill

	local progressText = Instance.new("TextLabel")
	progressText.Size = UDim2.new(1, 0, 1, 0)
	progressText.BackgroundTransparency = 1
	progressText.TextColor3 = Theme.GetActive().textPrimary
	progressText.Font = Enum.Font.GothamBold
	progressText.TextScaled = true
	progressText.Text = string.format("%d / %d", quest.progress, quest.target)
	progressText.Parent = barBg

	-- Theme.Changed re-tint for the row's manually-built labels +
	-- progress bar (StrokedFrame handles its own stroke/bg).
	local themeConn = Theme.Changed:Connect(function()
		if not name.Parent then
			return
		end
		local p = Theme.GetActive()
		name.TextColor3 = p.textPrimary
		desc.TextColor3 = p.textMuted
		progressText.TextColor3 = p.textPrimary
		barBg.BackgroundColor3 = p.background
		barFill.BackgroundColor3 = (p :: any)[fillSlot]
	end)
	row.Destroying:Connect(function()
		themeConn:Disconnect()
	end)

	-- Reward + Claim button.
	local btnText: string
	local btnBgSlot: string
	local btnTextSlot: string
	if quest.claimed then
		btnText = "Claimed"
		btnBgSlot = "background"
		btnTextSlot = "textMuted"
	elseif quest.complete then
		btnText = string.format("Claim\n+%s ¢ +%d ♦", HudFormat.Abbreviated(quest.rewardCredits), quest.rewardCores)
		btnBgSlot = "highlight"
		btnTextSlot = "background"
	else
		btnText = string.format("+%s ¢ +%d ♦", HudFormat.Abbreviated(quest.rewardCredits), quest.rewardCores)
		btnBgSlot = "background"
		btnTextSlot = "textMuted"
	end

	local btnHandle = Components.Button({
		parent = row,
		name = "ClaimButton",
		text = btnText,
		size = UDim2.fromOffset(156, 64),
		position = UDim2.new(1, -168, 0, 12),
		bgSlot = btnBgSlot,
		textSlot = btnTextSlot,
		strokeSlot = strokeSlot,
		playSound = false, -- claim button: chime supersedes click; disabled state suppresses anyway
		onActivated = if quest.complete and not quest.claimed then onClaim else function() end,
	})
	btnHandle:SetEnabled(quest.complete and not quest.claimed)
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
	gui.DisplayOrder = 30
	gui.Parent = playerGui

	local panel = Components.StrokedFrame({
		parent = gui,
		name = "Panel",
		size = UDim2.fromOffset(560, 400),
		position = UDim2.fromScale(0.5, 0.5),
		anchorPoint = Vector2.new(0.5, 0.5),
		bgSlot = "panel",
		strokeSlot = "accent",
		cornerAccent = true,
	})

	local scale = Instance.new("UIScale")
	scale.Scale = 1.0
	scale.Parent = panel
	panelScale = scale

	local title = Instance.new("TextLabel")
	title.Size = UDim2.new(1, -60, 0, 40)
	title.Position = UDim2.new(0, 16, 0, 12)
	title.BackgroundTransparency = 1
	title.TextColor3 = Theme.GetActive().textPrimary
	title.Font = Enum.Font.GothamBold
	title.TextScaled = true
	title.TextXAlignment = Enum.TextXAlignment.Left
	title.Text = "Daily Quests"
	title.Parent = panel
	titleLabel = title

	local themeConn = Theme.Changed:Connect(function()
		if title.Parent then
			title.TextColor3 = Theme.GetActive().textPrimary
		end
	end)
	panel.Destroying:Connect(function()
		themeConn:Disconnect()
	end)

	Components.Button({
		parent = panel,
		name = "CloseButton",
		text = "X",
		size = UDim2.fromOffset(36, 36),
		position = UDim2.new(1, -14, 0, 14),
		anchorPoint = Vector2.new(1, 0),
		strokeSlot = "danger",
		onActivated = function()
			setVisible(false)
		end,
	})

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
