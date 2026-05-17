--!strict
--[[
	Outpost-7 — reusable UI component primitives.

	Phase G5. Builders for the sharp-angular-sci-fi frame style locked
	with the user (UICorner 2px + UIStroke 2px accent + diagonal
	top-right corner accent). Each builder returns the constructed
	Instance + a tiny controller table with `Destroy` / `Show` / `Hide`
	hooks the caller can use.

	Theme-aware: every builder pulls the current palette from `Theme.GetActive()`
	at build time AND subscribes to `Theme.Changed` so the instance
	re-tints when the active biome flips.

	Audio: builders fire UI cues via AudioController.PlayLocal at the
	natural moments (button activated = ui_button_click, panel open =
	ui_panel_open, panel close = ui_panel_close). Reward chimes are
	caller-driven via Components.PlayClaimChime() since not every panel
	involves a claim.

	Builders:
	  Components.StrokedFrame(parent, opts)   — base sci-fi frame
	  Components.CornerAccent(parent)         — top-right diagonal mark
	  Components.Button(parent, opts)         — accent-stroked button
	  Components.Panel(opts)                  — full-screen modal w/ title
	  Components.HudPill(parent, opts)        — small currency/HUD readout

	Component pattern: builders accept an `opts` table with the bare
	minimum fields (parent, text, size, etc.) and apply Theme + Motion
	defaults from Constants.UI. Caller never sets BackgroundColor3 or
	Font directly; ALL styling routes through Theme.
--]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Constants = require(Shared:WaitForChild("Constants"))
local Theme = require(Shared:WaitForChild("Modules"):WaitForChild("UI"):WaitForChild("Theme"))

local Components = {}

-- Lazy AudioController require — only fetched on the client where the
-- module exists. Server-side imports of Components (for shared type
-- references) should not pull AudioController.
local audioController: any = nil
local function getAudioController(): any?
	if not RunService:IsClient() then
		return nil
	end
	if audioController then
		return audioController
	end
	-- Resolve by walking from LocalPlayer.PlayerScripts. Defensive: if
	-- AudioController hasn't been required yet, we bail and skip the
	-- sound (the click still happens, just silent).
	local player = Players.LocalPlayer
	if not player then
		return nil
	end
	local scripts = player:FindFirstChild("PlayerScripts")
	if not scripts then
		return nil
	end
	local clientRoot = scripts:FindFirstChild("Client")
	if not clientRoot then
		return nil
	end
	local mods = clientRoot:FindFirstChild("Modules")
	if not mods then
		return nil
	end
	local audioFolder = mods:FindFirstChild("Audio")
	if not audioFolder then
		return nil
	end
	local controllerScript = audioFolder:FindFirstChild("AudioController")
	if not controllerScript then
		return nil
	end
	local ok, mod = pcall(require, controllerScript)
	if ok then
		audioController = mod
		return mod
	end
	return nil
end

local function playLocalCue(cueId: string)
	local ac = getAudioController()
	if ac and ac.PlayLocal then
		ac.PlayLocal(cueId)
	end
end

local function easingInfoFor(presetName: string): TweenInfo
	local preset: any = Constants.UI.Motion[presetName]
	if not preset then
		return TweenInfo.new(0.1)
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

-- ---------- StrokedFrame ----------

export type StrokedFrameOpts = {
	parent: Instance,
	name: string?,
	size: UDim2,
	position: UDim2?,
	anchorPoint: Vector2?,
	bgSlot: string?, -- palette slot for BackgroundColor3 (default "panel")
	strokeSlot: string?, -- palette slot for stroke (default "accent")
	cornerAccent: boolean?, -- draw top-right corner accent (default true)
}

function Components.CornerAccent(parent: GuiObject): GuiObject
	-- Small 45-degree diagonal stroke on the top-right corner, drawn
	-- as a thin Frame rotated 45° with the stroke color. Adds the
	-- "in-fiction HUD" detail the user picked.
	local palette = Theme.GetActive()
	local size = Constants.UI.Frame.CornerAccentSize
	local thickness = Constants.UI.Frame.CornerAccentThickness

	local accent = Instance.new("Frame")
	accent.Name = "CornerAccent"
	accent.AnchorPoint = Vector2.new(1, 0)
	accent.Position = UDim2.new(1, -2, 0, 2)
	accent.Size = UDim2.fromOffset(size, thickness)
	accent.BackgroundColor3 = palette.accent
	accent.BorderSizePixel = 0
	accent.Rotation = -45
	accent.ZIndex = (parent.ZIndex or 1) + 1
	accent.Parent = parent

	-- Live re-tint on theme swap.
	local conn = Theme.Changed:Connect(function()
		if accent.Parent then
			accent.BackgroundColor3 = Theme.GetActive().accent
		else
			-- Self-clean when the host frame is destroyed.
		end
	end)
	accent.Destroying:Connect(function()
		conn:Disconnect()
	end)

	return accent
end

function Components.StrokedFrame(opts: StrokedFrameOpts): Frame
	local palette = Theme.GetActive()
	local frame = Instance.new("Frame")
	frame.Name = opts.name or "StrokedFrame"
	frame.Size = opts.size
	if opts.position then
		frame.Position = opts.position
	end
	if opts.anchorPoint then
		frame.AnchorPoint = opts.anchorPoint
	end
	local bgSlot = opts.bgSlot or "panel"
	frame.BackgroundColor3 = (palette :: any)[bgSlot] or palette.panel
	frame.BackgroundTransparency = Constants.UI.Frame.BackgroundTransparency
	frame.BorderSizePixel = 0

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, Constants.UI.Frame.CornerRadius)
	corner.Parent = frame

	local strokeSlot = opts.strokeSlot or "accent"
	local stroke = Instance.new("UIStroke")
	stroke.Name = "OutpostStroke"
	stroke.Color = (palette :: any)[strokeSlot] or palette.accent
	stroke.Thickness = Constants.UI.Frame.StrokeThickness
	stroke.Transparency = Constants.UI.Frame.StrokeTransparency
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	stroke.Parent = frame

	frame.Parent = opts.parent

	if opts.cornerAccent ~= false then
		Components.CornerAccent(frame)
	end

	-- Live theme re-tint.
	local conn = Theme.Changed:Connect(function()
		if not frame.Parent then
			return
		end
		local p = Theme.GetActive()
		frame.BackgroundColor3 = (p :: any)[bgSlot] or p.panel
		stroke.Color = (p :: any)[strokeSlot] or p.accent
	end)
	frame.Destroying:Connect(function()
		conn:Disconnect()
	end)

	return frame
