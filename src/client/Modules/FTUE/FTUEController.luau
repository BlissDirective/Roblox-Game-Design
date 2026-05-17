--!strict
--[[
	Outpost-7 — FTUE client overlay + cinematic.

	Phase F4 (original state machine). Phase G8 polish pass.

	Server pushes `FTUEState` per current step; this module renders the
	client-side response:

	  cinematic step → multi-stage scripted cinematic (3 keyframes,
	                   title cards, intro sting cue). Skippable.
	  scout step     → rotating-ring beacon above the target node +
	                   hint banner pointing the player toward it.
	  place_extractor → hint banner + animated arrow pointing at the
	                   action bar (where the build palette lives).
	  first_credits  → hint banner + animated arrow pointing at the
	                   Credits HUD pill (top-right).

	Polish (G8) per locked user spec:
	  - Multi-stage cinematic (wide → orbit → gameplay-angle pull-back)
	    with title cards ("OUTPOST-7" / "// Sector 14-J") sliding in.
	  - Rotating ring + emissive pulse beacon (replaces solid pillar).
	  - HUD pointer arrows on place_extractor + first_credits.
	  - Hint banner auto-dismiss after 8s (next step replaces it).
	  - Step-advance audio cue fires on every transition.
	  - All overlays use Components.StrokedFrame + Theme palette slots
	    so the FTUE matches the rest of the UI and biome-tints live.
--]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Constants = require(Shared:WaitForChild("Constants"))
local Remotes = require(Shared:WaitForChild("Remotes"))
local Components = require(Shared:WaitForChild("Modules"):WaitForChild("UI"):WaitForChild("Components"))
local Theme = require(Shared:WaitForChild("Modules"):WaitForChild("UI"):WaitForChild("Theme"))

local FTUEController = {}

type State = {
	step: string,
	hint: string,
	cinematicSeconds: number?,
	targetCellX: number?,
	targetCellZ: number?,
}

local CINEMATIC_STEP = "cinematic"
local SCOUT_STEP = "scout"
local PLACE_EXTRACTOR_STEP = "place_extractor"
local FIRST_CREDITS_STEP = "first_credits"

local HINT_AUTODISMISS_SECONDS = 8.0
local BEACON_ROTATION_PERIOD = 4.0 -- seconds per full rotation
local BEACON_PULSE_PERIOD = 1.5 -- seconds per Brightness pulse cycle

local screenGui: ScreenGui? = nil
local hintFrame: Frame? = nil
local hintLabel: TextLabel? = nil
local hintDismissTask: thread? = nil
local skipBtnHandle: any = nil
local titleLabel: TextLabel? = nil
local subtitleLabel: TextLabel? = nil
local blackoutFrame: Frame? = nil
local nodeBeacon: Folder? = nil
local beaconHeartbeat: RBXScriptConnection? = nil
local pointerArrow: Frame? = nil
local pointerHeartbeat: RBXScriptConnection? = nil
local cinematicCameraSubject: Camera? = nil
local lastSeenStep: string? = nil

-- Lazy AudioController require — same pattern as Components.
local audioController: any = nil
local function playLocalCue(cueId: string)
	if not audioController then
		local player = Players.LocalPlayer
		if not player then
			return
		end
		local scripts = player:FindFirstChild("PlayerScripts")
		if not scripts then
			return
		end
		local clientRoot = scripts:FindFirstChild("Client")
		if not clientRoot then
			return
		end
		local mods = clientRoot:FindFirstChild("Modules")
		if not mods then
			return
		end
		local audioFolder = mods:FindFirstChild("Audio")
		if not audioFolder then
			return
		end
		local controllerScript = audioFolder:FindFirstChild("AudioController")
		if not controllerScript then
			return
		end
		local ok, mod = pcall(require, controllerScript)
		if not ok then
			return
		end
		audioController = mod
	end
	if audioController and audioController.PlayLocal then
		audioController.PlayLocal(cueId)
	end
end

local function ensureScreenGui(): ScreenGui
	if screenGui and screenGui.Parent then
		return screenGui
	end
	local pg = Players.LocalPlayer:WaitForChild("PlayerGui") :: PlayerGui
	local existing = pg:FindFirstChild("OutpostFTUE")
	if existing and existing:IsA("ScreenGui") then
		screenGui = existing
		return existing
	end
	local gui = Instance.new("ScreenGui")
	gui.Name = "OutpostFTUE"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.DisplayOrder = 60 -- above HUD, ActionBar, ToastService
	gui.Parent = pg
	screenGui = gui
	return gui
end

local function cancelHintDismiss()
	if hintDismissTask then
		task.cancel(hintDismissTask)
		hintDismissTask = nil
	end
end

local function clearHint()
	cancelHintDismiss()
	if hintFrame then
		hintFrame:Destroy()
		hintFrame = nil
		hintLabel = nil
	end
end

local function clearSkipButton()
	if skipBtnHandle then
		skipBtnHandle:Destroy()
		skipBtnHandle = nil
	end
end

local function clearTitleCards()
	if titleLabel then
		titleLabel:Destroy()
		titleLabel = nil
	end
	if subtitleLabel then
		subtitleLabel:Destroy()
		subtitleLabel = nil
	end
end

local function clearBlackout()
	if blackoutFrame then
		blackoutFrame:Destroy()
		blackoutFrame = nil
	end
end

local function clearBeacon()
	if beaconHeartbeat then
		beaconHeartbeat:Disconnect()
		beaconHeartbeat = nil
	end
	if nodeBeacon then
		nodeBeacon:Destroy()
		nodeBeacon = nil
	end
end

local function clearPointerArrow()
	if pointerHeartbeat then
		pointerHeartbeat:Disconnect()
		pointerHeartbeat = nil
	end
	if pointerArrow then
		pointerArrow:Destroy()
		pointerArrow = nil
	end
end

local function clearCinematicCamera()
	if cinematicCameraSubject then
		cinematicCameraSubject.CameraType = Enum.CameraType.Custom
		cinematicCameraSubject = nil
	end
end

local function clearAll()
	clearHint()
	clearSkipButton()
	clearTitleCards()
	clearBlackout()
	clearBeacon()
	clearPointerArrow()
	clearCinematicCamera()
end

-- ---------- Hint banner ----------

local function showHintBanner(text: string)
	cancelHintDismiss()
	if hintFrame and hintLabel then
		hintLabel.Text = text
	else
		local gui = ensureScreenGui()
		local frame = Components.StrokedFrame({
			parent = gui,
			name = "HintBanner",
			size = UDim2.fromOffset(520, 56),
			position = UDim2.new(0.5, 0, 0, 56),
			anchorPoint = Vector2.new(0.5, 0),
			bgSlot = "panel",
			strokeSlot = "accent",
			cornerAccent = false,
		})
		local label = Instance.new("TextLabel")
		label.Name = "Body"
		label.Size = UDim2.new(1, -32, 1, 0)
		label.Position = UDim2.fromOffset(16, 0)
		label.BackgroundTransparency = 1
		label.TextColor3 = Theme.GetActive().textPrimary
		label.TextScaled = true
		label.Font = Enum.Font.GothamBold
		label.Text = text
		label.Parent = frame

		local conn = Theme.Changed:Connect(function()
			if label.Parent then
				label.TextColor3 = Theme.GetActive().textPrimary
			end
		end)
		frame.Destroying:Connect(function()
			conn:Disconnect()
		end)

		hintFrame = frame
		hintLabel = label
	end
	-- Auto-dismiss after 8s. Cancellable if next step arrives first.
	hintDismissTask = task.delay(HINT_AUTODISMISS_SECONDS, function()
		clearHint()
	end)
end

-- ---------- Skip button ----------

local function ackCinematicStep()
	local remote = Remotes.FTUEStepAck :: RemoteFunction
	pcall(function()
		remote:InvokeServer(CINEMATIC_STEP)
	end)
end

local function showSkipButton()
	if skipBtnHandle then
		return
	end
	local gui = ensureScreenGui()
	skipBtnHandle = Components.Button({
		parent = gui,
		name = "SkipButton",
		text = "Skip",
		size = UDim2.fromOffset(96, 32),
		position = UDim2.new(1, -112, 1, -48),
		strokeSlot = "textMuted",
		onActivated = ackCinematicStep,
	})
end

-- ---------- Title cards ----------

local function showTitleCard(title: string, subtitle: string, duration: number)
	local gui = ensureScreenGui()
	clearTitleCards()

	local titleInst = Instance.new("TextLabel")
	titleInst.Name = "FtueTitle"
	titleInst.Size = UDim2.fromOffset(720, 64)
	titleInst.Position = UDim2.new(0.5, 0, 0.5, -48)
	titleInst.AnchorPoint = Vector2.new(0.5, 0.5)
	titleInst.BackgroundTransparency = 1
	titleInst.TextColor3 = Theme.GetActive().textPrimary
	titleInst.TextStrokeColor3 = Color3.new(0, 0, 0)
	titleInst.TextStrokeTransparency = 0.3
	titleInst.Font = Enum.Font.GothamBold
	titleInst.TextScaled = true
	titleInst.Text = title
	titleInst.TextTransparency = 1
	titleInst.Parent = gui
	titleLabel = titleInst

	local subtitleInst = Instance.new("TextLabel")
	subtitleInst.Name = "FtueSubtitle"
	subtitleInst.Size = UDim2.fromOffset(720, 36)
	subtitleInst.Position = UDim2.new(0.5, 0, 0.5, 16)
	subtitleInst.AnchorPoint = Vector2.new(0.5, 0.5)
	subtitleInst.BackgroundTransparency = 1
	subtitleInst.TextColor3 = Theme.GetActive().accent
	subtitleInst.TextStrokeColor3 = Color3.new(0, 0, 0)
	subtitleInst.TextStrokeTransparency = 0.3
	subtitleInst.Font = Enum.Font.Gotham
	subtitleInst.TextScaled = true
	subtitleInst.Text = subtitle
	subtitleInst.TextTransparency = 1
	subtitleInst.Parent = gui
	subtitleLabel = subtitleInst

	-- Title fade in (0.4s), hold, fade out at end.
	local fadeIn = TweenInfo.new(0.4, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	TweenService:Create(titleInst, fadeIn, { TextTransparency = 0 }):Play()
	task.delay(0.5, function()
		if subtitleInst.Parent then
			TweenService:Create(subtitleInst, fadeIn, { TextTransparency = 0 }):Play()
		end
	end)
	-- Fade out 0.6s before duration ends.
	task.delay(math.max(0, duration - 0.6), function()
		local fadeOut = TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
		if titleInst.Parent then
			TweenService:Create(titleInst, fadeOut, { TextTransparency = 1 }):Play()
		end
		if subtitleInst.Parent then
			TweenService:Create(subtitleInst, fadeOut, { TextTransparency = 1 }):Play()
		end
	end)
end

-- ---------- Multi-stage cinematic ----------

local function runCinematic(state: State)
	local total = state.cinematicSeconds or 5.0
	local camera = Workspace.CurrentCamera
	if not camera then
		ackCinematicStep()
		return
	end
	cinematicCameraSubject = camera
	camera.CameraType = Enum.CameraType.Scriptable

	local character = Players.LocalPlayer.Character
	local targetPosition = if character and character:FindFirstChild("HumanoidRootPart")
		then (character:FindFirstChild("HumanoidRootPart") :: BasePart).Position
		else Vector3.zero

	-- 3 keyframes: wide overhead → orbit → gameplay angle pull-back.
	-- Stage 1 = 40% of total, Stage 2 = 30%; the last 30% is the
	-- camera hold on the final gameplay angle so the title card has
	-- time to fade out before control returns.
	local d1 = total * 0.40
	local d2 = total * 0.30

	-- Stage 1: wide overhead establishing shot.
	local cf1 = CFrame.new(targetPosition + Vector3.new(0, 180, -10), targetPosition)
	-- Stage 2: orbit-around drop point (rotated 70°, closer in).
	local rot = CFrame.fromEulerAnglesYXZ(0, math.rad(70), 0)
	local orbitOffset = (rot * CFrame.new(0, 0, -90)).Position + Vector3.new(0, 60, 0)
	local cf2 = CFrame.new(targetPosition + orbitOffset, targetPosition)
	-- Stage 3: gameplay angle pull-back (matches the standard camera framing).
	local cf3 = CFrame.new(targetPosition + Vector3.new(0, 30, -25), targetPosition)

	camera.CFrame = cf1

	-- Title card lives over the entire cinematic.
	showTitleCard("OUTPOST-7", "// Sector 14-J", total)

	-- Audio sting fires at the start.
	playLocalCue("ftue_intro_sting")

	-- Show skip button.
	showSkipButton()

	local easing = TweenInfo.new(d1, Enum.EasingStyle.Quart, Enum.EasingDirection.Out)
	local t1 = TweenService:Create(camera, easing, { CFrame = cf2 })
	t1:Play()
	task.delay(d1, function()
		if cinematicCameraSubject ~= camera then
			return
		end
		local e2 = TweenInfo.new(d2, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut)
		TweenService:Create(camera, e2, { CFrame = cf3 }):Play()
	end)

	task.delay(total, function()
		if cinematicCameraSubject == camera then
			ackCinematicStep()
		end
	end)
end

-- ---------- Rotating ring beacon ----------

local function buildBeaconAtNode(nodePart: BasePart): Folder
	local folder = Instance.new("Folder")
	folder.Name = "FTUEBeacon"

	-- Center anchor part (invisible, used as rotation pivot).
	local pivot = Instance.new("Part")
	pivot.Name = "Pivot"
	pivot.Anchored = true
	pivot.CanCollide = false
	pivot.CastShadow = false
	pivot.Transparency = 1
	pivot.Size = Vector3.new(1, 1, 1)
	pivot.CFrame = CFrame.new(nodePart.Position + Vector3.new(0, 4, 0))
	pivot.Parent = folder

	-- Build 12 wedges arranged in a circle of radius 4 studs.
	local SEGMENTS = 12
	local RADIUS = 4
	local accentColor = Theme.GetActive().accent
	for i = 1, SEGMENTS do
		local theta = (i / SEGMENTS) * math.pi * 2
		local segment = Instance.new("Part")
		segment.Name = "Seg_" .. i
		segment.Anchored = true
		segment.CanCollide = false
		segment.CastShadow = false
		segment.Material = Enum.Material.Neon
		segment.Color = accentColor
		segment.Size = Vector3.new(1.6, 0.3, 0.4)
		local offset = Vector3.new(math.cos(theta) * RADIUS, 0, math.sin(theta) * RADIUS)
		segment.CFrame = pivot.CFrame * CFrame.new(offset)
			* CFrame.fromEulerAnglesYXZ(0, -theta + math.pi * 0.5, 0)
		segment.Parent = folder
	end

	-- Pillar from node up to the ring (helps visibility from far away).
	local pillar = Instance.new("Part")
	pillar.Name = "Pillar"
	pillar.Anchored = true
	pillar.CanCollide = false
	pillar.CastShadow = false
	pillar.Material = Enum.Material.Neon
	pillar.Color = accentColor
	pillar.Transparency = 0.4
	pillar.Size = Vector3.new(0.3, 8, 0.3)
	pillar.CFrame = CFrame.new(nodePart.Position + Vector3.new(0, 4, 0))
	pillar.Parent = folder

	folder.Parent = Workspace
	return folder
end

local function startBeaconAnimation()
	if not nodeBeacon then
		return
	end
	local pivot = nodeBeacon:FindFirstChild("Pivot") :: BasePart?
	if not pivot then
		return
	end
	local baseCFrame = pivot.CFrame
	local startTime = os.clock()
	beaconHeartbeat = RunService.Heartbeat:Connect(function()
		if not nodeBeacon or not pivot.Parent then
			return
		end
		local elapsed = os.clock() - startTime
		-- Rotation.
		local rotAngle = (elapsed / BEACON_ROTATION_PERIOD) * math.pi * 2
		-- Update each segment CFrame relative to the pivot's rotation.
		for _, child in nodeBeacon:GetChildren() do
			if not child:IsA("BasePart") then
				continue
			end
			if not string.match(child.Name, "^Seg_") then
				continue
			end
			local idx = tonumber(string.sub(child.Name, 5)) or 0
			local theta = (idx / 12) * math.pi * 2 + rotAngle
			local offset = Vector3.new(math.cos(theta) * 4, 0, math.sin(theta) * 4)
			child.CFrame = baseCFrame * CFrame.new(offset)
				* CFrame.fromEulerAnglesYXZ(0, -theta + math.pi * 0.5, 0)
		end
		-- Pulse: Brightness via Transparency (Neon's intensity proxy).
		local pulsePhase = (elapsed / BEACON_PULSE_PERIOD) % 1.0
		local t = (math.sin(pulsePhase * math.pi * 2) + 1) * 0.5 -- 0..1
		local transparency = 0.7 - 0.5 * t -- 0.2..0.7
		for _, child in nodeBeacon:GetChildren() do
			if child:IsA("BasePart") and string.match(child.Name, "^Seg_") then
				child.Transparency = transparency
			end
		end
	end)
end

local function findNodePart(cellX: number, cellZ: number): BasePart?
	local plotsRoot = Workspace:FindFirstChild("Plots")
	if not plotsRoot then
		return nil
	end
	for _, plot in plotsRoot:GetChildren() do
		local nodes = plot:FindFirstChild("Nodes")
		if not nodes then
			continue
		end
		for _, node in nodes:GetChildren() do
			if not node:IsA("BasePart") then
				continue
			end
			if node:GetAttribute("CellX") == cellX and node:GetAttribute("CellZ") == cellZ then
				return node
			end
		end
	end
	return nil
end

local function showNodeBeacon(cellX: number, cellZ: number)
	if nodeBeacon then
		return
	end
	local nodePart = findNodePart(cellX, cellZ)
	if not nodePart then
		return
	end
	nodeBeacon = buildBeaconAtNode(nodePart)
	startBeaconAnimation()
end

-- ---------- HUD pointer arrow ----------

local function findActionBarShopButton(): GuiObject?
	local pg = Players.LocalPlayer:FindFirstChild("PlayerGui")
	if not pg then
		return nil
	end
	local actionBar = pg:FindFirstChild("ActionBar")
	if not actionBar then
		return nil
	end
	local bar = actionBar:FindFirstChild("Bar")
	if not bar then
		return nil
	end
	local shop = bar:FindFirstChild("Shop")
	return if shop and shop:IsA("GuiObject") then shop else nil
end

local function findCreditsPill(): GuiObject?
	local pg = Players.LocalPlayer:FindFirstChild("PlayerGui")
	if not pg then
		return nil
	end
	local hud = pg:FindFirstChild("CreditsHud")
	if not hud then
		return nil
	end
	local pill = hud:FindFirstChild("CreditsPill")
	return if pill and pill:IsA("GuiObject") then pill else nil
end

-- Show an animated arrow pointing AT a target on-screen GuiObject. The
-- arrow lives in the FTUE ScreenGui (DisplayOrder 60, above HUD). It
-- updates each Heartbeat to track the target's AbsolutePosition + a
-- bobbing motion. The arrow points toward the target from a fixed
-- offset (8 studs away in the direction of screen-center, so it sits
-- between the player's eye and the target).
local function showPointerArrow(getTarget: () -> GuiObject?)
	clearPointerArrow()
	local gui = ensureScreenGui()
	local arrow = Components.StrokedFrame({
		parent = gui,
		name = "PointerArrow",
		size = UDim2.fromOffset(48, 48),
		anchorPoint = Vector2.new(0.5, 0.5),
		bgSlot = "highlight",
		strokeSlot = "highlight",
		cornerAccent = false,
	})
	arrow.Rotation = 45 -- diamond — visually distinct from a square

	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromScale(1, 1)
	label.Font = Enum.Font.GothamBlack
	label.TextScaled = true
	label.Text = "!"
	label.Rotation = -45
	label.TextColor3 = Theme.GetActive().background
	label.Parent = arrow

	pointerArrow = arrow

	local startTime = os.clock()
	pointerHeartbeat = RunService.Heartbeat:Connect(function()
		if not arrow.Parent then
			return
		end
		local target = getTarget()
		if not target then
			arrow.Visible = false
			return
		end
		arrow.Visible = true
		local abs = target.AbsolutePosition
		local size = target.AbsoluteSize
		local cx = abs.X + size.X * 0.5
		local cy = abs.Y + size.Y * 0.5

		-- Determine which side to anchor the arrow on. We want it
		-- ADJACENT to the target, not overlapping. Use the target's
		-- proximity to the screen edges to decide:
		-- - if target is in the top half → arrow sits BELOW it (cy + size/2 + 32)
		-- - else → arrow sits ABOVE it (cy - size/2 - 32)
		local camera = Workspace.CurrentCamera
		local screenH = if camera then camera.ViewportSize.Y else 720
		local arrowX = cx
		local arrowY: number
		if cy < screenH * 0.5 then
			arrowY = cy + size.Y * 0.5 + 32
		else
			arrowY = cy - size.Y * 0.5 - 32
		end

		-- Bob motion (±4px over 1s).
		local bob = math.sin((os.clock() - startTime) * math.pi * 2) * 4
		arrow.Position = UDim2.fromOffset(arrowX, arrowY + bob)
	end)
end

-- ---------- Step-advance audio ----------

local function fireStepAdvanceIfChanged(newStep: string)
	if lastSeenStep ~= nil and lastSeenStep ~= newStep then
		playLocalCue("ftue_step_advance")
	end
	lastSeenStep = newStep
end

-- ---------- Top-level state handler ----------

function FTUEController.Init()
	local stateRemote = Remotes.FTUEState :: RemoteEvent
	stateRemote.OnClientEvent:Connect(function(state: any)
		if state == nil then
			clearAll()
			lastSeenStep = nil
			return
		end
		if typeof(state) ~= "table" then
			return
		end
		local s = state :: State

		fireStepAdvanceIfChanged(s.step)

		showHintBanner(s.hint)

		if s.step == CINEMATIC_STEP then
			runCinematic(s)
			-- Cinematic doesn't need pointers/beacons.
			clearBeacon()
			clearPointerArrow()
		else
			-- Leaving cinematic — drop the camera + skip button.
			clearSkipButton()
			clearTitleCards()
			clearCinematicCamera()

			if s.step == SCOUT_STEP then
				clearPointerArrow()
				if s.targetCellX and s.targetCellZ then
					showNodeBeacon(s.targetCellX, s.targetCellZ)
				end
			elseif s.step == PLACE_EXTRACTOR_STEP then
				clearBeacon()
				showPointerArrow(findActionBarShopButton)
			elseif s.step == FIRST_CREDITS_STEP then
				clearBeacon()
				showPointerArrow(findCreditsPill)
			else
				clearBeacon()
				clearPointerArrow()
			end
		end
	end)
end

return FTUEController
