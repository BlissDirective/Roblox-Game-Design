--!strict
--[[
	Outpost-7 — DataStore manager. ProfileStore-backed.

	Phase A2. Owns the per-player profile lifecycle:

	  Init()                 — connects Players signals + BindToClose
	  LoadPlayer(player)     — yields until session is acquired (kicks on fail)
	  SavePlayer(player)     — explicit flush via ProfileStore EndSession
	  GetData(player)        — non-yielding accessor (nil if not loaded)
	  WaitForData(player)    — yielding accessor (nil if player left first)

	ProfileStore handles the transport layer: pcall, retries, cross-server
	session locks via MessagingService, periodic auto-save (5 min default).
	We own the schema (see ProfileSchema.luau), the migrations
	(tools/migrations/), and this façade.

	See docs/architecture/DECISIONS.md ADR-003 for the build-vs-buy decision.
--]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerScriptService = game:GetService("ServerScriptService")

local ProfileStore = require(ServerScriptService:WaitForChild("ServerPackages"):WaitForChild("ProfileStore"))
local ProfileSchema = require(script.Parent.ProfileSchema)
local Constants = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Constants"))

type PlayerData = ProfileSchema.PlayerData

-- ProfileStore's Profile<T> type isn't easily importable; treat as opaque.
type Profile = any

local DataManager = {}

-- One ProfileStore instance for V1. `.Mock` in Studio so the audit loop
-- exercises the same join → mutate → leave → rejoin shape as live.
local profileStore = ProfileStore.New(Constants.DATASTORE.StoreName, ProfileSchema.DEFAULT_DATA)
if RunService:IsStudio() then
	profileStore = profileStore.Mock
end

local profiles: { [Player]: Profile } = {}
local loadedSignals: { [Player]: BindableEvent } = {}
-- Set when we initiate the session end (PlayerRemoving / BindToClose) so
-- OnSessionEnd can distinguish our own teardown from a cross-server steal.
local intentionalEnd: { [Player]: boolean } = {}
-- Per-session metadata captured during LoadPlayer. Kept separate from
-- the persisted Profile.Data so it doesn't get serialized. C4
-- (offline progression) reads previousLastJoinAt to compute elapsed
-- time × extractor income.
export type SessionMeta = {
	previousLastJoinAt: number?,
}
local sessionMeta: { [Player]: SessionMeta } = {}

local function profileKey(player: Player): string
	return tostring(player.UserId)
end

local function fireLoaded(player: Player)
	local signal = loadedSignals[player]
	if signal then
		signal:Fire()
	end
end

local function clearLoadSignal(player: Player)
	local signal = loadedSignals[player]
	if signal then
		loadedSignals[player] = nil
		signal:Destroy()
	end
end

function DataManager.LoadPlayer(player: Player)
	if profiles[player] or loadedSignals[player] then
		return
	end

	local signal = Instance.new("BindableEvent")
	loadedSignals[player] = signal

	local profile = profileStore:StartSessionAsync(profileKey(player), {
		Cancel = function()
			return player:IsDescendantOf(Players) == false
		end,
	})

	if not profile then
		clearLoadSignal(player)
		if player:IsDescendantOf(Players) then
			player:Kick("[Outpost-7] Could not load your save. Please rejoin in a moment.")
		end
		return
	end

	profile:AddUserId(player.UserId)
	profile:Reconcile() -- merges new template defaults into older saves
	ProfileSchema.Migrate(profile.Data) -- applies versioned migrations (no-op at v1)

	profile.OnSessionEnd:Connect(function()
		profiles[player] = nil
		local wasIntentional = intentionalEnd[player]
		intentionalEnd[player] = nil
		if not wasIntentional and player:IsDescendantOf(Players) then
			-- Another server claimed this profile. Boot the player so they
			-- can rejoin and pick up the now-fresh session.
			player:Kick("[Outpost-7] Your save was claimed by another server. Please rejoin.")
		end
	end)

	if not player:IsDescendantOf(Players) then
		-- Player left during StartSessionAsync; release the lock and bail.
		intentionalEnd[player] = true
		profile:EndSession()
		clearLoadSignal(player)
		return
	end

	-- Bookkeeping fields prove round-trip persistence to the A audit:
	-- firstJoinAt is sticky; lastJoinAt + sessionsPlayed advance every load.
	-- Capture the previous lastJoinAt BEFORE stamping the new value
	-- so OfflineProgression (C4) can compute elapsed time on rejoin.
	local now = os.time()
	sessionMeta[player] = { previousLastJoinAt = profile.Data.lastJoinAt }
	profile.Data.firstJoinAt = profile.Data.firstJoinAt or now
	profile.Data.lastJoinAt = now
	profile.Data.sessionsPlayed += 1

	profiles[player] = profile
	fireLoaded(player)

	print(
		string.format(
			"[DataManager] Loaded %s — session #%d, credits=%d, firstJoinAt=%d",
			player.Name,
			profile.Data.sessionsPlayed,
			profile.Data.credits,
			profile.Data.firstJoinAt or 0
		)
	)
end

function DataManager.SavePlayer(player: Player)
	local profile = profiles[player]
	if not profile then
		return
	end
	intentionalEnd[player] = true
	print(string.format("[DataManager] Saving %s (sessions=%d)", player.Name, profile.Data.sessionsPlayed))
	profile:EndSession()
end

function DataManager.GetData(player: Player): PlayerData?
	local profile = profiles[player]
	return if profile then profile.Data else nil
end

function DataManager.WaitForData(player: Player): PlayerData?
	local existing = profiles[player]
	if existing then
		return existing.Data
	end
	local signal = loadedSignals[player]
	if not signal then
		return nil
	end
	signal.Event:Wait()
	local profile = profiles[player]
	return if profile then profile.Data else nil
end

function DataManager.GetSessionMeta(player: Player): SessionMeta?
	return sessionMeta[player]
end

function DataManager.Init()
	Players.PlayerAdded:Connect(DataManager.LoadPlayer)

	-- Catch any players already present when this module Init's (e.g. a
	-- script reload during dev, or join-before-Init race on cold boot).
	for _, player in Players:GetPlayers() do
		task.spawn(DataManager.LoadPlayer, player)
	end

	Players.PlayerRemoving:Connect(function(player)
		DataManager.SavePlayer(player)
		clearLoadSignal(player)
		sessionMeta[player] = nil
	end)

	game:BindToClose(function()
		local activeCount = 0
		for player in pairs(profiles) do
			activeCount += 1
			task.spawn(DataManager.SavePlayer, player)
		end
		print(string.format("[DataManager] BindToClose: flushing %d profile(s)", activeCount))
		-- Wait until every active session has fully ended, or the
		-- timeout in Constants (25s; below BindToClose's 30s ceiling).
		local deadline = os.clock() + Constants.DATASTORE.BindToCloseTimeoutSeconds
		while next(profiles) ~= nil and os.clock() < deadline do
			task.wait(0.5)
		end
		print("[DataManager] BindToClose: flush complete")
	end)
end

return DataManager
