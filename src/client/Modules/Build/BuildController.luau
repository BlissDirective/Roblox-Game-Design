--!strict
--[[
	Outpost-7 — build mode orchestrator (client).

	Phase B4. Wires the three pieces of the build loop together:
	  - BuildPalette emits selection changes
	  - PlacementPreview renders + tracks the snapped cell
	  - Tap/click on the world fires the PlaceBuilding Remote

	Server validates everything authoritatively (PlacementService);
	we send the snap coords without trusting the advisory client-side
	validity flag (the server doesn't trust us, and we shouldn't trust
	ourselves either — same boundary).
--]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Remotes = require(Shared:WaitForChild("Remotes"))

local BuildPalette = require(script.Parent.BuildPalette)
local PlacementPreview = require(script.Parent.PlacementPreview)

local BuildController = {}

local function tryFireRemote()
	local selected = BuildPalette.GetSelected()
	if not selected then
		return
	end
	local snap = PlacementPreview.GetSnap()
	if not snap then
		return
	end
	-- Skip the round-trip when the client-side advisory check failed.
	-- The server will reject anyway; saving the Remote keeps the wire
	-- quiet during cursor sweeps over invalid cells.
	if not snap.valid then
		return
	end
	local remote = Remotes.PlaceBuilding :: RemoteEvent
	remote:FireServer(selected, snap.x, snap.z)
end

function BuildController.Init()
	BuildPalette.Init()
	BuildPalette.OnSelectionChanged(function(buildableId: string?)
		if buildableId then
			PlacementPreview.Show(buildableId)
		else
			PlacementPreview.Hide()
		end
	end)

	UserInputService.InputBegan:Connect(function(input: InputObject, processed: boolean)
		if processed then
			-- Input was consumed by GUI (e.g., palette button).
			return
		end
		if
			input.UserInputType == Enum.UserInputType.MouseButton1
			or input.UserInputType == Enum.UserInputType.Touch
		then
			tryFireRemote()
		end
	end)
end

return BuildController
