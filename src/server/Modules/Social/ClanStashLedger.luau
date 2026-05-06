--!strict
--[[
	Outpost-7 — clan shared-stash deposits + withdrawals.

	Phase E3. Wraps `ClanService.MutateClan` (the atomic CAS chokepoint)
	for stash-specific operations:
	  - **Deposit** — TrySpend on the player's profile, then increment
	    clan stashCredits inside the same UpdateAsync call. If the
	    UpdateAsync fails, the spend is refunded so the stash and the
	    player's wallet stay consistent.
	  - **Withdraw** — small (<= AutoApproveWithdrawalThreshold): atomic
	    decrement + grant. Large: queue a PendingWithdrawal entry; leader
	    must approve via `TryApprove`.
	  - **Approve** — leader-only. Removes the pending entry and publishes
	    `outpost.clan.withdrawal.grant` MessagingService payload so the
	    requester's home server applies the credits via CurrencyService.Add.
	    If the requester is offline at approval time, the publish fires
	    into a void and the credits are lost — V1 acceptable per
	    ADR-008-style "online-only delivery"; V1.5+ may add a
	    `ClanWithdrawalLedger` for offline grants.

	Single-writer-per-profile invariant (ADR-008) preserved: the
	requester's CurrencyService.Add only runs on the requester's home
	server, never on the approving leader's server.

	Public API:
	  Init                    — Remote wires + MessagingService subscribe
	  TryDeposit(p, amount)   — yielding
	  TryWithdraw(p, amount)  — yielding
	  TryApprove(leader, withdrawalId, approve) — yielding
--]]

