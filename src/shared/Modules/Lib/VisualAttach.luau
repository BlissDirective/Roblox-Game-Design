--!strict
--[[
	Outpost-7 — attach an imported art template to a procedural placeholder.

	Phase H4 (design harness). Every gameplay object in V1 is a procedural
	Part (buildables, aliens, drones, resource nodes) and the whole trust /
	collision / targeting stack keys off that Part: attributes (MaxHp,
	CellX…), raycasts (weapon hits), Touched (alien melee), TurretService
	muzzle math. Swapping the Part for a Model would touch all of it.

	Instead, the imported MeshPart model is cloned UNDER the Part as a child
	named `Constants.ART.VisualName`, the Part goes invisible, and nothing
	else changes:
	  - the Part keeps CanCollide / CanQuery / CanTouch → physics, raycasts,
	    and touch detection are unchanged
	  - visual parts are CanCollide=false, CanQuery=false, CanTouch=false,
	    Massless — they can never intercept a hit or add mass
	  - static mode (anchored structures): visual parts are Anchored
	  - dynamic mode (aliens, drones): visual parts are unanchored and
	    WeldConstraint-ed to the root so they follow Humanoid / CFrame moves
	  - the visual's bounding box is centered on the Part in XZ and its
	    bottom is aligned to the Part's bottom, so a "base flat to ground"
	    FBX (the harness's export rule) sits on the floor regardless of
	    where the importer put the pivot

	Shared (not server-only) because the client PlacementPreview may later
	want the same helper for ghost previews. Templates themselves live in
	ServerStorage and are resolved server-side by Server.World.ArtTemplateLoader.
--]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Constants = require(Shared:WaitForChild("Constants"))

local VisualAttach = {}

local function preparePart(root: BasePart, descendant: BasePart, dynamic: boolean)
	descendant.CanCollide = false
	descendant.CanQuery = false
	descendant.CanTouch = false
	descendant.Massless = true
	if dynamic then
		descendant.Anchored = false
		local weld = Instance.new("WeldConstraint")
		weld.Part0 = root
		weld.Part1 = descendant
		weld.Parent = descendant
	else
		descendant.Anchored = true
	end
end

-- Clone `template` under `root`, aligned to it. Returns the visual Model, or
-- nil when there is no template (procedural placeholder stays visible).
-- Idempotent: an existing visual is replaced.
function VisualAttach.Attach(root: BasePart, template: Model?, dynamic: boolean?): Model?
	if not template then
		return nil
	end
	local existing = root:FindFirstChild(Constants.ART.VisualName)
	if existing then
		existing:Destroy()
	end

	local visual = template:Clone()
	visual.Name = Constants.ART.VisualName

	-- Orient like the root, then re-center on the root's XZ and drop the
	-- bounding box's bottom onto the root's bottom face.
	visual:PivotTo(root.CFrame)
	local boxCFrame, boxSize = visual:GetBoundingBox()
	local rootBottomY = root.Position.Y - root.Size.Y / 2
	local boxBottomY = boxCFrame.Position.Y - boxSize.Y / 2
	local delta = Vector3.new(
		root.Position.X - boxCFrame.Position.X,
		rootBottomY - boxBottomY,
		root.Position.Z - boxCFrame.Position.Z
	)
	visual:PivotTo(visual:GetPivot() + delta)

	local isDynamic = dynamic == true
	for _, descendant in visual:GetDescendants() do
		if descendant:IsA("BasePart") then
			preparePart(root, descendant, isDynamic)
		end
	end

	visual.Parent = root
	root.Transparency = 1
	root:SetAttribute(Constants.ART.HasVisualAttribute, true)
	return visual
end

-- Remove an attached visual and restore the placeholder's visibility.
function VisualAttach.Detach(root: BasePart)
	local existing = root:FindFirstChild(Constants.ART.VisualName)
	if existing then
		existing:Destroy()
	end
	root.Transparency = 0
	root:SetAttribute(Constants.ART.HasVisualAttribute, nil)
end

-- Clone a template as a free-standing anchored decoration at `cframe`
-- (bounding-box bottom at the cframe's Y, centered on its XZ). Used for
-- flora, cave overlay, arches — things that have no gameplay Part.
function VisualAttach.Place(template: Model, cframe: CFrame, scaleToHeight: number?): Model
	local clone = template:Clone()
	if scaleToHeight and scaleToHeight > 0 then
		local _, size = clone:GetBoundingBox()
		if size.Y > 0 then
			clone:ScaleTo(scaleToHeight / size.Y)
		end
	end
	clone:PivotTo(cframe)
	local boxCFrame, boxSize = clone:GetBoundingBox()
	local delta = Vector3.new(
		cframe.Position.X - boxCFrame.Position.X,
		cframe.Position.Y - (boxCFrame.Position.Y - boxSize.Y / 2),
		cframe.Position.Z - boxCFrame.Position.Z
	)
	clone:PivotTo(clone:GetPivot() + delta)
	for _, descendant in clone:GetDescendants() do
		if descendant:IsA("BasePart") then
			descendant.Anchored = true
			descendant.CanCollide = false
			descendant.CanQuery = false
			descendant.CanTouch = false
			descendant.CastShadow = false
		end
	end
	return clone
end

return VisualAttach
