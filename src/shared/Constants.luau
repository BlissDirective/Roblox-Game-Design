--!strict
-- Outpost-7 — centralized tunables, feature flags, and configuration keys.
--
-- Phase A1 scaffold: feature flags only. Subsequent phases populate sections
-- as systems land (rate limits, tick rates, costs, durations, …).
--
-- Rule: no hardcoded magic numbers in modules. If a value needs tuning, it
-- lives here (or, if it's content-shaped, in /config and is loaded via
-- src/shared/Modules/Config/).

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
}

return Constants
