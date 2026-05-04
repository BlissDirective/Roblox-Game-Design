--!strict
--[[
	Outpost-7 — centralized tunables, feature flags, and configuration.

	Phase A1: FEATURES table.
	Phase A3: structural sections (DATASTORE, RATE_LIMITS, TICK, GRID).
	Subsequent phases populate values as the systems they back come online.

	Rule: no hardcoded magic numbers in modules. If a value needs tuning,
	it lives here — or, if it's content-shaped (quest text, biome data,
	balance curves), it lives in /config and is loaded via
	src/shared/Modules/Config/.
--]]

local Constants = {
	-- Feature flags. V1.5 / V2 work lands behind these gates so `main` stays
	-- shippable. Flip false → true when the gated system is audit-ready.
	-- See ROADMAP.md for the staged rollout list.
	FEATURES = {
		tradingMarketplace = false, -- V1.5
		autoClipReplay = false, -- V1.5
		crossBiomeTrading = false, -- V1.5
		playerBuiltArenas = false, -- V2
		coopColonies = false, -- V2
		cosmeticGacha = false, -- V2
	},

	-- DataStore configuration. Read by DataManager.
	DATASTORE = {
		StoreName = "PlayerData_v1",
		-- Hard ceiling on BindToClose flush wait. Roblox enforces a 30s
		-- BindToClose budget; we leave 5s headroom for the engine to
		-- complete its own teardown after we return.
		BindToCloseTimeoutSeconds = 25,
	},

	-- Per-player Remote rate limits in calls/second. Used by
	-- Server.Security.AntiExploit.RateCheck. The default is the floor;
	-- specific Remotes override per docs/architecture/REMOTES_REGISTRY.md.
	-- Tuned in Phase F1.
	RATE_LIMITS = {
		Default = 10,
		Placement = 60, -- build-mode placement bursts
		Purchase = 1, -- monetization Remotes
	},

	-- Game cadence (seconds unless noted). Per-system tick rates.
	TICK = {
		Currency = 1, -- Phase B2
	},

	-- Build-mode geometry. Mobile-thumb-friendly grid per Phase B4 plan.
	GRID = {
		Size = 4, -- studs
	},
}

return Constants
