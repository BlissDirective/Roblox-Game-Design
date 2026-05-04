--!strict
--[[
	Outpost-7 — shop blueprint catalog (server-side).

	Phase C2. The pool ShopService draws from each 6h rotation. Each
	entry has a `weight` (relative likelihood of appearing in a given
	rotation) and a `rarity` tag (informational, drives UI tinting).

	V1 ships placeholder content: Credit Caches that grant net-positive
	Credits at a cost (so a Jackpot rotation rewards the engaged player
	who checks 4× a day). Phase E expands the catalog with actual
	blueprint unlocks (turret variants, drone-bay configs, etc.) once
	those buildables exist.

	Per finalized-brainstorm.md §2.4: rare blueprints appear in 24h
	rotations. We lean on weighting rather than hard cadence — at
	weight 1, a Rare item shows roughly once every ~17 rotations
	(~4 days) given the V1 weights. Phase G tunes for
	"hits ~every 24h, sometimes sooner".
--]]

local BlueprintRegistry = {}

export type Rarity = "Common" | "Uncommon" | "Rare"

export type Blueprint = {
	id: string,
	displayName: string,
	description: string,
	rarity: Rarity,
	weight: number, -- relative pick weight in the rotation pool
	cost: number, -- Credits charged on purchase
	-- V1 effect: grant Credits directly. Phase E may add other effect
	-- shapes (`grantBuildableUnlock`, `applyTempMultiplier`, etc.); for
	-- now this single field keeps ShopService simple.
	grantCredits: number,
}

local CATALOG: { [string]: Blueprint } = {
	cred_pack_s = {
		id = "cred_pack_s",
		displayName = "Credit Cache (S)",
		description = "+200 Credits",
		rarity = "Common",
		weight = 5,
		cost = 100,
		grantCredits = 200,
	},
	cred_pack_m = {
		id = "cred_pack_m",
		displayName = "Credit Cache (M)",
		description = "+400 Credits",
		rarity = "Common",
		weight = 5,
		cost = 200,
		grantCredits = 400,
	},
	cred_pack_l = {
		id = "cred_pack_l",
		displayName = "Credit Cache (L)",
		description = "+600 Credits",
		rarity = "Common",
		weight = 5,
		cost = 300,
		grantCredits = 600,
	},
	cred_pack_xl = {
		id = "cred_pack_xl",
		displayName = "Credit Cache (XL)",
		description = "+1500 Credits",
		rarity = "Uncommon",
		weight = 2,
		cost = 600,
		grantCredits = 1500,
	},
	cred_pack_xxl = {
		id = "cred_pack_xxl",
		displayName = "Credit Cache (XXL)",
		description = "+3000 Credits",
		rarity = "Uncommon",
		weight = 2,
		cost = 1100,
		grantCredits = 3000,
	},
	cred_pack_jackpot = {
		id = "cred_pack_jackpot",
		displayName = "Operator Jackpot",
		description = "+10,000 Credits",
		rarity = "Rare",
		weight = 1,
		cost = 3000,
		grantCredits = 10000,
	},
}

function BlueprintRegistry.Get(id: string): Blueprint?
	return CATALOG[id]
end

function BlueprintRegistry.GetAll(): { [string]: Blueprint }
	return CATALOG
end

function BlueprintRegistry.IsValidId(id: string): boolean
	return CATALOG[id] ~= nil
end

return BlueprintRegistry
