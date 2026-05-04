--!strict
--[[
	Outpost-7 — centralized tunables, feature flags, and configuration.

	Phase A1: FEATURES table.
	Phase A3: structural sections (DATASTORE, RATE_LIMITS, TICK, GRID).
	Phase B1: WORLD (plots, dimensions), NODES (spawner params), BUILD
	          (placement reach), STREAMING (radii).
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

		-- Debug aids — leave true through Phase F4, flip false for ship.
		debugModeToggle = true, -- B5: keybind to swap TP↔FP without combat present
	},

	-- DataStore configuration. Read by DataManager.
	DATASTORE = {
		StoreName = "PlayerData_v1",
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

	-- Retention mechanics (Phase C). All values picked per
	-- finalized-brainstorm.md §2.4 and §4.4. Server-only enforcement.
	RETENTION = {
		-- Daily login reward by streak day. The default fallback is
		-- DailyRewards[7] for any non-milestone day past day 7. Day-14
		-- and day-30 are milestone bumps to reward sustained streaks.
		-- Tunable in Phase G after playtest data lands.
		DailyRewards = {
			[1] = 500,
			[2] = 750,
			[3] = 1000,
			[4] = 1500,
			[5] = 2000,
			[6] = 3000,
			[7] = 5000,
			[14] = 15000,
			[30] = 50000,
		},
		-- "yesterday" by UTC date counts as in-streak; anything older
		-- resets to day 1. The brainstorm calls this the "24h grace
		-- window" — interpreted as a one-day-late tolerance.
		StreakGraceDays = 1,
		-- Phase C2 — restocking shop (UTC seconds per rotation).
		ShopRotationSeconds = 6 * 60 * 60,
		-- Phase C4 — offline progression cap (seconds).
		OfflineProgressionCapSeconds = 12 * 60 * 60,
	},

	-- World layout. V1 ships with a single shared server containing
	-- N fixed plots. Each plot is a square of `PlotSize` studs centered
	-- on its origin. Plots are arranged in a 2×2 grid with a `PlotGap`
	-- gutter between them.
	WORLD = {
		PlotCount = 4, -- 2×2 grid; matches squad max (4) per finalized-brainstorm.md §2.6
		PlotSize = 64, -- studs; mobile-camera-friendly footprint
		PlotGap = 32, -- studs between adjacent plots
		BaseY = 0, -- world Y of all plot floors
		PlotFloorThickness = 1,
	},

	-- Resource node spawner params (Phase B1). Per-plot Poisson disk
	-- distribution: `MinDistance` controls density, `MaxAttemptsPerCell`
	-- caps how hard the sampler tries before giving up. The seed is
	-- derived per-server from `game.JobId` so re-rolls during dev get
	-- a different layout — but every player on a given server sees the
	-- same nodes.
	NODES = {
		PerPlotTarget = 10, -- aim for ~10 nodes per plot
		MinDistance = 8, -- studs between any two nodes
		MaxAttemptsPerCell = 30, -- Bridson's recommended k value
		EdgeMargin = 4, -- nodes don't spawn within N studs of plot edges
		HeightOffset = 0.5, -- node visual sits this far above plot floor
		Radius = 1, -- node visual radius (studs)
	},

	-- Placement validation. PlacementService enforces these.
	BUILD = {
		MaxReachStuds = 32, -- a player must be within this distance of a
		-- claimed cell to place / interact (anti-cheat
		-- rough cut; F1 hardens with server-side raycast)
		ExtractorRequiresNode = true, -- extractors must be placed on a node cell
	},

	-- Workspace.StreamingEnabled tuning. Conservative radii for a
	-- 128×128 stud world (4 plots + gaps). Re-evaluate when biomes
	-- expand in Phase G.
	STREAMING = {
		MinRadius = 256,
		MaxRadius = 512,
		-- Plot-reset destroys: batch this many per task.wait() tick to
		-- dodge the "bulk-destroy ping spike" footgun documented on the
		-- Roblox DevForum for tycoon games using StreamingEnabled.
		BulkDestroyBatchSize = 8,
		BulkDestroyBatchDelay = 0.05, -- seconds
	},
}

return Constants
