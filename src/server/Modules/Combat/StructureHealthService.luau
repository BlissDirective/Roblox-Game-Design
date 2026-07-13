--!strict
--[[
	Outpost-7 — structure hit points, damage, destruction, repair.

	Phase R1 ("Fortify"). Before R1 the base was decoration: aliens meleed
	the player and ignored walls/turrets/extractors entirely (audit §4.2).
	This service makes structures mechanically real — they have HP, the
	swarm chews through them, and the player repairs them.

	Ownership of state:
	  - Canonical HP lives in this service's `records` table AND mirrored to
	    the Part's `CurrentHp`/`MaxHp` attributes (so the client damage-state
	    renderer reads a single source of truth off the Part).
	  - AlienAI is the sole damage *source* in V1 PvE (raids add the attacker
	    weapon in R2/R3). It calls `Damage` — it never mutates HP directly.
	  - PlacementService owns the occupancy map + baseLayout; when a structure
	    dies this service calls back into `PlacementService.RemoveStructure`
	    (lazy-required to avoid the require cycle) so cleanup stays in one
	    place.

	Wave-loss policy (Constants.COMBAT.WaveLossMode — user-switchable
	soft/medium/hard, default medium):
	  - Walls + turrets at 0 HP are ALWAYS destroyed (removed). Losing the
	    perimeter IS the drama; the mode doesn't soften it.
	  - Extractors (the income core) read the mode:
	      soft   → disabled (income 0) until repaired, no credit loss
	      medium → disabled + a capped % of current Credits skimmed
	      hard   → destroyed (rebuild required) + the capped skim

	Public API:
	  Init()                                   — PlayerRemoving cleanup + repair Remote
	  Register(player, part, buildable, x, z)  — track a freshly placed/restored structure
	  Unregister(part)                         — drop tracking (called by PlacementService.RemoveStructure)
	  Damage(part, amount, sourceLabel)        — apply damage; handles death/disable/skim
	  GetHp(part) / GetMaxHp(part)             — non-yielding reads (0 if untracked)
	  IsDamageable(part)                       — true if the part is a tracked structure with HP
--]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Constants = require(Shared:WaitForChild("Constants"))
local Remotes = require(Shared:WaitForChild("Remotes"))
local GridMath = require(Shared:WaitForChild("Modules"):WaitForChild("Math"):WaitForChild("GridMath"))
local BuildableRegistry =
	require(Shared:WaitForChild("Modules"):WaitForChild("Registry"):WaitForChild("BuildableRegistry"))

local CurrencyService = require(script.Parent.Parent.Economy.CurrencyService)
local PlotManager = require(script.Parent.Parent.World.PlotManager)
local AntiExploit = require(script.Parent.Parent.Security.AntiExploit)
local AuditLog = require(script.Parent.Parent.Security.AuditLog)
local RemoteValidator = require(script.Parent.Parent.Security.RemoteValidator)

type Buildable = BuildableRegistry.Buildable

local StructureHealthService = {}

export type HealthUpdate = {
	buildableId: string,
	cellX: number,
	cellZ: number,
	position: Vector3,
	hp: number,
	maxHp: number,
	-- "damaged" | "destroyed" | "disabled" | "repaired"
	state: string,
}

type Record = {
	player: Player,
	part: BasePart,
	buildable: Buildable,
	plotId: number,
	cellX: number,
	cellZ: number,
	hp: number,
	maxHp: number,
	isExtractor: boolean,
}

-- Every tracked structure, keyed by its Part.
local records: { [BasePart]: Record } = {}
-- Fast cell lookup for repair requests: plotId -> cellKey -> Part.
local byCell: { [number]: { [string]: BasePart } } = {}

local function indexCell(plotId: number, cellKey: string, part: BasePart)
	local plotCells = byCell[plotId]
	if not plotCells then
		plotCells = {}
		byCell[plotId] = plotCells
	end
	plotCells[cellKey] = part
end

local function deindexCell(plotId: number, cellKey: string)
	local plotCells = byCell[plotId]
	if plotCells then
		plotCells[cellKey] = nil
	end
end

