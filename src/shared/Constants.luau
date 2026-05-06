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
		-- How many slots the rotation surfaces per cycle. Items are
		-- picked deterministically from BlueprintRegistry by rotation
		-- index so all players on all servers see the same stock.
		ShopSlotsPerRotation = 3,
		-- Phase C4 — offline progression cap (seconds).
		OfflineProgressionCapSeconds = 12 * 60 * 60,
	},

	-- Monetization (Phase D). All ID values are placeholders for V1
	-- dev — REPLACE_BEFORE_LAUNCH per the protocol's "real money flow"
	-- escalation rule (10_BUILD_PROTOCOL.md). A 0 ID makes
	-- MarketplaceService:PromptGamePassPurchase / PromptProductPurchase
	-- raise an "invalid ID" error in Studio — that's the desired
	-- developer signal.
	MONETIZATION = {
		-- Game Passes (one-time permanent unlocks per
		-- 05_MONETIZATION.md / brainstorm §2.7).
		GamePasses = {
			DoubleCredits = {
				key = "DoubleCredits",
				id = 0, -- REPLACE_BEFORE_LAUNCH
				displayName = "2× Credits",
				description = "Doubles all Credit gains permanently.",
				priceRobux = 199,
				multiplier = 2.0,
			},
			AutoCollect = {
				key = "AutoCollect",
				id = 0, -- REPLACE_BEFORE_LAUNCH
				displayName = "Auto-Collect",
				-- V1 effect (Phase D3 decision): +50% income while
				-- online. Stacks with DoubleCredits via multiplicative
				-- composition: base × 2.0 × 1.5 = ×3.0 max.
				description = "+50% income while online (stacks with 2× Credits → ×3.0 max).",
				priceRobux = 299,
				multiplier = 1.5,
			},
			VipOperator = {
				key = "VipOperator",
				id = 0, -- REPLACE_BEFORE_LAUNCH
				displayName = "VIP Operator",
				description = "Exclusive armor skin, +1 daily quest slot, VIP-only blueprints.",
				priceRobux = 499,
			},
			-- D4: Battle Pass Premium track. Tactical V1 decision —
			-- ship as a one-time GamePass (all seasons covered)
			-- rather than per-season DevProduct (industry standard).
			-- Tradeoff: simpler V1 implementation vs. lower lifetime
			-- revenue per payer. Revisit at V1.5 if revenue model
			-- needs to shift; framework already supports DevProduct
			-- swap (just stop reading GamePassService.Owns and start
			-- reading a per-season profile flag set in ProcessReceipt).
			BattlePassPremium = {
				key = "BattlePassPremium",
				id = 0, -- REPLACE_BEFORE_LAUNCH
				displayName = "Battle Pass — Premium Track",
				description = "Unlocks the Premium reward track for all seasons.",
				priceRobux = 799,
			},
		},

		-- Developer Products (consumable; per-purchase grants).
		-- Phase D2 wires ProcessReceipt + PurchaseLedger.
		DevProducts = {
			EmergencyShield = {
				key = "EmergencyShield",
				id = 0, -- REPLACE_BEFORE_LAUNCH
				displayName = "Emergency Shield",
				description = "5-minute raid immunity.",
				priceRobux = 49,
			},
			CreditPackSmall = {
				key = "CreditPackSmall",
				id = 0,
				displayName = "Credit Pack (Small)",
				description = "+10,000 Credits.",
				priceRobux = 99,
				grantCredits = 10000,
			},
			CreditPackLarge = {
				key = "CreditPackLarge",
				id = 0,
				displayName = "Credit Pack (Large)",
				description = "+75,000 Credits.",
				priceRobux = 499,
				grantCredits = 75000,
			},
			CorePack = {
				key = "CorePack",
				id = 0,
				displayName = "Core Pack",
				description = "+50 Cores.",
				priceRobux = 199,
				grantCores = 50,
			},
		},
	},

	-- Battle Pass (Phase D4). Season-scoped progression with a free
	-- and premium track. Premium ownership reads from
	-- MONETIZATION.GamePasses.BattlePassPremium via GamePassService.
	--
	-- V1 ships placeholder Credits/Cores tier rewards because the
	-- cosmetic system isn't built yet. Phase G replaces with real
	-- cosmetics per finalized-brainstorm.md §2.7's "cosmetic-only"
	-- rule. Important: Phase G must replace before launch — V1
	-- placeholder rewards technically violate the no-pay-to-win
	-- invariant.
	BATTLE_PASS = {
		SeasonId = "S1",
		MaxTier = 30,
		XpPerTier = 1000, -- linear curve; tunable in Phase G after playtest data
		-- XP awarded by event. Subscribed via QuestObjectives by
		-- BattlePassXP. Phase E adds raid_won and wave_survived.
		XpRewards = {
			quest_claimed = 100,
			claim_daily = 25,
		},
		-- Tier reward formulas (Phase G replaces with cosmetic grants).
		-- Reading these as functions keeps the curve in one place.
		FreeRewardCreditsPerTier = 100, -- free track tier N → 100*N credits
		PremiumRewardCreditsPerTier = 250, -- premium tier N → 250*N credits
		PremiumRewardCoresPerTier = 5, -- premium tier N → 5*N cores
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

	-- Raid pipeline (Phase E1). The raid system uses MemoryStoreService
	-- for the cross-server queue + snapshot + targets pool, MessagingService
	-- for matched broadcasts and outcome relay, and TeleportService's
	-- ReserveServerAsync for the raid instance.
	--
	-- Two-place architecture per ADR-009: V1 ships true two-PlaceId
	-- split. `default.project.json` builds the main `.rbxl`;
	-- `raid.project.json` builds the raid `.rbxl`. Both are published
	-- to separate PlaceIds in the same Universe via release.yml. Each
	-- bootstrap branches on `game.PrivateServerId` so the same server
	-- code can run in either context — matchmaker on main, raid round
	-- on raid place — without cross-contamination. Future Phase G can
	-- specialize raid.project.json's Workspace properties (e.g.,
	-- always-night lighting for the bioluminescent jungle ambush vibe)
	-- without touching main.
	--
	-- All real-money / placement-id-sensitive values are placeholders
	-- (REPLACE_BEFORE_LAUNCH per the protocol's escalation rule). The
	-- ReservedServerLauncher refuses to teleport with id = 0 and warns.
	RAID = {
		-- Main place id. V1 dev = 0; Phase H sets to the public-facing
		-- PlaceId. Used by the raid place to teleport attackers home.
		MainPlaceId = 0, -- REPLACE_BEFORE_LAUNCH
		-- Reserved-server target. V1 dev = 0; Phase H sets to a separate
		-- PlaceId in the same Universe (the raid place id).
		RaidPlaceId = 0, -- REPLACE_BEFORE_LAUNCH
		-- Round duration. Brainstorm §2.1: "queue into a 5-min round".
		RoundSeconds = 5 * 60,
		-- After the round ends, give the player a brief grace window in
		-- the raid place before forcing the home teleport.
		PostRoundGraceSeconds = 8,
		-- Matchmaker cadence. The elected leader runs this loop.
		MatchmakerTickSeconds = 2,
		-- An attacker who's been queued past this without being matched
		-- is auto-popped and offered a PvE wave (Phase E2 fallback).
		QueueDeadlineSeconds = 30,
		-- MemoryStoreService expirations.
		QueueEntryTtl = 90, -- queue rows; cleared on match or deadline
		SnapshotTtl = 180, -- snapshot lives just long enough to load
		TargetsTtlSeconds = 90, -- raidable-target heartbeats expire after 2 missed heartbeats
		-- How often each main server heartbeats its online players into
		-- the global "raidable" pool.
		TargetsHeartbeatSeconds = 30,
		-- Sentinel-based matchmaker leader election. First server to
		-- claim the sentinel via MemoryStore SetAsync(absent) wins for
		-- ttl seconds; the leader extends its lease each tick.
		MatchmakerSentinelKey = "raid.matchmaker.leader",
		MatchmakerSentinelTtl = 15,
		-- MemoryStoreService bucket names (single-source-of-truth).
		QueueMapName = "OutpostRaidQueue",
		TargetsMapName = "OutpostRaidableTargets",
		SnapshotMapName = "OutpostRaidSnapshots",
		SentinelMapName = "OutpostRaidSentinels",
		-- MessagingService topics.
		TopicMatched = "outpost.raid.matched",
		TopicOutcome = "outpost.raid.outcome",
		-- V1 placeholder reward bands (Phase G/E2 tunes via
		-- config/balance/raid_rewards.json).
		AttackerWinCredits = 1000,
		AttackerLossCredits = 100,
		-- Defender's consolation reward when raided (the "asynchronous
		-- defense reward" per brainstorm §2.1). Tuned in Phase G.
		DefenderRaidedCredits = 250,
	},

	-- PvE waves (Phase E2). Brainstorm §2.1: "By night, the jungle moves.
	-- Aggressive alien fauna swarm your perimeter." V1 ships one alien
	-- type (Stalker — matches the bioluminescent jungle theme) and a
	-- linear difficulty curve scaling with wave number. Phase G adds
	-- biome-specific variants (volcanic, ice cave) and tunes the curve
	-- via `config/balance/wave_scaling.json`.
	--
	-- Object pooling per CLAUDE.md "anything spawned in bulk" rule. The
	-- pool is sized to `AlienPoolSize` per server; aliens beyond that
	-- spawn fresh instances (graceful degradation if a wave overshoots
	-- the pool, but the warn surfaces tuning regressions).
	COMBAT = {
		-- How often a wave fires for every online player who has a plot.
		-- 600s = 10 min. Approximates the brainstorm's "by night, the
		-- jungle moves" cadence without needing a real day/night cycle
		-- yet (Phase G adds the cycle).
		WaveClockSeconds = 600,
		-- Wave difficulty curve. Linear: wave N spawns
		-- `AliensPerWaveBase + (N-1) * AliensPerWaveScale` aliens, capped
		-- at `AliensPerWaveCap`. V1 placeholder; Phase G tunes after
		-- playtest data shows where the difficulty wall lands.
		AliensPerWaveBase = 5,
		AliensPerWaveScale = 1,
		AliensPerWaveCap = 30,
		-- How long a wave runs before auto-ending (regardless of remaining
		-- aliens). 90s caps the round so a player who can't kill them all
		-- isn't stuck forever.
		WaveDurationSeconds = 90,
		-- Stagger spawns over this fraction of the wave duration. Prevents
		-- a "bulk Instance.new spike" footgun on wave start.
		WaveSpawnWindowSeconds = 15,
		-- Object pool size per server. V1 cap of 30 aliens × 1.5 buffer
		-- for overlap when waves stack from queue-deadline fallback +
		-- regular wave clock. Pool overflow logs and falls back to
		-- ad-hoc spawn (correct, just slower).
		AlienPoolSize = 50,
		-- Alien stats — Stalker (V1 sole type).
		AlienBaseHp = 100,
		AlienMeleeDamage = 10,
		AlienMeleeCooldownSeconds = 1.0,
		AlienWalkSpeed = 14,
		-- Spawn ring: aliens appear at the plot edge and walk toward the
		-- player. `SpawnRingPadding` is the additional distance outside
		-- the plot bounds where they spawn (so they don't clip the wall).
		SpawnRingPadding = 6,
		-- Turret stats (E2.5). The first offensive option for the player —
		-- auto-targets nearest alien within range, raycasts for damage.
		-- Phase G adds turret HP (currently invincible), targeting
		-- priorities, and projectile VFX.
		TurretRange = 40, -- studs; alien must be within this radius
		TurretDamage = 25, -- HP per shot (4 shots to kill a Stalker)
		TurretFireSeconds = 1.0, -- one shot per second per turret
		-- Turret tick cadence. Decoupled from fire cadence so a low fire
		-- rate doesn't starve targeting (e.g. tracking a moving alien
		-- between shots).
		TurretTickSeconds = 0.5,
		-- Drone swarm stats (E2.6). 3 mobile drones per player; smaller
		-- range than turrets, faster fire rate, lower per-shot damage.
		-- Combat preset is the only V1-functional preset; Recon /
		-- Engineering are catalog stubs, deferred to Phase G.
		DroneSwarmCount = 3, -- drones per player
		DroneOrbitRadius = 8, -- studs around player when no target
		DroneOrbitHeight = 4, -- studs above player's HumanoidRootPart
		DroneOrbitSpeedDeg = 90, -- degrees per second
		DroneAttackRange = 25, -- studs; mobile drones fire at closer aliens
		DroneDamage = 8, -- per shot (3 shots to kill a 24HP-remaining Stalker)
		DroneFireSeconds = 0.5, -- 2 shots/sec (vs turret 1/sec)
		DroneTickSeconds = 0.4, -- targeting cadence
		DroneMoveSpeed = 32, -- studs/sec; how fast a drone closes on a target
		-- Pool sized for the Roblox 20-default-server-cap × 3 drones
		-- per player + buffer for character respawn churn.
		DronePoolSize = 80,
	},

	-- Clan / squad system (Phase E3). 4-person max per brainstorm §2.6
	-- with a shared Credits + Cores stash; large withdrawals require
	-- leader approval (anti-grief per §4.6). Cross-server clan chat via
	-- MessagingService topic per clan.
	--
	-- Clan data lives in its own DataStore (`StoreName` below) keyed by
	-- clanId, separate from `PlayerData_v1`. Mutations go through
	-- `DataStoreService:UpdateAsync` for atomic CAS — multi-server
	-- deposits/withdrawals can't lose updates. Cache invalidation across
	-- servers is push-based via MessagingService.
	CLAN = {
		-- Membership cap (brainstorm §2.6 "4-person squads").
		MaxMembers = 4,
		-- Tag is the short visible prefix (e.g. "[OPS]") in chat /
		-- leaderboards. Name is the full title.
		TagMinLength = 2,
		TagMaxLength = 5,
		NameMinLength = 3,
		NameMaxLength = 24,
		-- Withdrawals at or below this amount are auto-approved
		-- (instant grant). Above requires leader approval. Brainstorm
		-- §4.6 anti-grief rule.
		AutoApproveWithdrawalThreshold = 5000,
		-- Maximum pending withdrawals per clan; bounds the
		-- pendingWithdrawals dictionary so a malicious member can't
		-- inflate a single clan's DataStore payload past the 4MB limit.
		MaxPendingWithdrawals = 16,
		-- Chat message length cap; F1 hardens with rate limits.
		ChatMessageMaxLength = 240,
		-- DataStore (separate keyspace from PlayerData_v1).
		StoreName = "ClanData_v1",
		-- MessagingService topics.
		ChatTopicPrefix = "outpost.clan.chat", -- per-clan suffix appended
		InvalidateTopic = "outpost.clan.invalidate",
		WithdrawalGrantTopic = "outpost.clan.withdrawal.grant",
		-- Cache TTL — cached clan data is considered stale after this
		-- many seconds and re-fetched on next access. Belt-and-suspenders
		-- next to MessagingService invalidation (handles missed
		-- broadcasts).
		CacheTtlSeconds = 60,
	},

	-- Leaderboards + friends (Phase E5). OrderedDataStore-backed
	-- per ADR-010: one store per ISO-week bucket for weekly boards
	-- (key shape `RaidWins_<isoYear>W<isoWeek>`); a single perpetual
	-- store for the lifetime global Credits board.
	--
	-- Score push cadence: each home server pushes its online players'
	-- current credits + raid-wins to the relevant OrderedDataStore
	-- every `ScorePushIntervalSeconds`. Reads (top-N for the leaderboard
	-- panel) cache per-server and refresh every `ReadCacheTtlSeconds`.
	-- The asymmetric cadence (push 60s, read 300s) keeps DataStore call
	-- volume bounded under the 2026 per-Experience quota.
	LEADERBOARD = {
		ScorePushIntervalSeconds = 60,
		ReadCacheTtlSeconds = 300,
		TopN = 50, -- entries fetched per board; client UI shows top 10 by default
		-- Store name prefixes (suffixed with bucket key for weekly).
		GlobalCreditsStoreName = "Outpost_GlobalCredits_v1",
		WeeklyRaidWinsStorePrefix = "Outpost_RaidWins_v1",
	},

	-- Friends (Phase E5). Cache `Players:GetFriendsAsync` per-session
	-- with hourly refresh. V1 only surfaces "online in this server"
	-- presence; cross-server friend presence is V1.5+ (would need a
	-- MemoryStoreService presence map; flagged as tech debt).
	FRIENDS = {
		RefreshIntervalSeconds = 60 * 60, -- 1 hour
		MaxFriendsListed = 200, -- safety cap; Roblox account caps friends at 200
	},

	-- Spatial Voice (Phase E4). Enabled at the *place* level via
	-- raid.project.json's `VoiceChatService.EnableDefaultVoice = true`.
	-- The main place inherits the platform default (off). Server-side
	-- VoiceGate is a defensive verifier + state-push so the client HUD
	-- can render an indicator when voice is active.
	--
	-- Universe-level voice toggle lives in the Roblox Creator Dashboard
	-- (NOT something Rojo can configure). Phase H prerequisite.
	--
	-- Voice availability also depends on per-account permissions:
	--   - Account is 13+
	--   - Account has voice chat enabled in Roblox account settings
	--   - User is in a region where voice chat is available
	-- We surface "voice unavailable for this user" via the VoiceState
	-- payload so the client HUD can show a muted indicator instead of
	-- a misleading "voice active" one.
	VOICE = {
		-- How often the gate verifies VoiceChatService is still in the
		-- expected state (defensive — catches a future Roblox API rename
		-- or property change). Logs once per state flip.
		VerifyIntervalSeconds = 30,
		-- Roblox 2026 Feb API: GetChatGroupsAsync diagnostic call. We
		-- use it to verify chat group membership at raid round start.
		-- If it fails, voice is degraded but not blocking — we log and
		-- continue.
		UseChatGroupDiagnostic = true,
	},
}

return Constants
