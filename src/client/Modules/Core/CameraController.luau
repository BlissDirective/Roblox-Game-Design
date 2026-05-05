--!strict
--[[
	Outpost-7 — TP↔FP camera transition.

	Phase B5. Subscribes to ModeController. On mode change, switches
	`CameraType` to Scriptable, tweens `Camera.CFrame` to the target
	view (TP for Build, FP for Combat/Raid) over ~0.3s, then hands
	control back to Roblox by setting CameraMode + CameraType =
	Custom.

	**This is the prototype the brainstorm flags as a go/no-go gate**
	(`finalized-brainstorm.md` §3.4 risk #2). Audit it: press M to
	toggle, watch the swap. If it feels jittery, nauseous, or the
	tween goes through the character mesh, file findings and we
	either:
	  (a) tune (longer tween, different easing, reposition camera
	      origin during transition)
	  (b) fall back to TP-only with FP zoom for combat (Soft V1)

	Server Authority Beta context (ADR-005): with
	`PlayerScriptsUseInput` enabled, our LocalScripts read input
	normally via UserInputService — no behavior change here from the
	manual pattern. Camera CFrame is purely client-side; server
	doesn't replicate it.
--]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Enums = require(Shared:WaitForChild("Enums"))

local ModeController = require(script.Parent.ModeController)

local CameraController = {}

local TRANSITION_SECONDS = 0.3
local TP_BACK_OFFSET = Vector3.new(0, 6, 16) -- studs behind+above HRP, looking at center
local FP_HEAD_OFFSET = Vector3.new(0, 1.5, 0) -- approx head pos relative to HRP

local activeTween: Tween? = nil

local function getCharacterParts(): (Model?, BasePart?)
	local player = Players.LocalPlayer
	local character = player.Character
	if not character then
		return nil, nil
	end
	local hrp = character:FindFirstChild("HumanoidRootPart")
	if hrp and hrp:IsA("BasePart") then
		return character, hrp
	end
	return character, nil
end

local function targetCFrame(mode: string): CFrame?
	local _, hrp = getCharacterParts()
	if not hrp then
		return nil
	end
	if mode == Enums.Mode.Build then
		-- TP target: pull back+above the HRP, look at center.
		local backOffset = hrp.CFrame:VectorToWorldSpace(TP_BACK_OFFSET)
		return CFrame.lookAt(hrp.Position + backOffset, hrp.Position)
	end
	-- Combat / Raid: first-person at head, looking forward along HRP.
	local headPos = hrp.Position + FP_HEAD_OFFSET
	local lookAt = headPos + hrp.CFrame.LookVector
	return CFrame.lookAt(headPos, lookAt)
end

local function applyFinalCameraSettings(mode: string)
	local player = Players.LocalPlayer
	local camera = Workspace.CurrentCamera
	if not camera then
		return
	end
	if mode == Enums.Mode.Build then
		player.CameraMode = Enum.CameraMode.Classic
		player.CameraMinZoomDistance = 8
		player.CameraMaxZoomDistance = 32
	else
		player.CameraMode = Enum.CameraMode.LockFirstPerson
	end
	camera.CameraType = Enum.CameraType.Custom
end

local function transition(mode: string)
	local camera = Workspace.CurrentCamera
	if not camera then
		return
	end
	local target = targetCFrame(mode)
	if not target then
		-- Character not yet loaded. Apply final settings anyway so the
		-- mode "takes" — Roblox will snap into place once the character
		-- spawns.
		applyFinalCameraSettings(mode)
		return
	end

	-- Cancel any tween in flight; rapid mode toggles otherwise stack.
	if activeTween then
		activeTween:Cancel()
		activeTween = nil
	end

	camera.CameraType = Enum.CameraType.Scriptable
	local tween = TweenService:Create(
		camera,
		TweenInfo.new(TRANSITION_SECONDS, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{ CFrame = target }
	)
	activeTween = tween

	tween.Completed:Connect(function()
		if activeTween == tween then
			activeTween = nil
			applyFinalCameraSettings(mode)
		end
	end)
	tween:Play()
end

function CameraController.Init()
	local player = Players.LocalPlayer

	-- Apply the initial mode (no tween — initial state).
	applyFinalCameraSettings(ModeController.GetMode())

	ModeController.OnModeChanged(function(newMode: string, _oldMode: string)
		transition(newMode)
	end)

	-- On respawn, the character changes (HRP swaps), and Roblox may
	-- reset CameraMode to Classic. Re-apply our mode after a brief
	-- settle so the camera doesn't snap from FP→TP→FP.
	player.CharacterAdded:Connect(function()
		task.wait(0.5)
		applyFinalCameraSettings(ModeController.GetMode())
	end)
end

return CameraController
