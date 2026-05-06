--!strict
--[[
	Outpost-7 — friends list service.

	Phase E5. Caches `Players:GetFriendsAsync` per player on join,
	refreshes hourly, and pushes a `FriendsList` Remote to the
	affected client. Per-friend `inThisServer` flag set by checking
	`Players:GetPlayerByUserId` against the cached friend userId.

	V1 limitation: only "online in this server" presence is surfaced
	for friends. Cross-server friend presence (a friend in another
	Outpost-7 server elsewhere in the universe) is V1.5+ — would
	require a `OutpostPresence` MemoryStoreService key per online
	player + a fan-out subscription per server. Acceptable V1 cost
	since the brainstorm §2.6 friends feature centers on "see your
	friends in your server, invite them" rather than universe-wide
	presence.

	Trust boundary: friend data comes from Roblox's friend graph via
	`GetFriendsAsync`. The client never sends a friend payload; the
	`RefreshFriends` Remote only triggers a re-fetch.

	Public API:
	  Init                    — wires PlayerAdded + Refresh Remote +
	                            local-presence-change push
	  GetCachedFriends(p)     — non-yielding read of the cached list
	  PushStateToPlayer(p)    — fires FriendsList Remote
	  RefreshNow(p)           — yielding; re-fetches via GetFriendsAsync
--]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Constants = require(Shared:WaitForChild("Constants"))
local Remotes = require(Shared:WaitForChild("Remotes"))

local DataManager = require(script.Parent.Parent.Player.DataManager)

local FriendsService = {}

export type Friend = {
	userId: number,
	username: string,
	displayName: string,
	inThisServer: boolean,
}

export type State = {
	friends: { Friend },
	fetchedAt: number,
}

export type Result = {
	ok: true,
	state: State,
} | {
	ok: false,
	error: string,
}

-- Per-player cache. Keyed by userId. Survives the player's session;
-- cleared on PlayerRemoving.
local cache: { [number]: State } = {}
-- Track when the last refresh happened to throttle RefreshFriends.
local lastRefreshAt: { [number]: number } = {}

local function annotateInThisServer(friends: { Friend }): { Friend }
	for _, friend in friends do
		friend.inThisServer = Players:GetPlayerByUserId(friend.userId) ~= nil
	end
	return friends
end

local function fetchFriends(player: Player): { Friend }?
	local out: { Friend } = {}
	local ok, pages = pcall(function()
		return Players:GetFriendsAsync(player.UserId)
	end)
	if not ok or not pages then
		warn(string.format("[FriendsService] GetFriendsAsync failed for %s: %s", player.Name, tostring(pages)))
		return nil
	end

	local count = 0
	while count < Constants.FRIENDS.MaxFriendsListed do
		local okPage, page = pcall(function()
			return pages:GetCurrentPage()
		end)
		if not okPage or typeof(page) ~= "table" then
			break
		end
		for _, entry in page do
			if count >= Constants.FRIENDS.MaxFriendsListed then
				break
			end
			-- entry has Id, Username, DisplayName per Roblox docs.
			local userId = tonumber(entry.Id)
			if userId then
				table.insert(out, {
					userId = userId,
					username = tostring(entry.Username or ""),
					displayName = tostring(entry.DisplayName or entry.Username or ""),
					inThisServer = false,
				})
				count += 1
			end
		end
		if pages.IsFinished then
			break
		end
		local okAdvance = pcall(function()
			pages:AdvanceToNextPageAsync()
		end)
		if not okAdvance then
			break
		end
	end
	return annotateInThisServer(out)
end

function FriendsService.GetCachedFriends(player: Player): State?
	return cache[player.UserId]
end

function FriendsService.PushStateToPlayer(player: Player)
	local state = cache[player.UserId]
	if not state then
		return
	end
	-- Re-annotate before push to catch any presence changes since the
	-- last fetch.
	annotateInThisServer(state.friends)
	local remote = Remotes.FriendsList :: RemoteEvent
	remote:FireClient(player, state)
end

function FriendsService.RefreshNow(player: Player): Result
	local now = os.time()
	-- Throttle: refuse if last refresh was within the throttle window.
	local last = lastRefreshAt[player.UserId]
	if last and now - last < 60 then
		local cached = cache[player.UserId]
		if cached then
			return { ok = true, state = cached }
		end
		return { ok = false, error = "throttled" }
	end
	lastRefreshAt[player.UserId] = now

	local friends = fetchFriends(player)
	if not friends then
		return { ok = false, error = "fetch failed" }
	end
	local state: State = {
		friends = friends,
		fetchedAt = now,
	}
	cache[player.UserId] = state
	FriendsService.PushStateToPlayer(player)
	return { ok = true, state = state }
end

local function hourlyRefreshLoop()
	while true do
		task.wait(Constants.FRIENDS.RefreshIntervalSeconds)
		for _, player in Players:GetPlayers() do
			task.spawn(function()
				FriendsService.RefreshNow(player)
			end)
		end
	end
end

-- When any player joins / leaves this server, every other player
-- with that user as a friend should see their inThisServer flag flip.
-- Cheaper than a full GetFriendsAsync re-fetch.
local function rePushAllForLocalPresenceChange()
	for _, player in Players:GetPlayers() do
		if cache[player.UserId] then
			FriendsService.PushStateToPlayer(player)
		end
	end
end

function FriendsService.Init()
	Players.PlayerAdded:Connect(function(player)
		task.spawn(function()
			DataManager.WaitForData(player)
			if not player:IsDescendantOf(Players) then
				return
			end
			-- Initial fetch.
			FriendsService.RefreshNow(player)
			-- Tell every other online player to re-render their friends
			-- panel — this player joining may flip an inThisServer flag
			-- in their cached list.
			rePushAllForLocalPresenceChange()
		end)
	end)
	Players.PlayerRemoving:Connect(function(player)
		cache[player.UserId] = nil
		lastRefreshAt[player.UserId] = nil
		-- Same re-push: this player leaving may flip a flag elsewhere.
		task.spawn(rePushAllForLocalPresenceChange)
	end)

	-- RefreshFriends Remote — manual user-triggered refresh.
	local refreshRemote = Remotes.RefreshFriends :: RemoteFunction
	refreshRemote.OnServerInvoke = function(player: Player): Result
		return FriendsService.RefreshNow(player)
	end

	-- Catch existing players (Studio reload during dev).
	for _, player in Players:GetPlayers() do
		task.spawn(function()
			FriendsService.RefreshNow(player)
		end)
	end

	task.spawn(hourlyRefreshLoop)
end

return FriendsService
