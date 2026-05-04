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
local RunService = game:GetService("RunService")
local ServerScriptService = game:GetService("ServerScriptService")

local ProfileStore = require(ServerScriptService:WaitForChild("ServerPackages"):WaitForChild("ProfileStore"))
local ProfileSchema = require(script.Parent.ProfileSchema)

type PlayerData = ProfileSchema.PlayerData

-- ProfileStore's Profile<T> type isn't easily importable; treat as opaque.
type Profile = any

local DataManager = {}

local STORE_NAME = "PlayerData_v1"

-- One ProfileStore instance for V1. `.Mock` in Studio so the audit loop
-- exercises the same join → mutate → leave → rejoin shape as live.
local profileStore = ProfileStore.New(STORE_NAME, ProfileSchema.DEFAULT_DATA)
if RunService:IsStudio() then
	profileStore = profileStore.Mock
end

local profiles: { [Player]: Profile } = {}
local loadedSignals: { [Player]: BindableEvent } = {}
-- Set when we initiate the session end (PlayerRemoving / BindToClose) so
-- OnSessionEnd can distinguish our own teardown from a cross-server steal.
local intentionalEnd: { [Player]: boolean } = {}

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

	-- Bookkeeping fields prove round-trip persistence to the A2 audit:
	-- firstJoinAt is sticky; lastJoinAt + sessionsPlayed advance every load.
	local now = os.time()
	profile.Data.firstJoinAt = profile.Data.firstJoinAt or now
	profile.Data.lastJoinAt = now
	profile.Data.sessionsPlayed += 1

	profiles[player] = profile
	fireLoaded(player)
end

function DataManager.SavePlayer(player: Player)
	local profile = profiles[player]
	if not profile then
		return
	end
	intentionalEnd[player] = true
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
	end)

	game:BindToClose(function()
		for player in pairs(profiles) do
			task.spawn(DataManager.SavePlayer, player)
		end
		-- Wait until every active session has fully ended (or 25s timeout —
		-- BindToClose's hard ceiling is 30s).
		local deadline = os.clock() + 25
		while next(profiles) ~= nil and os.clock() < deadline do
			task.wait(0.5)
		end
	end)
end

return DataManager
