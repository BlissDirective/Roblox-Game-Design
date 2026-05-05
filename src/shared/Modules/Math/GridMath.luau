--!strict
--[[
	Outpost-7 — grid-snapping helpers for build mode.

	Phase B1. The build palette places objects on a 4-stud grid (per
	Constants.GRID.Size). This module is the single place that math
	lives, so any tweak to grid resolution or snap behavior touches one
	file. Both server (PlacementService) and client (PlacementPreview)
	use the same snapping so client previews match server placements.

	Conventions:
	  - Grid coordinates are integer cell indices (cellX, cellZ).
	  - World coordinates are stud Vector3s on the Y=baseY plane.
	  - The cell with index (0, 0) is centered at world XZ origin.
--]]

local GridMath = {}

function GridMath.SnapToCell(worldX: number, worldZ: number, cellSize: number): (number, number)
	local cellX = math.floor(worldX / cellSize + 0.5)
	local cellZ = math.floor(worldZ / cellSize + 0.5)
	return cellX, cellZ
end

function GridMath.CellToWorld(cellX: number, cellZ: number, cellSize: number, baseY: number): Vector3
	return Vector3.new(cellX * cellSize, baseY, cellZ * cellSize)
end

function GridMath.SnapVector(world: Vector3, cellSize: number, baseY: number): Vector3
	local cellX, cellZ = GridMath.SnapToCell(world.X, world.Z, cellSize)
	return GridMath.CellToWorld(cellX, cellZ, cellSize, baseY)
end

-- Test whether a world XZ falls inside the axis-aligned square plot
-- centered at `plotCenter` with side length `plotSize`.
function GridMath.IsInsidePlot(worldX: number, worldZ: number, plotCenter: Vector3, plotSize: number): boolean
	local half = plotSize / 2
	return worldX >= plotCenter.X - half
		and worldX <= plotCenter.X + half
		and worldZ >= plotCenter.Z - half
		and worldZ <= plotCenter.Z + half
end

-- Pack a (cellX, cellZ) pair into a single string key for use in dicts.
-- Compact and human-readable in logs.
function GridMath.CellKey(cellX: number, cellZ: number): string
	return string.format("%d,%d", cellX, cellZ)
end

return GridMath
