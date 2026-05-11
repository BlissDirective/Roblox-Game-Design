--!strict
--[[
	Outpost-7 — top-level monetization orchestrator.

	Phase D1. Thin wrapper that initializes the monetization sub-
	systems in the right order and exposes a single Init() to the
	server bootstrap. As D2–D5 land, additional sub-services
	(DevProductService, PassEffects, BattlePassService, Cosmetics)
	wire in here.

	Why a top-level orchestrator vs. flat init.server: the
	monetization stack has internal dependencies (PassEffects depends
	on GamePassService's cache being primed; ProcessReceipt depends
	on PurchaseLedger being live). Centralizing here keeps that
	ordering inside the monetization module rather than spreading
	through init.server.luau.
--]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Constants = require(Shared:WaitForChild("Constants"))
local Remotes = require(Shared:WaitForChild("Remotes"))

local GamePassService = require(script.Parent.GamePassService)
local DevProductService = require(script.Parent.DevProductService)
local PassEffects = require(script.Parent.PassEffects)
local BattlePassService = require(script.Parent.BattlePass.BattlePassService)
local BattlePassXP = require(script.Parent.BattlePass.BattlePassXP)
local BattlePassClaimService = require(script.Parent.BattlePass.ClaimService)

local MonetizationService = {}

-- D5: builds a snapshot of which GamePasses the player owns and pushes
-- it down the OwnershipState Remote. Client uses this to render
-- "Owned" badges in the pass shop without re-querying
-- UserOwnsGamePassAsync (which is stale per ADR-006). Server is the
-- source of truth.
local function pushOwnershipState(player: Player)
	local ownership: { [string]: boolean } = {}
	for key in Constants.MONETIZATION.GamePasses do
		ownership[key] = GamePassService.Owns(player, key)
	end
	local remote = Remotes.OwnershipState :: RemoteEvent
	remote:FireClient(player, ownership)
end

function MonetizationService.Init()
	GamePassService.Init()
	DevProductService.Init()
	-- PassEffects must Init AFTER GamePassService so its subscription
	-- to OnOwnershipChanged is in place before the first prime.
	PassEffects.Init()
	-- BattlePassService also subscribes to OnOwnershipChanged for the
	-- premium track flip; same ordering rule.
	BattlePassService.Init()
	-- BattlePassXP subscribes to QuestObjectives; idempotent to call
	-- Init in any order relative to DailyQuestManager.
	BattlePassXP.Init()
	BattlePassClaimService.Init()

	-- OwnershipState replication. Push on every ownership flip
	-- (initial prime fires once per pass; rapid mid-session purchase
	-- fires once per pass). Each push is a small map (≤ ~6 keys at V1
	-- catalog size); chattiness is negligible.
	GamePassService.OnOwnershipChanged:Connect(function(player)
		pushOwnershipState(player)
	end)

	-- G7: Pass-bound cosmetic grants. When ownership flips to true,
	-- grant the cosmetics listed in Constants.COSMETIC.PassUnlocks for
	-- that pass. Per user-approved G7 design (2026-05-05): unlock-only
	-- + toast (CosmeticService fires the toast Remote internally).
	-- Lazy-require to avoid load-time cycle with Cosmetics module.
	GamePassService.OnOwnershipChanged:Connect(function(player: Player, passKey: string, owned: boolean)
		if not owned then
			return
		end
		local unlocks = Constants.COSMETIC.PassUnlocks[passKey]
		if not unlocks then
			return
		end
		local CosmeticService = require(script.Parent.Parent.Cosmetics.CosmeticService)
		for _, cosmeticId in unlocks do
			CosmeticService.GrantCosmetic(player, cosmeticId)
		end
	end)

	-- Push an initial state on join in case the player connects before
	-- any OnOwnershipChanged fires (e.g. all passes default to "not
	-- owned" with placeholder IDs — no flip occurs and the client
	-- otherwise sees no state).
	Players.PlayerAdded:Connect(function(player)
		task.spawn(function()
			-- Wait briefly for primeAllForPlayer to complete its first
			-- pass; without this the snapshot may be empty.
			task.wait(1)
			if player:IsDescendantOf(Players) then
				pushOwnershipState(player)
			end
		end)
	end)
	for _, player in Players:GetPlayers() do
		task.spawn(pushOwnershipState, player)
	end
end

return MonetizationService
