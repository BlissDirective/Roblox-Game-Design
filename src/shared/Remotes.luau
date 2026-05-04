--!strict
--[[
	Outpost-7 — shared RemoteEvent / RemoteFunction registry.

	Every Remote in the game lives here. The registry pattern means:
	  1. The trust boundary is auditable from a single file.
	  2. Studio's reload cycle (Rojo re-syncing while a place is open)
	     doesn't create duplicate Instances — getOrCreate reuses.
	  3. Adding a Remote = one entry here + one row in
	     docs/architecture/REMOTES_REGISTRY.md.

	Rate limits and validation rules live with the consumers
	(Server/Security/AntiExploit + RemoteValidator). This file is just
	the wire-shape declaration.
--]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CONTAINER_NAME = "OutpostRemotes"

local function ensureContainer(): Folder
	local existing = ReplicatedStorage:FindFirstChild(CONTAINER_NAME)
	if existing and existing:IsA("Folder") then
		return existing
	end
	if existing then
		-- Unexpected non-Folder under that name. Reclaim it.
		existing:Destroy()
	end
	local folder = Instance.new("Folder")
	folder.Name = CONTAINER_NAME
	folder.Parent = ReplicatedStorage
	return folder
end

local function getOrCreate(name: string, className: "RemoteEvent" | "RemoteFunction"): Instance
	local container = ensureContainer()
	local existing = container:FindFirstChild(name)
	if existing and existing:IsA(className) then
		return existing
	end
	if existing then
		-- Type-shape mismatch (e.g. RemoteEvent where we expected
		-- RemoteFunction). Rebuild.
		existing:Destroy()
	end
	local instance = Instance.new(className)
	instance.Name = name
	instance.Parent = container
	return instance
end

local Remotes = {
	-- Phase B1 — Build:
	-- Client → Server. Args: (buildableId: string, cellX: number, cellZ: number).
	-- Server validates and places (or silently rejects). Phase B4 may
	-- add a paired PlacementResult event for UI feedback.
	PlaceBuilding = getOrCreate("PlaceBuilding", "RemoteEvent") :: RemoteEvent,

	-- Phase B2 — Economy:
	-- Server → Client. Args: (newCredits: number).
	-- Notification only — the client renders this for HUD display; it
	-- is not the source of truth. CurrencyService fires per affected
	-- player on every credit change (income tick, spend, grant).
	CreditsChanged = getOrCreate("CreditsChanged", "RemoteEvent") :: RemoteEvent,

	-- Phase C1 — Retention / daily login:
	-- Server → Client. Args: (state: DailyLoginManager.State).
	-- Server pushes the current claim state on join + after each
	-- successful claim. Client renders the popup off this.
	DailyLoginState = getOrCreate("DailyLoginState", "RemoteEvent") :: RemoteEvent,
	-- Client → Server (RemoteFunction). Args: ().
	-- Server validates (server-side os.time, exploit-proof), grants,
	-- returns DailyLoginManager.ClaimResult.
	ClaimDailyReward = getOrCreate("ClaimDailyReward", "RemoteFunction") :: RemoteFunction,
}

return Remotes
