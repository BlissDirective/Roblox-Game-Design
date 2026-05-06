--!strict
--[[
	Outpost-7 — clan/squad lifecycle (4-person max, shared stash,
	cross-server cache).

	Phase E3. Owns the persistent ClanData_v1 DataStore plus per-server
	in-memory cache. All mutations go through `MutateClan` which wraps
	`DataStoreService:UpdateAsync` for atomic CAS — multi-server
	deposits/withdrawals/joins can't lose updates.

	Cache invalidation: every mutation publishes `outpost.clan.invalidate`
	via MessagingService with the affected clanId. All servers subscribe
	and drop the cache entry; next access re-fetches. Belt-and-suspenders
	`CacheTtlSeconds` covers missed broadcasts (network blip, server
	crash mid-publish).

	Trust boundary: every Remote is server-validated. Names + tags are
	length-checked + character-class-restricted (alnum + space). Role
	checks (leader/officer/member) on every mutation that requires
	elevation. The client never sends a role — it sends an action and
	the server decides.

	Public API (read):
	  Init                         — Remotes wire + MessagingService
	                                 subscribe + PlayerAdded state push
	  GetCachedClanForPlayer(p)    — non-yielding; nil if cache miss /
	                                 unaffiliated
	  GetClan(clanId)              — yielding; loads via DataStore on miss
	  GetClanForPlayer(player)     — yielding; reads profile.clanId then
	                                 loads
	  PushStateToPlayer(player)    — fires ClanState Remote
	  IsLeader(clan, userId)       — non-yielding role check
	  IsOfficer(clan, userId)      — non-yielding role check (returns
	                                 true for leader too)
	  IsMember(clan, userId)       — non-yielding membership check

	Public API (write):
	  MutateClan(clanId, mutator)  — yielding; runs mutator inside
	                                 UpdateAsync, publishes invalidate;
	                                 mutator returns nil to abort
	  TryCreateClan(player, name, tag)
	  TryJoinClan(player, clanId)
	  TryLeaveClan(player)
	  TryKickMember(actor, targetUserId)

	Stash + chat operations live in their dedicated modules
	(ClanStashLedger, ClanChatService) but route writes through
	`MutateClan` to keep the atomicity invariant in one place.
--]]