local function pushUpdate(record: Record, state: string)
	local remote = Remotes.StructureHealth :: RemoteEvent
	-- Owner-only push in V1 PvE. Raids (R2) will push to the attacker as
	-- well when the snapshot base takes damage.
	if record.player and record.player:IsDescendantOf(Players) then
		remote:FireClient(record.player, {
			buildableId = record.buildable.id,
			cellX = record.cellX,
			cellZ = record.cellZ,
			position = record.part.Position,
			hp = record.hp,
			maxHp = record.maxHp,
			state = state,
		} :: HealthUpdate)
	end
end

-- Resolve the active wave-loss profile once per call (cheap; keeps the
-- mode switch to a single Constants edit with no service restart).
local function lossProfile()
	local mode = Constants.COMBAT.WaveLossMode
	local profiles = Constants.COMBAT.WaveLossProfiles
	return profiles[mode] or profiles.medium
end

function StructureHealthService.Register(
	player: Player,
	part: BasePart,
	buildable: Buildable,
	cellX: number,
	cellZ: number
)
	local maxHp = buildable.maxHp or 0
	if maxHp <= 0 then
		-- Indestructible buildable — nothing to track.
		return
	end
	local plot = PlotManager.GetPlot(player)
	local plotId = if plot then plot.id else -1
	-- On a restore the Part may already carry a CurrentHp attribute from a
	-- prior session; V1 does not persist mid-wave damage, so a
	-- freshly-placed or restored structure always starts at full.
	local record: Record = {
		player = player,
		part = part,
		buildable = buildable,
		plotId = plotId,
		cellX = cellX,
		cellZ = cellZ,
		hp = maxHp,
		maxHp = maxHp,
		isExtractor = buildable.income > 0,
	}
	records[part] = record
	part:SetAttribute("MaxHp", maxHp)
	part:SetAttribute("CurrentHp", maxHp)
	if plotId >= 0 then
		indexCell(plotId, GridMath.CellKey(cellX, cellZ), part)
	end
end

function StructureHealthService.Unregister(part: BasePart)
	local record = records[part]
	if not record then
		return
	end
	records[part] = nil
	if record.plotId >= 0 then
		deindexCell(record.plotId, GridMath.CellKey(record.cellX, record.cellZ))
	end
end

function StructureHealthService.GetHp(part: BasePart): number
	local record = records[part]
	return if record then record.hp else 0
end

function StructureHealthService.GetMaxHp(part: BasePart): number
	local record = records[part]
	return if record then record.maxHp else 0
end

function StructureHealthService.IsDamageable(part: BasePart): boolean
	return records[part] ~= nil
end

-- Remove a dead structure from the world + all registries. Lazy-requires
-- PlacementService to avoid the load-time require cycle (PlacementService
-- requires this service to Register on placement).
local function destroyStructure(record: Record)
	local PlacementService = require(script.Parent.Parent.Build.PlacementService)
	StructureHealthService.Unregister(record.part)
	PlacementService.RemoveStructure(record.player, record.cellX, record.cellZ)
end

-- Extractor reached 0 HP — apply the credit skim (medium/hard) and either
-- disable (soft/medium) or destroy (hard) per the active wave-loss profile.
local function handleExtractorDown(record: Record)
	local profile = lossProfile()

	-- Credit skim (the "loot" the swarm carries off).
	if profile.creditStealPct > 0 then
		local current = CurrencyService.GetCredits(record.player)
		local wanted = math.floor(current * profile.creditStealPct)
		if profile.creditStealCap > 0 then
			wanted = math.min(wanted, profile.creditStealCap)
		end
		if wanted > 0 then
			local taken = CurrencyService.Drain(record.player, wanted)
			if taken > 0 then
				print(
					string.format(
						"[StructureHealthService] Wave skimmed %d Credits from %s (mode=%s)",
						taken,
						record.player.Name,
						Constants.COMBAT.WaveLossMode
					)
				)
			end
		end
	end

	if profile.extractorOnZero == "destroy" then
		pushUpdate(record, "destroyed")
		destroyStructure(record)
	else
		-- Disable in place; income stops until repaired.
		record.hp = 0
		record.part:SetAttribute("CurrentHp", 0)
		CurrencyService.SetExtractorDisabled(record.part, true)
		pushUpdate(record, "disabled")
	end