end

-- ---------- Button ----------

export type ButtonOpts = {
	parent: Instance,
	name: string?,
	text: string,
	size: UDim2,
	position: UDim2?,
	anchorPoint: Vector2?,
	textSlot: string?, -- default "textPrimary"
	bgSlot: string?, -- default "panel"
	strokeSlot: string?, -- default "accent"
	onActivated: (() -> ())?,
	playSound: boolean?, -- default true
}

export type ButtonHandle = {
	instance: TextButton,
	SetText: (self: ButtonHandle, value: string) -> (),
	SetEnabled: (self: ButtonHandle, on: boolean) -> (),
	Destroy: (self: ButtonHandle) -> (),
}

function Components.Button(opts: ButtonOpts): ButtonHandle
	local palette = Theme.GetActive()
	local btn = Instance.new("TextButton")
	btn.Name = opts.name or "Button"
	btn.Text = opts.text
	btn.Size = opts.size
	if opts.position then
		btn.Position = opts.position
	end
	if opts.anchorPoint then
		btn.AnchorPoint = opts.anchorPoint
	end
	local bgSlot = opts.bgSlot or "panel"
	local textSlot = opts.textSlot or "textPrimary"
	local strokeSlot = opts.strokeSlot or "accent"
	btn.BackgroundColor3 = (palette :: any)[bgSlot] or palette.panel
	btn.TextColor3 = (palette :: any)[textSlot] or palette.textPrimary
	btn.BackgroundTransparency = Constants.UI.Frame.BackgroundTransparency
	btn.BorderSizePixel = 0
	btn.AutoButtonColor = false
	btn.Font = Enum.Font.GothamBold
	btn.TextScaled = true

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, Constants.UI.Frame.CornerRadius)
	corner.Parent = btn

	local stroke = Instance.new("UIStroke")
	stroke.Color = (palette :: any)[strokeSlot] or palette.accent
	stroke.Thickness = Constants.UI.Frame.StrokeThickness
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	stroke.Parent = btn

	-- Padding so the text doesn't kiss the stroke.
	local padding = Instance.new("UIPadding")
	padding.PaddingLeft = UDim.new(0, 8)
	padding.PaddingRight = UDim.new(0, 8)
	padding.PaddingTop = UDim.new(0, 4)
	padding.PaddingBottom = UDim.new(0, 4)
	padding.Parent = btn

	-- UIScale child for press/release tween (don't tween Size — UDim2
	-- tweens are coarser than UIScale + cleaner for nested layouts).
	local scale = Instance.new("UIScale")
	scale.Scale = 1.0
	scale.Parent = btn

	local pressInfo = easingInfoFor("ButtonPress")
	local releaseInfo = easingInfoFor("ButtonRelease")
	local pressTarget = (Constants.UI.Motion.ButtonPress :: any).scale or 0.95

	local function pressDown()
		TweenService:Create(scale, pressInfo, { Scale = pressTarget }):Play()
	end
	local function releaseUp()
		TweenService:Create(scale, releaseInfo, { Scale = 1.0 }):Play()
	end

	btn.MouseButton1Down:Connect(pressDown)
	btn.MouseButton1Up:Connect(releaseUp)
	btn.MouseLeave:Connect(releaseUp)
	btn.TouchTap:Connect(function()
		-- TouchTap covers mobile; pair with pressDown→releaseUp for
		-- visual feedback even on tap (no Mouse events on touch).
		pressDown()
		task.delay(0.05, releaseUp)
	end)

	btn.Activated:Connect(function()
		if opts.playSound ~= false then
			playLocalCue("ui_button_click")
		end
		if opts.onActivated then
			opts.onActivated()
		end
	end)

	btn.Parent = opts.parent

	local conn = Theme.Changed:Connect(function()
		if not btn.Parent then
			return
		end
		local p = Theme.GetActive()
		btn.BackgroundColor3 = (p :: any)[bgSlot] or p.panel
		btn.TextColor3 = (p :: any)[textSlot] or p.textPrimary
		stroke.Color = (p :: any)[strokeSlot] or p.accent
	end)
	btn.Destroying:Connect(function()
		conn:Disconnect()
	end)

	local handle: ButtonHandle = {
		instance = btn,
		SetText = function(self, v)
			btn.Text = v
		end,
		SetEnabled = function(self, on)
			btn.AutoButtonColor = false
			btn.Active = on
			btn.AutoLocalize = false
			btn.TextTransparency = if on then 0 else 0.5
			stroke.Transparency = if on then 0 else 0.6
		end,
		Destroy = function(self)
			btn:Destroy()
		end,
	}
	return handle
