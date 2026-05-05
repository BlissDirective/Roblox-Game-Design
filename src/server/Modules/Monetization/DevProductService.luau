--!strict
--[[
	Outpost-7 — Developer Product purchase processing.

	Phase D2. Sets `MarketplaceService.ProcessReceipt` and routes
	receipts through `PurchaseLedger` for idempotency. This is the
	single registered ProcessReceipt callback in the entire game per
	Roblox's "set once" rule.

	Flow on each receipt:
	  1. Resolve player from receipt.PlayerId. If they're not in this
	     server, return NotProcessedYet — Roblox retries on next join.
	  2. WaitForData so the profile + ledger are ready.
	  3. Idempotency check via PurchaseLedger.HasPurchase. Hit →
	     return PurchaseGranted (we already gave them the item).
	  4. Resolve product key from receipt.ProductId via the
	     Constants.MONETIZATION.DevProducts table.
	  5. Apply the effect (V1: grantCredits + grantCores; Phase E
	     extends with Emergency Shield's raid-immunity timer).
	  6. Record the purchaseId in the ledger.
	  7. Return PurchaseGranted.

	V1 dev caveat: all DevProduct IDs are placeholder 0 in
	Constants.MONETIZATION (REPLACE_BEFORE_LAUNCH). Studio's purchase
	prompt rejects ID=0, so this callback only fires once real IDs
	land in Phase H. The audit recipe in PHASE_D_MONETIZATION.md
	covers the manual Command-Bar invocation path.
--]]

local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Constants = require(Shared:WaitForChild("Constants"))

local DataManager = require(script.Parent.Parent.Player.DataManager)
local CurrencyService = require(script.Parent.Parent.Economy.CurrencyService)
local PurchaseLedger = require(script.Parent.PurchaseLedger)

local DevProductService = {}

type DevProductDef = {
	key: string,
	id: number,
	displayName: string,
	description: string,
	priceRobux: number,
	grantCredits: number?,
	grantCores: number?,
}

local function findProductByID(productId: number): DevProductDef?
	for _, def in Constants.MONETIZATION.DevProducts do
		if def.id == productId then
			return def
		end
	end
	return nil
end

local function applyEffect(player: Player, def: DevProductDef): boolean
	-- V1 effect surface: direct currency grants. Phase E extends with
	-- Emergency Shield's per-player raid-immunity timer.
	local applied = false
	if def.grantCredits and def.grantCredits > 0 then
		CurrencyService.Add(player, def.grantCredits)
		applied = true
	end
	if def.grantCores and def.grantCores > 0 then
		CurrencyService.AddCores(player, def.grantCores)
		applied = true
	end
	-- A product that grants nothing (all 0/nil) means we have a
	-- catalog entry for a product we don't yet know how to handle —
	-- Emergency Shield in V1 is in this state. Return false so the
	-- receipt comes back as NotProcessedYet rather than silently
	-- granting nothing for real money.
	if not applied then
		warn(
			string.format(
				"[DevProductService] No effect implemented for product %s — returning NotProcessedYet",
				def.key
			)
		)
		return false
	end
	return true
end

function DevProductService.ProcessReceipt(receiptInfo: any): Enum.ProductPurchaseDecision
	local player = Players:GetPlayerByUserId(receiptInfo.PlayerId)
	if not player then
		-- Player isn't in this server (left between prompt and process,
		-- or teleported). Roblox will retry on their next join.
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end

	-- Wait for profile to load. ProcessReceipt can fire very early in
	-- a session — before DataManager.LoadPlayer completes — and
	-- granting against a nil profile would silently lose the purchase.
	local data = DataManager.WaitForData(player)
	if not data then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end

	-- Idempotency: same purchaseId twice → return PurchaseGranted
	-- without re-applying. Roblox stops retrying.
	if PurchaseLedger.HasPurchase(player, receiptInfo.PurchaseId) then
		print(
			string.format(
				"[DevProductService] Idempotent skip: %s already had purchase %s",
				player.Name,
				tostring(receiptInfo.PurchaseId)
			)
		)
		return Enum.ProductPurchaseDecision.PurchaseGranted
	end

	-- Resolve product. NotProcessedYet so Roblox retries — the only
	-- way this fires for a known-issued product is if Constants got
	-- out of sync with the live product catalog (deployment drift).
	local def = findProductByID(receiptInfo.ProductId)
	if not def then
		warn(
			string.format(
				"[DevProductService] Unknown product ID %s for %s — returning NotProcessedYet",
				tostring(receiptInfo.ProductId),
				player.Name
			)
		)
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end

	-- Apply effect first; ledger record only on success. If apply
	-- returns false we return NotProcessedYet so Roblox retries
	-- (the player paid for something we can't yet deliver — hold
	-- the line until we ship the effect, don't burn the receipt).
	if not applyEffect(player, def) then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end

	PurchaseLedger.RecordPurchase(player, receiptInfo.PurchaseId)

	print(
		string.format(
			"[DevProductService] Granted %s to %s (purchaseId=%s)",
			def.key,
			player.Name,
			tostring(receiptInfo.PurchaseId)
		)
	)
	return Enum.ProductPurchaseDecision.PurchaseGranted
end

function DevProductService.Init()
	-- Roblox enforces "set once per server" — this is the only place
	-- ProcessReceipt should be assigned in the entire game.
	MarketplaceService.ProcessReceipt = DevProductService.ProcessReceipt
end

return DevProductService
