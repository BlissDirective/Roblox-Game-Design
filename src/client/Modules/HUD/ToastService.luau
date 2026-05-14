--!strict
--[[
	Outpost-7 — Toast notification service (client).

	Phase G5. Split-by-severity layout per user spec:
	  error  → top-center cascade  (3 max, oldest drops)
	  reward → bottom-center single (newest replaces previous)
	  info   → right-side column   (4 max, oldest drops)

	Each toast is a sharp-angular-sci-fi StrokedFrame with the
	severity-appropriate stroke color (danger / highlight / accent).
	Slide-in via UIScale + BackgroundTransparency tween; slide-out on
	auto-dismiss or stack overflow.

	Public API:
	  Init                                — build the 3 layout containers,
	                                        subscribe to Theme + relevant
	                                        Remotes for built-in toasts
	  Show(severity, text, opts?)         — display a toast
	  ShowError(text, opts?)              — convenience
	  ShowReward(text, opts?)             — convenience (auto-plays
	                                         ui_claim_reward chime)
	  ShowInfo(text, opts?)               — convenience

	Built-in subscriptions (G5.1):
	  - CosmeticUnlocked Remote → ShowInfo
	  - (Future) BattlePassClaim claim → ShowReward
	  - (Future) Placement validation failure → ShowError
--]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Constants = require(Shared:WaitForChild("Constants"))
local Remotes = require(Shared:WaitForChild("Remotes"))
local Theme = require(Shared:WaitForChild("Modules"):WaitForChild("UI"):WaitForChild("Theme"))
local Components = require(Shared:WaitForChild("Modules"):WaitForChild("UI"):WaitForChild("Components"))
local CosmeticRegistry =
	require(Shared:WaitForChild("Modules"):WaitForChild("Registry"):WaitForChild("CosmeticRegistry"))

local ToastService = {}

export type Severity = "error" | "reward" | "info"

export type ToastOpts = {
	severity: Severity?, -- overrides positional `severity` if Show is called dict-style
	autoDismissSeconds: number?, -- override Constants default
	playChime: boolean?, -- reward severity auto-plays; override to disable
}

local GUI_NAME = "OutpostToasts"
local TOP_CONTAINER = "TopCenter"
local BOTTOM_CONTAINER = "BottomCenter"
local RIGHT_CONTAINER = "RightColumn"

-- Active toast tracking per severity.
local active: { [Severity]: { Frame } } = {
	error = {},
	reward = {},
	info = {},
}

local containers: { [string]: Frame } = {}
local screenGui: ScreenGui?

local function strokeSlotForSeverity(severity: Severity): string
	if severity == "error" then
		return "danger"
	elseif severity == "reward" then
		return "highlight"
	end
	return "accent"
end

local function ensureGui(): ScreenGui
	if screenGui and screenGui.Parent then
		return screenGui
	end
	local player = Players.LocalPlayer
	local playerGui = player:WaitForChild("PlayerGui")
	local existing = playerGui:FindFirstChild(GUI_NAME)
	if existing and existing:IsA("ScreenGui") then
		screenGui = existing
		return existing
	end
	local gui = Instance.new("ScreenGui")
	gui.Name = GUI_NAME
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.DisplayOrder = 50 -- above HUD pills, below FTUE overlays
	gui.Parent = playerGui
	screenGui = gui
	return gui
end

local function buildContainers()
	local gui = ensureGui()
	-- Top-center cascade (errors).
	local top = Instance.new("Frame")
	top.Name = TOP_CONTAINER
	top.BackgroundTransparency = 1
	top.AnchorPoint = Vector2.new(0.5, 0)
	top.Position = UDim2.new(0.5, 0, 0, Constants.UI.Toast.OffsetTopPx)
	top.Size = UDim2.fromOffset(Constants.UI.Toast.ToastWidthPx, 320)
	top.Parent = gui
	local topLayout = Instance.new("UIListLayout")
	topLayout.SortOrder = Enum.SortOrder.LayoutOrder
	topLayout.Padding = UDim.new(0, Constants.UI.Toast.InterToastGapPx)
	topLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	topLayout.Parent = top
	containers[TOP_CONTAINER] = top

	-- Bottom-center single (rewards).
	local bottom = Instance.new("Frame")
	bottom.Name = BOTTOM_CONTAINER
	bottom.BackgroundTransparency = 1
	bottom.AnchorPoint = Vector2.new(0.5, 1)
	bottom.Position = UDim2.new(0.5, 0, 1, -Constants.UI.Toast.OffsetBottomPx)
	bottom.Size = UDim2.fromOffset(Constants.UI.Toast.ToastWidthPx, Constants.UI.Toast.ToastHeightPx)
	bottom.Parent = gui
	containers[BOTTOM_CONTAINER] = bottom

	-- Right-side column (info).
	local right = Instance.new("Frame")
	right.Name = RIGHT_CONTAINER
	right.BackgroundTransparency = 1
	right.AnchorPoint = Vector2.new(1, 0.5)
	right.Position = UDim2.new(1, -Constants.UI.Toast.OffsetRightPx, 0.5, 0)
	right.Size = UDim2.fromOffset(Constants.UI.Toast.ToastWidthPx, 320)
	right.Parent = gui
	local rightLayout = Instance.new("UIListLayout")
	rightLayout.SortOrder = Enum.SortOrder.LayoutOrder
	rightLayout.Padding = UDim.new(0, Constants.UI.Toast.InterToastGapPx)
	rightLayout.HorizontalAlignment = Enum.HorizontalAlignment.Right
	rightLayout.Parent = right
	containers[RIGHT_CONTAINER] = right
end

local function containerFor(severity: Severity): Frame
	if severity == "error" then
		return containers[TOP_CONTAINER]
	elseif severity == "reward" then
		return containers[BOTTOM_CONTAINER]
	end
	return containers[RIGHT_CONTAINER]
end

local function easingInfoFor(presetName: string): TweenInfo
	local preset: any = Constants.UI.Motion[presetName]
	if not preset then
		return TweenInfo.new(0.2)
	end
	return TweenInfo.new(
		preset.duration,
		Theme.EasingStyleFor(preset.easing),
		Theme.EasingDirectionFor(preset.easing),
		0,
		false,
		0
	)
end

local function dismissToast(severity: Severity, frame: Frame)
	local list = active[severity]
	for i, f in list do
		if f == frame then
			table.remove(list, i)
			break
		end
	end
	-- Slide-out tween, then destroy.
	local outInfo = easingInfoFor("ToastSlideOut")
	TweenService:Create(frame, outInfo, { BackgroundTransparency = 1 }):Play()
	local scale = frame:FindFirstChildOfClass("UIScale")
	if scale then
		TweenService:Create(scale, outInfo, { Scale = 0.95 }):Play()
	end
	local label = frame:FindFirstChild("Body") :: TextLabel?
	if label then
		TweenService:Create(label, outInfo, { TextTransparency = 1 }):Play()
	end
	local stroke = frame:FindFirstChildOfClass("UIStroke")
	if stroke then
		TweenService:Create(stroke, outInfo, { Transparency = 1 }):Play()
	end
	task.delay((Constants.UI.Motion.ToastSlideOut :: any).duration + 0.05, function()
		frame:Destroy()
	end)
end

function ToastService.Show(severity: Severity, text: string, opts: ToastOpts?)
	if not containers[TOP_CONTAINER] then
		buildContainers()
	end
	local options: ToastOpts = opts or {}
	local sev: Severity = options.severity or severity

	local list = active[sev]
	local cap = Constants.UI.Toast.MaxVisible[sev]
	-- Reward = single replaces; error/info = drop oldest on overflow.
	if sev == "reward" then
		for _, f in list do
			dismissToast(sev, f)
		end
	else
		while #list >= cap do
			dismissToast(sev, list[1])
		end
	end

	local toast = Components.StrokedFrame({
		parent = containerFor(sev),
		name = string.format("Toast_%s", sev),
		size = UDim2.fromOffset(Constants.UI.Toast.ToastWidthPx, Constants.UI.Toast.ToastHeightPx),
		bgSlot = "panel",
		strokeSlot = strokeSlotForSeverity(sev),
		cornerAccent = false,
	})
	toast.LayoutOrder = -tick() -- newer toasts higher (smaller LayoutOrder)

	local body = Instance.new("TextLabel")
	body.Name = "Body"
	body.BackgroundTransparency = 1
	body.Size = UDim2.new(1, -24, 1, -8)
	body.Position = UDim2.new(0, 12, 0, 4)
	body.Font = Enum.Font.GothamBold
	body.TextScaled = true
	body.TextWrapped = true
	body.TextXAlignment = Enum.TextXAlignment.Left
	body.TextYAlignment = Enum.TextYAlignment.Center
	body.Text = text
	body.TextColor3 = Theme.GetActive().textPrimary
	body.Parent = toast

	local conn = Theme.Changed:Connect(function()
		if body.Parent then
			body.TextColor3 = Theme.GetActive().textPrimary
		end
	end)
	toast.Destroying:Connect(function()
		conn:Disconnect()
	end)

	-- Slide-in: start at scale 0.95 + transparent, tween to 1 + opaque.
	local scale = Instance.new("UIScale")
	scale.Scale = 0.95
	scale.Parent = toast
	toast.BackgroundTransparency = 1
	body.TextTransparency = 1
	local inInfo = easingInfoFor("ToastSlideIn")
	TweenService:Create(scale, inInfo, { Scale = 1.0 }):Play()
	TweenService:Create(toast, inInfo, { BackgroundTransparency = Constants.UI.Frame.BackgroundTransparency }):Play()
	TweenService:Create(body, inInfo, { TextTransparency = 0 }):Play()

	table.insert(list, toast)

	-- Reward severity auto-plays the claim chime.
	if sev == "reward" and options.playChime ~= false then
		Components.PlayClaimChime()
	end

	local dismissAt = options.autoDismissSeconds or Constants.UI.Toast.AutoDismissSeconds[sev]
	task.delay(dismissAt, function()
		if toast.Parent then
			dismissToast(sev, toast)
		end
	end)
end

function ToastService.ShowError(text: string, opts: ToastOpts?)
	ToastService.Show("error", text, opts)
end

function ToastService.ShowReward(text: string, opts: ToastOpts?)
	ToastService.Show("reward", text, opts)
end

function ToastService.ShowInfo(text: string, opts: ToastOpts?)
	ToastService.Show("info", text, opts)
end

function ToastService.Init()
	buildContainers()
	-- Bind to CosmeticUnlocked for built-in info toast. Server sends
	-- { cosmeticId, source }; we resolve the displayName via the shared
	-- CosmeticRegistry.
	Remotes.CosmeticUnlocked.OnClientEvent:Connect(function(payload: any)
		if type(payload) ~= "table" or not payload.cosmeticId then
			return
		end
		local entry = CosmeticRegistry.Catalog[payload.cosmeticId]
		local name = if entry and entry.displayName then entry.displayName else tostring(payload.cosmeticId)
		ToastService.ShowInfo(string.format("Unlocked: %s", name))
	end)
end

return ToastService