local DataStoreService = game:GetService("DataStoreService")
local HttpService = game:GetService("HttpService")
local MessagingService = game:GetService("MessagingService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Constants = require(Shared:WaitForChild("Constants"))
local Remotes = require(Shared:WaitForChild("Remotes"))

local DataManager = require(script.Parent.Parent.Player.DataManager)
local AntiExploit = require(script.Parent.Parent.Security.AntiExploit)
local AuditLog = require(script.Parent.Parent.Security.AuditLog)
local RemoteValidator = require(script.Parent.Parent.Security.RemoteValidator)

local ClanService = {}

export type ClanRole = "leader" | "officer" | "member"

export type ClanMember = {
	userId: number,
	name: string,
	role: ClanRole,
	joinedAt: number,
}

export type PendingWithdrawal = {
	withdrawalId: string,
	requesterUserId: number,
	requesterName: string,
	amount: number,
	requestedAt: number,
}

-- Persisted shape (one row per clanId in ClanData_v1).
export type ClanData = {
	clanId: string,
	name: string,
	tag: string,
	createdAt: number,
	leaderUserId: number,
	-- Members keyed by tostring(userId) for stable JSON round-trip.
	members: { [string]: ClanMember },
	stashCredits: number,
	stashCores: number,
	pendingWithdrawals: { [string]: PendingWithdrawal },
	schemaVersion: number,
}

-- Client-facing snapshot. Mirrors ClanData but with the player's own
-- role surfaced for UI gating.
export type State = {
	clanId: string,
	name: string,
	tag: string,
	createdAt: number,
	leaderUserId: number,
	members: { ClanMember }, -- array form for stable client-side iteration
	stashCredits: number,
	stashCores: number,
	pendingWithdrawals: { PendingWithdrawal },
	youAre: ClanRole?,
}

export type Result = {
	ok: true,
	state: State?,
	-- Some mutations carry extra payload (e.g. created clanId).
	clanId: string?,
	withdrawalId: string?,
} | {
	ok: false,
	error: string,
}

local CURRENT_SCHEMA_VERSION = 1
local NAME_PATTERN = "^[%w%s]+$"
local TAG_PATTERN = "^[%w]+$"

local clanStore: DataStore = DataStoreService:GetDataStore(Constants.CLAN.StoreName)

-- Per-server cache. Keyed by clanId.
type CacheEntry = { data: ClanData, fetchedAt: number }
local cache: { [string]: CacheEntry } = {}

-- Forward decl for cross-module use.
local pushStateForClanMembers

local function newClanId(): string
	-- HttpService:GenerateGUID returns "{xxxxxxxx-xxxx-...}". Strip braces
	-- so the clanId can be used unmodified as a DataStore key + chat topic
	-- suffix.
	local guid = HttpService:GenerateGUID(false)
	return guid
end

local function nowSec(): number
	return os.time()
end

local function isCacheFresh(entry: CacheEntry?): boolean
	if not entry then
		return false
	end
	return nowSec() - entry.fetchedAt < Constants.CLAN.CacheTtlSeconds
end

local function invalidate(clanId: string)
	cache[clanId] = nil
end

local function publishInvalidate(clanId: string)
	local ok, err = pcall(function()
		MessagingService:PublishAsync(Constants.CLAN.InvalidateTopic, { clanId = clanId })
	end)
	if not ok then
		warn(string.format("[ClanService] PublishAsync(invalidate) failed: %s", tostring(err)))
	end
end

local function memberArray(data: ClanData): { ClanMember }
	local arr: { ClanMember } = {}
	for _, member in data.members do
		table.insert(arr, member)
	end
	table.sort(arr, function(a, b)
		return a.joinedAt < b.joinedAt
	end)
	return arr
end

local function pendingArray(data: ClanData): { PendingWithdrawal }
	local arr: { PendingWithdrawal } = {}
	for _, w in data.pendingWithdrawals do
		table.insert(arr, w)
	end
	table.sort(arr, function(a, b)
		return a.requestedAt < b.requestedAt
	end)
	return arr
end

local function buildStateForPlayer(data: ClanData, userId: number): State
	local memberKey = tostring(userId)
	local self_ = data.members[memberKey]
	return {
		clanId = data.clanId,
		name = data.name,
		tag = data.tag,
		createdAt = data.createdAt,
		leaderUserId = data.leaderUserId,
		members = memberArray(data),
		stashCredits = data.stashCredits,
		stashCores = data.stashCores,
		pendingWithdrawals = pendingArray(data),
		youAre = if self_ then self_.role else nil,
	}
end

function ClanService.IsMember(data: ClanData, userId: number): boolean
	return data.members[tostring(userId)] ~= nil
end

function ClanService.IsLeader(data: ClanData, userId: number): boolean
	local member = data.members[tostring(userId)]
	return member ~= nil and member.role == "leader"
end

function ClanService.IsOfficer(data: ClanData, userId: number): boolean
	local member = data.members[tostring(userId)]
	if not member then
		return false
	end
	return member.role == "officer" or member.role == "leader"
end

function ClanService.GetCachedClanForPlayer(player: Player): ClanData?
	local data = DataManager.GetData(player)
	if not data or not data.clanId then
		return nil
	end
	local entry = cache[data.clanId]
	return if entry then entry.data else nil
end

function ClanService.GetClan(clanId: string): ClanData?
	local entry = cache[clanId]
	if entry and isCacheFresh(entry) then
		return entry.data
	end
	-- Miss / stale: load via GetAsync.
	local ok, raw = pcall(function()
		return clanStore:GetAsync(clanId)
	end)
	if not ok then
		warn(string.format("[ClanService] GetAsync failed for %s: %s", clanId, tostring(raw)))
		return nil
	end
	if typeof(raw) ~= "table" then
		invalidate(clanId)
		return nil
	end
	cache[clanId] = { data = raw :: ClanData, fetchedAt = nowSec() }
	return raw :: ClanData
end

function ClanService.GetClanForPlayer(player: Player): ClanData?
	local profile = DataManager.GetData(player)
	if not profile or not profile.clanId then
		return nil
	end
	return ClanService.GetClan(profile.clanId)
end

function ClanService.PushStateToPlayer(player: Player)
	local profile = DataManager.GetData(player)
	local data = ClanService.GetClanForPlayer(player)
	local remote = Remotes.ClanState :: RemoteEvent
	-- Defensive auto-clear: if the profile points at a clan but the
	-- ClanData says we're not a member (cross-server kick happened
	-- while we were on a different server, OR a stale pointer from a
	-- crash mid-write), clear the pointer + push nil.
	if profile and profile.clanId and (not data or not ClanService.IsMember(data, player.UserId)) then
		profile.clanId = nil
		remote:FireClient(player, nil)
		return
	end
	if data then
		remote:FireClient(player, buildStateForPlayer(data, player.UserId))
	else
		remote:FireClient(player, nil)
	end
