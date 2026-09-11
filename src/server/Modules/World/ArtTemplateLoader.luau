--!strict
--[[
	Outpost-7 — boot-time loader for uploaded art templates.

	Phase H4 (design harness). Every `AssetIds.Models.<Key>` that is no longer
	the placeholder is loaded once at server boot via InsertService:LoadAsset
	(the asset is group-owned and the experience is group-owned, so the load
	is permitted) and parked under ServerStorage.<Constants.ART.TemplatesFolderName>.
	Consumers ask `ArtTemplateLoader.Get("BuildTurretAuto")` and get a Model
	to clone through Shared.Lib.VisualAttach — or nil, in which case they keep
	their procedural placeholder. Nothing in the game ever hard-depends on a
	template existing.

	Init yields up to Constants.ART.LoadTimeoutSeconds so PlotManager /
	BuildRestorer see the templates on the first player's join; anything
	still loading after the deadline just lands late (later placements pick
	it up; earlier ones keep the placeholder until the next server).

	Gated by Constants.FEATURES.artPipeline. With every id at the
	placeholder, Init is a no-op that prints nothing but a count.

	Public API:
	  Init()                — load all non-placeholder Models (yields ≤ timeout)
	  Get(key: string?)     — Model? for an AssetIds.Models key
	  Count()               — how many templates loaded
--]]

local InsertService = game:GetService("InsertService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Constants = require(Shared:WaitForChild("Constants"))
local AssetIds = require(Shared:WaitForChild("AssetIds"))

local ArtTemplateLoader = {}

local templates: { [string]: Model } = {}
local folder: Folder? = nil
local loadedCount = 0

local function ensureFolder(): Folder
	if folder then
		return folder
	end
	local name = Constants.ART.TemplatesFolderName
	local existing = ServerStorage:FindFirstChild(name)
	if existing and existing:IsA("Folder") then
		existing:ClearAllChildren()
		folder = existing
		return existing
	end
	local f = Instance.new("Folder")
	f.Name = name
	f.Parent = ServerStorage
	folder = f
	return f
end

-- "rbxassetid://123" → 123; nil for the placeholder or malformed ids.
local function parseAssetId(uri: string?): number?
	if AssetIds.isPlaceholder(uri) then
		return nil
	end
	local digits = string.match(uri :: string, "^rbxassetid://(%d+)$")
	if not digits then
		return nil
	end
	local id = tonumber(digits)
	if id and id > 0 then
		return id
	end
	return nil
end

-- LoadAsset returns a wrapper Model containing the asset's top-level
-- instances. A Model upload yields wrapper → Model → MeshParts; unwrap one
-- level when that is the shape so consumers get the authored Model.
local function unwrap(container: Model): Model
	local children = container:GetChildren()
	if #children == 1 and children[1]:IsA("Model") then
		return children[1] :: Model
	end
	return container
end

local function loadOne(key: string, assetId: number, parent: Folder)
	local ok, result = pcall(function()
		return InsertService:LoadAsset(assetId)
	end)
	if not ok or not result then
		warn(
			string.format("[ArtTemplateLoader] %s (rbxassetid://%d) failed to load: %s", key, assetId, tostring(result))
		)
		return
	end
	local container = result :: Model
	local model = unwrap(container)
	model.Name = key
	model.Parent = parent
	if model ~= container then
		container:Destroy()
	end
	templates[key] = model
	loadedCount += 1
end

function ArtTemplateLoader.Init()
	if not Constants.FEATURES.artPipeline then
		print("[ArtTemplateLoader] artPipeline flag off; procedural placeholders only")
		return
	end
	local parent = ensureFolder()
	local pending = 0
	local models: { [string]: string } = (AssetIds :: any).Models or {}
	for key, uri in models do
		local assetId = parseAssetId(uri)
		if assetId then
			pending += 1
			task.spawn(function()
				loadOne(key, assetId, parent)
				pending -= 1
			end)
		end
	end
	local deadline = os.clock() + Constants.ART.LoadTimeoutSeconds
	while pending > 0 and os.clock() < deadline do
		task.wait(0.1)
	end
	if pending > 0 then
		warn(
			string.format(
				"[ArtTemplateLoader] %d template(s) still loading after %ds; they attach late",
				pending,
				Constants.ART.LoadTimeoutSeconds
			)
		)
	end
	print(string.format("[ArtTemplateLoader] %d template(s) loaded", loadedCount))
end

function ArtTemplateLoader.Get(key: string?): Model?
	if not key then
		return nil
	end
	return templates[key]
end

function ArtTemplateLoader.Count(): number
	return loadedCount
end

return ArtTemplateLoader
