--!strict
--[[
	Outpost-7 — server-authoritative currency.

	Phase B2. Owns the per-player Credits ledger:
	  - 1Hz tick aggregates extractor income per player and writes it
	    to ProfileSchema.credits via DataManager.
	  - TrySpend is the atomic check-and-deduct path used by
	    PlacementService for affordability gates.
	  - Add is the grant path for daily logins, raid rewards, etc.
	  - GetCredits is the non-yielding read.
	  - CreditsChanged Remote replicates the new value to the owning
	    client whenever credits move (display only — server is the
	    source of truth).

	Extractor income flows through here via Register/Unregister:
	PlacementService calls Register on a successful extractor placement;
	CurrencyService cleans up on player leave. Future income-bearing
	buildables register the same way.

	Pass multipliers (Phase D) attach via SetMultiplier(player, x). At
	B2, every player has a flat 1.0; GamePassService overwrites the
	multiplier when a 2x Credits pass is owned.
--]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Constants = require(Shared:WaitForChild("Constants"))
local Remotes = require(Shared:WaitForChild("Remotes"))

local DataManager = require(script.Parent.Parent.Player.DataManager)
local BuildableRegistry = require(script.Parent.Parent.Build.BuildableRegistry)

type Buildable = BuildableRegistry.Buildable

local CurrencyService = {}

-- player -> set of (BasePart -> Buildable). The Part is the canonical
-- key so destruction (in Phase E plot-reset, etc.) maps cleanly.
local extractorsByPlayer: { [Player]: { [BasePart]: Buildable } } = {}
-- player -> credit multiplier (defaults to 1.0; Phase D's GamePassService
-- bumps this for 2x Credits etc.).
local multipliers: { [Player]: number } = {}

local function fireChanged(player: Player, newCredits: number)
	local remote = Remotes.CreditsChanged :: RemoteEvent
	remote:FireClient(player, newCredits)
end

local function getMultiplier(player: Player): number
	return multipliers[player] or 1
end

local function tickPlayer(player: Player)
	local data = DataManager.GetData(player)
	if not data then
		return
	end
	local extractors = extractorsByPlayer[player]
	if not extractors then
		return
	end

	local baseIncome = 0
	for _, buildable in extractors do
		baseIncome += buildable.income
	end
	if baseIncome <= 0 then
		return
	end

	local gain = math.floor(baseIncome * getMultiplier(player))
	if gain <= 0 then
		return
	end

	data.credits += gain
	fireChanged(player, data.credits)
end

local function tickLoop()
	while true do
		task.wait(Constants.TICK.Currency)
		for player in pairs(extractorsByPlayer) do
			tickPlayer(player)
		end
	end
end

function CurrencyService.GetCredits(player: Player): number
	local data = DataManager.GetData(player)
	return if data then data.credits else 0
end

function CurrencyService.TrySpend(player: Player, amount: number): boolean
	if amount <= 0 then
		return false
	end
	local data = DataManager.GetData(player)
	if not data then
		return false
	end
	if data.credits < amount then
		return false
	end
	data.credits -= amount
	fireChanged(player, data.credits)
	return true
end

function CurrencyService.Add(player: Player, amount: number): boolean
	if amount <= 0 then
		return false
	end
	local data = DataManager.GetData(player)
	if not data then
		return false
	end
	data.credits += amount
	fireChanged(player, data.credits)
	return true
end

function CurrencyService.SetMultiplier(player: Player, value: number)
	-- Bounded sanity. Multipliers above 10 are almost certainly bugs;
	-- log and clamp instead of trusting the caller blindly.
	if value <= 0 or value > 10 then
		warn(string.format("[CurrencyService] Refusing implausible multiplier %f for %s", value, player.Name))
		return
	end
	multipliers[player] = value
end

function CurrencyService.RegisterExtractor(player: Player, buildable: Buildable, part: BasePart)
	if buildable.income <= 0 then
		return
	end
	local set = extractorsByPlayer[player]
	if not set then
		set = {}
		extractorsByPlayer[player] = set
	end
	set[part] = buildable
end

function CurrencyService.UnregisterExtractor(player: Player, part: BasePart)
	local set = extractorsByPlayer[player]
	if not set then
		return
	end
	set[part] = nil
end

function CurrencyService.Init()
	Players.PlayerAdded:Connect(function(player)
		multipliers[player] = 1
		-- Push the initial credits value to the client once data is loaded.
		task.spawn(function()
			local data = DataManager.WaitForData(player)
			if data then
				fireChanged(player, data.credits)
			end
		end)
	end)

	Players.PlayerRemoving:Connect(function(player)
		extractorsByPlayer[player] = nil
		multipliers[player] = nil
	end)

	task.spawn(tickLoop)
end

return CurrencyService