local HttpService = game:GetService("HttpService")
local MessagingService = game:GetService("MessagingService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Constants = require(Shared:WaitForChild("Constants"))
local Remotes = require(Shared:WaitForChild("Remotes"))

local CurrencyService = require(script.Parent.Parent.Economy.CurrencyService)
local DataManager = require(script.Parent.Parent.Player.DataManager)
local ClanService = require(script.Parent.ClanService)

type ClanData = ClanService.ClanData
type PendingWithdrawal = ClanService.PendingWithdrawal

local ClanStashLedger = {}

export type Result = {
	ok: true,
	status: string?, -- "instant" | "pending"
	withdrawalId: string?,
	state: ClanService.State?,
} | {
	ok: false,
	error: string,
}

local function newWithdrawalId(): string
	return HttpService:GenerateGUID(false)
end

local function nowSec(): number
	return os.time()
end

local function pendingCount(data: ClanData): number
	local n = 0
	for _ in data.pendingWithdrawals do
		n += 1
	end
	return n
end

local function publishWithdrawalGrant(requesterUserId: number, amount: number, clanId: string, withdrawalId: string)
	local ok, err = pcall(function()
		MessagingService:PublishAsync(Constants.CLAN.WithdrawalGrantTopic, {
			requesterUserId = requesterUserId,
			amount = amount,
			clanId = clanId,
			withdrawalId = withdrawalId,
		})
	end)
	if not ok then
		warn(string.format("[ClanStashLedger] PublishAsync(withdrawal.grant) failed: %s", tostring(err)))
	end
end

function ClanStashLedger.TryDeposit(player: Player, amount: any): Result
	if typeof(amount) ~= "number" or amount ~= math.floor(amount) or amount <= 0 then
		return { ok = false, error = "invalid amount" }
	end
	local profile = DataManager.GetData(player)
	if not profile or not profile.clanId then
		return { ok = false, error = "no clan" }
	end
	local clanId = profile.clanId

	-- Spend first, then write to clan. If the write fails, refund.
	if not CurrencyService.TrySpend(player, amount) then
		return { ok = false, error = "insufficient credits" }
	end

	local final = ClanService.MutateClan(clanId, function(current)
		if not current then
			return nil
		end
		if not current.members[tostring(player.UserId)] then
			return nil
		end
		current.stashCredits += amount
		return current
	end)
	if not final then
		-- Write rejected; refund the player.
		CurrencyService.Add(player, amount)
		return { ok = false, error = "deposit rejected" }
	end
	ClanService.PushStateForClanMembers(clanId)
	print(
		string.format(
			"[ClanStashLedger] %s deposited %d to %s (new stash=%d)",
			player.Name,
			amount,
			clanId,
			final.stashCredits
		)
	)
	return { ok = true, status = "instant" }
end

function ClanStashLedger.TryWithdraw(player: Player, amount: any): Result
	if typeof(amount) ~= "number" or amount ~= math.floor(amount) or amount <= 0 then
		return { ok = false, error = "invalid amount" }
	end
	local profile = DataManager.GetData(player)
	if not profile or not profile.clanId then
		return { ok = false, error = "no clan" }
	end
	local clanId = profile.clanId

	local autoApprove = amount <= Constants.CLAN.AutoApproveWithdrawalThreshold

	if autoApprove then
		-- Atomic decrement + (out-of-band) grant. We can apply the grant
		-- locally because the requester is on this server (we're holding
		-- their Player). No cross-server hop needed.
		local accepted = false
		local final = ClanService.MutateClan(clanId, function(current)
			if not current then
				return nil
			end
			if not current.members[tostring(player.UserId)] then
				return nil
			end
			if current.stashCredits < amount then
				return nil
			end
			current.stashCredits -= amount
			accepted = true
			return current
		end)
		if not final or not accepted then
			return { ok = false, error = "stash insufficient or rejected" }
		end
		CurrencyService.Add(player, amount)
		ClanService.PushStateForClanMembers(clanId)
		print(
			string.format(
				"[ClanStashLedger] %s withdrew %d from %s (auto-approved; new stash=%d)",
				player.Name,
				amount,
				clanId,
				final.stashCredits
			)
		)
		return { ok = true, status = "instant" }
	end

	-- Large withdrawal: queue a pending entry awaiting leader approval.
	local withdrawalId = newWithdrawalId()
	local final = ClanService.MutateClan(clanId, function(current)
		if not current then
			return nil
		end
		if not current.members[tostring(player.UserId)] then
			return nil
		end
		if current.stashCredits < amount then
			return nil
		end
		if pendingCount(current) >= Constants.CLAN.MaxPendingWithdrawals then
			return nil
		end
		local entry: PendingWithdrawal = {
			withdrawalId = withdrawalId,
			requesterUserId = player.UserId,
			requesterName = player.Name,
			amount = amount,
			requestedAt = nowSec(),
		}
		current.pendingWithdrawals[withdrawalId] = entry
		return current
	end)
	if not final then
		return { ok = false, error = "queue rejected (stash low or queue full)" }
	end
	ClanService.PushStateForClanMembers(clanId)
	print(
		string.format(
			"[ClanStashLedger] %s queued withdrawal %d from %s (id=%s; awaiting approval)",
			player.Name,
			amount,
			clanId,
			withdrawalId
		)
	)
	return { ok = true, status = "pending", withdrawalId = withdrawalId }
end

function ClanStashLedger.TryApprove(leader: Player, withdrawalId: any, approve: any): Result
	if typeof(withdrawalId) ~= "string" then
		return { ok = false, error = "invalid withdrawal id" }
	end
	if typeof(approve) ~= "boolean" then
		return { ok = false, error = "invalid approve flag" }
	end
	local profile = DataManager.GetData(leader)
	if not profile or not profile.clanId then
		return { ok = false, error = "no clan" }
	end
	local clanId = profile.clanId

	local resolvedAmount: number? = nil
	local resolvedRequester: number? = nil
	local final = ClanService.MutateClan(clanId, function(current)
		if not current then
			return nil
		end
		if not ClanService.IsLeader(current, leader.UserId) then
			return nil
		end
		local entry = current.pendingWithdrawals[withdrawalId]
		if not entry then
			return nil
		end
		if approve then
			if current.stashCredits < entry.amount then
				-- Stash drained below the queued amount since the request.
				-- Reject the withdrawal and leave the entry in place so
				-- the leader can re-evaluate (or deny).
				return nil
			end
			current.stashCredits -= entry.amount
			resolvedAmount = entry.amount
			resolvedRequester = entry.requesterUserId
		end
		current.pendingWithdrawals[withdrawalId] = nil
		return current
	end)
	if not final then
		return { ok = false, error = "approve rejected (not leader / stash low)" }
	end

	if approve and resolvedAmount and resolvedRequester then
		-- Cross-server credit grant via MessagingService. Requester's home
		-- server applies via CurrencyService.Add.
		publishWithdrawalGrant(resolvedRequester, resolvedAmount, clanId, withdrawalId)
		print(
			string.format(
				"[ClanStashLedger] %s APPROVED withdrawal %s (%d to userId=%d)",
				leader.Name,
				withdrawalId,
				resolvedAmount,
				resolvedRequester
			)
		)
	else
		print(
			string.format("[ClanStashLedger] %s DENIED withdrawal %s", leader.Name, withdrawalId)
		)
	end
	ClanService.PushStateForClanMembers(clanId)
	return { ok = true, status = if approve then "instant" else "denied" }
end

local function subscribeWithdrawalGrant()
	local ok, err = pcall(function()
		MessagingService:SubscribeAsync(Constants.CLAN.WithdrawalGrantTopic, function(message)
			local payload = message.Data
			if typeof(payload) ~= "table" then
				return
			end
			if typeof(payload.requesterUserId) ~= "number" or typeof(payload.amount) ~= "number" then
				return
			end
			local requester = Players:GetPlayerByUserId(payload.requesterUserId)
			if not requester then
				return
			end
			-- Only the requester's home server reaches this branch.
			task.spawn(function()
				DataManager.WaitForData(requester)
				if requester:IsDescendantOf(Players) then
					CurrencyService.Add(requester, payload.amount)
					print(
						string.format(
							"[ClanStashLedger] Home applied withdrawal: %s +%d (clanId=%s, withdrawalId=%s)",
							requester.Name,
							payload.amount,
							tostring(payload.clanId),
							tostring(payload.withdrawalId)
						)
					)
				end
			end)
		end)
	end)
	if not ok then
		warn(string.format("[ClanStashLedger] SubscribeAsync(withdrawal.grant) failed: %s", tostring(err)))
	end
end

function ClanStashLedger.Init()
	local depositRemote = Remotes.ClanStashDeposit :: RemoteFunction
	depositRemote.OnServerInvoke = function(player: Player, amount: any): Result
		return ClanStashLedger.TryDeposit(player, amount)
	end

	local withdrawRemote = Remotes.ClanStashWithdraw :: RemoteFunction
	withdrawRemote.OnServerInvoke = function(player: Player, amount: any): Result
		return ClanStashLedger.TryWithdraw(player, amount)
	end

	local approveRemote = Remotes.ClanStashApprove :: RemoteFunction
	approveRemote.OnServerInvoke = function(player: Player, withdrawalId: any, approve: any): Result
		return ClanStashLedger.TryApprove(player, withdrawalId, approve)
	end

	subscribeWithdrawalGrant()
end

return ClanStashLedger
