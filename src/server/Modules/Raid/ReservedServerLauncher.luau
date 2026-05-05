--!strict
--[[
	Outpost-7 — reserved-server allocation + teleport.

	Phase E1. Wraps `TeleportService:ReserveServerAsync` (the modern
	replacement for the deprecated `ReserveServer`) and
	`TeleportService:TeleportToPrivateServer`. Carries the snapshot id
	and role data via `setTeleportData`, so the raid place can read it
	on join via `Player:GetJoinData()`.

	V1 dev: `Constants.RAID.RaidPlaceId == 0`. The launcher refuses to
	teleport with a placeholder id and warns. Real id lands at Phase H.

	Public API:
	  ReserveAndTeleport(attacker, snapshot)  — yielding; returns ok
--]]

local TeleportService = game:GetService("TeleportService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Constants = require(Shared:WaitForChild("Constants"))

local RaidSnapshot = require(script.Parent.RaidSnapshot)

local ReservedServerLauncher = {}

export type TeleportData = {
	snapshotId: string,
	defenderUserId: number,
	defenderName: string,
	attackerUserId: number,
	roundSeconds: number,
	startedAt: number, -- os.time(), used by the raid place to derive end time
}

function ReservedServerLauncher.ReserveAndTeleport(attacker: Player, snapshot: RaidSnapshot.Snapshot): boolean
	local placeId = Constants.RAID.RaidPlaceId
	if placeId <= 0 then
		warn(
			string.format(
				"[ReservedServerLauncher] RaidPlaceId is placeholder (%d) — REPLACE_BEFORE_LAUNCH; refusing teleport for %s",
				placeId,
				attacker.Name
			)
		)
		return false
	end

	-- ReserveServerAsync replaces the deprecated ReserveServer. Returns
	-- (accessCode, privateServerId).
	local reserveOk, accessCode, privateServerId = pcall(function()
		return TeleportService:ReserveServerAsync(placeId)
	end)
	if not reserveOk or typeof(accessCode) ~= "string" then
		warn(
			string.format(
				"[ReservedServerLauncher] ReserveServerAsync failed for placeId=%d: %s",
				placeId,
				tostring(accessCode)
			)
		)
		return false
	end

	local teleportData: TeleportData = {
		snapshotId = snapshot.snapshotId,
		defenderUserId = snapshot.defenderUserId,
		defenderName = snapshot.defenderName,
		attackerUserId = attacker.UserId,
		roundSeconds = Constants.RAID.RoundSeconds,
		startedAt = os.time(),
	}

	-- Use TeleportToPrivateServer (still supported in 2026; ReserveServer
	-- was the only deprecated half of the pair).
	local teleportOk, err = pcall(function()
		TeleportService:TeleportToPrivateServer(placeId, accessCode, { attacker }, nil, teleportData)
	end)
	if not teleportOk then
		warn(
			string.format(
				"[ReservedServerLauncher] TeleportToPrivateServer failed for %s (privateServerId=%s): %s",
				attacker.Name,
				tostring(privateServerId),
				tostring(err)
			)
		)
		return false
	end

	print(
		string.format(
			"[ReservedServerLauncher] Reserved raid server for %s → private=%s, snapshot=%s",
			attacker.Name,
			tostring(privateServerId),
			snapshot.snapshotId
		)
	)
	return true
end

return ReservedServerLauncher
