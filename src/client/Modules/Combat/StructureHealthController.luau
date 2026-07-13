--!strict
--[[
	Outpost-7 — structure damage-state visuals + repair input (client).

	Phase R1b. The client half of Fortify. Server (StructureHealthService)
	owns all HP + validation; this controller only renders state and offers
	the repair affordance. Nothing here is trusted — the server re-validates
	every repair request (ownership + reach + affordability).

	Two independent signal sources:

	  1. Damage-state VISUALS are driven off the replicated `CurrentHp`
	     attribute the server mirrors onto each structure Part. Watching the
	     attribute (rather than the Remote) means the tint is always in sync
	     with authoritative HP and needs no per-frame push — a wall smoothly
	     reddens as the swarm chews it, and snaps back on repair, for free.

	  2. Event TOASTS (extractor down / breached / repaired) come off the
	     `StructureHealth` Remote, which fires once per state transition.

	Repair input: a tap/click raycast. If it lands on a damaged structure the
	local player owns, we fire `RepairStructure(cellX, cellZ)`. The server
	restores the structure to full HP in a single call, so one tap = one
	repair — no hold-to-repeat needed.

	Public API:
	  Init()  — bind the local plot, wire visuals + toasts + repair input
--]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Remotes = require(Shared:WaitForChild("Remotes"))
local Theme = require(Shared:WaitForChild("Modules"):WaitForChild("UI"):WaitForChild("Theme"))

local ToastService = require(script.Parent.Parent.HUD.ToastService)

local StructureHealthController = {}

-- Original (undamaged) colors captured the first time we see a structure,
-- so the damage tint always lerps from the true base color back to full.
local originalColor: { [BasePart]: Color3 } = {}

local function dangerColor(): Color3
	return Theme.GetActive().danger
end

-- Repaint a structure toward danger-red as its HP drops; dim it when downed.
local function applyDamageTint(part: BasePart)
	local maxHp = part:GetAttribute("MaxHp")
	local curHp = part:GetAttribute("CurrentHp")
	if typeof(maxHp) ~= "number" or typeof(curHp) ~= "number" or maxHp <= 0 then
		return
	end
	local base = originalColor[part]
	if not base then
		base = part.Color
		originalColor[part] = base
	end
	local ratio = math.clamp(curHp / maxHp, 0, 1)
	part.Color = base:Lerp(dangerColor(), 1 - ratio)
	-- A downed structure (0 HP but still in the world — a disabled
	-- extractor) reads as "offline": dimmed + non-emissive-looking.
	part.Transparency = if curHp <= 0 then 0.35 else 0
end

local function watchStructure(part: BasePart)
	if part:GetAttribute("MaxHp") == nil then
		return -- indestructible / not a tracked structure
	end
	applyDamageTint(part)
	part:GetAttributeChangedSignal("CurrentHp"):Connect(function()
		applyDamageTint(part)
	end)
end

-- Resolve the local player's plot Buildings folder, waiting for plot
-- allocation (the PlotId attribute the server stamps on join).
local function waitForBuildingsFolder(): Folder?
	local player = Players.LocalPlayer
	if typeof(player:GetAttribute("PlotId")) ~= "number" then
		player:GetAttributeChangedSignal("PlotId"):Wait()
	end
	local plotId = player:GetAttribute("PlotId")
	if typeof(plotId) ~= "number" then
		return nil
	end
	local plotsRoot = Workspace:WaitForChild("Plots", 30) :: Folder?
	if not plotsRoot then
		return nil
	end
	local plotFolder = plotsRoot:FindFirstChild("Plot" .. plotId) :: Folder?
	if not plotFolder then
		return nil
	end
	return plotFolder:WaitForChild("Buildings", 30) :: Folder?
end

local function bindVisuals()
	local buildings = waitForBuildingsFolder()
	if not buildings then
		return
	end
	for _, child in buildings:GetChildren() do
		if child:IsA("BasePart") then
			watchStructure(child)
		end
	end
	buildings.ChildAdded:Connect(function(child: Instance)
		if child:IsA("BasePart") then
			-- Attributes replicate a frame or two after the Part; a short
			-- deferral avoids missing MaxHp on the very first read.
			task.defer(watchStructure, child)
		end
	end)
	buildings.ChildRemoved:Connect(function(child: Instance)
		if child:IsA("BasePart") then
			originalColor[child] = nil
		end
	end)
end

local function bindToasts()
	local remote = Remotes.StructureHealth :: RemoteEvent
	remote.OnClientEvent:Connect(function(update: any)
		if typeof(update) ~= "table" then
			return
		end
		local state = update.state
		if state == "disabled" then
			ToastService.ShowError("Extractor down — repair it!")
		elseif state == "destroyed" then
			if update.buildableId == "wall" then
				ToastService.ShowError("Wall breached!")
			elseif update.buildableId == "turret" then
				ToastService.ShowError("Turret destroyed!")
			elseif update.buildableId == "extractor" then
				ToastService.ShowError("Extractor lost!")
			end
		elseif state == "repaired" then
			ToastService.ShowReward("Repaired")
		end
	end)
end

-- Raycast a screen point into the world; return the hit BasePart if any.
local function raycastToPart(screenPos: Vector3): BasePart?
	local camera = Workspace.CurrentCamera
	if not camera then
		return nil
	end
	local ray = camera:ViewportPointToRay(screenPos.X, screenPos.Y)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	local character = Players.LocalPlayer.Character
	if character then
		params.FilterDescendantsInstances = { character }
	end
	local result = Workspace:Raycast(ray.Origin, ray.Direction * 512, params)
	if result and result.Instance and result.Instance:IsA("BasePart") then
		return result.Instance
	end
	return nil
end

local function tryRepairAt(screenPos: Vector3)
	local part = raycastToPart(screenPos)
	if not part then
		return
	end
	-- Only our own damaged structures are repairable from here (server
	-- re-checks ownership regardless).
	if part:GetAttribute("OwnerUserId") ~= Players.LocalPlayer.UserId then
		return
	end
	local maxHp = part:GetAttribute("MaxHp")
	local curHp = part:GetAttribute("CurrentHp")
	if typeof(maxHp) ~= "number" or typeof(curHp) ~= "number" then
		return
	end
	if curHp >= maxHp then
		return -- undamaged; nothing to repair
	end
	local cellX = part:GetAttribute("CellX")
	local cellZ = part:GetAttribute("CellZ")
	if typeof(cellX) ~= "number" or typeof(cellZ) ~= "number" then
		return
	end
	local remote = Remotes.RepairStructure :: RemoteEvent
	remote:FireServer(cellX, cellZ)
end

local function bindRepairInput()
	UserInputService.InputBegan:Connect(function(input: InputObject, processed: boolean)
		if processed then
			return
		end
		if
			input.UserInputType == Enum.UserInputType.MouseButton1
			or input.UserInputType == Enum.UserInputType.Touch
		then
			tryRepairAt(input.Position)
		end
	end)
end

function StructureHealthController.Init()
	-- Visuals bind can yield (waits for plot allocation) — spawn it so Init
	-- stays non-blocking like the rest of the client bootstrap.
	task.spawn(bindVisuals)
	bindToasts()
	bindRepairInput()
end

return StructureHealthController
