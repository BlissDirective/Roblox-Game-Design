--!strict
--[[
	Outpost-7 — clan chat (cross-server).

	Phase E3. Each clan has its own MessagingService topic
	(`outpost.clan.chat.<clanId>`). Sending fans out via the topic to
	every server with at least one online member of that clan; each
	server filters to its local clan members and fires `ClanChatReceived`
	to them.

	Subscriptions are lazily created when the first member of a clan
	joins this server, and torn down when the last member leaves.
	Avoids subscribing to every clan's topic on every server (Roblox
	caps subscriptions per server).

	Trust boundary: server validates length + non-empty; sanitizes
	control characters. F1 hardens with a per-player rate limit
	(default 10 msg / 10s; configurable in Constants).

	V1 limitation: no chat history / scrollback. A player who joins a
	clan after a message was sent doesn't see it. Phase G or V1.5 may
	add a 50-message ring buffer per clan in MemoryStoreService.

	Public API:
	  Init                — Remote wires + Players signals
	  TrySend(p, msg)     — yielding (PublishAsync)
--]]

local MessagingService = game:GetService("MessagingService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Constants = require(Shared:WaitForChild("Constants"))
local Remotes = require(Shared:WaitForChild("Remotes"))

local DataManager = require(script.Parent.Parent.Player.DataManager)
local AntiExploit = require(script.Parent.Parent.Security.AntiExploit)

local ClanChatService = {}

export type Entry = {
	clanId: string,
	senderUserId: number,
	senderName: string,
	message: string,
	sentAt: number,
}

export type Result = {
	ok: true,
} | {
	ok: false,
	error: string,
}

-- Per-server subscription tracking.
local subscriptions: { [string]: RBXScriptConnection } = {}
-- Per-clan local member count (for sub/unsub lifecycle).
local memberRefcount: { [string]: number } = {}

local function topicFor(clanId: string): string
	return string.format("%s.%s", Constants.CLAN.ChatTopicPrefix, clanId)
end

local function sanitize(message: string): string
	-- Strip control chars; clip to length cap.
	local out = string.gsub(message, "[%c]", " ")
	if #out > Constants.CLAN.ChatMessageMaxLength then
		out = string.sub(out, 1, Constants.CLAN.ChatMessageMaxLength)
	end
	return out
end

local function fireToLocalMembers(clanId: string, entry: Entry)
	local remote = Remotes.ClanChatReceived :: RemoteEvent
	for _, player in Players:GetPlayers() do
		local profile = DataManager.GetData(player)
		if profile and profile.clanId == clanId then
			remote:FireClient(player, entry)
		end
	end
end

local function ensureSubscribed(clanId: string)
	if subscriptions[clanId] then
		return
	end
	local ok, connection = pcall(function()
		return MessagingService:SubscribeAsync(topicFor(clanId), function(message)
			local payload = message.Data
			if typeof(payload) ~= "table" then
				return
			end
			if typeof(payload.message) ~= "string" or typeof(payload.senderUserId) ~= "number" then
				return
			end
			fireToLocalMembers(clanId, payload :: Entry)
		end)
	end)
	if ok and connection then
		subscriptions[clanId] = connection
	else
		warn(
			string.format(
				"[ClanChatService] SubscribeAsync(chat.%s) failed: %s",
				clanId,
				tostring(connection)
			)
		)
	end
end

local function maybeUnsubscribe(clanId: string)
	if memberRefcount[clanId] and memberRefcount[clanId] > 0 then
		return
	end
	local connection = subscriptions[clanId]
	if connection then
		connection:Disconnect()
		subscriptions[clanId] = nil
	end
	memberRefcount[clanId] = nil
end

local function refMember(clanId: string)
	memberRefcount[clanId] = (memberRefcount[clanId] or 0) + 1
	ensureSubscribed(clanId)
end

local function unrefMember(clanId: string)
	memberRefcount[clanId] = (memberRefcount[clanId] or 0) - 1
	if memberRefcount[clanId] <= 0 then
		memberRefcount[clanId] = 0
		maybeUnsubscribe(clanId)
	end
end

function ClanChatService.TrySend(player: Player, message: any): Result
	if typeof(message) ~= "string" then
		return { ok = false, error = "invalid message" }
	end
	if #message == 0 then
		return { ok = false, error = "empty message" }
	end
	local profile = DataManager.GetData(player)
	if not profile or not profile.clanId then
		return { ok = false, error = "no clan" }
	end
	local entry: Entry = {
		clanId = profile.clanId,
		senderUserId = player.UserId,
		senderName = player.Name,
		message = sanitize(message),
		sentAt = os.time(),
	}
	local ok, err = pcall(function()
		MessagingService:PublishAsync(topicFor(profile.clanId), entry)
	end)
	if not ok then
		warn(string.format("[ClanChatService] PublishAsync(chat) failed: %s", tostring(err)))
		return { ok = false, error = "publish failed" }
	end
	-- The MessagingService callback will deliver to local members too,
	-- including the sender (so they see their own message immediately).
	return { ok = true }
end

-- Track per-player clan membership transitions so we can refcount the
-- subscription. Called from PlayerAdded (after profile loads) and from
-- ClanService events ideally — but for V1 simplicity we re-scan on a
-- 30s heartbeat per server. Phase F may add explicit hooks.
local function refreshMembershipFor(player: Player)
	local profile = DataManager.GetData(player)
	if not profile then
		return
	end
	local current: string? = profile.clanId
	local previous = (player :: any):GetAttribute("ClanChatRef")
	if current == previous then
		return
	end
	if previous and typeof(previous) == "string" then
		unrefMember(previous)
	end
	if current then
		refMember(current)
	end
	;(player :: any):SetAttribute("ClanChatRef", current)
end

local function membershipPollLoop()
	while true do
		task.wait(30)
		for _, player in Players:GetPlayers() do
			refreshMembershipFor(player)
		end
	end
end

function ClanChatService.Init()
	local sendRemote = Remotes.ClanChatSend :: RemoteFunction
	sendRemote.OnServerInvoke = function(player: Player, message: any): Result
		-- F1 token-bucket rate limit. Tightest bucket in the system
		-- (0.5/sec sustained, capacity 1 — no burst). Chat spam is the
		-- highest-volume exploit vector.
		if not AntiExploit.RateCheck(player, "ClanChatSend") then
			return { ok = false, error = "rate-limited" }
		end
		return ClanChatService.TrySend(player, message)
	end

	Players.PlayerAdded:Connect(function(player)
		task.spawn(function()
			DataManager.WaitForData(player)
			if player:IsDescendantOf(Players) then
				refreshMembershipFor(player)
			end
		end)
	end)
	Players.PlayerRemoving:Connect(function(player)
		local previous = (player :: any):GetAttribute("ClanChatRef")
		if previous and typeof(previous) == "string" then
			unrefMember(previous)
		end
	end)
	-- Catch existing players (Studio reload during dev).
	for _, player in Players:GetPlayers() do
		task.spawn(function()
			refreshMembershipFor(player)
		end)
	end

	task.spawn(membershipPollLoop)
end

return ClanChatService