end

function StructureHealthService.Damage(part: BasePart, amount: number, sourceLabel: string): boolean
	local record = records[part]
	if not record or amount <= 0 then
		return false
	end
	-- A disabled extractor sitting at 0 HP takes no further damage — it's
	-- already down; only a repair changes its state.
	if record.hp <= 0 then
		return false
	end

	record.hp = math.max(0, record.hp - math.floor(amount))
	part:SetAttribute("CurrentHp", record.hp)

	if record.hp > 0 then
		pushUpdate(record, "damaged")
		return true
	end

	-- Reached zero.
	if record.isExtractor then
		handleExtractorDown(record)
	else
		-- Walls + turrets are always removed on breach, regardless of mode.
		pushUpdate(record, "destroyed")
		destroyStructure(record)
	end
	return true
end

-- Repair the structure at (cellX, cellZ) on the player's own plot. Server
-- validates ownership, that the structure exists + is damaged, reach, and
-- affordability. Returns true on a successful repair.
function StructureHealthService.Repair(player: Player, cellX: number, cellZ: number): boolean
	local plot = PlotManager.GetPlot(player)
	if not plot then
		return false
	end
	local plotCells = byCell[plot.id]
	if not plotCells then
		return false
	end
	local part = plotCells[GridMath.CellKey(cellX, cellZ)]
	if not part then
		return false
	end
	local record = records[part]
	if not record then
		return false
	end
	if record.hp >= record.maxHp then
		return false -- already full
	end

	-- Reach check — player must be near the structure they're repairing.
	local character = player.Character
	if not character then
		return false
	end
	local hrp = character:FindFirstChild("HumanoidRootPart")
	if not hrp or not hrp:IsA("BasePart") then
		return false
	end
	if (hrp.Position - record.part.Position).Magnitude > Constants.COMBAT.RepairReachStuds then
		return false
	end

	-- Cost scales with missing HP, floored so trivial repairs aren't free.
	local missing = record.maxHp - record.hp
	local cost = math.max(Constants.COMBAT.RepairCostMin, math.floor(missing * Constants.COMBAT.RepairCostPerHp))
	if not CurrencyService.TrySpend(player, cost) then
		return false
	end

	local wasDisabledExtractor = record.isExtractor and record.hp <= 0
	record.hp = record.maxHp
	record.part:SetAttribute("CurrentHp", record.maxHp)
	if wasDisabledExtractor then
		CurrencyService.SetExtractorDisabled(record.part, false)
	end
	pushUpdate(record, "repaired")
	return true
end

local function onRepairRemote(player: Player, cellX: any, cellZ: any)
	if not AntiExploit.RateCheck(player, "RepairStructure") then
		AuditLog.Record(player, "rate_limited", "RepairStructure")
		return
	end
	local maxCells = Constants.WORLD.PlotSlotSize / Constants.GRID.Size + 4
	local xOk, xValue = RemoteValidator.IsInteger(cellX, -maxCells, maxCells)
	if not xOk then
		AuditLog.Record(player, "validation_failed", "RepairStructure: cellX out of range")
		return
	end
	local zOk, zValue = RemoteValidator.IsInteger(cellZ, -maxCells, maxCells)
	if not zOk then
		AuditLog.Record(player, "validation_failed", "RepairStructure: cellZ out of range")
		return
	end
	StructureHealthService.Repair(player, xValue :: number, zValue :: number)
end

function StructureHealthService.Init()
	-- Drop all tracking for a leaving player (PlotManager destroys the
	-- Parts; we just clear our references so they can be GC'd).
	Players.PlayerRemoving:Connect(function(player)
		local plot = PlotManager.GetPlot(player)
		if plot then
			byCell[plot.id] = nil
		end
		for part, record in records do
			if record.player == player then
				records[part] = nil
			end
		end
	end)

	local repairRemote = Remotes.RepairStructure :: RemoteEvent
	repairRemote.OnServerEvent:Connect(onRepairRemote)
end

return StructureHealthService
