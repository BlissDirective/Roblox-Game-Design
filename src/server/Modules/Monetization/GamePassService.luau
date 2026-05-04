--!strict
--[[
	Outpost-7 — Game Pass ownership + purchase flow.

	Phase D1. Single chokepoint for "does player X own pass Y".
	Implements ADR-006: a per-session local ownership cache,
	authoritative via `PromptGamePassPurchaseFinished` to dodge the
	long-standing `UserOwnsGamePassAsync` mid-session staleness bug.

	Public API:
	  Init                         — connects PlayerAdded + the prompt-
	                                  finished signal; primes ownership
	                                  cache on join
	  Owns(player, passKey)        — non-yielding cache read
	  Prompt(player, passKey)      — server-side helper; mostly used by
	                                  server-driven prompts (the client
	                                  also calls MarketplaceService
	                                  directly for player-driven flows)
	  OnOwnershipChanged           — RBXScriptSignal fired when our cache
	                                  flips for a (player, passKey).
	                                  Phase D3's PassEffects subscribes.
--]]

local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Constants = require(Shared:WaitForChild("Constants"))

local GamePassService = {}

-- Per-player ownership cache: ownership[userId][passKey] = bool.
-- Cleared on PlayerRemoving.
local ownership: { [number]: { [string]: boolean } } = {}

local onOwnershipChanged = Instance.new("BindableEvent")
GamePassService.OnOwnershipChanged = onOwnershipChanged.Event

local function passKeyForId(passId: number): string?
	for key, def in Constants.MONETIZATION.GamePasses do
		if def.id == passId then
			return key
		end
	end
	return nil
end

local function ensurePlayerSlot(userId: number): { [string]: boolean }
	local slot = ownership[userId]
	if not slot then
		slot = {}
		ownership[userId] = slot
	end
	return slot
end

local function setOwned(player: Player, passKey: string, owned: boolean)
	local slot = ensurePlayerSlot(player.UserId)
	if slot[passKey] == owned then
		return
	end
	slot[passKey] = owned
	onOwnershipChanged:Fire(player, passKey, owned)
end

-- Yielding initial query for a single pass. Wrapped in pcall — a network
-- failure here is non-fatal, we just default the cache to false and the
-- player can re-trigger via prompt.
local function primeOwnership(player: Player, passKey: string, passId: number)
	if passId <= 0 then
		-- Placeholder ID; defer until real ID is assigned.
		setOwned(player, passKey, false)
		return
	end
	local ok, owns = pcall(function()
		return MarketplaceService:UserOwnsGamePassAsync(player.UserId, passId)
	end)
	if ok then
		setOwned(player, passKey, owns == true)
	else
		setOwned(player, passKey, false)
		warn(string.format("[GamePassService] UserOwnsGamePassAsync failed for %s/%s", player.Name, passKey))
	end
end

local function primeAllForPlayer(player: Player)
	for key, def in Constants.MONETIZATION.GamePasses do
		primeOwnership(player, key, def.id)
	end
end

function GamePassService.Owns(player: Player, passKey: string): boolean
	local slot = ownership[player.UserId]
	if not slot then
		return false
	end
	return slot[passKey] == true
end

function GamePassService.Prompt(player: Player, passKey: string): boolean
	local def = Constants.MONETIZATION.GamePasses[passKey]
	if not def then
		warn(string.format("[GamePassService] Unknown pass key: %s", tostring(passKey)))
		return false
	end
	if def.id <= 0 then
		warn(string.format("[GamePassService] Pass %s has placeholder ID — REPLACE_BEFORE_LAUNCH", passKey))
		return false
	end
	if GamePassService.Owns(player, passKey) then
		return true
	end
	local ok = pcall(function()
		MarketplaceService:PromptGamePassPurchase(player, def.id)
	end)
	return ok
end

function GamePassService.Init()
	Players.PlayerAdded:Connect(function(player)
		task.spawn(primeAllForPlayer, player)
	end)
	for _, player in Players:GetPlayers() do
		task.spawn(primeAllForPlayer, player)
	end

	Players.PlayerRemoving:Connect(function(player)
		ownership[player.UserId] = nil
	end)

	-- The authoritative ownership flip per ADR-006 — when wasPurchased
	-- is true, set our cache directly without re-querying
	-- UserOwnsGamePassAsync (which would still return stale false).
	MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(player, passId, wasPurchased)
		if not wasPurchased then
			return
		end
		local key = passKeyForId(passId)
		if not key then
			return
		end
		setOwned(player, key, true)
		print(string.format("[GamePassService] %s purchased %s mid-session", player.Name, key))
	end)
end

return GamePassService
