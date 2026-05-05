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

local GamePassService = require(script.Parent.GamePassService)
local DevProductService = require(script.Parent.DevProductService)
local PassEffects = require(script.Parent.PassEffects)

local MonetizationService = {}

function MonetizationService.Init()
	GamePassService.Init()
	DevProductService.Init()
	-- PassEffects must Init AFTER GamePassService so its subscription
	-- to OnOwnershipChanged is in place before the first prime.
	PassEffects.Init()
	-- D4: BattlePassService.Init().
end

return MonetizationService
