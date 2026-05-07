--!strict
--[[
	Outpost-7 — FTUE client overlay + cinematic.

	Phase F4. Server pushes `FTUEState` per current step; this
	module renders the client-side response:
	  - cinematic step: takes Camera control via a brief TweenService
	    pull-back (5s); shows intro text overlay; sends FTUEStepAck on
	    timer or "Skip" tap
	  - scout step: shows hint banner + a beacon highlight on the
	    target node (via Workspace lookup of the cell coordinates)
	  - place_extractor step: hint banner pointing at the build palette
	  - first_credits step: hint banner pointing at the credits HUD

	V1 visuals are placeholder per the build protocol Phase F escalation
	("FTUE is taste-critical — needs human input"). Phase G replaces:
	  - real camera framing for the drop-pod descent shot
	  - ambient SFX + voice-over intro
	  - operator landing animation
	  - localized + writer-polished overlay copy
	  - tactile beacon VFX on the highlighted node

	Public API:
	  Init  — wires Remote listener + builds overlay scaffolding
--]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Remotes = require(Shared:WaitForChild("Remotes"))

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

local screenGui: ScreenGui? = nil
local hintLabel: TextLabel? = nil
local skipButton: TextButton? = nil
local nodeBeacon: BasePart? = nil
local cinematicConnection: RBXScriptConnection? = nil
local cinematicCameraSubject: Camera? = nil

local function ensureScreenGui(): ScreenGui
	if screenGui then
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
	gui.DisplayOrder = 50 -- above HUD
	gui.Parent = pg
	screenGui = gui
	return gui
end

local function clearOverlay()
	if hintLabel then
		hintLabel:Destroy()
		hintLabel = nil
	end
	if skipButton then
		skipButton:Destroy()
		skipButton = nil
	end
	if nodeBeacon then
		nodeBeacon:Destroy()
		nodeBeacon = nil
	end
	if cinematicConnection then
		cinematicConnection:Disconnect()
		cinematicConnection = nil
	end
	-- Restore default camera if we held control during cinematic.
	if cinematicCameraSubject then
		cinematicCameraSubject.CameraType = Enum.CameraType.Custom
		cinematicCameraSubject = nil
	end
end

local function showHintBanner(text: string)
	local gui = ensureScreenGui()
	if hintLabel then
		hintLabel.Text = text
		return
	end
	local label = Instance.new("TextLabel")
	label.Name = "HintBanner"
	label.Size = UDim2.fromOffset(520, 56)
	label.Position = UDim2.new(0.5, -260, 0, 56)
	label.BackgroundColor3 = Color3.fromRGB(20, 20, 28)
	label.BackgroundTransparency = 0.1
	label.BorderSizePixel = 0
	label.TextColor3 = Color3.fromRGB(220, 240, 255)
	label.TextScaled = true
	label.Font = Enum.Font.GothamBold
	label.Text = text

	local stroke = Instance.new("UIStroke")
	stroke.Thickness = 2
	stroke.Color = Color3.fromRGB(120, 220, 255)
	stroke.Parent = label

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 8)
	corner.Parent = label

	local pad = Instance.new("UIPadding")
	pad.PaddingLeft = UDim.new(0, 16)
	pad.PaddingRight = UDim.new(0, 16)
	pad.Parent = label

	label.Parent = gui
	hintLabel = label
end

local function ackCinematicStep()
	local remote = Remotes.FTUEStepAck :: RemoteFunction
	pcall(function()
		remote:InvokeServer(CINEMATIC_STEP)
	end)
end

