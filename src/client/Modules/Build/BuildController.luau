--!strict
--[[
	Outpost-7 — build mode orchestrator (client).

	Phase B4 wires palette + preview + input → PlaceBuilding Remote.
	Phase B5 adds mode-awareness: out of Build mode the palette hides,
	any in-progress selection clears, and the preview tears down. No
	build-mode-only Remotes are sent during Combat / Raid.

	Server validates everything authoritatively (PlacementService);
	we send the snap coords without trusting the advisory client-side
	validity flag (the server doesn't trust us, and we shouldn't trust
	ourselves either — same boundary).
--]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Enums = require(Shared:WaitForChild("Enums"))
local Remotes = require(Shared:WaitForChild("Remotes"))

local BuildPalette = require(script.Parent.BuildPalette)
local PlacementPreview = require(script.Parent.PlacementPreview)
local ModeController = require(script.Parent.Parent.Core.ModeController)
local ToastService = require(script.Parent.Parent.HUD.ToastService)

local BuildController = {}

local function tryFireRemote()
	-- Mode gate: only Build mode sends placement Remotes.
	if ModeController.GetMode() ~= Enums.Mode.Build then
		return
	end
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

-- R4: humanize server placement-failure reasons for the toast.
local FAIL_MESSAGES: { [string]: string } = {
	["insufficient credits"] = "Not enough Credits",
	["cell already occupied"] = "That spot is taken",
	["cell outside plot"] = "Outside your plot",
	["no resource node at cell"] = "Extractors need a resource node",
	["node already claimed"] = "That node is already claimed",
	["no plot allocated"] = "No plot yet — hang tight",
}

function BuildController.Init()
	BuildPalette.Init()

	-- R4: toast placement failures (previously silent — audit §4.8).
	local resultRemote = Remotes.PlacementResult :: RemoteEvent
	resultRemote.OnClientEvent:Connect(function(result: any)
		if typeof(result) ~= "table" or result.ok then
			return
		end
		local reason = if typeof(result.reason) == "string" then result.reason else ""
		ToastService.ShowError(FAIL_MESSAGES[reason] or "Can't build there")
	end)
	BuildPalette.OnSelectionChanged(function(buildableId: string?)
		if buildableId then
			PlacementPreview.Show(buildableId)
		else
			PlacementPreview.Hide()
		end
	end)

	-- Hide the palette when the player isn't in Build mode. Selection
	-- clearing also hides the preview (via OnSelectionChanged → Hide).
	ModeController.OnModeChanged(function(newMode: string, _oldMode: string)
		if newMode == Enums.Mode.Build then
			BuildPalette.Show()
		else
			BuildPalette.SetSelected(nil)
			BuildPalette.Hide()
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
