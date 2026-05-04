--!strict
--[[
	Outpost-7 — plot allocation and world layout.

	Phase B1. Each server hosts a fixed number of plots
	(`Constants.WORLD.PlotCount`) arranged in a square grid. On player
	join, a free plot is allocated to that player; on leave, the plot
	releases and any in-progress placements wipe (V1 plots are
	per-server-session, not per-player-persistent — persistent base
	state lands in B3 and re-applies on top of an allocated plot).

	Workspace layout produced by Init():

	  Workspace.Plots (Folder)
	    Plot1 (Folder)
	      Floor       (Part — the visible plot baseplate)
	      Nodes       (Folder — populated by ResourceNodeSpawner)
	      Buildings   (Folder — populated by PlacementService)
	    Plot2 ...

	Public API:
	  Init()                        — build the world, connect signals
	  GetPlot(player)               — current plot for player (nil if none)
	  GetPlotById(id)               — lookup by 1-based id
	  GetPlotForWorld(x, z)         — lookup by world XZ (nil if outside any plot)
	  GetAllPlots()                 — readonly list (immutable order)
--]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Constants = require(Shared:WaitForChild("Constants"))
local GridMath = require(Shared:WaitForChild("Modules"):WaitForChild("Math"):WaitForChild("GridMath"))

export type PlotInfo = {
	id: number,
	center: Vector3,
	size: number,
	folder: Folder,
	floor: BasePart,
	nodes: Folder,
	buildings: Folder,
	ownerUserId: number?,
}

local PlotManager = {}

local plots: { PlotInfo } = {}
local playerToPlot: { [Player]: PlotInfo } = {}

local PLOT_TINTS: { Color3 } = {
	Color3.fromRGB(40, 90, 60), -- Plot 1: muted green
	Color3.fromRGB(60, 50, 90), -- Plot 2: muted purple
	Color3.fromRGB(90, 70, 40), -- Plot 3: muted amber
	Color3.fromRGB(40, 80, 100), -- Plot 4: muted teal
}

local function buildFloor(parent: Folder, plotId: number, center: Vector3, size: number): BasePart
	local floor = Instance.new("Part")
	floor.Name = "Floor"
	floor.Anchored = true
	floor.CanCollide = true
	floor.Size = Vector3.new(size, Constants.WORLD.PlotFloorThickness, size)
	floor.Position = Vector3.new(center.X, center.Y - Constants.WORLD.PlotFloorThickness / 2, center.Z)
	floor.Material = Enum.Material.Concrete
	floor.Color = PLOT_TINTS[((plotId - 1) % #PLOT_TINTS) + 1]
	floor.TopSurface = Enum.SurfaceType.Smooth
	floor.BottomSurface = Enum.SurfaceType.Smooth
	floor.Parent = parent
	return floor
end

local function plotCenterFor(plotId: number, plotCount: number): Vector3
	-- Square grid layout. cols = ceil(sqrt(N)) so we get a tight square.
	local cols = math.ceil(math.sqrt(plotCount))
	local row = math.floor((plotId - 1) / cols)
	local col = (plotId - 1) % cols
	local stride = Constants.WORLD.PlotSize + Constants.WORLD.PlotGap
	-- Center the grid on world origin.
	local cx = (col - (cols - 1) / 2) * stride
	local cz = (row - (cols - 1) / 2) * stride
	return Vector3.new(cx, Constants.WORLD.BaseY, cz)
end

local function buildPlot(plotsRoot: Folder, plotId: number): PlotInfo
	local center = plotCenterFor(plotId, Constants.WORLD.PlotCount)

	local folder = Instance.new("Folder")
	folder.Name = "Plot" .. plotId
	folder.Parent = plotsRoot

	local floor = buildFloor(folder, plotId, center, Constants.WORLD.PlotSize)

	local nodes = Instance.new("Folder")
	nodes.Name = "Nodes"
	nodes.Parent = folder

	local buildings = Instance.new("Folder")
	buildings.Name = "Buildings"
	buildings.Parent = folder

	return {
		id = plotId,
		center = center,
		size = Constants.WORLD.PlotSize,
		folder = folder,
		floor = floor,
		nodes = nodes,
		buildings = buildings,
		ownerUserId = nil,
	}
end

local function allocate(player: Player): PlotInfo?
	for _, plot in plots do
		if plot.ownerUserId == nil then
			plot.ownerUserId = player.UserId
			playerToPlot[player] = plot
			print(string.format("[PlotManager] Allocated Plot%d to %s", plot.id, player.Name))
			return plot
		end
	end
	print(
		string.format(
			"[PlotManager] No free plot for %s — server full (%d/%d)",
			player.Name,
			#plots,
			Constants.WORLD.PlotCount
		)
	)
	return nil
end

local function release(player: Player)
	local plot = playerToPlot[player]
	if not plot then
		return
	end
	playerToPlot[player] = nil
	plot.ownerUserId = nil
	-- Wipe any in-progress placements; persistent state lives in DataStore
	-- and re-applies on the next allocation (Phase B3).
	for _, child in plot.buildings:GetChildren() do
		child:Destroy()
	end
	print(string.format("[PlotManager] Released Plot%d from %s", plot.id, player.Name))
end

function PlotManager.GetPlot(player: Player): PlotInfo?
	return playerToPlot[player]
end

function PlotManager.GetPlotById(id: number): PlotInfo?
	return plots[id]
end

function PlotManager.GetPlotForWorld(worldX: number, worldZ: number): PlotInfo?
	for _, plot in plots do
		if GridMath.IsInsidePlot(worldX, worldZ, plot.center, plot.size) then
			return plot
		end
	end
	return nil
end

function PlotManager.GetAllPlots(): { PlotInfo }
	-- Return a shallow copy so callers can't mutate ordering.
	local copy: { PlotInfo } = table.create(#plots)
	for i, plot in plots do
		copy[i] = plot
	end
	return copy
end

function PlotManager.Init()
	local plotsRoot = Workspace:FindFirstChild("Plots")
	if plotsRoot then
		-- Idempotent — Studio script reload during dev would otherwise
		-- duplicate the world. Reuse if shape matches; rebuild if not.
		plotsRoot:Destroy()
	end
	plotsRoot = Instance.new("Folder")
	plotsRoot.Name = "Plots"
	plotsRoot.Parent = Workspace

	for id = 1, Constants.WORLD.PlotCount do
		plots[id] = buildPlot(plotsRoot, id)
	end
	print(
		string.format(
			"[PlotManager] Built %d plots (%dx%d studs each)",
			Constants.WORLD.PlotCount,
			Constants.WORLD.PlotSize,
			Constants.WORLD.PlotSize
		)
	)

	Players.PlayerAdded:Connect(allocate)
	Players.PlayerRemoving:Connect(release)
	for _, player in Players:GetPlayers() do
		task.spawn(allocate, player)
	end
end

return PlotManager