local function showSkipButton()
	local gui = ensureScreenGui()
	if skipButton then
		return
	end
	local btn = Instance.new("TextButton")
	btn.Name = "SkipButton"
	btn.Size = UDim2.fromOffset(96, 32)
	btn.Position = UDim2.new(1, -112, 1, -48)
	btn.BackgroundColor3 = Color3.fromRGB(30, 30, 42)
	btn.BorderSizePixel = 0
	btn.TextColor3 = Color3.fromRGB(220, 220, 235)
	btn.Font = Enum.Font.GothamBold
	btn.TextSize = 14
	btn.Text = "Skip"

	local stroke = Instance.new("UIStroke")
	stroke.Thickness = 1
	stroke.Color = Color3.fromRGB(120, 220, 255)
	stroke.Parent = btn

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 6)
	corner.Parent = btn

	btn.Parent = gui

	btn.MouseButton1Click:Connect(ackCinematicStep)
	skipButton = btn
end

-- Phase G replaces with proper drop-pod descent + operator landing
-- animation. F4 V1: a brief camera pull-back so the player sees a
-- wide angle of their plot before the standard Roblox character cam
-- takes over.
local function runCinematic(state: State)
	local seconds = state.cinematicSeconds or 5
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
	-- Pull back + up; angle slightly down toward the player.
	local startCFrame = CFrame.new(targetPosition + Vector3.new(0, 80, -60), targetPosition)
	local endCFrame = CFrame.new(targetPosition + Vector3.new(0, 30, -25), targetPosition)
	camera.CFrame = startCFrame

	local tween = TweenService:Create(
		camera,
		TweenInfo.new(seconds, Enum.EasingStyle.Quart, Enum.EasingDirection.Out),
		{ CFrame = endCFrame }
	)
	tween:Play()

	-- Auto-advance after the cinematic duration; user can also Skip
	-- via the button (renders during cinematic).
	showSkipButton()
	task.delay(seconds, function()
		if cinematicCameraSubject == camera then
			ackCinematicStep()
		end
	end)
end

-- Lookup the highlighted node's Part and spawn a tall pillar beacon
-- above it. Phase G replaces with a proper VFX (rotating glyph,
-- emissive pulse, audio cue).
local function showNodeBeacon(cellX: number, cellZ: number)
	if nodeBeacon then
		return
	end
	-- Find the player's plot folder and walk Nodes for the matching cell.
	local plotsRoot = Workspace:FindFirstChild("Plots")
	if not plotsRoot then
		return
	end
	local nodePart: BasePart? = nil
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
				nodePart = node
				break
			end
		end
		if nodePart then
			break
		end
	end
	if not nodePart then
		return
	end

	local beacon = Instance.new("Part")
	beacon.Name = "FTUEBeacon"
	beacon.Anchored = true
	beacon.CanCollide = false
	beacon.CastShadow = false
	beacon.Material = Enum.Material.Neon
	beacon.Color = Color3.fromRGB(120, 240, 255)
	beacon.Size = Vector3.new(0.6, 30, 0.6)
	beacon.CFrame = CFrame.new(nodePart.Position + Vector3.new(0, 15, 0))
	beacon.Parent = Workspace
	nodeBeacon = beacon
end

function FTUEController.Init()
	local stateRemote = Remotes.FTUEState :: RemoteEvent
	stateRemote.OnClientEvent:Connect(function(state: any)
		if state == nil then
			clearOverlay()
			return
		end
		if typeof(state) ~= "table" then
			return
		end
		local s = state :: State
		showHintBanner(s.hint)
		if s.step == CINEMATIC_STEP then
			runCinematic(s)
		else
			-- Non-cinematic step — clear the cinematic-only artifacts
			-- but keep the hint banner.
			if skipButton then
				skipButton:Destroy()
				skipButton = nil
			end
			if cinematicCameraSubject then
				cinematicCameraSubject.CameraType = Enum.CameraType.Custom
				cinematicCameraSubject = nil
			end
			if s.step == SCOUT_STEP and s.targetCellX and s.targetCellZ then
				showNodeBeacon(s.targetCellX, s.targetCellZ)
			elseif nodeBeacon then
				nodeBeacon:Destroy()
				nodeBeacon = nil
			end
		end
	end)
end

return FTUEController
