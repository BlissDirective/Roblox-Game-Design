--!strict
--[[
	Outpost-7 — snap-to-grid ghost preview for build mode.

	Phase B4. While a buildable is selected in BuildPalette, a
	semi-transparent "ghost" Part follows the player's cursor (mouse
	position on desktop, last-touch on mobile). The ghost snaps to
	the same grid the server uses (Constants.GRID.Size) so the
	preview lines up exactly with where the placement will land.

	Validation here is *advisory* — we tint the ghost red when the
	cell would be rejected (out of plot, occupied, no node for an
	extractor). The server still does its own authoritative check
	on PlaceBuilding receipt; this is only to avoid wasted Remote
	traffic on obviously-bad placements and to give the player
	immediate feedback.
--]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Constants = require(Shared:WaitForChild("Constants"))
local GridMath = require(Shared:WaitForChild("Modules"):WaitForChild("Math"):WaitForChild("GridMath"))
local BuildableRegistry =
	require(Shared:WaitForChild("Modules"):WaitForChild("Registry"):WaitForChild("BuildableRegistry"))

type Buildable = BuildableRegistry.Buildable

local PlacementPreview = {}

local OK_COLOR = Color3.fromRGB(120, 220, 180)
local BAD_COLOR = Color3.fromRGB(220, 100, 100)

local previewPart: Part? = nil
local heartbeatConn: RBXScriptConnection? = nil
local activeBuildable: Buildable? = nil
-- Last advisory cell decision so BuildController can read it on tap
-- without re-running the raycast. Cleared when preview hides.
local lastSnap: { x: number, z: number, valid: boolean }? = nil

local function getPlayerPlot(): Folder?
	local player = Players.LocalPlayer
	local plotId = player:GetAttribute("PlotId")
	if typeof(plotId) ~= "number" then
		return nil
	end
	local plotsRoot = Workspace:FindFirstChild("Plots")
	if not plotsRoot then
		return nil
	end
	local plotFolder = plotsRoot:FindFirstChild("Plot" .. plotId)
	return plotFolder :: Folder?
end

local function plotCenterFromFolder(plotFolder: Folder): Vector3?
	local floor = plotFolder:FindFirstChild("Floor") :: BasePart?
	if not floor then
		return nil
	end
	-- Floor is positioned at center.Y - thickness/2. Reverse to get
	-- the plot's logical baseY (the surface the buildables sit on).
	return floor.Position + Vector3.new(0, Constants.WORLD.PlotFloorThickness / 2, 0)
end

local function findNodeAtCell(plotFolder: Folder, cellX: number, cellZ: number): BasePart?
	local nodes = plotFolder:FindFirstChild("Nodes") :: Folder?
	if not nodes then
		return nil
	end
	for _, node in nodes:GetChildren() do
		if not node:IsA("BasePart") then
			continue
		end
		if node:GetAttribute("CellX") == cellX and node:GetAttribute("CellZ") == cellZ then
			return node
		end
	end
	return nil
end

local function isCellOccupied(plotFolder: Folder, worldPos: Vector3, buildable: Buildable): boolean
	local buildings = plotFolder:FindFirstChild("Buildings") :: Folder?
	if not buildings then
		return false
	end
	for _, child in buildings:GetChildren() do
		if not child:IsA("BasePart") then
			continue
		end
		-- Coarse collision: same XZ within a half-cell tolerance.
		local dx = math.abs(child.Position.X - worldPos.X)
		local dz = math.abs(child.Position.Z - worldPos.Z)
		if dx < Constants.GRID.Size / 2 and dz < Constants.GRID.Size / 2 then
			return true
		end
	end
	-- Suppress unused-parameter warning until we wire shape-aware checks.
	local _ = buildable
	return false
end

local function ensurePart(buildable: Buildable)
	if not previewPart then
		previewPart = Instance.new("Part")
		previewPart.Anchored = true
		previewPart.CanCollide = false
		previewPart.CanQuery = false
		previewPart.CanTouch = false
		previewPart.Material = Enum.Material.ForceField
		previewPart.Color = OK_COLOR
		previewPart.Transparency = 0.45
		previewPart.Parent = Workspace
	end
	previewPart.Size = buildable.size
	previewPart.Color = OK_COLOR
end

local function clear()
	if heartbeatConn then
		heartbeatConn:Disconnect()
		heartbeatConn = nil
	end
	if previewPart then
		previewPart:Destroy()
		previewPart = nil
	end
	activeBuildable = nil
	lastSnap = nil
end

local function getCursorWorldHit(): Vector3?
	local camera = Workspace.CurrentCamera
	if not camera then
		return nil
	end
	local cursor = UserInputService:GetMouseLocation()
	local ray = camera:ViewportPointToRay(cursor.X, cursor.Y)

	local rayParams = RaycastParams.new()
	rayParams.FilterType = Enum.RaycastFilterType.Exclude
	local exclusions: { Instance } = {}
	local character = Players.LocalPlayer.Character
	if character then
		table.insert(exclusions, character)
	end
	if previewPart then
		table.insert(exclusions, previewPart)
	end
	rayParams.FilterDescendantsInstances = exclusions

	local result = Workspace:Raycast(ray.Origin, ray.Direction * 1000, rayParams)
	return if result then result.Position else nil
end

local function tick()
	if not previewPart or not activeBuildable then
		return
	end

	local hit = getCursorWorldHit()
	if not hit then
		previewPart.Transparency = 1
		lastSnap = nil
		return
	end

	local cellX, cellZ = GridMath.SnapToCell(hit.X, hit.Z, Constants.GRID.Size)
	local plotFolder = getPlayerPlot()
	if not plotFolder then
		previewPart.Transparency = 1
		lastSnap = nil
		return
	end
	local plotCenter = plotCenterFromFolder(plotFolder)
	if not plotCenter then
		previewPart.Transparency = 1
		lastSnap = nil
		return
	end

	local snapped = GridMath.CellToWorld(cellX, cellZ, Constants.GRID.Size, plotCenter.Y)
	previewPart.Position = snapped + Vector3.new(0, activeBuildable.size.Y / 2, 0)
	previewPart.Transparency = 0.45

	-- Advisory validation
	local valid = true
	if not GridMath.IsInsidePlot(snapped.X, snapped.Z, plotCenter, Constants.WORLD.PlotSize) then
		valid = false
	elseif isCellOccupied(plotFolder, snapped, activeBuildable) then
		valid = false
	elseif activeBuildable.requiresNode then
		local node = findNodeAtCell(plotFolder, cellX, cellZ)
		if not node or node:GetAttribute("Claimed") then
			valid = false
		end
	end
	previewPart.Color = if valid then OK_COLOR else BAD_COLOR

	lastSnap = { x = cellX, z = cellZ, valid = valid }
end

function PlacementPreview.Show(buildableId: string)
	clear()
	local buildable = BuildableRegistry.Get(buildableId)
	if not buildable then
		return
	end
	activeBuildable = buildable
	ensurePart(buildable)
	heartbeatConn = RunService.Heartbeat:Connect(tick)
end

function PlacementPreview.Hide()
	clear()
end

-- Returns the snapped cell currently under the cursor, or nil if no
-- valid hit. The `valid` flag is the advisory client-side check; the
-- server will revalidate on PlaceBuilding receipt.
function PlacementPreview.GetSnap(): { x: number, z: number, valid: boolean }?
	return lastSnap
end

return PlacementPreview
