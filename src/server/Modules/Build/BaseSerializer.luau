--!strict
--[[
	Outpost-7 — base layout serialization.

	Phase B3. Thin façade over `ProfileSchema.baseLayout` — the
	persistent list of placed buildings on a player's plot. Compact
	form is `{ id, x, z }` per entry; the visual Part is rebuilt from
	BuildableRegistry on restore.

	Persistence rhythm:
	  - PlacementService calls Append on each successful placement.
	    The mutation lands in the in-memory profile.Data table; the
	    actual DataStore write happens on ProfileStore's auto-save
	    (~every 5 min) and on PlayerRemoving / BindToClose. So a
	    server crash can lose up to ~5 min of placements; acceptable
	    for V1.
	  - BuildRestorer reads via Get on plot allocation and replays.
	  - Plot wipes (PlotManager release) clear in-memory layout via
	    Clear so the next session starts fresh on that plot.

	The list is mutated in place — callers don't need to write back.
--]]

local DataManager = require(script.Parent.Parent.Player.DataManager)
local ProfileSchema = require(script.Parent.Parent.Player.ProfileSchema)

type SerializedBuilding = ProfileSchema.SerializedBuilding

local BaseSerializer = {}

local function getLayout(player: Player): { SerializedBuilding }?
	local data = DataManager.GetData(player)
	if not data then
		return nil
	end
	-- Defensive: older saves loaded before Reconcile() ran would lack
	-- baseLayout. ProfileStore handles this, but a manual nil-fill is
	-- cheap insurance.
	if not data.baseLayout then
		data.baseLayout = {}
	end
	return data.baseLayout
end

function BaseSerializer.Append(player: Player, buildableId: string, cellX: number, cellZ: number): boolean
	local layout = getLayout(player)
	if not layout then
		return false
	end
	table.insert(layout, { id = buildableId, x = cellX, z = cellZ })
	return true
end

function BaseSerializer.Remove(player: Player, cellX: number, cellZ: number): boolean
	local layout = getLayout(player)
	if not layout then
		return false
	end
	for i, entry in layout do
		if entry.x == cellX and entry.z == cellZ then
			table.remove(layout, i)
			return true
		end
	end
	return false
end

function BaseSerializer.Get(player: Player): { SerializedBuilding }
	return getLayout(player) or {}
end

function BaseSerializer.Clear(player: Player)
	local layout = getLayout(player)
	if layout then
		table.clear(layout)
	end
end

return BaseSerializer
