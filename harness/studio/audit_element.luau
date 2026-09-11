--!strict
--[[
	Outpost-7 design harness — Studio-side element audit.

	Run via the Studio MCP `run_code` tool in EDIT mode on the STAGING place.
	Fill CONFIG from harness/design_manifest.json before running. Prints one
	line starting with `HARNESS_AUDIT ` followed by JSON; the Studio Operator
	copies that JSON into harness/artifacts/<id>/studio_audit.json.

	What it checks (per DESIGN_HARNESS.md §3 / prompts/validator.md gate 2–5,
	re-verified inside the engine):
	  - the asset loads via InsertService:LoadAsset (group-owned)
	  - bounding box vs dims_studs (±15%)
	  - MeshPart count + expected sub-mesh names
	  - CollisionFidelity is Box or Hull (never PreciseConvexDecomposition)
	  - TextureID present on every MeshPart
	  - triangle count via EditableMesh when the API permits (else "unknown")
	  - load time

	Never saves the place. Run again with CONFIG.cleanup = true to remove the
	audit pad. Safe to re-run: the pad is rebuilt from scratch each time.
--]]

local InsertService = game:GetService("InsertService")
local AssetService = game:GetService("AssetService")
local HttpService = game:GetService("HttpService")
local Workspace = game:GetService("Workspace")

export type Config = {
	elementId: string,
	assetId: number, -- Models.<PascalId> id from AssetIds.luau (0 = decal-only element)
	dimsStuds: { number }?, -- { x, y, z } from the manifest; nil for 2D tiers
	triBudget: { number }?, -- { min, max }
	submeshes: { string }?, -- expected MeshPart names for multi_mesh
	cleanup: boolean?,
}

-- ====== FILL FROM THE MANIFEST BEFORE RUNNING ======
local CONFIG: Config = {
	elementId = "build_turret_auto",
	assetId = 0,
	dimsStuds = { 2, 4, 2 },
	triBudget = { 1500, 2500 },
	submeshes = { "Base", "Head" },
	cleanup = false,
}
-- ===================================================

local PAD_NAME = "HarnessAudit"
local PAD_POSITION = Vector3.new(2000, 0, 2000) -- far from the 4×2 plot grid
local TOLERANCE = 0.15

local function getOrBuildPad(): Model
	local existing = Workspace:FindFirstChild(PAD_NAME)
	if existing then
		existing:Destroy()
	end
	local pad = Instance.new("Model")
	pad.Name = PAD_NAME
	local floor = Instance.new("Part")
	floor.Name = "Floor"
	floor.Anchored = true
	floor.Size = Vector3.new(48, 1, 48)
	floor.Position = PAD_POSITION
	floor.Material = Enum.Material.Metal
	floor.Color = Color3.fromRGB(40, 44, 50)
	floor.Parent = pad
	pad.Parent = Workspace
	return pad
end

local function countTriangles(meshPart: MeshPart): number?
	-- EditableMesh needs the asset to be creator-owned and the API enabled;
	-- pcall so an unavailable API degrades to "unknown", not a failed audit.
	local ok, result = pcall(function()
		local editable = AssetService:CreateEditableMeshAsync(Content.fromUri(meshPart.MeshId))
		local n = #editable:GetFaces()
		editable:Destroy()
		return n
	end)
	if ok and typeof(result) == "number" then
		return result
	end
	return nil
end

