--!strict
--[[
	Outpost-7 — shared RemoteEvent / RemoteFunction registry.

	Every Remote in the game lives here. The registry pattern means:
	  1. The trust boundary is auditable from a single file.
	  2. Studio's reload cycle (Rojo re-syncing while a place is open)
	     doesn't create duplicate Instances — getOrCreate reuses.
	  3. Adding a Remote = one entry here + one row in
	     docs/architecture/REMOTES_REGISTRY.md.

	A3 ships the helper + an empty registry. Phases B+ register their
	Remotes by appending to the `Remotes` table at the bottom.

	Registration shape (uncomment per phase that adds the Remote):

	    local Remotes = {
	        CoinChanged   = getOrCreate("CoinChanged",   "RemoteEvent")    :: RemoteEvent,
	        PlaceBuilding = getOrCreate("PlaceBuilding", "RemoteEvent")    :: RemoteEvent,
	        ClaimDaily    = getOrCreate("ClaimDaily",    "RemoteFunction") :: RemoteFunction,
	    }
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

-- selene: allow(unused_variable)
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
	-- Phases B+ register Remotes here.
}

return Remotes
