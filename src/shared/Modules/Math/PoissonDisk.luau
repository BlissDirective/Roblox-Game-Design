--!strict
--[[
	Outpost-7 — 2D Poisson disk sampler (Bridson's algorithm).

	Phase B1. Deterministic, seeded, bounded. Produces a set of points
	in the rectangle (0,0)..(width,height) such that every pair of points
	is at least `minDistance` apart. Used by ResourceNodeSpawner to
	scatter nodes across plots so the layout *feels* designed rather than
	random.

	Reference: Bridson, "Fast Poisson Disk Sampling in Arbitrary
	Dimensions" (2007). Cell-grid acceleration: each cell is sized
	r/√2 so it can contain at most one point, and neighbor checks only
	scan the 5×5 region around a candidate's cell.

	Tunables (caller-provided):
	  width, height   — bounds, in arbitrary units (this module is unitless)
	  minDistance (r) — minimum distance between any two points
	  seed            — fed to Random.new for reproducible output
	  maxAttempts (k) — candidates per active point before giving up
	                    (Bridson recommends 30; we expose it for tuning)
--]]

local PoissonDisk = {}

local SQRT_2 = math.sqrt(2)

local function indexCell(grid: { { Vector2? } }, gx: number, gy: number): Vector2?
	local row = grid[gy]
	if not row then
		return nil
	end
	return row[gx]
end

local function setCell(grid: { { Vector2? } }, gx: number, gy: number, point: Vector2)
	local row = grid[gy]
	if not row then
		row = {}
		grid[gy] = row
	end
	row[gx] = point
end

function PoissonDisk.Sample(
	width: number,
	height: number,
	minDistance: number,
	seed: number,
	maxAttempts: number?
): { Vector2 }
	assert(width > 0 and height > 0, "PoissonDisk: width/height must be positive")
	assert(minDistance > 0, "PoissonDisk: minDistance must be positive")
	local k = maxAttempts or 30

	local rng = Random.new(seed)
	local cellSize = minDistance / SQRT_2
	local gridW = math.ceil(width / cellSize)
	local gridH = math.ceil(height / cellSize)

	local grid: { { Vector2? } } = {}
	local active: { Vector2 } = {}
	local accepted: { Vector2 } = {}

	local function pointToCell(p: Vector2): (number, number)
		return math.floor(p.X / cellSize) + 1, math.floor(p.Y / cellSize) + 1
	end

	local function isValid(candidate: Vector2): boolean
		if candidate.X < 0 or candidate.X >= width or candidate.Y < 0 or candidate.Y >= height then
			return false
		end
		local cx, cy = pointToCell(candidate)
		for gy = math.max(1, cy - 2), math.min(gridH, cy + 2) do
			for gx = math.max(1, cx - 2), math.min(gridW, cx + 2) do
				local existing = indexCell(grid, gx, gy)
				if existing and (existing - candidate).Magnitude < minDistance then
					return false
				end
			end
		end
		return true
	end

	-- Seed the algorithm with a single random initial point.
	local initial = Vector2.new(rng:NextNumber() * width, rng:NextNumber() * height)
	table.insert(active, initial)
	table.insert(accepted, initial)
	do
		local gx, gy = pointToCell(initial)
		setCell(grid, gx, gy, initial)
	end

	while #active > 0 do
		local pickIndex = rng:NextInteger(1, #active)
		local source = active[pickIndex]
		local placed = false

		for _ = 1, k do
			local angle = rng:NextNumber() * 2 * math.pi
			local radius = minDistance * (1 + rng:NextNumber()) -- annulus [r, 2r]
			local candidate = Vector2.new(source.X + math.cos(angle) * radius, source.Y + math.sin(angle) * radius)
			if isValid(candidate) then
				table.insert(active, candidate)
				table.insert(accepted, candidate)
				local gx, gy = pointToCell(candidate)
				setCell(grid, gx, gy, candidate)
				placed = true
				break
			end
		end

		if not placed then
			-- Remove the exhausted point from the active list. Swap-pop
			-- keeps removal O(1).
			active[pickIndex] = active[#active]
			active[#active] = nil
		end
	end

	return accepted
end

return PoissonDisk