end

function pushStateForClanMembers(clanId: string)
	local data = ClanService.GetClan(clanId)
	if not data then
		return
	end
	for _, player in Players:GetPlayers() do
		local profile = DataManager.GetData(player)
		if profile and profile.clanId == clanId then
			local remote = Remotes.ClanState :: RemoteEvent
			remote:FireClient(player, buildStateForPlayer(data, player.UserId))
		end
	end
end

ClanService.PushStateForClanMembers = pushStateForClanMembers

-- Atomic CAS update on the clan row. The mutator receives the current
-- ClanData (or nil if absent) and returns the new ClanData (or nil to
-- abort the update). Returns the post-write ClanData, or nil on
-- abort/error. Yields.
function ClanService.MutateClan(clanId: string, mutator: (ClanData?) -> ClanData?): ClanData?
	local final: ClanData?
	local ok, err = pcall(function()
		final = clanStore:UpdateAsync(clanId, function(current)
			local result = mutator(current :: ClanData?)
			if result == nil then
				return nil
			end
			result.schemaVersion = CURRENT_SCHEMA_VERSION
			return result
		end)
	end)
	if not ok then
		warn(string.format("[ClanService] UpdateAsync failed for %s: %s", clanId, tostring(err)))
		return nil
	end
	if final then
		cache[clanId] = { data = final, fetchedAt = nowSec() }
		publishInvalidate(clanId)
	end
	return final
end

local function validateName(name: any): (boolean, string?)
	if typeof(name) ~= "string" then
		return false, "name must be a string"
	end
	if #name < Constants.CLAN.NameMinLength or #name > Constants.CLAN.NameMaxLength then
		return false,
			string.format(
				"name must be %d-%d chars",
				Constants.CLAN.NameMinLength,
				Constants.CLAN.NameMaxLength
			)
	end
	if not string.match(name, NAME_PATTERN) then
		return false, "name has invalid characters"
	end
	return true, nil
end

local function validateTag(tag: any): (boolean, string?)
	if typeof(tag) ~= "string" then
		return false, "tag must be a string"
	end
	if #tag < Constants.CLAN.TagMinLength or #tag > Constants.CLAN.TagMaxLength then
		return false,
			string.format(
				"tag must be %d-%d chars",
				Constants.CLAN.TagMinLength,
				Constants.CLAN.TagMaxLength
			)
	end
	if not string.match(tag, TAG_PATTERN) then
		return false, "tag must be alphanumeric"
	end
	return true, nil
