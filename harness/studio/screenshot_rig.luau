--!strict
--[[
	Outpost-7 design harness — camera rig for audit screenshots.

	Run via Studio MCP `run_code` AFTER audit_element.luau has placed the
	element on Workspace.HarnessAudit. Sets Workspace.CurrentCamera to one of
	three standard framings; the Studio Operator then captures the 3D
	viewport with computer use. Run once per ANGLE:

	  "front34"   — 3/4 front view filling the frame (silhouette + materials)
	  "side"      — orthographic-ish side profile
	  "context20" — the element seen from 20 studs away at player eye height,
	                with the jungle biome lighting applied (how it reads in play)

	Never saves the place. Lighting changes are applied through the game's own
	BiomeLightingService so the screenshot matches what the server would show.
--]]

local Workspace = game:GetService("Workspace")
local ServerScriptService = game:GetService("ServerScriptService")

-- ====== SET BEFORE RUNNING ======
local ANGLE: string = "front34" -- "front34" | "side" | "context20"
local BIOME: string = "jungle" -- "jungle" | "volcanic" | "ice"
local ELEMENT_NAME: string? = nil -- nil = first Model under the audit pad
-- =================================

local pad = Workspace:FindFirstChild("HarnessAudit")
if not pad then
	error("HarnessAudit pad not found — run audit_element.luau first")
end

local target: Model? = nil
if ELEMENT_NAME then
	target = pad:FindFirstChild(ELEMENT_NAME) :: Model?
else
	for _, child in pad:GetChildren() do
		if child:IsA("Model") then
			target = child
			break
		end
	end
end
if not target then
	error("no element Model under HarnessAudit")
end
local model = target :: Model

local cf, size = model:GetBoundingBox()
local center = cf.Position
local radius = math.max(size.X, size.Y, size.Z)

local camera = Workspace.CurrentCamera
camera.CameraType = Enum.CameraType.Scriptable
camera.FieldOfView = 50

local function applyBiomeLighting()
	local ok, err = pcall(function()
		local server = ServerScriptService:WaitForChild("Server", 5)
		local modules = server:WaitForChild("Modules", 5)
		local world = modules:WaitForChild("World", 5)
		local BiomeLightingService = require(world:WaitForChild("BiomeLightingService", 5)) :: any
		BiomeLightingService.Apply(BIOME)
	end)
	if not ok then
		warn("[screenshot_rig] biome lighting not applied: " .. tostring(err))
	end
end

if ANGLE == "front34" then
	local eye = center + Vector3.new(radius * 1.2, radius * 0.9, -radius * 1.6)
	camera.CFrame = CFrame.lookAt(eye, center)
elseif ANGLE == "side" then
	local eye = center + Vector3.new(radius * 2.2, size.Y * 0.35, 0)
	camera.CFrame = CFrame.lookAt(eye, center)
	camera.FieldOfView = 30
elseif ANGLE == "context20" then
	applyBiomeLighting()
	local eye = center + Vector3.new(6, 4.5 - size.Y / 2, -20) -- player eye height, 20 studs out
	camera.CFrame = CFrame.lookAt(eye, center)
	camera.FieldOfView = 70
else
	error("unknown ANGLE " .. ANGLE)
end

print(string.format("[screenshot_rig] %s framed for '%s' (%s); radius %.1f", model.Name, ANGLE, BIOME, radius))