local function audit(config: Config): { [string]: any }
	local report: { [string]: any } = {
		elementId = config.elementId,
		assetId = config.assetId,
		placeId = game.PlaceId,
		checks = {},
		pass = true,
	}
	local checks = report.checks :: { [string]: any }

	local function fail(name: string, detail: any)
		checks[name] = { pass = false, detail = detail }
		report.pass = false
	end
	local function ok(name: string, detail: any)
		checks[name] = { pass = true, detail = detail }
	end

	if config.cleanup then
		local pad = Workspace:FindFirstChild(PAD_NAME)
		if pad then
			pad:Destroy()
		end
		report.cleanup = true
		return report
	end

	if config.assetId <= 0 then
		fail("assetId", "assetId is 0 — element not uploaded, or a 2D-only element (audit not applicable)")
		return report
	end

	local pad = getOrBuildPad()
	local t0 = os.clock()
	local loadOk, loaded = pcall(function()
		return InsertService:LoadAsset(config.assetId)
	end)
	local loadSeconds = os.clock() - t0
	if not loadOk then
		fail("load", tostring(loaded))
		return report
	end
	ok("load", { seconds = loadSeconds })
	local container = loaded :: Model

	-- LoadAsset returns a Model wrapping the asset's contents.
	local root: Instance = container
	local children = container:GetChildren()
	if #children == 1 and children[1]:IsA("Model") then
		root = children[1]
	end
	root.Name = config.elementId
	root.Parent = pad

	local meshParts: { MeshPart } = {}
	for _, d in root:GetDescendants() do
		if d:IsA("MeshPart") then
			table.insert(meshParts, d)
		end
	end
	if #meshParts == 0 then
		fail("meshparts", "no MeshPart found in the loaded asset")
		return report
	end
	local meshNames: { string } = {}
	for _, m in meshParts do
		table.insert(meshNames, m.Name)
	end
	ok("meshparts", { count = #meshParts, names = meshNames })

	-- Place base on the pad floor and measure.
	local model = if root:IsA("Model") then root :: Model else nil
	if model then
		model:PivotTo(CFrame.new(PAD_POSITION + Vector3.new(0, 0.5, 0)))
		local cf, size = model:GetBoundingBox()
		local minY = cf.Position.Y - size.Y / 2
		model:PivotTo(model:GetPivot() * CFrame.new(0, (PAD_POSITION.Y + 0.5) - minY, 0))
		cf, size = model:GetBoundingBox()
		report.bbox = { size.X, size.Y, size.Z }
		if config.dimsStuds then
			local within = true
			local ratios = {}
			local measured = { size.X, size.Y, size.Z }
			for i = 1, 3 do
				local expected = config.dimsStuds[i]
				local ratio = if expected > 0 then measured[i] / expected else 1
				ratios[i] = ratio
				if ratio < 1 - TOLERANCE or ratio > 1 + TOLERANCE then
					within = false
				end
			end
			if within then
				ok("bbox", { measured = measured, expected = config.dimsStuds, ratios = ratios })
			else
				fail("bbox", { measured = measured, expected = config.dimsStuds, ratios = ratios })
			end
		end
	end

	-- Sub-mesh names.
	if config.submeshes then
		local missing = {}
		for _, name in config.submeshes do
			if not root:FindFirstChild(name, true) then
				table.insert(missing, name)
			end
		end
		if #missing == 0 then
			ok("submeshes", config.submeshes)
		else
			fail("submeshes", { missing = missing })
		end
	end

	-- Collision fidelity + textures + triangles.
	local badCollision, noTexture = {}, {}
	local totalTris: number? = 0
	for _, m in meshParts do
		if m.CollisionFidelity == Enum.CollisionFidelity.PreciseConvexDecomposition then
			table.insert(badCollision, m.Name)
		end
		if m.TextureID == "" then
			table.insert(noTexture, m.Name)
		end
		local tris = countTriangles(m)
		if tris == nil then
			totalTris = nil
		elseif totalTris ~= nil then
			totalTris += tris
		end
	end
	if #badCollision == 0 then
		ok("collision", "no PreciseConvexDecomposition")
	else
		fail("collision", { preciseConvex = badCollision })
	end
	if #noTexture == 0 then
		ok("textures", "every MeshPart has a TextureID")
	else
		fail("textures", { untextured = noTexture })
	end
	if totalTris == nil then
		-- Not a failure: the offline Validator (gate 2) is authoritative for tris.
		ok("triangles", "unknown in-engine (EditableMesh unavailable)")
	elseif config.triBudget then
		local t = totalTris :: number
		if t >= config.triBudget[1] and t <= config.triBudget[2] then
			ok("triangles", { value = t, budget = config.triBudget })
		else
			fail("triangles", { value = t, budget = config.triBudget })
		end
	end

	report.loadedInstance = root:GetFullName()
	return report
end

local report = audit(CONFIG)
print("HARNESS_AUDIT " .. HttpService:JSONEncode(report))