end

-- ---------- Panel (full-screen modal) ----------

export type PanelOpts = {
	parent: Instance, -- typically the player's ScreenGui
	name: string?,
	title: string,
	size: UDim2?,
	onClose: (() -> ())?,
}

export type PanelHandle = {
	root: Frame,
	content: Frame,
	closeButton: ButtonHandle,
	Show: (self: PanelHandle) -> (),
	Hide: (self: PanelHandle) -> (),
	Destroy: (self: PanelHandle) -> (),
}

function Components.Panel(opts: PanelOpts): PanelHandle
	local size = opts.size or UDim2.new(0.7, 0, 0.7, 0)
	local root = Components.StrokedFrame({
		parent = opts.parent,
		name = opts.name or "Panel",
		size = size,
		position = UDim2.fromScale(0.5, 0.5),
		anchorPoint = Vector2.new(0.5, 0.5),
		bgSlot = "panel",
		strokeSlot = "accent",
		cornerAccent = true,
	})

	-- UIScale for open/close tween.
	local scale = Instance.new("UIScale")
	scale.Scale = 0.95
	scale.Parent = root
	root.BackgroundTransparency = 0.4 -- start transparent for fade-in

	-- Title row.
	local titleLabel = Instance.new("TextLabel")
	titleLabel.Name = "Title"
	titleLabel.BackgroundTransparency = 1
	titleLabel.AnchorPoint = Vector2.new(0, 0)
	titleLabel.Position = UDim2.new(0, 16, 0, 12)
	titleLabel.Size = UDim2.new(1, -120, 0, 32)
	titleLabel.Font = Enum.Font.GothamBold
	titleLabel.TextSize = 22
	titleLabel.TextXAlignment = Enum.TextXAlignment.Left
	titleLabel.Text = opts.title
	titleLabel.TextColor3 = Theme.GetActive().textPrimary
	titleLabel.Parent = root

	-- Close button.
	local closeBtn = Components.Button({
		parent = root,
		name = "CloseButton",
		text = "X",
		size = UDim2.fromOffset(40, 40),
		position = UDim2.new(1, -12, 0, 12),
		anchorPoint = Vector2.new(1, 0),
		strokeSlot = "danger",
		textSlot = "textPrimary",
	})

	-- Content host frame (everything below the title row).
	local content = Instance.new("Frame")
	content.Name = "Content"
	content.BackgroundTransparency = 1
	content.Position = UDim2.new(0, 16, 0, 56)
	content.Size = UDim2.new(1, -32, 1, -72)
	content.Parent = root

	-- Theme re-tint hook for the title (StrokedFrame already auto-tints).
	local titleConn = Theme.Changed:Connect(function()
		if titleLabel.Parent then
			titleLabel.TextColor3 = Theme.GetActive().textPrimary
		end
	end)
	root.Destroying:Connect(function()
		titleConn:Disconnect()
	end)

	-- Hidden by default; caller calls :Show() to open with anim.
	root.Visible = false

	local handle: PanelHandle
	local function doHide()
		local closeInfo = easingInfoFor("PanelClose")
		TweenService:Create(scale, closeInfo, { Scale = 0.95 }):Play()
		local fade = TweenService:Create(root, closeInfo, { BackgroundTransparency = 0.4 })
		fade:Play()
		fade.Completed:Once(function()
			root.Visible = false
		end)
		playLocalCue("ui_panel_close")
	end

	closeBtn.instance.Activated:Connect(function()
		if opts.onClose then
			opts.onClose()
		end
		doHide()
	end)

	handle = {
		root = root,
		content = content,
		closeButton = closeBtn,
		Show = function(self)
			root.Visible = true
			scale.Scale = 0.95
			root.BackgroundTransparency = 0.4
			local openInfo = easingInfoFor("PanelOpen")
			TweenService:Create(scale, openInfo, { Scale = 1.0 }):Play()
			TweenService:Create(root, openInfo, { BackgroundTransparency = Constants.UI.Frame.BackgroundTransparency }):Play()
			playLocalCue("ui_panel_open")
		end,
		Hide = function(self)
			doHide()
		end,
		Destroy = function(self)
			root:Destroy()
		end,
	}
	return handle