end

function ClanService.TryCreateClan(player: Player, name: any, tag: any): Result
	local profile = DataManager.GetData(player)
	if not profile then
		return { ok = false, error = "no profile" }
	end
	if profile.clanId then
		return { ok = false, error = "already in a clan" }
	end
	local nameOk, nameErr = validateName(name)
	if not nameOk then
		return { ok = false, error = nameErr or "invalid name" }
	end
	local tagOk, tagErr = validateTag(tag)
	if not tagOk then
		return { ok = false, error = tagErr or "invalid tag" }
	end

	local clanId = newClanId()
	local upperTag = string.upper(tag :: string)
	local now = nowSec()
	local memberKey = tostring(player.UserId)
	local data: ClanData = {
		clanId = clanId,
		name = name :: string,
		tag = upperTag,
		createdAt = now,
		leaderUserId = player.UserId,
		members = {
			[memberKey] = {
				userId = player.UserId,
				name = player.Name,
				role = "leader",
				joinedAt = now,
			},
		},
		stashCredits = 0,
		stashCores = 0,
		pendingWithdrawals = {},
		schemaVersion = CURRENT_SCHEMA_VERSION,
	}

	local final = ClanService.MutateClan(clanId, function(current)
		if current then
			-- Astronomical GUID collision; refuse rather than overwrite.
			return nil
		end
		return data
	end)
	if not final then
		return { ok = false, error = "create failed" }
	end
	profile.clanId = clanId
	ClanService.PushStateToPlayer(player)
	print(string.format("[ClanService] %s created clan %s (%s) [%s]", player.Name, data.name, clanId, upperTag))
	return { ok = true, clanId = clanId, state = buildStateForPlayer(final, player.UserId) }
end

function ClanService.TryJoinClan(player: Player, clanId: any): Result
	if typeof(clanId) ~= "string" then
		return { ok = false, error = "invalid clan id" }
	end
	local profile = DataManager.GetData(player)
	if not profile then
		return { ok = false, error = "no profile" }
	end
	if profile.clanId then
		return { ok = false, error = "already in a clan" }
	end

	local final = ClanService.MutateClan(clanId, function(current)
		if not current then
			return nil
		end
		local count = 0
		for _ in current.members do
			count += 1
		end
		if count >= Constants.CLAN.MaxMembers then
			return nil
		end
		local key = tostring(player.UserId)
		if current.members[key] then
			-- Already a member somehow; idempotent.
			return current
		end
		current.members[key] = {
			userId = player.UserId,
			name = player.Name,
			role = "member",
			joinedAt = nowSec(),
		}
		return current
	end)
	if not final then
		return { ok = false, error = "join rejected (full or missing)" }
	end
	if not final.members[tostring(player.UserId)] then
		-- Mutator aborted the join (full / missing); UpdateAsync returned
		-- the unchanged value.
		return { ok = false, error = "clan full or missing" }
	end
	profile.clanId = clanId
	pushStateForClanMembers(clanId)
	print(string.format("[ClanService] %s joined clan %s", player.Name, clanId))
	return { ok = true, clanId = clanId, state = buildStateForPlayer(final, player.UserId) }
end

-- When the leader leaves with other members present, leadership transfers
-- to the longest-tenured officer (or, if no officers, the longest-tenured
-- member). Promoted member's role flips to leader.
local function transferLeadership(data: ClanData, leavingUserId: number): ClanData
	local candidates: { ClanMember } = {}
	for _, member in data.members do
		if member.userId ~= leavingUserId then
			table.insert(candidates, member)
		end
	end
	if #candidates == 0 then
		return data
	end
	table.sort(candidates, function(a, b)
		-- Officers before members; within rank, oldest first.
		if a.role ~= b.role then
			return a.role == "officer"
		end
		return a.joinedAt < b.joinedAt
	end)
	local newLeader = candidates[1]
	newLeader.role = "leader"
	data.leaderUserId = newLeader.userId
	return data
