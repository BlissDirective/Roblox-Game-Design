--!strict
--[[
	Outpost-7 — receipt idempotency ledger.

	Phase D2. Thin façade over `profile.Data.purchaseHistory: { [string]: true }`.
	Roblox can fire `MarketplaceService.ProcessReceipt` more than once
	for the same logical purchase (network retries, client teleports
	mid-flow, server crashes). The ledger keys on the unique
	`PurchaseId` Roblox issues per receipt; if we've seen it, we skip
	the grant and return `PurchaseGranted` so Roblox stops retrying.

	Crash safety: ledger entries live in `profile.Data` alongside
	whatever the grant mutated (credits, cores, etc.). ProfileStore's
	auto-save flushes them together on the same DataStore write. If
	the server crashes between grant and flush, **both** the grant
	AND the ledger entry revert; the next ProcessReceipt retry
	re-grants from a clean slate, producing the correct net effect
	(player gets the purchase exactly once).

	Public API:
	  HasPurchase(player, purchaseId)    — non-yielding read
	  RecordPurchase(player, purchaseId) — non-yielding write
--]]

local DataManager = require(script.Parent.Parent.Player.DataManager)

local PurchaseLedger = {}

local function getHistory(player: Player): { [string]: boolean }?
	local data = DataManager.GetData(player)
	if not data then
		return nil
	end
	-- Defensive: older saves loaded before Reconcile() ran might
	-- lack the field. ProfileStore handles this, but a manual nil
	-- fill is cheap insurance.
	if not data.purchaseHistory then
		data.purchaseHistory = {}
	end
	return data.purchaseHistory
end

function PurchaseLedger.HasPurchase(player: Player, purchaseId: string): boolean
	local history = getHistory(player)
	if not history then
		return false
	end
	return history[purchaseId] == true
end

function PurchaseLedger.RecordPurchase(player: Player, purchaseId: string)
	local history = getHistory(player)
	if not history then
		return
	end
	history[purchaseId] = true
end

return PurchaseLedger