end

-- ---------- HUD pill (currency / wave-timer readouts) ----------

export type HudPillOpts = {
	parent: Instance,
	name: string?,
	size: UDim2,
	position: UDim2,
	anchorPoint: Vector2?,
	text: string,
	strokeSlot: string?, -- default "accent"
	textSlot: string?, -- default "textPrimary"
	bgSlot: string?, -- default "panel"
}

export type HudPillHandle = {
	frame: Frame,
	label: TextLabel,
	SetText: (self: HudPillHandle, value: string) -> (),
	FlashHighlight: (self: HudPillHandle) -> (), -- snap-tween to highlight color and back
	Destroy: (self: HudPillHandle) -> (),
}

function Components.HudPill(opts: HudPillOpts): HudPillHandle
	local strokeSlot = opts.strokeSlot or "accent"
	local textSlot = opts.textSlot or "textPrimary"
	local bgSlot = opts.bgSlot or "panel"

	local frame = Components.StrokedFrame({
		parent = opts.parent,
		name = opts.name or "HudPill",
		size = opts.size,
		position = opts.position,
		anchorPoint = opts.anchorPoint,
		bgSlot = bgSlot,
		strokeSlot = strokeSlot,
		cornerAccent = false, -- HUD pills are small; corner accent is too busy
	})

	local label = Instance.new("TextLabel")
	label.Name = "Value"
	label.Size = UDim2.new(1, -20, 1, 0)
	label.Position = UDim2.new(0, 10, 0, 0)
	label.BackgroundTransparency = 1
	label.TextColor3 = (Theme.GetActive() :: any)[textSlot] or Theme.GetActive().textPrimary
	label.Font = Enum.Font.GothamBold
	label.TextScaled = true
	label.TextXAlignment = Enum.TextXAlignment.Right
	label.Text = opts.text
	label.Parent = frame

	local conn = Theme.Changed:Connect(function()
		if label.Parent then
			label.TextColor3 = (Theme.GetActive() :: any)[textSlot] or Theme.GetActive().textPrimary
		end
	end)
	frame.Destroying:Connect(function()
		conn:Disconnect()
	end)

	local handle: HudPillHandle = {
		frame = frame,
		label = label,
		SetText = function(self, v)
			label.Text = v
		end,
		FlashHighlight = function(self)
			-- Snappy color flash to the highlight slot, then back.
			local snap = easingInfoFor("HudSnap")
			local highlight = Theme.GetActive().highlight
			local rest = (Theme.GetActive() :: any)[textSlot] or Theme.GetActive().textPrimary
			TweenService:Create(label, snap, { TextColor3 = highlight }):Play()
			task.delay(0.18, function()
				if label.Parent then
					TweenService:Create(label, snap, { TextColor3 = rest }):Play()
				end
			end)
		end,
		Destroy = function(self)
			frame:Destroy()
		end,
	}
	return handle
end

-- ---------- Sound helpers ----------

function Components.PlayClaimChime()
	playLocalCue("ui_claim_reward")
end

return Components