end

function ClanService.TryLeaveClan(player: Player): Result
	local profile = DataManager.GetData(player)
	if not profile or not profile.clanId then
		return { ok = false, error = "no clan" }
	end
	local clanId = profile.clanId

	local memberKey = tostring(player.UserId)
	local lastMember = false
	local final = ClanService.MutateClan(clanId, function(current)
		if not current or not current.members[memberKey] then
			return nil
		end
		current.members[memberKey] = nil
		local remaining = 0
		for _ in current.members do
			remaining += 1
		end
		if remaining == 0 then
			lastMember = true
			-- Returning nil from UpdateAsync deletes the row.
			return nil
		end
		if current.leaderUserId == player.UserId then
			current = transferLeadership(current, player.UserId)
		end
		return current
	end)

	if final == nil and not lastMember then
		return { ok = false, error = "leave failed" }
	end
	profile.clanId = nil
	if not lastMember then
		pushStateForClanMembers(clanId)
	end
	ClanService.PushStateToPlayer(player)
	print(
		string.format(
			"[ClanService] %s left clan %s%s",
			player.Name,
			clanId,
			if lastMember then " (clan disbanded)" else ""
		)
	)
	return { ok = true }
end

function ClanService.TryKickMember(actor: Player, targetUserId: any): Result
	if typeof(targetUserId) ~= "number" then
		return { ok = false, error = "invalid target" }
	end
	if targetUserId == actor.UserId then
		return { ok = false, error = "use leave to remove yourself" }
	end
	local actorProfile = DataManager.GetData(actor)
	if not actorProfile or not actorProfile.clanId then
		return { ok = false, error = "no clan" }
	end
	local clanId = actorProfile.clanId

	local kickedSelf = false
	local final = ClanService.MutateClan(clanId, function(current)
		if not current then
			return nil
		end
		local actorMember = current.members[tostring(actor.UserId)]
		if not actorMember then
			return nil
		end
		if actorMember.role == "member" then
			-- Members can't kick.
			return nil
		end
		local targetKey = tostring(targetUserId)
		local targetMember = current.members[targetKey]
		if not targetMember then
			return nil
		end
		-- Officers can only kick members; only leaders can kick officers.
		-- No one can kick the leader (they must leave themselves).
		if targetMember.role == "leader" then
			return nil
		end
		if actorMember.role == "officer" and targetMember.role == "officer" then
			return nil
		end
		current.members[targetKey] = nil
		kickedSelf = true
		return current
	end)
	if not final or not kickedSelf then
		return { ok = false, error = "kick rejected" }
	end
	-- Clear the kicked player's profile.clanId if they're online on this
	-- server. Cross-server clear happens via the cache invalidate +
	-- next ClanState push (which sees no membership and clears their
	-- displayed state); their profile.clanId on their home server stays
	-- stale until they rejoin OR a follow-up cross-server signal lands.
	-- V1.5 may add a `outpost.clan.kicked.<userId>` topic; for V1 the
	-- profile-state staleness is bounded by their next join.
	local kickedPlayer = Players:GetPlayerByUserId(targetUserId)
	if kickedPlayer then
		local kickedProfile = DataManager.GetData(kickedPlayer)
		if kickedProfile then
			kickedProfile.clanId = nil
		end
		ClanService.PushStateToPlayer(kickedPlayer)
	end
	pushStateForClanMembers(clanId)
	print(string.format("[ClanService] %s kicked %d from %s", actor.Name, targetUserId, clanId))
	return { ok = true }
end

