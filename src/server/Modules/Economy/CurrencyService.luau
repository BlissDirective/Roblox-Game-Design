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
local BuildableRegistry =
	require(Shared:WaitForChild("Modules"):WaitForChild("Registry"):WaitForChild("BuildableRegistry"))

local DataManager = require(script.Parent.Parent.Player.DataManager)
local QuestObjectives = require(script.Parent.Parent.Retention.QuestObjectives)

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

local function fireCoresChanged(player: Player, newCores: number)
	local remote = Remotes.CoresChanged :: RemoteEvent
	remote:FireClient(player, newCores)
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
	-- C3: emit quest progress for "spend_credits" objectives.
	QuestObjectives.Emit("spend_credits", player, amount)
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
	-- C3: emit quest progress for "earn_credits" objectives. Includes
	-- credits granted from quest rewards themselves — a small cascade
	-- bonus for active completers, intentional and balanced in Phase G.
	QuestObjectives.Emit("earn_credits", player, amount)
	return true
end

-- Cores are V1's premium currency. Granted by quest rewards (C3) and
-- monetization developer products (D2). Spent in Phase D's cosmetic
-- shop. There's no CoresChanged Remote yet — Phase D adds the HUD
-- readout and the paired event.
function CurrencyService.AddCores(player: Player, amount: number): boolean
	if amount <= 0 then
		return false
	end
	local data = DataManager.GetData(player)
	if not data then
		return false
	end
	data.cores += amount
	fireCoresChanged(player, data.cores)
	return true
end

function CurrencyService.GetCores(player: Player): number
	local data = DataManager.GetData(player)
	return if data then data.cores else 0
end

-- Sum of all currently-registered extractors' per-second income for
-- the player. C4's OfflineProgression reads this post-restore to
-- compute `elapsed × income` for the offline grant.
function CurrencyService.GetTotalIncomePerSecond(player: Player): number
	local set = extractorsByPlayer[player]
	if not set then
		return 0
	end
	local sum = 0
	for _, buildable in set do
		sum += buildable.income
	end
	return sum
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

-- Public accessor for the per-player multiplier. Returns 1 when the
-- player has no entry (fresh join, not yet primed by PassEffects).
-- D5 / OfflineProgression reads this to scale the offline grant.
function CurrencyService.GetMultiplier(player: Player): number
	return multipliers[player] or 1
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
		-- Push the initial credits + cores values to the client once
		-- data is loaded. D5: Cores HUD listens to CoresChanged and
		-- needs the initial value too.
		task.spawn(function()
			local data = DataManager.WaitForData(player)
			if data then
				fireChanged(player, data.credits)
				fireCoresChanged(player, data.cores)
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
