--!strict
--[[
	Outpost-7 — restocking blueprint shop.

	Phase C2. 6-hour rotations seeded deterministically by
	`floor(os.time() / ShopRotationSeconds)`, so every player on every
	server sees the same stock during a given window. Per-player
	per-rotation purchase tracking lives on ProfileSchema; stale
	rotations reset lazily on first GetState/TryBuy of a new window.

	Catalog lives in BlueprintRegistry. ShopService picks
	`ShopSlotsPerRotation` items via weighted-without-replacement
	sampling using `Random.new(rotationIndex)` for full determinism.

	Public API:
	  GetCurrentStock()              — current rotation's slot ids
	  GetState(player)               — { rotation, items, bought, secondsUntilRestock }
	  TryBuy(player, blueprintId)    — Result-style { ok, ...effect } | { ok=false, error }
	  Init                           — pushes ShopState on join + after each successful buy
--]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Constants = require(Shared:WaitForChild("Constants"))
local Remotes = require(Shared:WaitForChild("Remotes"))

local DataManager = require(script.Parent.Parent.Player.DataManager)
local CurrencyService = require(script.Parent.CurrencyService)
local BlueprintRegistry = require(script.Parent.BlueprintRegistry)
local QuestObjectives = require(script.Parent.Parent.Retention.QuestObjectives)
local AntiExploit = require(script.Parent.Parent.Security.AntiExploit)

type Blueprint = BlueprintRegistry.Blueprint

local ShopService = {}

export type ShopItemView = {
	id: string,
	displayName: string,
	description: string,
	rarity: string,
	cost: number,
	bought: boolean,
}

export type State = {
	rotation: number,
	secondsUntilRestock: number,
	items: { ShopItemView },
}

export type BuyResult = {
	ok: true,
	blueprintId: string,
	grantedCredits: number,
} | {
	ok: false,
	error: string,
}

local function getRotationIndex(): number
	return math.floor(os.time() / Constants.RETENTION.ShopRotationSeconds)
end

local function secondsUntilRestock(): number
	local nextBoundary = (getRotationIndex() + 1) * Constants.RETENTION.ShopRotationSeconds
	return nextBoundary - os.time()
end

-- Weighted sampling without replacement. The pool is mutated in place
-- (the caller passes a copy). Returns the chosen entry or nil.
local function pickWeighted(rng: Random, pool: { Blueprint }): Blueprint?
	if #pool == 0 then
		return nil
	end
	local totalWeight = 0
	for _, item in pool do
		totalWeight += item.weight
	end
	local target = rng:NextNumber() * totalWeight
	local cumulative = 0
	for i, item in pool do
		cumulative += item.weight
		if target <= cumulative then
			-- Remove from pool (swap-pop, O(1))
			pool[i] = pool[#pool]
			pool[#pool] = nil
			return item
		end
	end
	-- Floating-point fallback — shouldn't normally hit.
	local last = pool[#pool]
	pool[#pool] = nil
	return last
end

local stockCache: { rotation: number, items: { string } }? = nil

local function generateStockForRotation(rotation: number): { string }
	local rng = Random.new(rotation)
	-- Build a flat working copy; the registry table itself is read-only.
	local pool: { Blueprint } = {}
	for _, blueprint in BlueprintRegistry.GetAll() do
		table.insert(pool, blueprint)
	end
	local picked: { string } = {}
	for _ = 1, Constants.RETENTION.ShopSlotsPerRotation do
		if #pool == 0 then
			break
		end
		local chosen = pickWeighted(rng, pool)
		if chosen then
			table.insert(picked, chosen.id)
		end
	end
	return picked
end

function ShopService.GetCurrentStock(): { string }
	local rotation = getRotationIndex()
	if stockCache and stockCache.rotation == rotation then
		return stockCache.items
	end
	local items = generateStockForRotation(rotation)
	stockCache = { rotation = rotation, items = items }
	return items
end

local function ensureFreshRotation(data: any)
	local current = getRotationIndex()
	if data.shopRotationSeen ~= current then
		data.shopRotationSeen = current
		data.shopBuysThisRotation = {}
	end
end

function ShopService.GetState(player: Player): State?
	local data = DataManager.GetData(player)
	if not data then
		return nil
	end
	ensureFreshRotation(data)

	local stock = ShopService.GetCurrentStock()
	local items: { ShopItemView } = {}
	for _, id in stock do
		local blueprint = BlueprintRegistry.Get(id)
		if not blueprint then
			continue
		end
		table.insert(items, {
			id = blueprint.id,
			displayName = blueprint.displayName,
			description = blueprint.description,
			rarity = blueprint.rarity,
			cost = blueprint.cost,
			bought = data.shopBuysThisRotation[blueprint.id] == true,
		})
	end

	return {
		rotation = getRotationIndex(),
		secondsUntilRestock = secondsUntilRestock(),
		items = items,
	}
end

function ShopService.TryBuy(player: Player, blueprintId: string): BuyResult
	local data = DataManager.GetData(player)
	if not data then
		return { ok = false, error = "no profile" }
	end
	ensureFreshRotation(data)

	local blueprint = BlueprintRegistry.Get(blueprintId)
	if not blueprint then
		return { ok = false, error = "unknown blueprint: " .. tostring(blueprintId) }
	end

	-- Must be in the current rotation's stock.
	local stock = ShopService.GetCurrentStock()
	local inStock = false
	for _, id in stock do
		if id == blueprintId then
			inStock = true
			break
		end
	end
	if not inStock then
		return { ok = false, error = "not in current stock" }
	end

	-- One purchase per rotation per player.
	if data.shopBuysThisRotation[blueprintId] then
		return { ok = false, error = "already bought this rotation" }
	end

	-- Atomic check-and-deduct. CurrencyService.TrySpend handles the
	-- "insufficient credits" case.
	if not CurrencyService.TrySpend(player, blueprint.cost) then
		return { ok = false, error = "insufficient credits" }
	end

	-- Apply the effect. V1: blueprints grant Credits directly.
	if blueprint.grantCredits > 0 then
		CurrencyService.Add(player, blueprint.grantCredits)
	end

	-- Record the purchase so the slot turns "Sold Out" until restock.
	data.shopBuysThisRotation[blueprintId] = true

	-- C3: emit for "buy_shop_item" quest objectives.
	QuestObjectives.Emit("buy_shop_item", player, 1)

	print(
		string.format(
			"[ShopService] %s bought %s (cost %d, granted %d credits)",
			player.Name,
			blueprintId,
			blueprint.cost,
			blueprint.grantCredits
		)
	)
	return { ok = true, blueprintId = blueprintId, grantedCredits = blueprint.grantCredits }
end

local function pushStateToClient(player: Player)
	local state = ShopService.GetState(player)
	if not state then
		return
	end
	local remote = Remotes.ShopState :: RemoteEvent
	remote:FireClient(player, state)
end

function ShopService.Init()
	Players.PlayerAdded:Connect(function(player)
		task.spawn(function()
			DataManager.WaitForData(player)
			pushStateToClient(player)
		end)
	end)

	local buyRemote = Remotes.BuyShopItem :: RemoteFunction
	buyRemote.OnServerInvoke = function(player: Player, blueprintId: any): BuyResult
		-- F1 token-bucket rate limit.
		if not AntiExploit.RateCheck(player, "BuyShopItem") then
			return { ok = false, error = "rate-limited" }
		end
		if typeof(blueprintId) ~= "string" then
			return { ok = false, error = "invalid blueprint id" }
		end
		local result = ShopService.TryBuy(player, blueprintId)
		pushStateToClient(player)
		return result
	end

	-- Push restocked state to all online players when the rotation
	-- boundary crosses while a player is in-session. Cheap loop:
	-- check once a minute; only fire if rotation changed AND any
	-- players are online.
	task.spawn(function()
		local lastRotation = getRotationIndex()
		while true do
			task.wait(60)
			local current = getRotationIndex()
			if current ~= lastRotation then
				lastRotation = current
				stockCache = nil
				for _, player in Players:GetPlayers() do
					pushStateToClient(player)
				end
			end
		end
	end)
end

return ShopService
