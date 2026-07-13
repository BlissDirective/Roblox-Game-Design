--!strict
--[[
	Outpost-7 — resource node distribution.

	Phase B1. For each plot, scatters resource nodes via Poisson disk
	sampling so the layout *feels* designed instead of random. Nodes
	are visualized as small emissive Parts under
	`Workspace.Plots.PlotN.Nodes`. Their `cellX,cellZ` snap-coordinates
	are stored in attributes so PlacementService can look them up
	without redoing the math.

	The seed is derived from `game.JobId` + plot id, so:
	  - all players on the same server see the same node layout
	  - re-rolls during dev (stop, F5 again → new JobId) get a fresh
	    layout, useful for testing edge cases
	  - persistent runs (live servers) stay consistent for the lifetime
	    of the server

	Public API:
	  Init() — wait for PlotManager, spawn nodes for each plot
--]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Constants = require(Shared:WaitForChild("Constants"))
local PoissonDisk = require(Shared:WaitForChild("Modules"):WaitForChild("Math"):WaitForChild("PoissonDisk"))
local GridMath = require(Shared:WaitForChild("Modules"):WaitForChild("Math"):WaitForChild("GridMath"))

local PlotManager = require(script.Parent.PlotManager)

local ResourceNodeSpawner = {}

local NODE_TINT = Color3.fromRGB(120, 220, 180) -- bioluminescent jungle hint

local function seedForPlot(plotId: number): number
	-- string.byte sums give a stable hash without pulling in HashLib.
	-- Multiply plotId by a prime so adjacent plots diverge meaningfully.
	local jobId = game.JobId
	if jobId == "" then
		-- Studio sessions have empty JobId; use os.time so consecutive
		-- F5 runs get distinct seeds.
		return os.time() * 73 + plotId * 31
	end
	local sum = 0
	for i = 1, #jobId do
		sum += string.byte(jobId, i)
	end
	return sum * 73 + plotId * 31
end

local function buildNodePart(parent: Folder, worldPos: Vector3, cellX: number, cellZ: number): BasePart
	local part = Instance.new("Part")
	part.Name = "Node_" .. GridMath.CellKey(cellX, cellZ)
	part.Anchored = true
	part.CanCollide = false
	part.Shape = Enum.PartType.Ball
	part.Size = Vector3.new(Constants.NODES.Radius * 2, Constants.NODES.Radius * 2, Constants.NODES.Radius * 2)
	part.Position = worldPos + Vector3.new(0, Constants.NODES.HeightOffset, 0)
	part.Material = Enum.Material.Neon
	part.Color = NODE_TINT
	part:SetAttribute("CellX", cellX)
	part:SetAttribute("CellZ", cellZ)
	part:SetAttribute("Claimed", false)
	part.Parent = parent
	return part
end

local function spawnForPlot(plot: PlotManager.PlotInfo)
	local seed = seedForPlot(plot.id)
	local sampleAreaSize = plot.size - 2 * Constants.NODES.EdgeMargin

	-- Sample in plot-local coords, translate to world coords.
	local samples = PoissonDisk.Sample(
		sampleAreaSize,
		sampleAreaSize,
		Constants.NODES.MinDistance,
		seed,
		Constants.NODES.MaxAttemptsPerCell
	)

	local cellSize = Constants.GRID.Size
	local seenCells: { [string]: boolean } = {}

	for _, localPoint in samples do
		-- Translate plot-local (0..size) → world.
		local worldX = plot.center.X - plot.size / 2 + Constants.NODES.EdgeMargin + localPoint.X
		local worldZ = plot.center.Z - plot.size / 2 + Constants.NODES.EdgeMargin + localPoint.Y

		-- Snap to the grid PlacementService uses, so a node-cell maps
		-- 1:1 to a placement-cell. Two nodes can't share a snapped cell.
		local cellX, cellZ = GridMath.SnapToCell(worldX, worldZ, cellSize)
		local key = GridMath.CellKey(cellX, cellZ)
		if seenCells[key] then
			continue
		end
		seenCells[key] = true

		local snappedWorld = GridMath.CellToWorld(cellX, cellZ, cellSize, plot.center.Y)
		buildNodePart(plot.nodes, snappedWorld, cellX, cellZ)

		-- PerPlotTarget is a target, not a hard cap — but we honor it
		-- to keep the world readable on mobile.
		if #plot.nodes:GetChildren() >= Constants.NODES.PerPlotTarget then
			break
		end
	end

	print(string.format("[ResourceNodeSpawner] Plot%d: %d nodes (seed=%d)", plot.id, #plot.nodes:GetChildren(), seed))
end

function ResourceNodeSpawner.Init()
	for _, plot in PlotManager.GetAllPlots() do
		spawnForPlot(plot)
	end
end

return ResourceNodeSpawner