local function subscribeInvalidate()
	local ok, err = pcall(function()
		MessagingService:SubscribeAsync(Constants.CLAN.InvalidateTopic, function(message)
			local payload = message.Data
			if typeof(payload) ~= "table" or typeof(payload.clanId) ~= "string" then
				return
			end
			invalidate(payload.clanId)
			-- Re-push to any local members so their UI stays current.
			pushStateForClanMembers(payload.clanId)
		end)
	end)
	if not ok then
		warn(string.format("[ClanService] SubscribeAsync(invalidate) failed: %s", tostring(err)))
	end
end

function ClanService.Init()
	-- RemoteFunction wires. F1 token-bucket rate limit on every C→S
	-- entry. Tight buckets on Create/Join (anti-spam clan churn);
	-- looser on Leave/Kick (legitimate moderation actions can occur
	-- in quick burst).
	local createRemote = Remotes.CreateClan :: RemoteFunction
	createRemote.OnServerInvoke = function(player: Player, name: any, tag: any): Result
		if not AntiExploit.RateCheck(player, "CreateClan") then
			AuditLog.Record(player, "rate_limited", "CreateClan")
			return { ok = false, error = "rate-limited" }
		end
		-- F2 wire-shape: name + tag length caps. Domain validation
		-- (character class, exact length per Constants.CLAN.NameMinLength
		-- etc.) lives in TryCreateClan.
		local nameOk = RemoteValidator.IsString(name, 1, Constants.CLAN.NameMaxLength)
		local tagOk = RemoteValidator.IsString(tag, 1, Constants.CLAN.TagMaxLength)
		if not (nameOk and tagOk) then
			AuditLog.Record(player, "validation_failed", "CreateClan: name/tag invalid")
			return { ok = false, error = "invalid name or tag" }
		end
		return ClanService.TryCreateClan(player, name, tag)
	end

	local joinRemote = Remotes.JoinClan :: RemoteFunction
	joinRemote.OnServerInvoke = function(player: Player, clanId: any): Result
		if not AntiExploit.RateCheck(player, "JoinClan") then
			AuditLog.Record(player, "rate_limited", "JoinClan")
			return { ok = false, error = "rate-limited" }
		end
		local idOk, idValue = RemoteValidator.IsString(clanId, 1, Constants.VALIDATION.MaxClanIdLength)
		if not idOk then
			AuditLog.Record(player, "validation_failed", "JoinClan: clanId invalid")
			return { ok = false, error = "invalid clan id" }
		end
		return ClanService.TryJoinClan(player, idValue)
	end

	local leaveRemote = Remotes.LeaveClan :: RemoteFunction
	leaveRemote.OnServerInvoke = function(player: Player): Result
		if not AntiExploit.RateCheck(player, "LeaveClan") then
			AuditLog.Record(player, "rate_limited", "LeaveClan")
			return { ok = false, error = "rate-limited" }
		end
		return ClanService.TryLeaveClan(player)
	end

	local kickRemote = Remotes.KickFromClan :: RemoteFunction
	kickRemote.OnServerInvoke = function(player: Player, targetUserId: any): Result
		if not AntiExploit.RateCheck(player, "KickFromClan") then
			AuditLog.Record(player, "rate_limited", "KickFromClan")
			return { ok = false, error = "rate-limited" }
		end
		local userIdOk, userIdValue = RemoteValidator.IsUserId(targetUserId)
		if not userIdOk then
			AuditLog.Record(player, "validation_failed", "KickFromClan: targetUserId invalid")
			return { ok = false, error = "invalid target user id" }
		end
		return ClanService.TryKickMember(player, userIdValue)
	end

	-- State push on join.
	Players.PlayerAdded:Connect(function(player)
		task.spawn(function()
			DataManager.WaitForData(player)
			if player:IsDescendantOf(Players) then
				ClanService.PushStateToPlayer(player)
			end
		end)
	end)
	-- Existing players (Studio reload during dev).
	for _, player in Players:GetPlayers() do
		task.spawn(function()
			ClanService.PushStateToPlayer(player)
		end)
	end

	subscribeInvalidate()
end

return ClanService
