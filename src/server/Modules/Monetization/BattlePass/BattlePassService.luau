--!strict
--[[
	Outpost-7 — Battle Pass core service.

	Phase D4. Owns the per-player Battle Pass state: XP, derived tier,
	per-tier per-track claim flags. Premium ownership reads on demand
	from `GamePassService.Owns(player, "BattlePassPremium")` — no
	profile field for premium status; the GamePass is the source of
	truth.

	Season transitions: when `Constants.BATTLE_PASS.SeasonId` changes
	(e.g. SeasonId flips from "S1" to "S2" in V1.1), every player's
	XP/tier/claimed-flags reset on their next GetState/GrantXP/TryClaim.
	Premium ownership is sticky across seasons by design (single
	GamePass purchase covers all seasons — see ADR comment in
	Constants.MONETIZATION).

	Public API:
	  GetState(player)           — { seasonId, xp, tier, premiumOwned, tiers, secondsUntilSeasonEnd? }
	  GrantXP(player, amount)    — adds XP, recomputes tier, pushes state
	  TryClaim(player, tier, track) — Result-style; called from ClaimService
	  GetTierReward(tier, track) — { credits, cores } — formula owner
	  Init                       — Player join state push; BattlePassXP wires too
--]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Constants = require(Shared:WaitForChild("Constants"))
local Remotes = require(Shared:WaitForChild("Remotes"))

local DataManager = require(script.Parent.Parent.Parent.Player.DataManager)
local CurrencyService = require(script.Parent.Parent.Parent.Economy.CurrencyService)
local GamePassService = require(script.Parent.Parent.GamePassService)

local BattlePassService = {}

local PREMIUM_PASS_KEY = "BattlePassPremium"

export type TrackName = "free" | "premium"

export type TierReward = {
	credits: number,
	cores: number,
}

export type TierView = {
	tier: number,
	freeReward: TierReward,
	premiumReward: TierReward,
	freeClaimed: boolean,
	premiumClaimed: boolean,
}

export type State = {
	seasonId: string,
	xp: number,
	tier: number,
	maxTier: number,
	xpPerTier: number,
	premiumOwned: boolean,
	tiers: { TierView },
}

export type ClaimResult = {
	ok: true,
	tier: number,
	track: TrackName,
	credits: number,
	cores: number,
} | {
	ok: false,
	error: string,
}

local function tierKey(tier: number): string
	-- Stringified tier number for safe DataStore JSON round-trip.
	-- See ProfileSchema's BattlePassClaimEntry note.
	return tostring(tier)
end

local function ensureFreshSeason(data: any)
	if data.battlePassSeasonId == Constants.BATTLE_PASS.SeasonId then
		return
	end
	-- New season (or first-ever load this season): reset progression.
	-- Premium ownership is sticky across seasons because it lives in
	-- Roblox's GamePass system, not our profile — so the player who
	-- bought premium for S1 still has it in S2.
	data.battlePassSeasonId = Constants.BATTLE_PASS.SeasonId
	data.battlePassXP = 0
	data.battlePassTier = 0
	data.battlePassClaimed = {}
end

local function tierForXP(xp: number): number
	if xp <= 0 then
		return 0
	end
	local tier = math.floor(xp / Constants.BATTLE_PASS.XpPerTier)
	return math.min(tier, Constants.BATTLE_PASS.MaxTier)
end

function BattlePassService.GetTierReward(tier: number, track: TrackName): TierReward
	if track == "free" then
		return {
			credits = Constants.BATTLE_PASS.FreeRewardCreditsPerTier * tier,
			cores = 0,
		}
	end
	-- premium
	return {
		credits = Constants.BATTLE_PASS.PremiumRewardCreditsPerTier * tier,
		cores = Constants.BATTLE_PASS.PremiumRewardCoresPerTier * tier,
	}
end

function BattlePassService.GetState(player: Player): State?
	local data = DataManager.GetData(player)
	if not data then
		return nil
	end
	ensureFreshSeason(data)

	local premiumOwned = GamePassService.Owns(player, PREMIUM_PASS_KEY)

	local tiers: { TierView } = {}
	for tier = 1, Constants.BATTLE_PASS.MaxTier do
		local key = tierKey(tier)
		local claimed = data.battlePassClaimed[key]
		table.insert(tiers, {
			tier = tier,
			freeReward = BattlePassService.GetTierReward(tier, "free"),
			premiumReward = BattlePassService.GetTierReward(tier, "premium"),
			freeClaimed = if claimed then claimed.free else false,
			premiumClaimed = if claimed then claimed.premium else false,
		})
	end

	return {
		seasonId = Constants.BATTLE_PASS.SeasonId,
		xp = data.battlePassXP,
		tier = data.battlePassTier,
		maxTier = Constants.BATTLE_PASS.MaxTier,
		xpPerTier = Constants.BATTLE_PASS.XpPerTier,
		premiumOwned = premiumOwned,
		tiers = tiers,
	}
end

local function pushStateToClient(player: Player)
	local state = BattlePassService.GetState(player)
	if not state then
		return
	end
	local remote = Remotes.BattlePassState :: RemoteEvent
	remote:FireClient(player, state)
end

function BattlePassService.GrantXP(player: Player, amount: number): number?
	if amount <= 0 then
		return nil
	end
	local data = DataManager.GetData(player)
	if not data then
		return nil
	end
	ensureFreshSeason(data)

	local oldTier = data.battlePassTier
	data.battlePassXP += amount
	data.battlePassTier = tierForXP(data.battlePassXP)

	if data.battlePassTier > oldTier then
		print(
			string.format(
				"[BattlePassService] %s tier-up: %d → %d (XP=%d)",
				player.Name,
				oldTier,
				data.battlePassTier,
				data.battlePassXP
			)
		)
	end

	pushStateToClient(player)
	return data.battlePassTier
end

function BattlePassService.TryClaim(player: Player, tier: number, track: TrackName): ClaimResult
	local data = DataManager.GetData(player)
	if not data then
		return { ok = false, error = "no profile" }
	end
	ensureFreshSeason(data)

	if typeof(tier) ~= "number" or tier ~= math.floor(tier) then
		return { ok = false, error = "invalid tier" }
	end
	if tier < 1 or tier > Constants.BATTLE_PASS.MaxTier then
		return { ok = false, error = "tier out of range" }
	end
	if track ~= "free" and track ~= "premium" then
		return { ok = false, error = "invalid track" }
	end
	if data.battlePassTier < tier then
		return { ok = false, error = "tier not yet reached" }
	end
	if track == "premium" and not GamePassService.Owns(player, PREMIUM_PASS_KEY) then
		return { ok = false, error = "Premium track required" }
	end

	local key = tierKey(tier)
	local entry = data.battlePassClaimed[key]
	if not entry then
		entry = { free = false, premium = false }
		data.battlePassClaimed[key] = entry
	end
	if track == "free" and entry.free then
		return { ok = false, error = "already claimed (free)" }
	end
	if track == "premium" and entry.premium then
		return { ok = false, error = "already claimed (premium)" }
	end

	local reward = BattlePassService.GetTierReward(tier, track)
	if reward.credits > 0 then
		CurrencyService.Add(player, reward.credits)
	end
	if reward.cores > 0 then
		CurrencyService.AddCores(player, reward.cores)
	end

	if track == "free" then
		entry.free = true
	else
		entry.premium = true
	end

	pushStateToClient(player)

	print(
		string.format(
			"[BattlePassService] %s claimed S%s tier %d (%s) → +%d credits, +%d cores",
			player.Name,
			Constants.BATTLE_PASS.SeasonId,
			tier,
			track,
			reward.credits,
			reward.cores
		)
	)

	return {
		ok = true,
		tier = tier,
		track = track,
		credits = reward.credits,
		cores = reward.cores,
	}
end

function BattlePassService.Init()
	-- Push initial state on join (after profile loads).
	Players.PlayerAdded:Connect(function(player)
		task.spawn(function()
			DataManager.WaitForData(player)
			pushStateToClient(player)
		end)
	end)

	-- Re-push when premium ownership flips (mid-session purchase) so
	-- the panel reveals premium-only tier rewards as claimable.
	GamePassService.OnOwnershipChanged:Connect(function(player, passKey)
		if passKey == PREMIUM_PASS_KEY then
			pushStateToClient(player)
		end
	end)
end

return BattlePassService
