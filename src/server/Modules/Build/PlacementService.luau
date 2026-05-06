--!strict
--[[
	Outpost-7 — server-validated building placement.

	Phase B1. The single chokepoint for "client requested to place X
	at cell (Y,Z)". Validates against the player's plot, the buildable
	catalog, and the cell occupancy map; rejects everything else.

	Validation chain (in order):
	  1. Player has an allocated plot
	  2. buildableId is in BuildableRegistry
	  3. Cell is inside the player's plot bounds
	  4. Cell is not already occupied
	  5. If buildable.requiresNode: an unclaimed node exists at this cell
	  6. Affordability check (B2 wires — placeholder true at B1)
	  7. Reach check (F1 hardens with raycast — placeholder true at B1)

	On success the building is parented under the plot's Buildings
	folder, the cell is recorded in the occupancy map, and a `Buildable`
	attribute is stamped on the Part for replication-side identification.

	Public API:
	  Init()                                          — wire Remote
	  TryPlace(player, buildableId, cellX, cellZ)     — internal logic,
	                                                    exported for tests
	                                                    and Command Bar

	The Remote handler is a thin wrapper around TryPlace so a server
	module (e.g. tutorial gates in F4) can call placement directly
	without going through the wire.
--]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Constants = require(Shared:WaitForChild("Constants"))
local GridMath = require(Shared:WaitForChild("Modules"):WaitForChild("Math"):WaitForChild("GridMath"))
local Remotes = require(Shared:WaitForChild("Remotes"))
local BuildableRegistry =
	require(Shared:WaitForChild("Modules"):WaitForChild("Registry"):WaitForChild("BuildableRegistry"))

local PlotManager = require(script.Parent.Parent.World.PlotManager)
local BaseSerializer = require(script.Parent.BaseSerializer)
local CurrencyService = require(script.Parent.Parent.Economy.CurrencyService)
local DataManager = require(script.Parent.Parent.Player.DataManager)
local QuestObjectives = require(script.Parent.Parent.Retention.QuestObjectives)
local TurretService = require(script.Parent.Parent.Combat.TurretService)

type Buildable = BuildableRegistry.Buildable
type PlotInfo = PlotManager.PlotInfo

export type PlaceResult = {
	ok: true,
	part: BasePart,
} | {
	ok: false,
	error: string,
}

local PlacementService = {}

-- plotId -> cellKey ("x,z") -> buildable id
local occupancy: { [number]: { [string]: string } } = {}

local function ensureOccupancyTable(plotId: number): { [string]: string }
	local table_ = occupancy[plotId]
	if not table_ then
		table_ = {}
		occupancy[plotId] = table_
	end
	return table_
end

local function findNodeAtCell(plot: PlotInfo, cellX: number, cellZ: number): BasePart?
	local key = GridMath.CellKey(cellX, cellZ)
	for _, node in plot.nodes:GetChildren() do
		if not node:IsA("BasePart") then
			continue
		end
		if node:GetAttribute("CellX") == cellX and node:GetAttribute("CellZ") == cellZ then
			return node
		end
		-- Defensive: also accept the name match in case attributes drop.
		if node.Name == "Node_" .. key then
			return node
		end
	end
	return nil
end

local function fail(reason: string): PlaceResult
	return { ok = false, error = reason }
end

-- `trusted` mode is for restoration paths (BuildRestorer): skip the
-- affordability deduction (already paid in a prior session) and skip
-- persisting back to baseLayout (already saved). All other validations
-- still run — a restore that violates plot bounds or occupancy is a
-- bug we want to surface, not paper over.
function PlacementService.TryPlace(
	player: Player,
	buildableId: string,
	cellX: number,
	cellZ: number,
	trusted: boolean?
): PlaceResult
	-- 1. Plot allocation
	local plot = PlotManager.GetPlot(player)
	if not plot then
		return fail("no plot allocated")
	end

	-- 2. Buildable validity
	local buildable = BuildableRegistry.Get(buildableId)
	if not buildable then
		return fail("unknown buildable: " .. tostring(buildableId))
	end

	-- 3. Cell inside plot bounds
	local worldPos = GridMath.CellToWorld(cellX, cellZ, Constants.GRID.Size, plot.center.Y)
	if not GridMath.IsInsidePlot(worldPos.X, worldPos.Z, plot.center, plot.size) then
		return fail("cell outside plot")
	end

	-- 4. Cell occupancy
	local plotOcc = ensureOccupancyTable(plot.id)
	local cellKey = GridMath.CellKey(cellX, cellZ)
	if plotOcc[cellKey] then
		return fail("cell already occupied")
	end

	-- 5. Node requirement (extractors only)
	local claimedNode: BasePart? = nil
	if buildable.requiresNode then
		local node = findNodeAtCell(plot, cellX, cellZ)
		if not node then
			return fail("no resource node at cell")
		end
		if node:GetAttribute("Claimed") then
			return fail("node already claimed")
		end
		claimedNode = node
	end

	-- 6. Affordability — atomic check-and-deduct via CurrencyService.
	-- Skipped in `trusted` mode (restoration: already paid in prior session).
	if not trusted and buildable.cost > 0 then
		if not CurrencyService.TrySpend(player, buildable.cost) then
			return fail("insufficient credits")
		end
	end

	-- 7. Reach check — F1 hardens with server raycast.

	-- All validations passed. Spawn the part.
	local part = BuildableRegistry.BuildPart(buildable, player.UserId)
	-- Center the part vertically above the floor.
	part.Position = worldPos + Vector3.new(0, buildable.size.Y / 2, 0)
	part.Parent = plot.buildings

	plotOcc[cellKey] = buildable.id
	if claimedNode then
		claimedNode:SetAttribute("Claimed", true)
	end

	-- Income-bearing buildables register with CurrencyService so the
	-- 1Hz tick aggregates them into the owner's per-second income.
	if buildable.income > 0 then
		CurrencyService.RegisterExtractor(player, buildable, part)
	end

	-- Combat-role buildables (E2.5+): turrets register with TurretService
	-- so the targeting tick can find them. Both fresh placements and
	-- restorations (trusted) register — the runtime registry is per-
	-- session, not persisted, so a rejoin restoring 5 turrets needs all
	-- 5 added back.
	if buildable.combatRole == "turret" then
		TurretService.RegisterTurret(player, part)
	end

	-- 8. Persist to baseLayout — fresh placements only; restorations
	-- skip because the entry is already in the saved layout.
	if not trusted then
		BaseSerializer.Append(player, buildable.id, cellX, cellZ)
		-- Quest progress emissions: a specific event per buildable kind
		-- + a generic "place_any" so quest authors can target either.
		QuestObjectives.Emit("place_" .. buildable.id, player, 1)
		QuestObjectives.Emit("place_any", player, 1)
		-- F0: V1.5 Tier system foundation — track lifetime tycoon spend
		-- on placements (NOT shop / quest grants). Sticky signal; never
		-- decremented on demolish/refund. See V1_5_TIER_PROGRESSION.md §3.
		local data = DataManager.GetData(player)
		if data and buildable.cost > 0 then
			data.creditsInvestedLifetime = (data.creditsInvestedLifetime or 0) + buildable.cost
			QuestObjectives.Emit("credits_invested", player, buildable.cost)
		end
	end

	if trusted then
		print(
			string.format(
				"[PlacementService] Restored %s on Plot%d at %s for %s",
				buildable.id,
				plot.id,
				cellKey,
				player.Name
			)
		)
	else
		print(
			string.format(
				"[PlacementService] %s placed %s on Plot%d at %s",
				player.Name,
				buildable.id,
				plot.id,
				cellKey
			)
		)
	end
	return { ok = true, part = part }
end

local function onRemote(player: Player, buildableId: any, cellX: any, cellZ: any)
	-- F1 will route this through Security.AntiExploit + RemoteValidator;
	-- B1 does the type checks inline so the audit can exercise the path.
	if typeof(buildableId) ~= "string" then
		return
	end
	if typeof(cellX) ~= "number" or cellX ~= math.floor(cellX) then
		return
	end
	if typeof(cellZ) ~= "number" or cellZ ~= math.floor(cellZ) then
		return
	end
	-- Sanity bounds — cell coords beyond ±2× the plot grid are
	-- nonsensical; reject before doing more work.
	local maxCells = Constants.WORLD.PlotSize / Constants.GRID.Size + 4
	if math.abs(cellX) > maxCells or math.abs(cellZ) > maxCells then
		return
	end

	PlacementService.TryPlace(player, buildableId, cellX, cellZ)
end

function PlacementService.Init()
	-- Clean slate when a player leaves: wipe their plot's occupancy.
	Players.PlayerRemoving:Connect(function(player)
		local plot = PlotManager.GetPlot(player)
		if plot then
			occupancy[plot.id] = nil
		end
	end)

	local placeBuilding = Remotes.PlaceBuilding :: RemoteEvent
	placeBuilding.OnServerEvent:Connect(onRemote)
end

return PlacementService
